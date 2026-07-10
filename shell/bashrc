# Interactive shells only
[[ $- != *i* ]] && return

umask 077

# HELPER
_has() { command -v "$1" >/dev/null 2>&1; }

# SHELL OPTIONS
_setup_history() {
    HISTSIZE=10000
    HISTFILESIZE=20000
    HISTCONTROL=ignoreboth:erasedups
    HISTIGNORE='ls:ll:la:cd:cd -:pwd:exit:history:clear'
    shopt -s histappend checkwinsize promptvars
    shopt -s cmdhist lithist
    shopt -s globstar autocd 2>/dev/null

    [[ -n $HISTFILE && -f $HISTFILE ]] && chmod 600 "$HISTFILE" 2>/dev/null
}

_setup_prompt() {
    __set_bash_prompt() {
        local s=$? sym='$'
        (( EUID == 0 )) && sym='#'

        local p="$sym"
        (( s )) && p="\[\e[31m\]$sym\[\e[0m\]"

        local h=''
        [[ -n $SSH_CONNECTION ]] && h='\h '

        PS1="$h$p \W: "
    }

    PROMPT_COMMAND='__set_bash_prompt; history -a'
}

_setup_env() {
    export LESS='-RF'
    export LESSHISTFILE=/dev/null

    local _ed _found_ed
    for _ed in vim nvim vi nano; do
        _has "$_ed" && { _found_ed=$_ed; break; }
    done
    export EDITOR="${_found_ed:-vi}"
    export VISUAL="$EDITOR"

    [[ -t 0 ]] && export GPG_TTY=$(tty)

    local _lp
    for _lp in lesspipe lesspipe.sh; do
        if _has "$_lp"; then
            export LESSOPEN="| $_lp %s"
            break
        fi
    done
}

_setup_path() {
    local _dir
    for _dir in "$HOME/.cargo/bin" "$HOME/.local/bin" "$HOME/go/bin" "$HOME/bin"; do
        [[ -d $_dir && :$PATH: != *:$_dir:* ]] && PATH="$_dir:$PATH"
    done
}

_setup_completion() {
    bind 'set completion-ignore-case on' 2>/dev/null
    bind 'set show-all-if-ambiguous on' 2>/dev/null
    bind 'set menu-complete-display-prefix on' 2>/dev/null
    bind 'set colored-stats on' 2>/dev/null
    bind 'set colored-completion-prefix on' 2>/dev/null
    bind 'set mark-symlinked-directories on' 2>/dev/null
    bind 'set skip-completed-text on' 2>/dev/null

    bind '"\e[A": history-search-backward' 2>/dev/null
    bind '"\e[B": history-search-forward' 2>/dev/null

    local _bc
    for _bc in /etc/bash_completion /usr/share/bash-completion/bash_completion /opt/homebrew/etc/profile.d/bash_completion.sh; do
        [[ -r $_bc ]] && { source "$_bc"; break; }
    done
}

_setup_fzf() {
    _has fzf || return

    local _init
    _init=$(fzf --bash 2>/dev/null) && [[ -n $_init ]] && { eval "$_init"; return; }

    local _dir
    for _dir in /usr/share/fzf /usr/share/doc/fzf/examples /opt/homebrew/opt/fzf/shell /usr/local/opt/fzf/shell "$HOME/.fzf/shell"; do
        [[ -f $_dir/key-bindings.bash ]] && source "$_dir/key-bindings.bash"
        [[ -f $_dir/completion.bash ]] && source "$_dir/completion.bash"
    done
}

_setup_ls() {
    export LS_COLORS='di=1;34:ln=36:ex=32'
    export LSCOLORS='Exgxxxxxcxxxxxxxxxxxxx'
    export CLICOLOR=1

    local _ls_cmd
    if _has gls && gls --group-directories-first / >/dev/null 2>&1; then
        _ls_cmd='gls -h --color=auto --group-directories-first --indicator-style=classify'
    elif ls --group-directories-first / >/dev/null 2>&1; then
        _ls_cmd='ls -h --color=auto --group-directories-first --indicator-style=classify'
    elif ls -G / >/dev/null 2>&1; then
        _ls_cmd='ls -hFG'
    else
        _ls_cmd='ls -hF'
    fi

    alias ls="$_ls_cmd"
    alias ll="$_ls_cmd -l"
    alias la="$_ls_cmd -A"
}

_setup_man() {
    local _b
    for _b in bat batcat; do
        if _has "$_b"; then
            _BAT="$_b"
            break
        fi
    done

    man() {
        if [[ -z $_BAT ]] || ! _has col; then
            command man "$@"
            return
        fi
        command man "$@" | col -bx | "$_BAT" -l man -p
        return "${PIPESTATUS[0]}"
    }
}

# BINARY TOOLS
_pager() {
    if _has less; then command less
    elif _has more; then command more
    else command cat
    fi
}

dis() {
    local _od _found_od
    for _od in objdump gobjdump; do
        _has "$_od" && { _found_od=$_od; break; }
    done
    [[ -n $_found_od ]] || { echo "dis: no disassembler found (objdump/gobjdump)" >&2; return 1; }

    if [[ -n $_BAT ]]; then
        "$_found_od" -d -M intel --no-show-raw-insn "$@" | "$_BAT" -l asm -p
    else
        "$_found_od" -d -M intel --no-show-raw-insn "$@" | _pager
    fi
}

hex() {
    if _has xxd; then
        xxd -g1 "$@" | _pager
    else
        od -A x -t x1z "$@" | _pager
    fi
}

# INIT ALL
_setup_history
_setup_prompt
_setup_env
_setup_path
_setup_completion
_setup_fzf
_setup_ls
_setup_man

unset -f _setup_history _setup_prompt _setup_env _setup_path _setup_completion _setup_fzf _setup_ls _setup_man
