set -g fish_greeting ""

# Utils
alias cvim='nvim'
alias lvim='NVIM_LIGHT_MODE=1 nvim'
alias vim='/bin/vimx'
alias vi='/bin/vimx'
alias pls='sudo'
alias ssh="kitten ssh"
alias pack='tar -czvf'
alias unpack='tar -xzvf'

abbr -a .. 'cd ..'
abbr -a ... 'cd ../..'
abbr -a f 'fzf'
abbr -a gf 'fastfetch'
abbr -a gp 'git pull'
abbr -a gs 'git status'
abbr -a chx 'chmod +x'
abbr -a copt 'gcc -march=native -O3'
abbr -a cdebug 'gcc -O0 -g'

function man
    if type -q bat
        command man $argv | col -b | bat -l man
    else
        command man $argv
    end
end

function fuck
    set last (history | head -n 1)
    if test -n "$last"
        echo "D: Trying again with sudo..."
        eval "sudo $last"
    end
end

function please
    command sudo $argv
end

# Design
alias ls='ls --color=auto -h --group-directories-first'
alias ll='ls -lh --color=auto --group-directories-first'

function fish_prompt
    if test $status -eq 0
        set_color green
        echo -n 'λ '
    else
        set_color red
        echo -n '✗ '
    end

    set_color normal
    echo -n (prompt_pwd) ''

    set branch (git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if test -n "$branch" 
        echo -n "*$branch" 
    end

    set_color normal
    echo -n ': '
end

set -g fish_color_error red --bold
set -g fish_color_command white
set -g fish_color_param white
set -g fish_color_autosuggestion brblack
set -g fish_color_comment brgray

# Tmux
if status is-interactive
    if command -q tmux
        if not set -q TMUX
            tmux attach-session -t main 2>/dev/null; or tmux new-session -s main
        end
    end
end
