# shellcheck shell=bash
# plan: a menu of the sections, then the plan to confirm

# the text of sections/K.txt: a title line, then what K does, expanded as a here-document
section_text() {
    local f=$HERE/sections/$1.txt
    [[ -f $f ]] || die "no $f"
    eval "cat <<__SECTION__
$(tail -n +2 -- "$f")
__SECTION__"
}

section_title() {
    local t
    IFS= read -r t <"$HERE/sections/$1.txt"
    printf '%s\n' "$t"
}

# MENU_KEY: the section named by a number or a name
menu_key() {
    MENU_KEY=
    if [[ $1 =~ ^[0-9]+$ ]] && (($1 >= 1 && $1 <= ${#SECTIONS[@]})); then
        MENU_KEY=${SECTIONS[$1 - 1]}
    elif [[ " ${SECTIONS[*]} " == *" $1 "* ]]; then
        MENU_KEY=$1
    else
        MENU_MSG+="no section '$1'. "
        return 1
    fi
}

menu_toggle() {
    if [[ -n ${BLOCK[$1]:-} ]]; then
        MENU_MSG+="$1: ${BLOCK[$1]}. "
    elif ((SEL[$1])); then
        SEL[$1]=0
    else
        SEL[$1]=1
    fi
}

# harden takes setuid away from su: something has to take its place
menu_needs() {
    ((SEL[harden] && !SEL[doas])) || return 0
    ! command -v doas >/dev/null && ! command -v sudo >/dev/null || return 0
    SEL[doas]=1
    MENU_MSG+="doas is on too: harden takes setuid away from su. "
}

menu_show() {
    local text
    text=$(
        printf '%s%s%s\n\n' "$C_B" "$(section_title "$1")" "$C_0"
        section_text "$1" | wrap $((COLS - 4)) | sed 's/^/   /'
        [[ -z ${BLOCK[$1]:-} ]] || printf '\n   %scannot be applied here: %s%s\n' "$C_Y" "${BLOCK[$1]}" "$C_0"
    )
    if [[ -n $C_CL ]] && command -v less >/dev/null; then
        LESS= less -R -P'q to go back' <<<"$text"
    else
        printf '\n%s\n\n' "$text"
        read -rp "Enter to go back " _ </dev/tty || die "no input"
    fi
}

# one word of the menu input
menu_word() {
    local w=$1 k a b i
    case $w in
    a | all)
        for k in "${SECTIONS[@]}"; do [[ -n ${BLOCK[$k]:-} ]] || SEL[$k]=1; done
        ;;
    n | none)
        for k in "${SECTIONS[@]}"; do SEL[$k]=0; done
        ;;
    q | quit)
        say "nothing changed."
        exit 0
        ;;
    \?*)
        if menu_key "${w#\?}"; then menu_show "$MENU_KEY"; fi
        ;;
    [0-9]*-[0-9]*)
        a=${w%-*} b=${w#*-}
        if menu_key "$a" && menu_key "$b" && ((a <= b)); then
            for ((i = a; i <= b; i++)); do menu_toggle "${SECTIONS[i - 1]}"; done
        fi
        ;;
    *)
        if menu_key "$w"; then menu_toggle "$MENU_KEY"; fi
        ;;
    esac
}

# each section on a row with its title; on a short screen two columns of names
menu_draw() {
    local i k n=0 mark row cells=() half
    for k in "${SECTIONS[@]}"; do ((SEL[$k] == 0)) || n=$((n + 1)); done
    printf '%sDebian post-install%s  %s%s, %s%s\n' "$C_B" "$C_0" "$C_D" "$TUSER" "$REPO" "$C_0"
    head_line "What to apply" "$n of ${#SECTIONS[@]}"
    for i in "${!SECTIONS[@]}"; do
        k=${SECTIONS[i]}
        if [[ -n ${BLOCK[$k]:-} ]]; then
            mark="${C_D}[-]"
        elif ((SEL[$k])); then
            mark="${C_G}[x]${C_0}"
        else
            mark="[ ]"
        fi
        if ((ROWS >= ${#SECTIONS[@]} + 10)); then
            row=$(printf '%2d %-9s %s' $((i + 1)) "$k" "${BLOCK[$k]:-$(section_title "$k")}")
            ((${#row} <= COLS - 8)) || row=${row:0:COLS-8-${#S_MORE}}$S_MORE
            printf '   %s %s%s\n' "$mark" "$row" "$C_0"
        else
            cells+=("$(printf '%s %2d %-9s%s' "$mark" $((i + 1)) "$k" "$C_0")")
        fi
    done
    if ((${#cells[@]})); then
        half=$(((${#cells[@]} + 1) / 2))
        for ((i = 0; i < half; i++)); do
            printf '   %s     %s\n' "${cells[i]}" "${cells[i + half]:-}"
        done
    fi
    printf '\n   %snumber or name: switch it · 3-7: a range · ?N: what it does · a: all · n: none\n' "$C_D"
    printf '   Enter: go on to the plan · q: quit%s\n' "$C_0"
    [[ -z $MENU_MSG ]] || printf '   %s%s%s\n' "$C_Y" "$MENU_MSG" "$C_0"
}

# SEL from the menu: everything that can be applied starts on
choose() {
    local k in w words
    for k in "${SECTIONS[@]}"; do
        SEL[$k]=1
        [[ -z ${BLOCK[$k]:-} ]] || SEL[$k]=0
    done
    MENU_MSG=
    menu_needs
    if ((YES)); then
        menu_draw
        return 0
    fi
    while :; do
        [[ -z $C_CL ]] || printf '\e[H\e[2J'
        menu_draw
        MENU_MSG=
        printf '%s> %s' "$C_B" "$C_0"
        read -r in </dev/tty || die "no input"
        check_abort
        [[ -n ${in//[[:space:],]/} ]] || break
        # read -a, not $in unquoted: ?5 would be a glob
        read -ra words <<<"${in//,/ }"
        for w in "${words[@]}"; do menu_word "$w"; done
        menu_needs
    done
    return 0
}

plan() {
    local k on=() off=()
    detect_hw
    zram_size
    find_blocks
    choose
    log "sections: $(for k in "${SECTIONS[@]}"; do ((SEL[$k] == 0)) || printf '%s ' "$k"; done)"

    if ((SEL[maint])) && [[ $(stat -c %i /home) != 256 ]]; then
        note "/home becomes a subvolume of its own (maint)"
    fi
    ((SEL[usb] == 0)) || usb_check

    for k in "${SECTIONS[@]}"; do
        if ((SEL[$k])); then on+=("$k"); else off+=("$k"); fi
    done
    ((${#on[@]})) || {
        say "nothing selected."
        exit 0
    }

    local need=6 avail
    ((SEL[fonts])) && need=$((need + 1))
    ((SEL[apps])) && need=$((need + 2))
    avail=$(df --output=avail -BG / | tail -n1 | tr -dc 0-9)
    ((avail >= need)) || die "about ${need} GB needed on /, only ${avail} GB free"

    head_line "Plan" "${#on[@]} of ${#SECTIONS[@]}"
    say "   user  $TUSER ($THOME)"
    say "   apt   ${SOURCES##*/}: $COMPONENTS over https; packages without their Recommends"
    say "         downloads under seccomp, never from an unsigned repository, no translations"
    printf 'apply  %s\n' "${on[*]}" | fold -s -w $((COLS - 11)) | sed '1!s/^/       /; s/^/   /'
    ((${#off[@]} == 0)) || printf 'skip   %s\n' "${off[*]}" | fold -s -w $((COLS - 11)) | sed '1!s/^/       /; s/^/   /'
    for k in "${SECTIONS[@]}"; do
        [[ -z ${BLOCK[$k]:-} ]] || note "$k cannot be applied: ${BLOCK[$k]}"
    done
    if [[ -n ${SSH_CONNECTION:-} ]] && ((SEL[net])); then
        warn "you are on SSH: the network step at the end may drop this connection"
    fi
    printf '\n'
    ask "Proceed?" || {
        say "nothing changed."
        exit 0
    }
}
