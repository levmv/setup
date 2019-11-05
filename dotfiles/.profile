
if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

# Add path to brew's coreutils
if [ "$(uname)" = "Darwin" ] && [ -d /usr/local/opt/coreutils/libexec/gnubin ]; then
  PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH";
fi

# set PATH so it includes user's private bin if it exists

if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

if [ -z "$TMUX" ] && [[ "$TERM" != "screen" ]]; then
    tmux attach || exec tmux new-session && exit;
fi
