
alias grep='grep --color=tty -d skip'

alias ls='ls --color=auto'
alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'
alias lh='ls -lh'

alias paux='ps aux | grep'
#alias ..='cd ..'

alias df='df -Th'
alias du='du -h'


function ..() {
    cd $(printf '../%.0s' $(seq 1 $1))
}
