#!/usr/bin/env bash
set -euo pipefail

DEVCONTAINERS_PREFIX="${DEVCONTAINERS_PREFIX:-$HOME/.devcontainers}"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
BASH_ALIASES_FILE="${BASH_ALIASES_FILE:-$HOME/.bash_aliases}"
BASHRC="${BASHRC:-$HOME/.bashrc}"

echo "==> Checking requirements"

for required_command in curl podman; do
  command -v "$required_command" >/dev/null 2>&1 || {
    echo "error: $required_command is required" >&2
    exit 1
  }
done

echo "==> Installing / updating Dev Containers CLI"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL \
  https://raw.githubusercontent.com/devcontainers/cli/main/scripts/install.sh \
  -o "$tmp/install-devcontainer-cli.sh"

installer_args=(--prefix "$DEVCONTAINERS_PREFIX")
if [ -f "$DEVCONTAINERS_PREFIX/.metadata/installed-version" ]; then
  installer_args+=(--update)
fi

sh "$tmp/install-devcontainer-cli.sh" "${installer_args[@]}"

echo "==> Linking devcontainer into ~/.local/bin"

mkdir -p "$LOCAL_BIN"
ln -sf "$DEVCONTAINERS_PREFIX/bin/devcontainer" "$LOCAL_BIN/devcontainer"

echo "==> Installing shell helpers into ~/.bash_aliases"

HELPERS_FILE="$tmp/devcontainers.bash"

cat > "$HELPERS_FILE" <<'EOF'
# Dev Containers CLI helpers for Podman.
# Override the default UTF-8 locale for a single invocation with, for example:
#   DC_LANG=en_US.UTF-8 dc
# Override the workspace-derived SSH alias or a non-standard container home:
#   DC_SSH_ALIAS=my-project dc
#   DC_REMOTE_HOME=/opt/dev dc
# Show CLI banners and setup JSON for one invocation with DC_VERBOSE=1 dc.
# Command mode hides all successful setup chatter unless DC_VERBOSE=1.
# Containers get dc-<project-directory>-<short-container-id> names after up.
# Explicit runArgs --name and Docker Compose names take precedence.

_dc_workspace() {
  local dir="$PWD"

  while [ "$dir" != "/" ]; do
    if [ -f "$dir/.devcontainer/devcontainer.json" ] || [ -f "$dir/.devcontainer.json" ]; then
      printf '%s\n' "$dir"
      return 0
    fi

    dir="$(dirname "$dir")"
  done

  echo "dc: could not find .devcontainer/devcontainer.json or .devcontainer.json in parent directories" >&2
  return 1
}

_dc_cli() {
  local subcommand="$1" workspace="$2"
  local -a local_args=()
  shift 2

  case "$subcommand" in
    up | exec)
      local_args=(
        --remote-env "LANG=${DC_LANG:-C.UTF-8}"
        --remote-env "LC_ALL=${DC_LANG:-C.UTF-8}"
      )
      if [ -S "${SSH_AUTH_SOCK:-}" ]; then
        local_args+=(--remote-env "SSH_AUTH_SOCK=/tmp/ssh-agent.sock")
      fi
      if [ -d "$HOME/.codex" ]; then
        local_args+=(--remote-env "CODEX_HOME=$HOME/.codex")
      fi
      # Use Claude's default home paths: CLAUDE_CONFIG_DIR also relocates
      # .claude.json and would hide the separately mounted login state.
      if [ -d "$HOME/.claude" ]; then
        local_args+=(--remote-env "DISABLE_AUTOUPDATER=1")
      fi
      ;;
  esac

  set -- devcontainer "$subcommand" \
    --workspace-folder "$workspace" --docker-path podman \
    "${local_args[@]}" "$@"

  # Hide only the CLI version banner; keep progress/errors live. A command
  # executed inside the container must retain its own stderr verbatim.
  if [ "$subcommand" != "exec" ] && [ "${DC_VERBOSE:-0}" != "1" ]; then
    # Close the saved stdout FD in both children: background Podman processes
    # must not inherit it and keep a caller's output capture open.
    {
      "$@" 2>&1 1>&3 3>&- | sed -u '/^\[[^]]*\] @devcontainers\/cli /d' >&2 3>&-
      return "${PIPESTATUS[0]}"
    } 3>&1
  else
    "$@"
  fi
}

_dc_project_ssh_dir() {
  local workspace="$1"
  local runtime_uid runtime_dir dir_uid workspace_id ssh_dir

  runtime_uid="$(id -u)" || {
    echo "dc: could not determine the current user id for the private runtime directory" >&2
    return 1
  }
  if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    runtime_dir="$XDG_RUNTIME_DIR/devcontainers"
  else
    runtime_dir="${TMPDIR:-/tmp}/devcontainers-$runtime_uid"
  fi

  if [ -L "$runtime_dir" ]; then
    echo "dc: refusing symlink runtime directory $runtime_dir" >&2
    return 1
  fi
  if ! (umask 077 && mkdir -p -- "$runtime_dir") || ! chmod 700 -- "$runtime_dir"; then
    echo "dc: could not create a private runtime directory at $runtime_dir" >&2
    return 1
  fi
  dir_uid="$(stat -c %u -- "$runtime_dir")" || {
    echo "dc: could not verify owner of private runtime directory $runtime_dir" >&2
    return 1
  }
  if [ "$dir_uid" != "$runtime_uid" ]; then
    echo "dc: refusing runtime directory not owned by the current user: $runtime_dir" >&2
    return 1
  fi

  command -v sha256sum >/dev/null 2>&1 || {
    echo "dc: sha256sum is required to name private runtime files safely" >&2
    return 1
  }
  workspace_id="$(printf '%s' "$workspace" | sha256sum)" || {
    echo "dc: could not identify workspace $workspace for its runtime files" >&2
    return 1
  }
  workspace_id="${workspace_id%% *}"
  ssh_dir="$runtime_dir/ssh-$workspace_id"

  if [ -L "$ssh_dir" ] || { [ -e "$ssh_dir" ] && [ ! -d "$ssh_dir" ]; }; then
    echo "dc: refusing unsafe project SSH directory $ssh_dir" >&2
    return 1
  fi
  if ! (umask 077 && mkdir -p -- "$ssh_dir") || ! chmod 700 -- "$ssh_dir"; then
    echo "dc: could not create private project SSH directory $ssh_dir" >&2
    return 1
  fi

  printf '%s\n' "$ssh_dir"
}

_dc_project_ssh_config() {
  local workspace="$1"
  local ssh_alias effective_config key value
  local hostname="" ssh_user="" port=""
  local ssh_dir ssh_config known_hosts path

  ssh_alias="${DC_SSH_ALIAS:-${workspace##*/}}"

  # Host patterns have wildcard semantics, so keep the generated section tied
  # to one literal alias and prevent config-line injection.
  case "$ssh_alias" in
    "" | *[!A-Za-z0-9._-]*)
      echo "dc: invalid SSH alias '$ssh_alias'; use only letters, digits, dot, underscore, and hyphen" >&2
      return 1
      ;;
  esac

  command -v ssh >/dev/null 2>&1 || {
    echo "dc: ssh is required to resolve config for alias '$ssh_alias'" >&2
    return 1
  }

  if ! effective_config="$(ssh -G -T -- "$ssh_alias")"; then
    echo "dc: ssh -G failed for alias '$ssh_alias'; project SSH config was not mounted" >&2
    return 1
  fi

  while read -r key value _; do
    case "$key" in
      hostname) [ -n "$hostname" ] || hostname="$value" ;;
      user) [ -n "$ssh_user" ] || ssh_user="$value" ;;
      port) [ -n "$port" ] || port="$value" ;;
    esac
  done <<<"$effective_config"

  if [ -z "$hostname" ] || [ -z "$ssh_user" ] || [ -z "$port" ]; then
    echo "dc: ssh -G returned incomplete config for alias '$ssh_alias' (HostName, User, and Port are required)" >&2
    return 1
  fi

  case "$hostname$ssh_user" in
    *[$' \t\r\n#']*)
      echo "dc: ssh -G returned an unsafe HostName or User for alias '$ssh_alias'" >&2
      return 1
      ;;
  esac
  case "$port" in
    "" | *[!0-9]*)
      echo "dc: ssh -G returned an invalid Port for alias '$ssh_alias'" >&2
      return 1
      ;;
  esac

  ssh_dir="$(_dc_project_ssh_dir "$workspace")" || return 1
  ssh_config="$ssh_dir/config"
  known_hosts="$ssh_dir/known_hosts"

  for path in "$ssh_config" "$known_hosts"; do
    if [ -L "$path" ] || { [ -e "$path" ] && [ ! -f "$path" ]; }; then
      echo "dc: refusing unsafe project SSH file $path" >&2
      return 1
    fi
    if [ ! -e "$path" ] && ! (umask 077 && : >"$path"); then
      echo "dc: could not create private project SSH file $path" >&2
      return 1
    fi
    if ! chmod 600 -- "$path"; then
      echo "dc: could not secure private project SSH file $path" >&2
      return 1
    fi
  done

  if [ ! -s "$known_hosts" ] && [ -r "$HOME/.ssh/known_hosts" ]; then
    if ! cat -- "$HOME/.ssh/known_hosts" >"$known_hosts"; then
      echo "dc: could not copy host SSH known_hosts to $known_hosts" >&2
      return 1
    fi
  fi

  # Rewrite the existing inode: a running container may already have this file
  # bind-mounted and should see host config changes without being rebuilt.
  if ! printf 'Host %s\n    HostName %s\n    User %s\n    Port %s\n' \
    "$ssh_alias" "$hostname" "$ssh_user" "$port" >"$ssh_config"; then
    echo "dc: could not write project SSH config $ssh_config" >&2
    return 1
  fi

  printf '%s\n' "$ssh_dir"
}

_dc_configuration() {
  local workspace="$1"

  command -v jq >/dev/null 2>&1 || {
    echo "dc: jq is required to read the devcontainer configuration" >&2
    return 1
  }

  _dc_cli read-configuration "$workspace" --include-merged-configuration || {
    echo "dc: could not read devcontainer configuration for $workspace" >&2
    return 1
  }
}

# The CLI only turns "appPort" into published ports; "forwardPorts" is an
# editor-only setting it merges and then ignores. Report what the config asks
# for so _dc_print_ports can say why a port is unreachable from the host.
_dc_forward_ports() {
  local configuration="$1"

  jq -r '
    ( .mergedConfiguration.forwardPorts
      // .configuration.forwardPorts
      // []
    )
    | map(tostring)
    | join(" ")
  ' <<<"$configuration" || {
    echo "dc: could not read forwardPorts from the devcontainer configuration" >&2
    return 1
  }
}

_dc_remote_home() {
  local configuration="$1"
  local remote_user remote_home

  if [ -n "${DC_REMOTE_HOME:-}" ]; then
    remote_home="$DC_REMOTE_HOME"
  else
    remote_user="$(jq -er '
      .mergedConfiguration.remoteUser
      // .configuration.remoteUser
      // .mergedConfiguration.containerUser
      // .configuration.containerUser
      // empty
    ' <<<"$configuration")" || {
      echo "dc: could not determine the devcontainer remote user; set DC_REMOTE_HOME explicitly" >&2
      return 1
    }
    case "$remote_user" in
      "" | *[!A-Za-z0-9._-]*)
        echo "dc: invalid devcontainer remote user '$remote_user'; set DC_REMOTE_HOME explicitly" >&2
        return 1
        ;;
      root) remote_home="/root" ;;
      *) remote_home="/home/$remote_user" ;;
    esac
  fi

  case "$remote_home" in
    /*) ;;
    *)
      echo "dc: remote home must be an absolute path: $remote_home" >&2
      return 1
      ;;
  esac
  case "$remote_home" in
    *,* | *[$'\r\n']*)
      echo "dc: remote home cannot contain commas or newlines: $remote_home" >&2
      return 1
      ;;
  esac

  printf '%s\n' "$remote_home"
}

_dc_name_container() {
  local workspace="$1" container_id="$2" configuration="$3"
  local container_name current_name

  # Keep explicit/Compose names. Otherwise use the directory and a short ID to
  # separate worktrees and containers; recreating a container changes the ID.
  if ! container_name="$(jq -r \
    --arg project "${workspace##*/}" --arg id "$container_id" '
    (.mergedConfiguration // .configuration)
    | if has("dockerComposeFile")
      or any(.runArgs[]?; . == "--name" or startswith("--name="))
      then empty
      else
        $project | ascii_downcase | gsub("[^a-z0-9_.-]+"; "-")
        | .[0:48] | gsub("^[._-]+|[._-]+$"; "")
        | if . == "" then "workspace" else . end
        | "dc-\(.)-\($id[0:6])"
      end
  ' <<<"$configuration")"; then
    echo "dc: warning: could not generate a container name for $workspace" >&2
    return 0
  fi
  [ -n "$container_name" ] || return 0

  if ! current_name="$(podman inspect --format '{{.Name}}' "$container_id")"; then
    echo "dc: warning: could not inspect name of container $container_id" >&2
    return 0
  fi
  [ "${current_name#/}" != "$container_name" ] || return 0

  # Naming is cosmetic: a collision or a concurrent removal must not break dc.
  # CLI lookup and our stop/down helpers continue to use labels and IDs.
  if ! podman rename "$container_id" "$container_name"; then
    echo "dc: warning: could not rename container $container_id to $container_name; keeping its current name" >&2
    return 0
  fi
  if [ "${DC_VERBOSE:-0}" = "1" ]; then
    echo "dc: container $container_name"
  fi
}

_dc_up() {
  local workspace="$1"
  local ssh_dir configuration remote_home forward_ports path
  local up_result container_id
  local -a local_args=()
  shift

  ssh_dir="$(_dc_project_ssh_config "$workspace")" || return 1
  configuration="$(_dc_configuration "$workspace")" || return 1
  remote_home="$(_dc_remote_home "$configuration")" || return 1
  forward_ports="$(_dc_forward_ports "$configuration")" || return 1
  case "$ssh_dir" in
    *,* | *[$'\r\n']*)
      echo "dc: project SSH directory cannot contain commas or newlines: $ssh_dir" >&2
      return 1
      ;;
  esac
  local_args+=(
    --mount "type=bind,source=$ssh_dir,target=$remote_home/.ssh"
  )

  if [ -S "${SSH_AUTH_SOCK:-}" ]; then
    local_args+=(--mount "type=bind,source=$SSH_AUTH_SOCK,target=/tmp/ssh-agent.sock")
  fi

  # Preserve host paths for tools and symlink targets in ~/.local/bin.
  for path in "$HOME/.local/bin" "$HOME/.codex" "$HOME/.local/share/claude"; do
    if [ -d "$path" ]; then
      local_args+=(--mount "type=bind,source=$path,target=$path")
    fi
  done

  # These tools use the container user's home; Claude also needs .claude.json
  # beside .claude/ to recognize the logged-in account.
  for path in .skot .claude; do
    if [ -d "$HOME/$path" ]; then
      local_args+=(--mount "type=bind,source=$HOME/$path,target=$remote_home/$path")
    fi
  done
  if [ -f "$HOME/.claude.json" ]; then
    local_args+=(--mount "type=bind,source=$HOME/.claude.json,target=$remote_home/.claude.json")
  fi

  # The CLI writes progress to stderr and its JSON result to stdout. Use the
  # returned ID so only this container is renamed, even with several configs.
  if ! up_result="$(_dc_cli up "$workspace" \
    --terminal-columns "${COLUMNS:-120}" \
    --terminal-rows "${LINES:-40}" \
    "${local_args[@]}" \
    "$@")"; then
    [ -z "$up_result" ] || printf '%s\n' "$up_result"
    echo "dc: devcontainer up failed; project SSH directory was not mounted from $ssh_dir" >&2
    return 1
  fi
  if [ "${DC_VERBOSE:-0}" = "1" ]; then
    printf '%s\n' "$up_result"
  fi

  if container_id="$(jq -er '
    .containerId | select(type == "string" and test("^[0-9a-f]{64}$"))
  ' <<<"$up_result")"; then
    _dc_name_container "$workspace" "$container_id" "$configuration"
  else
    echo "dc: warning: devcontainer up returned no valid container ID; skipping container naming" >&2
  fi

  _dc_print_ports "$workspace" "$forward_ports"
}

# Hide successful setup in command mode; show diagnostics on failure or when
# DC_VERBOSE=1. The command's own stdout/stderr stay live in _dc_exec.
_dc_up_quiet() {
  local output

  if [ "${DC_VERBOSE:-0}" = "1" ]; then
    _dc_up "$@"
    return
  fi

  if ! output="$(_dc_up "$@" 2>&1)"; then
    [ -z "$output" ] || printf '%s\n' "$output" >&2
    return 1
  fi
}

_dc_exec() {
  local workspace="$1"
  shift

  if [ -d "$HOME/.local/bin" ]; then
    set -- sh -c 'PATH="$PATH:$1"; export PATH; shift; exec "$@"' \
      sh "$HOME/.local/bin" "$@"
  fi
  _dc_cli exec "$workspace" "$@"
}

_dc_print_ports() {
  local workspace="$1"
  local forward_ports="${2:-}"
  local output line container_port host_endpoint id
  local printed=0
  local published=" " wanted missing=""
  local IFS=$' \t\n'
  local -a ids

  if ! output="$(podman ps -q \
    --filter "label=devcontainer.local_folder=$workspace")"; then
    echo "dc: warning: could not inspect published ports for $workspace" >&2
    return 0
  fi
  [ -n "$output" ] || return 0
  readarray -t ids <<<"$output"

  for id in "${ids[@]}"; do
    if ! output="$(podman port "$id")"; then
      echo "dc: warning: could not inspect published ports for container $id" >&2
      continue
    fi

    while IFS= read -r line; do
      case "$line" in
        *" -> "*)
          container_port="${line%% -> *}"
          host_endpoint="${line#* -> }"
          if [ "$printed" -eq 0 ]; then
            echo "Ports (host -> container):"
            printed=1
          fi
          printf '%s -> %s\n' "$host_endpoint" "$container_port"
          # Keep the bare port number for the forwardPorts cross-check below.
          published="$published${container_port%%/*} "
          ;;
      esac
    done <<<"$output"
  done

  [ "$printed" -eq 1 ] || echo "No published ports."

  # Entries are numbers or "host:container" / "service:port" strings; the
  # container-side port is what podman publishes, so compare on that.
  for wanted in $forward_ports; do
    wanted="${wanted##*:}"
    case "$wanted" in
      "" | *[!0-9]*) continue ;;
    esac
    case "$published" in
      *" $wanted "*) ;;
      *) missing="$missing $wanted" ;;
    esac
  done

  if [ -n "$missing" ]; then
    echo "dc: warning: forwardPorts (${missing# }) are not published; the CLI merges forwardPorts but never publishes it (it is an editor-only setting)." >&2
    echo "dc: to reach them from the host, use appPort in devcontainer.json (for example \"appPort\": \"127.0.0.1:8081:8080\"), then recreate the container with dcre." >&2
  fi
}

dc() {
  local workspace

  workspace="$(_dc_workspace)" || return 1

  if [ "$#" -eq 0 ]; then
    _dc_up "$workspace" || return 1
    set -- sh -lc 'command -v bash >/dev/null 2>&1 && exec bash || exec sh'
  else
    _dc_up_quiet "$workspace" || return 1
  fi
  _dc_exec "$workspace" "$@"
}

_dc_container_action() {
  local caller="$1" workspace output
  local -a ids
  shift

  workspace="$(_dc_workspace)" || return 1
  output="$(podman ps -aq --filter "label=devcontainer.local_folder=$workspace")" || return 1

  if [ -z "$output" ]; then
    echo "$caller: no dev container found for $workspace"
    return 0
  fi

  readarray -t ids <<<"$output"
  podman "$@" "${ids[@]}"
}

dcstop() { _dc_container_action dcstop stop; }

dcdown() { _dc_container_action dcdown rm -f; }

dcre() {
  local workspace

  workspace="$(_dc_workspace)" || return 1
  _dc_up "$workspace" --remove-existing-container
}

dcread() {
  local workspace

  workspace="$(_dc_workspace)" || return 1

  _dc_cli read-configuration "$workspace"
}
EOF

BEGIN_MARKER='# >>> devcontainers helpers >>>'
END_MARKER='# <<< devcontainers helpers <<<'
OLD_BEGIN_MARKER='# >>> setup-devcontainers helpers >>>'
OLD_END_MARKER='# <<< setup-devcontainers helpers <<<'

touch "$BASH_ALIASES_FILE"

# Preserve everything outside the block managed by this installer and trim
# trailing blank lines so repeated runs do not grow the file.
awk \
  -v begin="$BEGIN_MARKER" \
  -v end="$END_MARKER" \
  -v old_begin="$OLD_BEGIN_MARKER" \
  -v old_end="$OLD_END_MARKER" '
  $0 == begin || $0 == old_begin { skip = 1; next }
  $0 == end || $0 == old_end { skip = 0; next }
  !skip { lines[++count] = $0 }
  END {
    while (count > 0 && lines[count] == "") {
      count--
    }
    for (i = 1; i <= count; i++) {
      print lines[i]
    }
  }
' "$BASH_ALIASES_FILE" > "$tmp/bash_aliases.base"

{
  if [ -s "$tmp/bash_aliases.base" ]; then
    cat "$tmp/bash_aliases.base"
    echo
  fi
  echo "$BEGIN_MARKER"
  cat "$HELPERS_FILE"
  echo "$END_MARKER"
} > "$BASH_ALIASES_FILE"

echo "==> Ensuring ~/.bashrc loads ~/.bash_aliases"

touch "$BASHRC"

# Remove the exact loader line written by the previous installer version.
OLD_SOURCE_LINE='[ -f "$HOME/.config/devtools/devcontainers.bash" ] && . "$HOME/.config/devtools/devcontainers.bash"'
awk -v old="$OLD_SOURCE_LINE" '$0 != old { print }' "$BASHRC" > "$tmp/bashrc"
cat "$tmp/bashrc" > "$BASHRC"

if ! grep -Fq '.bash_aliases' "$BASHRC"; then
  {
    echo
    echo "# User aliases and shell helpers"
    echo 'if [ -f "$HOME/.bash_aliases" ]; then'
    echo '  . "$HOME/.bash_aliases"'
    echo 'fi'
  } >> "$BASHRC"
fi

# Clean up the helper file created by the previous installer, but only when it
# still has the generated-file signature.
OLD_HELPERS="$HOME/.config/devtools/devcontainers.bash"
if [ -f "$OLD_HELPERS" ] && grep -Fq '# Dev Containers CLI helpers for Podman.' "$OLD_HELPERS"; then
  rm -f "$OLD_HELPERS"
  rmdir "$HOME/.config/devtools" 2>/dev/null || true
fi

echo "==> Checking ~/.local/bin in PATH"

case ":$PATH:" in
  *":$LOCAL_BIN:"*) ;;
  *)
    echo
    echo "warning: $LOCAL_BIN is not in current PATH."
    echo "Debian desktop usually adds ~/.local/bin from ~/.profile after relogin."
    echo "For the current shell, run:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac

echo
echo "Installed:"
"$LOCAL_BIN/devcontainer" --version || true

echo
echo "Next steps:"
echo "  source ~/.bashrc"
echo "  command -v devcontainer"
echo "  devcontainer --version"
echo
echo "Usage from a project with .devcontainer/:"
echo "  dc          # up + shell"
echo "  dc go test ./..."
echo "  DC_VERBOSE=1 dc go test ./...  # include setup diagnostics"
echo "  dcstop"
echo "  dcdown"
echo "  dcre"
echo "  dcread"
