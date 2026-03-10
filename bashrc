# UTILS
alias ls='ls -h --group-directories-first --indicator-style=classify'

# DESIGN
__set_bash_prompt() {
  local s=$? p='$'
  (( s )) && p='\[\e[31m\]$\[\e[0m\]'
  PS1="$p \W: "
}
PROMPT_COMMAND="__set_bash_prompt"
