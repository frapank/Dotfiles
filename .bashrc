# -- UTILS
alias pvim='vim -u ~/.vimprc'
alias vim='/usr/local/bin/vim'
alias ls='ls -h --group-directories-first --indicator-style=classify'
alias lynx='torsocks lynx'
alias nlynx='lynx'

# -- DESIGN
__set_bash_prompt() {
  local s=$? p='$'
  (( s )) && p='\[\e[31m\]$\[\e[0m\]'
  PS1="$p \W: "
}
PROMPT_COMMAND="__set_bash_prompt"
