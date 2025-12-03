# --- UTILS ---
alias pls='sudo'
alias ssh='kitten ssh'
alias pack='tar -czvf'
alias unpack='tar -xzvf'

..() { cd ..; }
...() { cd ../..; }
alias f='fzf'
alias gf='fastfetch'
alias gp='git pull'
alias gs='git status'
alias chx='chmod +x'
alias copt='gcc -march=native -O3'
alias cdebug='gcc -O0 -g'

vim() {
  if command -v nvim >/dev/null 2>&1; then
    command nvim -u "$HOME/.vimrc" "$@"
  else
    command vim "$@"
  fi
}

fuck() {
  local last
  last=$(fc -ln -1)
  if [ -n "$last" ]; then
    echo "D: Trying again with sudo..."
    eval "sudo $last"
  fi
}

please() {
  sudo "$@"
}

# --- DESIGN / prompt ---
GREEN="\[\e[32m\]"
RED="\[\e[31m\]"
NORMAL="\[\e[0m\]"

__set_bash_prompt() {
  local exit_status=$?
  local symbol
  if [ $exit_status -eq 0 ]; then
    symbol="${GREEN}λ${NORMAL}"
  else
    symbol="${RED}✗${NORMAL}"
  fi

  local cwd="\w"

  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    branch=" *${branch}"
  else
    branch=""
  fi

  PS1="${symbol} ${cwd}${branch}: "
}

PROMPT_COMMAND="__set_bash_prompt"

export LS_OPTIONS='--color=auto -h --group-directories-first'
alias ls="ls $LS_OPTIONS"
alias ll='ls -lh --color=auto --group-directories-first'

# --- TMUX auto-attach for interactive shells ---
if [ -n "$PS1" ]; then
  if command -v tmux >/dev/null 2>&1; then
    if [ -z "$TMUX" ]; then
      tmux attach-session -t main 2>/dev/null || tmux new-session -s main
    fi
  fi
fi

# --- OTHER / PATHS ---
export PATH="$HOME/.cargo/bin:${PATH}"
export PATH="/usr/local/i386elfgcc/bin:${PATH}"
