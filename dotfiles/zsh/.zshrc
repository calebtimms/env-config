# ~/.zshrc — Arch workstation configuration
[[ -o interactive ]] || return

# === Environment ==============================================================

typeset -U path fpath
path-prepend() { [[ -d $1 ]] && path=($1 $path) }
path-prepend ~/env-config/scripts

# Programs (git commit, sudoedit, Claude Code's Ctrl+E) run Vim with OBSESSION_AUTO=0, which stops it from tracking,
# and so overwriting, the session saved for that directory.
export EDITOR='env OBSESSION_AUTO=0 vim' SUDO_EDITOR='env OBSESSION_AUTO=0 vim'
export OBSESSION_ROOT=${OBSESSION_ROOT:-$HOME/obsessions}
# Man pages open in read-only Vim (Vim's :MANPAGER). MANROFFOPT keeps groff to plain overstrikes that Vim cleans up: no
# SGR escapes (-c) and no groff 1.23 hyperlinks (-rU0).
export MANROFFOPT='-c -rU0' MANPAGER='env VIM_MANPAGER=1 vim +MANPAGER --not-a-term -'
# noti (noti.py) emails NOTI_EMAIL and keeps its logs under NOTI_LOG_DIR.
export NOTI_EMAIL=${NOTI_EMAIL:-calebtimms@gmail.com}
NOTI_LOG_DIR=${NOTI_LOG_DIR:-$HOME/.noti_logs}

# === tmux =====================================================================
# Interactive terminal shells run inside tmux (~/.tmux.conf, the work setup). A terminal attaches to the most recently
# used unattached session, else the most recent one, else a new "main"; detaching, or the server ending, closes the
# terminal. Left alone: shells already in tmux (or under a multiplexer across ssh, TERM tmux*/screen*), Vim and Code
# OSS terminals, zsh -c and scripts, TMUX_AUTO=0, and machines without a ~/.tmux.conf. If tmux cannot start, the shell
# carries on without it. Meanwhile a Kitty window has its in_tmux user variable set, so kitty.conf's split, pane and
# scrollback keys drive tmux there.
if [[ -z $TMUX && $TMUX_AUTO != 0 && -z $ZSH_EXECUTION_STRING$ZSH_SCRIPT && -t 0 && -t 1 && $TERM != (dumb|tmux*|screen*) &&
      -z $VIM_TERMINAL && $TERM_PROGRAM != vscode && -e ~/.tmux.conf ]] && (( $+commands[tmux] )); then
    () {
        local -i start=$SECONDS
        local s=$(tmux list-sessions -F '#{session_attached} #{session_activity} #{session_name}' 2>/dev/null |
            sort -k1,1n -k2,2nr | head -n 1)
        [[ $TERM == xterm-kitty ]] && print -n '\e]1337;SetUserVar=in_tmux=MQ==\a'   # MQ== is base64 for 1
        # -A: when another terminal starting at the same moment has just created main, attach to it instead of failing.
        if [[ -n $s ]]; then tmux attach-session -t "=${s#* * }"; else tmux new-session -A -s main; fi
        (( $? == 0 || SECONDS - start > 3 ))   # ran, then detached or its server ended; a failure to start is quick
    } && exit
    [[ $TERM == xterm-kitty ]] && print -n '\e]1337;SetUserVar=in_tmux\a'   # no value: unset
    print -u2 'zsh: tmux did not start, so this shell runs without it (TMUX_AUTO=0 skips tmux).'
fi

# === Options & history ========================================================

# No extendedglob at the prompt: ^, # and ~ stay ordinary characters there, so grep ^foo, e ^foo and git show HEAD^
# work as typed (with it, ^foo expands to every file but foo). Functions here that need it set it locally.
setopt autocd noextendedglob nomatch notify interactivecomments globdots typesetsilent auto_param_slash prompt_subst no_beep
HISTFILE=${HISTFILE:-$HOME/.zsh_history} HISTSIZE=1000000 SAVEHIST=1000000
setopt append_history share_history hist_ignore_dups hist_find_no_dups hist_reduce_blanks hist_verify extended_history

# === Prompt ===================================================================

autoload -Uz vcs_info add-zsh-hook
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr '+'
zstyle ':vcs_info:git:*' unstagedstr '*'
zstyle ':vcs_info:git:*' formats '%F{yellow}[%b%c%u]%f '
zstyle ':vcs_info:git:*' actionformats '%F{yellow}[%b|%a%c%u]%f '
add-zsh-hook precmd vcs_info
PROMPT='%B%F{cyan}%1~%f%b ${vcs_info_msg_0_}%B%F{magenta}>%f%b '
RPROMPT='%(?..%F{red}exit %?%f) %(1j.%F{yellow}%j job(s)%f.)'
PROMPT_EOL_MARK=''

# === Completion ===============================================================

ZSH_COMPLETION_DIR=~/.local/share/zsh/site-functions
[[ -d $ZSH_COMPLETION_DIR ]] || mkdir -p $ZSH_COMPLETION_DIR
fpath=($ZSH_COMPLETION_DIR $fpath)
autoload -Uz compinit
_ZCOMPDUMP=${ZDOTDIR:-$HOME}/.zcompdump
# A full compinit at every start (a few ms more than compinit -C): it rebuilds the dump whenever the completions on
# fpath change, so a command installed since the last shell completes at once.
compinit -d $_ZCOMPDUMP
completion-refresh() { rehash; rm -f $_ZCOMPDUMP $_ZCOMPDUMP.zwc; compinit -d $_ZCOMPDUMP }

# List ambiguous matches; never cycle through or auto-accept them.
unsetopt recexact automenu menucomplete completealiases
setopt autolist list_ambiguous
zstyle ':completion:*' accept-exact false
zstyle ':completion:*' accept-exact-dirs false
zstyle ':completion:*' insert-tab false

# === Custom command registry ==================================================
# Every user-facing command is registered so `list-custom [-v] [filter]` can index it.

typeset -ga _CUSTOM_ORDER=() _CUSTOM_GROUP_ORDER=(Shell Files Search Editors Git Packages System Applications Tools)
typeset -gA _CUSTOM_GROUP=() _CUSTOM_DESC=()

_custom-register() {  # GROUP name 'description' ...
    local group=$1; shift
    (( $_CUSTOM_GROUP_ORDER[(Ie)$group] )) || _CUSTOM_GROUP_ORDER+=($group)
    while (( $# >= 2 )); do
        (( $+_CUSTOM_DESC[$1] )) || _CUSTOM_ORDER+=($1)
        _CUSTOM_GROUP[$1]=$group _CUSTOM_DESC[$1]=$2
        shift 2
    done
}

_custom-alias() {  # GROUP name 'expansion' 'description' ...
    local group=$1; shift
    while (( $# >= 3 )); do alias -- "$1=$2"; _custom-register "$group" "$1" "$3"; shift 3; done
}

list-custom() {
    local verbose=0 printed=0 filter group name kind
    local -a matches
    while (( $# )); do
        case $1 in
            -v|-verbose|--verbose) verbose=1 ;;
            -h|--help) print -l 'Usage: list-custom [-v|--verbose] [filter]' 'Filter matches command name, category, or description.'; return 0 ;;
            -*) print -u2 "Unknown option: $1"; return 2 ;;
            *)  [[ -z $filter ]] || { print -u2 'Only one filter may be supplied.'; return 2 }; filter=$1 ;;
        esac
        shift
    done
    for group in $_CUSTOM_GROUP_ORDER; do
        matches=()
        for name in $_CUSTOM_ORDER; do
            [[ $_CUSTOM_GROUP[$name] == "$group" ]] || continue
            [[ -z $filter || "${(L)name} ${(L)group} ${(L)_CUSTOM_DESC[$name]}" == *"${(L)filter}"* ]] && matches+=($name)
        done
        (( $#matches )) || continue
        if (( verbose )); then
            (( printed )) && print
            print -P "%B$group%b"
            for name in $matches; do
                if   (( $+aliases[$name] ));   then kind=alias
                elif (( $+functions[$name] )); then kind=function
                elif (( $+builtins[$name] ));  then kind=builtin
                elif (( $+commands[$name] ));  then kind=command
                else kind=none; fi
                printf '  %-18s %-9s %s\n' $name $kind $_CUSTOM_DESC[$name]
            done
        else
            print -r -- "$group: ${(j: :)matches}"
        fi
        printed=1
    done
    (( printed )) || { print -u2 "No custom commands matched: $filter"; return 1 }
}

_list-custom() {
    local name; local -a filters=(${^_CUSTOM_GROUP_ORDER}':command category')
    for name in $_CUSTOM_ORDER; do filters+=("$name:$_CUSTOM_DESC[$name]"); done
    _arguments '(-v -verbose --verbose)'{-v,-verbose,--verbose}'[show command descriptions]' \
               '(-h --help)'{-h,--help}'[show help]' \
               '1:command or category:{_describe "command or category" filters}'
}
compdef _list-custom list-custom

_custom-register Shell list-custom 'List custom commands; use --verbose for descriptions.'
_custom-alias Shell \
    sz   'source ~/.zshrc' 'Reload ~/.zshrc in the current shell.' \
    vimz 'vim ~/.zshrc'    'Edit ~/.zshrc in Vim.' \
    type 'type -a'         'Show all resolutions for a command name.'
_custom-register Shell completion-refresh 'Rebuild Zsh command and completion caches.'

# === Line editor ==============================================================

bindkey -e
zle_highlight=(${zle_highlight:#paste:*} paste:none)   # replaced, not appended, so each sz leaves one

# Alt+Backspace kills one path segment: "/" is a word boundary for this widget only.
_backward-kill-path-segment() { local WORDCHARS=${WORDCHARS//\/}; zle backward-kill-word }
zle -N _backward-kill-path-segment

# Alt+j / Alt+k step through this shell's own history: the lines typed in this pane, then what history held when it
# started. Up / Down step through every shell's, which share_history imports as they run. -n sets the mode for the one
# step (set-local-history reads only its numeric argument), so Up / Down are never left local.
_up-line-or-local-history()   { zle set-local-history -n 1; zle up-line-or-history; zle set-local-history -n 0 }
_down-line-or-local-history() { zle set-local-history -n 1; zle down-line-or-history; zle set-local-history -n 0 }
zle -N _up-line-or-local-history; zle -N _down-line-or-local-history

() {
    local key widget
    for key widget in \
        '^H'  beginning-of-line       '^L'  end-of-line \
        '^[h' backward-char           '^[l' forward-char \
        '^[H' vi-backward-word        '^[L' vi-forward-word \
        '^[j' _up-line-or-local-history '^[k' _down-line-or-local-history \
        '^[J' beginning-of-history    '^[K' end-of-history \
        '^W'  backward-kill-word      '^U'  backward-kill-line \
        '^[d' kill-word               '^[x' backward-kill-word \
        '^[u' undo                    '^[r' redo \
        '^[^?' _backward-kill-path-segment
    do bindkey -M emacs $key $widget; done
}

# === fzf / zoxide / atuin =====================================================

if (( $+commands[fzf] )); then
    export FZF_DEFAULT_OPTS='--height=60% --layout=reverse --border --cycle --bind=ctrl-k:down,ctrl-j:up,ctrl-d:half-page-down,ctrl-u:half-page-up'
    # Keep fzf's **<Tab> completion; ^R, ^T and Alt+C belong to the pickers below.
    FZF_CTRL_R_COMMAND= FZF_CTRL_T_COMMAND= FZF_ALT_C_COMMAND= source <(fzf --zsh 2>/dev/null)
    (( $+widgets[fzf-completion] )) && zle -A fzf-completion _fzf-completion-original
fi
(( $+commands[fd] )) && export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git --exclude .cache'
(( $+commands[zoxide] )) && eval "$(zoxide init zsh --cmd cd)"
(( $+commands[atuin] )) && { export ATUIN_NOBIND=true; eval "$(atuin init zsh)" }

# === Tab completion ===========================================================
# Tab: a word ending in ** after the command → fzf; a word containing * ? or [ → glob completion (src/**/*.v
# included); otherwise → normal.
# Glob completion never expands the line. The cursor acts as a trailing *, as in normal completion:
# Tab fills in whatever every match has in common next, then lists the matches (never cycles).
#   *.lat<Tab> → *.latest     .venv*/li<Tab> → .venv*/lib     Do*<Tab> → lists Documents Downloads
# A glob in a parent component offers every child found under any matched parent, as the glob
# itself would expand:   */*/*rc*<Tab> → lists .vimrc .vimrc-orig .zshrc .zshrc-orig
# Symlinks to directories count as directories (e.g. a venv's lib64 -> lib).
# A leading ~ or ~name and $NAME/${NAME} are expanded first; command substitution never runs.
# When nothing qualifies, a one-line message says why instead of Tab silently doing nothing.

# REPLY=$1 with ~, ~name, $NAME and ${NAME} replaced by their values, quoted so that only the
# glob characters actually typed stay special.
_glob-expand-path() {
    setopt localoptions extendedglob
    local p=$1 head
    if [[ $p == \~* ]]; then
        head=${p%%/*}
        if [[ $head == \~ ]]; then head=$HOME
        elif (( $+nameddirs[${head#\~}] )); then head=$nameddirs[${head#\~}]
        elif (( $+userdirs[${head#\~}] )); then head=$userdirs[${head#\~}]
        fi
        [[ $p == */* ]] && p=${(b)head}/${p#*/} || p=${(b)head}
    fi
    REPLY=${p//(#m)\$(\{[[:IDENT:]]##\}|[[:IDENT:]]##)/${(b)${(P)${${MATCH#\$}//[\{\}]/}}}}
}

_glob-list-completer() {
    # The typed glob is matched with the prompt's own options, as the command line will expand it: no
    # extendedglob there, so ^, # and ~ in it stay ordinary characters here too.
    local dir leaf base hit name tail REPLY
    local -i nparents
    local -a parents dirs files dir_words file_words
    local -A count dir_count
    compstate[list]='list force'
    # parents: glob-quoted directory prefixes ending in / ('' for the current directory).
    if [[ $PREFIX == */* ]]; then
        dir=${PREFIX%/*} leaf=${PREFIX##*/}
        _glob-expand-path $dir
        if [[ $dir == *[\*\?\[]* ]]; then
            if [[ $REPLY == (*/|)\*\*(\*|) ]]; then
                # A last component ** (or ***) is the recursive glob, as in src/**/*.v: dir itself and every
                # directory below it; a bare ** starts at the current directory, as ./
                parents=(${~REPLY}/(N-/)) parents=(${parents%/})
                [[ $REPLY == \*\*(\*|) ]] && parents=(. $parents)
            else
                parents=(${~REPLY}(N-/))
            fi
            (( $#parents )) || { compadd -x "no directory matches ${dir//\%/%%}"; return 1 }
            parents=(${(b)^parents}/)
        else
            parents=($REPLY/)
        fi
    else
        leaf=$PREFIX parents=('')
    fi
    nparents=$#parents
    for base in "${parents[@]}"; do
        for hit in ${~base}${~leaf}*(N); do
            name=${hit:t}
            count[$name]=$(( ${count[$name]:-0} + 1 ))
            [[ -d $hit ]] && dir_count[$name]=$(( ${dir_count[$name]:-0} + 1 ))
        done
    done
    # Every name found under any matched parent is offered, as the glob itself would expand; it counts
    # as a directory only if it is one everywhere it appears. Each name completes to the word as typed
    # plus the rest of the name after what the typed glob matched (*.lat + est), so the common part of
    # those words is what Tab fills in.
    for name in ${(ko)count}; do
        [[ $name == ${~leaf}* ]] && tail=${name##${~leaf}} || tail=
        if (( ${dir_count[$name]:-0} == $count[$name] )); then dirs+=($name) dir_words+=("$leaf${tail:+${(q)tail}}")
        else files+=($name) file_words+=("$leaf${tail:+${(q)tail}}"); fi
    done
    if (( $#dirs + $#files == 0 )); then
        if (( nparents > 1 )); then
            compadd -x "no ${leaf//\%/%%}* under the $nparents directories matching ${dir//\%/%%}"
        else
            compadd -x "no match for ${PREFIX//\%/%%}*"
        fi
        return 1
    fi
    compstate[insert]=unambiguous
    compset -P '*/'
    # -Q: the words are already quoted. -2: keep identical words (every *.latest match completes to
    # "*.latest") so each match is still listed, under its plain name (-d).
    (( $#dirs )) && compadd -Q -J glob -2 -S / -d dirs -- $dir_words
    (( $#files )) && compadd -Q -J glob -2 -d files -- $file_words
}
zle -C _glob-list-widget list-choices _glob-list-completer

_smart-tab-completion() {
    local word trigger=${FZF_COMPLETION_TRIGGER-'**'}
    local -a words
    [[ $LBUFFER == *[[:space:]] ]] || { words=(${(z)LBUFFER}); word=$words[-1] }
    # fzf completes only a word that ends in its trigger after a command word; given any other word it falls back to
    # expand-or-complete, which would expand a ** glob (src/**/*.v) into the line, so those get glob completion.
    if [[ -n $trigger && $word == *$trigger ]] && (( $#words > 1 && $+widgets[_fzf-completion-original] )); then
        zle _fzf-completion-original
    elif [[ $word == *[\*\?\[]* ]]; then zle _glob-list-widget
    else zle complete-word; fi
}
zle -N _smart-tab-completion
bindkey -M emacs '^I' _smart-tab-completion

# === Pickers ==================================================================
# ^F all history · ^R this directory's history · ^T files · ^G directories. The same keys switch
# pickers inside fzf (the active picker's key closes it); ^X deletes the highlighted history entry, and ^D picks another
# directory to search (^R, ^T, ^G; from ^F it opens that directory's history). The picked directory carries across
# picker switches until the picker closes.

# _atuin-history-rows [atuin search args]: one NUL-terminated row per distinct command, newest first: the command, then
# the line fzf shows, in two fields, its columns and the command as shown, so that fzf searches only that command
# (--nth): a query never matches a row by its age, status, duration or directory, and ^foo anchors to the command's
# start. fzf draws the \x1f between them as nothing. NULs (atuin --print0, fzf --read0) keep a multi-line command one
# row; it shows on one line, ↵ marking its line breaks, and the whole command is what is picked.
_atuin-history-rows() {
    (( $+commands[atuin] )) || return 1
    atuin search "$@" --reverse --human --print0 --format $'{command}\x1f{relativetime}\x1f{exit}\x1f{duration}\x1f{directory}' |
        awk -F $'\x1f' -v OFS=$'\x1f' -v RS='\0' -v ORS='\0' -v home="$HOME" '
            BEGIN { reset = "\033[0m"; dim = "\033[90m"; cyan = "\033[36m"; white = "\033[1;37m" }
            function short(dir) {
                if (dir == home) dir = "~"
                else if (index(dir, home "/") == 1) dir = "~" substr(dir, length(home) + 1)
                return (length(dir) > 28) ? ("…" substr(dir, length(dir) - 26)) : dir
            }
            !seen[$1]++ {
                if ($3 == "0")                  { status = "✓";     color = "\033[32m" }
                else if ($3 == "-1" || $3 == "") { status = "?";     color = dim }
                else                            { status = "✗ " $3; color = "\033[31m" }
                shown = $1; gsub(/\n/, " ↵ ", shown)
                print $1, sprintf("%s%-7s%s │ %s%-8s%s │ %s%-10s%s │ %s%-28s%s │ ",
                    dim, $2, reset, color, status, reset, dim, $4, reset, cyan, short($5), reset), white shown reset
            }'
}

# Delete every history entry exactly equal to $1, through atuin's r/…/ regex: regex characters are escaped, and "/" is
# written [/], since atuin ends the regex at the first "/ " and an escaped \/ would still contain one.
_atuin-history-delete-exact() {
    setopt localoptions extendedglob
    local regex=${1//(#m)[][\\.^\$|?*+(){}]/\\$MATCH}
    regex=${regex//\//[/]}
    [[ -n $regex ]] && atuin search --delete --search-mode fuzzy -- "r/^${regex}$/"
}

# _fzf-root-step list <typed path> | result | tab: the ^D directory picker's list and its event steps. fzf runs it in a
# plain `zsh -f` from its body in $_FZF_ROOT_STEP, so it needs no other function. "list" records the directory part of
# the typed path in $_FZF_ROOT_STATE and prints it, its parent, and its subdirectories, each written as typed so the
# query keeps matching and ending in /, then $_FZF_ROOT_HISTORY (history pickers: Atuin's directories). "result" runs
# after every search and relists when the typed directory part is not the one recorded: fzf keeps one pending search
# request, so a reload asked for during a burst of keys can be replaced by the next key's search, and this retries it.
# "tab" completes like the shell: the subdirectory names starting with the typed name complete to their longest common
# prefix, or into the directory when only one is left; when no name starts with it, only a single fuzzy match completes.
_fzf-root-step() {
    local d r p n leaf
    local -a names
    if [[ $1 == list ]]; then d=${(M)2##*/}; else d=${(M)FZF_QUERY##*/}; fi
    r=$d; [[ $r == \~/* ]] && r=$HOME${r#\~}
    case $1 in
        list)
            [[ -z $_FZF_ROOT_STATE ]] || print -r -- "$d" >| $_FZF_ROOT_STATE
            print -r -- ${d:-./}
            case ${${d%/}:t} in
                ''|.|..|\~) [[ $d == / ]] || print -r -- ${d#./}../ ;;
                *)          p=${${d%/}:h}; print -r -- ${p%/}/ ;;
            esac
            names=(${r:-./}*(N-/D:t)); names=(${names:#(.git|.cache)})
            (( $#names )) && print -rl -- $d${^names}/
            [[ -z $_FZF_ROOT_HISTORY ]] || print -r -- $_FZF_ROOT_HISTORY ;;
        result)
            [[ -r $_FZF_ROOT_STATE ]] || return 0
            p=$(<$_FZF_ROOT_STATE)
            if [[ $p != "$d" ]]; then
                print -r -- "reload-sync(set -- list {q}; eval \"\$_FZF_ROOT_STEP\")"
            elif [[ $p != "$FZF_BORDER_LABEL" ]]; then
                print -r -- "change-border-label:$p"
            fi ;;
        tab)
            leaf=${FZF_QUERY:$#d}
            names=(${r:-./}*(N-/D:t) ..); names=(${(M)${names:#(.git|.cache)}:#${(b)leaf}*})
            if (( $#names == 1 )); then
                p=$d$names[1]/
            elif (( $#names > 1 )); then
                p=$names[1]
                for n in $names[2,-1]; do while [[ $n != ${(b)p}* ]]; do p=${p[1,-2]}; done; done
                p=$d$p
            elif (( FZF_MATCH_COUNT == 1 )); then
                p=${FZF_CURRENT_ITEM-}
            fi
            [[ -n $p && $p != "$FZF_QUERY" ]] && print -r -- "change-query:$p" ;;
    esac
    return 0
}

# _fzf-pick-root <picker mode>: the ^D directory picker. It starts in the current directory; typing a path lists its
# directory, Tab completes like the shell (see _fzf-root-step), and Enter picks the highlighted directory. History modes
# also list every directory that has Atuin history, newest first, even ones since deleted. Sets REPLY to the pick as
# typed ('' for the current directory); returns 1 when closed with Esc or ^D, or when the pick is not a directory (or a
# listed history one).
_fzf-pick-root() {
    local mode=$1 result pick dir d
    local -i st
    local -a lines dirs
    local -x _FZF_ROOT_STEP=$functions[_fzf-root-step] _FZF_ROOT_HISTORY=
    local -x _FZF_ROOT_STATE=$(mktemp "${TMPDIR:-/tmp}/fzf-root.XXXXXX" 2>/dev/null)
    if [[ $mode == *history ]]; then
        for d in ${(u)${(f)"$(atuin search --reverse --format '{directory}' 2>/dev/null)"}}; do
            case $d in
                "$HOME")   d='~' ;;
                "$HOME"/*) d="~${d#$HOME}" ;;
            esac
            dirs+=(${d%/}/)
        done
        _FZF_ROOT_HISTORY=${(F)dirs}
    fi
    result=$(_fzf-root-step list |
        fzf --with-shell="${commands[zsh]:-zsh} -fc" --print-query --prompt='Directory> ' \
            --header='Type a path or pick one  │  Tab: Complete  Enter: Search There  Ctrl+D/Esc: Back' \
            --bind='result:transform:set -- result; eval "$_FZF_ROOT_STEP"' \
            --bind='tab:transform:set -- tab; eval "$_FZF_ROOT_STEP"' \
            --bind=ctrl-d:abort)
    st=$?
    [[ -z $_FZF_ROOT_STATE ]] || rm -f -- $_FZF_ROOT_STATE
    (( st == 0 || st == 1 )) || return 1
    lines=("${(@f)result}")   # the query, then the highlighted directory, if any
    pick=${lines[2]:-$lines[1]}
    [[ $pick == / ]] || pick=${pick%/}
    [[ -n $pick ]] || return 1
    [[ $pick == . ]] && { REPLY=; return 0 }
    dir=$pick; [[ $dir == \~(/*|) ]] && dir=$HOME${dir#\~}
    [[ -d $dir || ( $mode == *history && -n ${lines[2]-} ) ]] || return 1
    [[ ${dir:a} == "$PWD" ]] && pick=
    REPLY=$pick
}

_fzf-switcher() {
    (( $+commands[fzf] )) || return 1
    local mode=$1 next key result label fd preview file cols root dir query
    local -a lines picked cwd extra
    local -A needs=(history atuin directory_history atuin files fd directories fd)
    local -A key_mode=(ctrl-f history ctrl-r directory_history ctrl-t files ctrl-g directories)
    local nav='Ctrl+F: All History  Ctrl+R: Directory History  Ctrl+T: Files  Ctrl+G: Directories'
    local search="Search: fuzzy=foo  exact='foo  word='foo'  start=^foo  end=foo\$" logic='exclude=!foo  │  AND=foo bar  OR=foo | bar'
    printf -v cols '%-7s │ %-8s │ %-10s │ %-28s │ %s' AGE STATUS DURATION DIRECTORY COMMAND
    while true; do
        (( $+commands[$needs[$mode]] )) || return 1
        # root: the directory ^D picked, as typed ('' for the current one); dir: the same with ~ expanded.
        dir=$root; [[ $dir == \~(/*|) ]] && dir=$HOME${dir#\~}
        if [[ $mode == *history ]]; then
            # Atuin records each command's logical $PWD, so a picked directory is matched by its absolute logical path.
            cwd=(); [[ $mode == directory_history ]] && cwd=(--cwd ${${root:+${dir:a}}:-.})
            result=$(_atuin-history-rows $cwd |
                fzf --ansi --scheme=history --no-hscroll --read0 --print0 --delimiter=$'\x1f' --with-nth=2.. --nth=2.. --accept-nth=1 \
                    --header="$nav  │  Ctrl+D: Directory  Ctrl+X: Delete"$'\n'"$search  $logic"$'\n'"$cols" \
                    --prompt="${cwd:+Directory }History> " --border-label=${cwd:+${root:+ $root }} \
                    --print-query --query=$query --expect=ctrl-f,ctrl-r,ctrl-t,ctrl-g,ctrl-d,ctrl-x)
            lines=("${(@0)${result%$'\0'}}")   # the query, the key pressed, then the command; each ended by a NUL
        else
            [[ -d $dir ]] || root= dir=
            if [[ $mode == files ]]; then
                label=Files fd="$commands[fd] --type f" extra=(--multi)
                if (( $+commands[bat] )); then preview="$commands[bat] --style=numbers --color=always -- {}"
                else preview="sed -n '1,200p' -- {}"; fi
            else
                label=Directories fd="$commands[fd] --type d" extra=()
                if (( $+commands[eza] )); then preview="$commands[eza] --tree --level=2 --color=always -- {}"
                elif (( $+commands[tree] )); then preview="$commands[tree] -a -L 2 {}"
                else preview='find {} -maxdepth 2 -print 2>/dev/null | head -200'; fi
            fi
            fd+=' --hidden --exclude .git --exclude .cache'${root:+" --search-path ${(q)dir}"}
            # ^L toggles following symlinks and ^O toggles ignored files; the prompt carries the state.
            result=$(FZF_DEFAULT_COMMAND=$fd fzf $extra --scheme=path --no-hscroll --prompt="$label> " \
                --header="$nav  │  Ctrl+D: Directory  Ctrl+L: Links  Ctrl+O: Ignored  Ctrl+P: Preview"$'\n'"$search  $logic" \
                --border-label=${root:+ $root } --print-query --query=$query \
                --preview=$preview --preview-window='right:50%:hidden' \
                --bind='ctrl-p:toggle-preview,alt-k:preview-down,alt-j:preview-up,alt-h:preview-top,alt-g:preview-bottom' \
                --bind='alt-d:preview-half-page-down,alt-u:preview-half-page-up' \
                --bind="ctrl-l:transform:case \"\$FZF_PROMPT\" in
                    '$label> ')               echo 'change-prompt($label+Links> )+reload($fd --follow)' ;;
                    '$label+Links> ')         echo 'change-prompt($label> )+reload($fd)' ;;
                    '$label+Ignored> ')       echo 'change-prompt($label+Links+Ignored> )+reload($fd --follow --no-ignore)' ;;
                    '$label+Links+Ignored> ') echo 'change-prompt($label+Ignored> )+reload($fd --no-ignore)' ;;
                esac" \
                --bind="ctrl-o:transform:case \"\$FZF_PROMPT\" in
                    '$label> ')               echo 'change-prompt($label+Ignored> )+reload($fd --no-ignore)' ;;
                    '$label+Ignored> ')       echo 'change-prompt($label> )+reload($fd)' ;;
                    '$label+Links> ')         echo 'change-prompt($label+Links+Ignored> )+reload($fd --follow --no-ignore)' ;;
                    '$label+Links+Ignored> ') echo 'change-prompt($label+Links> )+reload($fd --follow)' ;;
                esac" \
                --expect=ctrl-f,ctrl-r,ctrl-t,ctrl-g,ctrl-d </dev/tty)
            lines=("${(@f)result}")   # the query, the key pressed, then the picks
        fi
        [[ -n $result ]] || break
        query= key=${lines[2]-} picked=("${(@)lines[3,-1]}")
        next=${key_mode[$key]-}
        if [[ -n $next ]]; then
            (( $+commands[$needs[$next]] )) || continue
            [[ $next == $mode ]] && break
            mode=$next; zle reset-prompt; zle -R; continue
        elif [[ $key == ctrl-x ]]; then
            [[ -n ${picked[1]-} ]] && _atuin-history-delete-exact $picked[1]
            continue
        elif [[ $key == ctrl-d ]]; then
            # The search text survives the trip; ^F becomes the picked directory's history.
            query=$lines[1]
            _fzf-pick-root $mode && { root=$REPLY; [[ $mode == history ]] && mode=directory_history }
            zle reset-prompt; zle -R; continue
        fi
        (( $#picked )) || break
        case $mode in
            *history)    BUFFER=$picked[1]; CURSOR=$#BUFFER ;;
            files)       for file in "${picked[@]}"; do LBUFFER+="${(q)file} "; done ;;
            directories) [[ -n $picked[1] ]] && cd "$picked[1]" ;;
        esac
        break
    done
    zle reset-prompt; zle -R
}

_fzf-history-switcher() { _fzf-switcher history }
_fzf-directory-history-switcher() { _fzf-switcher directory_history }
_fzf-file-switcher() { _fzf-switcher files }
_fzf-directory-switcher() { _fzf-switcher directories }
zle -N _fzf-history-switcher; zle -N _fzf-directory-history-switcher
zle -N _fzf-file-switcher;    zle -N _fzf-directory-switcher

if (( $+commands[fzf] && $+commands[atuin] )); then
    bindkey -M emacs '^F' _fzf-history-switcher
    bindkey -M emacs '^R' _fzf-directory-history-switcher
fi
if (( $+commands[fzf] && $+commands[fd] )); then
    bindkey -M emacs '^T' _fzf-file-switcher
    bindkey -M emacs '^G' _fzf-directory-switcher
fi

# tmux's prefix e sends ESC [99~ (no key does) to a zsh at its prompt: the pane's scrollback opens here in read-only
# Vim (the vimrc's VIM_SCROLLBACK viewer), like a man page, and :a returns to the line as it was.
_tmux-scrollback() {
    tmux capture-pane -p -J -S - -t $TMUX_PANE | env VIM_SCROLLBACK=1 vim -R --not-a-term -
    zle reset-prompt; zle -R
}

# tmux's prefix r and Z write a new stamp beside the tmux sockets, then send ESC [98~ (no key does) to every zsh idle at
# its prompt that set the pane's @zsh-reload-key (below; a shell from an older zshrc gets M-q sz Enter instead). At a
# primary prompt that runs sz, with the half-typed line set aside (push-line) and restored afterwards. The same check
# runs as each line starts (line-init), so a shell that was busy runs sz itself at its next prompt. Only at a primary
# prompt: in the middle of a multi-line command (a PS2 continuation, vared, select) it does nothing, and the reload
# waits for the next primary prompt instead of typing sz into a quoted string or a loop.
_zshrc_stamp=${TMUX:+${${TMUX%%,*}:h}/zshrc-reload} _zshrc_loaded=
[[ -n $_zshrc_stamp ]] && { read -r _zshrc_loaded < $_zshrc_stamp } 2>/dev/null
_zshrc-reload-check() {
    [[ $CONTEXT == start && -z $PREBUFFER ]] || return 0
    local stamp
    [[ -n $_zshrc_stamp ]] && { read -r stamp < $_zshrc_stamp } 2>/dev/null && [[ $stamp != $_zshrc_loaded ]] || return 0
    _zshrc_loaded=$stamp   # first, so a ~/.zshrc that fails to load is not retried at every prompt
    zle push-line; BUFFER=sz; zle accept-line
}
zle -N _tmux-scrollback; zle -N _zshrc-reload-check
bindkey -M emacs '^[[99~' _tmux-scrollback      # prefix e
bindkey -M emacs '^[[98~' _zshrc-reload-check   # prefix r, Z
autoload -Uz add-zle-hook-widget && add-zle-hook-widget line-init _zshrc-reload-check
# Tells tmux that this shell takes ESC [98~; at every load, so a shell started from an older zshrc sets it once sz
# reloads it.
[[ -n $TMUX_PANE ]] && command tmux set -p -t $TMUX_PANE @zsh-reload-key 1 2>/dev/null

# === Files ====================================================================
# Modified-time listings put the newest entry last (next to the prompt); ltr/lrt reverse that.

if (( $+commands[eza] )); then
    # The work palette, also at home: eza's default plain blue is too dark to read on black in xfce4-terminal's default
    # palette, so directories and mount points are orange (256-color 208), and executables green, all without eza's
    # bold (mount points still underlined). Dates, lg's Git "modified" flag and SELinux users are sky blue (75).
    # Compressed files and sizes in GiB lose the palette's dark red for #f33636 (24-bit; a terminal without 24-bit
    # color gets the nearest red). An EZA_COLORS from the environment wins; the one this file set is replaced at each
    # load, so sz picks up a change here.
    [[ -z $EZA_COLORS || $EZA_COLORS == "$_eza_colors" ]] && {
        _eza_colors='di=38;5;208:mp=4;38;5;208:ex=32:da=38;5;75:gm=38;5;75:Su=38;5;75'
        _eza_colors+=':co=38;2;243;54;54:ng=38;2;243;54;54:ug=38;2;243;54;54'
        export EZA_COLORS=$_eza_colors
    }
    # With no path argument, eza lists the names it reads from stdin whenever stdin isn't a terminal (a `noti`
    # job's /dev/null, a pipe, a while-read loop): it listed nothing, or ate the loop's input. So feed it .
    # then; a path argument still takes precedence, and --stdin still reads the real stdin.
    _eza-ls() { if [[ -t 0 ]] || (( $@[(I)--stdin] )); then eza "$@"; else print . | eza "$@"; fi }
    compdef _eza-ls=eza
    _custom-alias Files \
        ls  '_eza-ls -a'                            'List all files with eza.' \
        ll  '_eza-ls -la'                           'Long file listing with eza.' \
        lt  '_eza-ls -la --sort=modified'           'Long listing by modified time, newest last.' \
        ltr '_eza-ls -la --sort=modified --reverse' 'Long listing by modified time, newest first.' \
        lrt '_eza-ls -la --sort=modified --reverse' 'Compatibility alias for ltr.' \
        lg  '_eza-ls -la --git'                     'Long eza listing with Git status.' \
        et  '_eza-ls --tree'                        'Display an eza directory tree.'
else
    _custom-alias Files \
        ls  'command ls -AF --color=auto'    'List all files with GNU ls.' \
        ll  'command ls -lAF --color=auto'   'Long file listing.' \
        lt  'command ls -lAFrt --color=auto' 'Long listing by modified time, newest last.' \
        ltr 'command ls -lAFt --color=auto'  'Long listing by modified time, newest first.' \
        lrt 'command ls -lAFt --color=auto'  'Compatibility alias for ltr.'
fi
(( $+commands[tree] )) && _custom-alias Files tree 'tree -a' 'Show directory trees including hidden entries.'
(( $+commands[dust] )) && _custom-alias Files dust 'dust -r' 'Show disk usage in reverse size order.'

# glow [options] [FILE | URL | -]: Markdown rendered by glow, read in Vim like a man page: read-only, whose VIM_ANSI
# viewer (the vimrc) turns glow's colors into highlighting, so Vim's keys, searches and yanks see plain text and ;a comes
# back here. Lines wrap at the window's width, and when the window changes size (a tmux pane zoomed) the viewer has glow
# render the page again at the new width (VIM_ANSI_CMD); -w gives a fixed width instead. Markdown piped in is kept in a
# temporary file meanwhile. Piped, glow ignores its config file and has no auto style, so that file's style (else dark)
# is passed on; -s given here still wins. glow runs as it is for its commands (config, completion, help), its file
# browser (no file, or a directory), -p, -t, -h and -v, and when its output is not a terminal.
if (( $+commands[glow] )); then
    glow() {
        local conf=${XDG_CONFIG_HOME:-$HOME/.config}/glow/glow.yml src name style out tmp
        local -i i own=0
        local -a run width=(-w $COLUMNS)
        [[ -t 1 && $1 != (config|completion|help) ]] || own=1
        for (( i = 1; i <= $#; i++ )); do
            case ${@[i]} in
                --config)              conf=${@[i+1]}; (( i++ )) ;;
                --config=*)            conf=${@[i]#*=} ;;
                -w|--width)            width=(); (( i++ )) ;;
                -w?*|--width=*)        width=() ;;
                -s|--style)            (( i++ )) ;;
                -p|--pager|-t|--tui|-h|--help|-v|--version) own=1 ;;
                -)                     src=- ;;
                -*)                    ;;
                *)                     src=${@[i]}; [[ -d $src ]] && own=1 ;;
            esac
        done
        [[ -n $src || ! -t 0 ]] || own=1   # no file and nothing piped in: the file browser
        (( own )) && { command glow "$@"; return }
        [[ -r $conf ]] && style=$(sed -nE "s/^style:[[:space:]]*[\"']?([^\"' #]+).*/\1/p" $conf)
        [[ -n $style && $style != auto ]] || style=dark
        name=${${src:#-}:-stdin}
        {
            # Markdown piped in goes to a file that each rendering reads: glow reads a stdin that is not a terminal
            # instead of its file, so it never gets one.
            if [[ -z $src || $src == - ]]; then
                tmp=$(mktemp ${TMPDIR:-/tmp}/glow.XXXXXX) && cat > $tmp || return
                if [[ -n $src ]]; then set -- "${@/#%-/$tmp}"; else set -- "$@" $tmp; fi
            fi
            run=($commands[glow] -s ${style/#\~/$HOME} "$@")
            out=$("${run[@]}" $width </dev/null) || return
            print -r -- $out |
                env VIM_ANSI="glow ${name:t}" VIM_ANSI_CMD=${width:+${(j: :)${(qq)run}}} vim -R --not-a-term -
        } always {
            [[ -n $tmp ]] && rm -f $tmp
        }
    }
    _custom-register Files glow 'Read Markdown rendered by glow in Vim, like a man page.'
fi

# === Search ===================================================================

_custom-alias Search grep 'grep --color=auto' 'Run GNU grep with automatic color.'
# grep -Z's "file\0line:text" (ANSI-colored) becomes "file : line : text". zgrep rejects -Z, so for z
# the file name ends at the first ":" in grep's separator color instead.
_grep-pretty() { perl -pe 'BEGIN { $ansi = qr/\e\[[0-9;]*[A-Za-z]/ } s/\0|\e\[[0-9;]*m\e\[K:\e\[m\e\[K/ : /; s/( : (?:$ansi)*[0-9]+(?:$ansi)*):/$1 : /' }
# e, er, ep and z split their arguments like GNU grep does it, so after -e/-f/--regexp/--file every operand is a file
# rather than the pattern. e searches only the files directly in directory operands (default .) and er recurses
# through them; ep (grep) and z (zgrep) take files only, skipping directories, and read stdin when there are none.
# Patterns are extended regexes unless a matcher option (-F, -G, -P, ...) is given, since grep rejects two matchers.
_e-grep() {  # e|er|ep|z args...
    setopt localoptions extendedglob
    local name=$1; shift
    local -a opts operands files; local a pat re=-E
    while (( $# )); do
        a=$1; shift
        case $a in
            --) operands+=("$@"); break ;;
            --(regexp|file)=*) pat=1; opts+=("$a") ;;
            --(regexp|file)) pat=1; opts+=("$a" "$1"); shift $(( $# > 0 )) ;;
            --(max-count|after-context|before-context|context|directories|devices|include|exclude|exclude-from|exclude-dir|label|binary-files|group-separator))
                opts+=("$a" "$1"); shift $(( $# > 0 )) ;;
            --(extended-regexp|basic-regexp|perl-regexp|fixed-strings)) re=; opts+=("$a") ;;
            --*) opts+=("$a") ;;
            -?*) opts+=("$a")
                [[ $a == -[^efmABCdD]#[EFGP]* ]] && re=
                # In a bundle such as -iA3 or -iA 3, the first letter that takes an argument takes the rest of the
                # word, or else the next word.
                if [[ $a == (#b)-[^efmABCdD]#([efmABCdD])(*) ]]; then
                    [[ $match[1] == [ef] ]] && pat=1
                    [[ -z $match[2] ]] && { opts+=("$1"); shift $(( $# > 0 )) }
                fi ;;
            *) operands+=("$a") ;;
        esac
    done
    if [[ -z $pat ]]; then
        (( $#operands )) || { print "Usage: $name <pattern> [file${${name:#(ep|z)}:+|dir}...]"; return 1 }
        opts+=(-e "$operands[1]"); shift operands
    fi
    case $name in
        e)  (( $#operands )) || files=(*(DN-.))
            for a in "${operands[@]}"; do
                if [[ -d $a ]]; then files+=(${a%/}/*(DN-.)); else files+=("$a"); fi
            done
            (( $#files )) || return 1
            print -rN -- "${files[@]}" | xargs -0r grep -Z $re -HsiIn --color=always "${opts[@]}" -- | _grep-pretty ;;
        er) grep -Z $re -HsiInr --color=always "${opts[@]}" -- "${operands[@]}" | _grep-pretty ;;
        ep) grep -Z $re -HsiIn --color=always "${opts[@]}" -- "${operands[@]}" | _grep-pretty ;;
        z)  zgrep $re -HsiIn --color=always "${opts[@]}" -- "${operands[@]}" | _grep-pretty ;;
    esac
}
e()  { _e-grep e "$@" }
er() { _e-grep er "$@" }
ep() { _e-grep ep "$@" }
z()  { _e-grep z "$@" }
hs()   { (( $# )) || { print 'Usage: hs <history-search-pattern>'; return 1 }; fc -l 1 | grep -EHiIn --color=auto -- "$*" }
fdir() { (( $# )) || { print 'Usage: fdir <directory-name-pattern>'; return 1 }; find . -type d -iname "*$1*" }
ff()   { (( $# )) || { print 'Usage: ff <file-name-pattern>'; return 1 }; find . -type f -iname "*$1*" }
_custom-register Search \
    e    'Case-insensitive grep of the files directly in each directory (default .), with formatted file/line output.' \
    er   'Recursive case-insensitive grep with formatted file/line output.' \
    ep   'Search explicitly supplied files with formatted grep output.' \
    z    'Search compressed files with formatted zgrep output.' \
    hs   'Search shell history with a regular expression.' \
    fdir 'Find directories by case-insensitive name substring.' \
    ff   'Find files by case-insensitive name substring.'

# === Git ======================================================================

unalias gdc gdco 2>/dev/null  # older aliases would expand inside the function definitions below

gg() { git grep -in --color=always "$@" | sed -e 's/:/ : /1' -e 's/:/ : /2' }
_custom-register Git gg 'Search tracked Git content with formatted output.'
_custom-alias Git \
    gf 'git ls-files | rg'                        'Search tracked Git filenames with ripgrep.' \
    gm 'git config pull.rebase false && git pull' 'Set pull to merge for this repo, then pull.' \
    gr 'git config pull.rebase true && git pull'  'Set pull to rebase for this repo, then pull.' \
    gs 'git status'                               'Show Git working-tree status.' \
    ga 'git add .'                                'Stage all changes under the current directory.'
gc() { git commit -m "$*" }

# gdc/gdo [git-diff-options]: a simplified diff of the working tree (gdo: against origin's default branch), colored and
# paged on a terminal; gdco/gdoo [file] [git-diff-options] write it to ./git-diff-commit and ./git-diff-origin.
# gla/glf/glo [-me] [git-log-options]: the graph history of all refs (glf with each commit's changed files; glo the
# commits not yet in the upstream branch), from git log itself, colored and paged on a terminal; glao/glfo/gloo
# [file] [-me] [git-log-options] write it to ./git-log-all, ./git-log-files and ./git-log-origin, which the vimrc colors
# as git colors it in a terminal. -me is --author=<git user.name>. A writer's first argument names another file unless
# it starts with -, and a first -- keeps the default (gdoo -- src/). All are git-helpers.py, a Python program in
# ~/env-config/scripts that any shell can run with these names as its first word (git-helpers.py gdc); the docstring at
# its top describes them all.
_git-helpers() {
    whence -p git-helpers.py >/dev/null ||
        { print -u2 "$1: git-helpers.py not found on PATH (it is in ~/env-config/scripts)"; return 127 }
    git-helpers.py "$@"
}
gdc()   { _git-helpers gdc "$@" }
gdo()   { _git-helpers gdo "$@" }
gdco()  { _git-helpers gdco "$@" }
gdoo()  { _git-helpers gdoo "$@" }
gla()   { _git-helpers gla "$@" }
glf()   { _git-helpers glf "$@" }
glo()   { _git-helpers glo "$@" }
glao()  { _git-helpers glao "$@" }
glfo()  { _git-helpers glfo "$@" }
gloo()  { _git-helpers gloo "$@" }
# git diff options for option prefixes, plain files otherwise (what gdc and gdco completed as aliases).
_git-diff-completion() { if [[ $PREFIX == -* ]]; then local service=git-diff; _git; else _files; fi }
compdef _git-diff-completion gdc gdco gdo gdoo
# -me (until a --) and git log options for option prefixes, plain files otherwise.
_gl-completion() {
    [[ $PREFIX == -* ]] || { _files; return }
    local ret=1 service=git-log; local -a me=('-me:show only your commits')
    (( ${${words[1,CURRENT-1]}[(I)--]} )) || { _describe -t git-log-options 'git log option' me && ret=0 }
    _git && ret=0
    return ret
}
compdef _gl-completion gla glf glo glao glfo gloo
# The zsh helpers these replaced (glog and glogf became gla and glf): a shell reloading from an older zshrc drops them.
unfunction _git-origin-ref glog glogf 2>/dev/null; unset _glog_format

DEFAULT_CLONE_REPO=${DEFAULT_CLONE_REPO:-/nfs/site/disks/ttl.git.zsc10.001/ttlh78/hub-ttlh78-a0}
clone() { git clone $DEFAULT_CLONE_REPO "$@" }

_custom-register Git \
    gc    'Commit staged changes using the arguments as the message.' \
    gdc   'Show a simplified working-tree diff.' \
    gdco  'Write a simplified working-tree diff to git-diff-commit.' \
    gdo   'Show a simplified diff against the origin default branch.' \
    gdoo  'Write a simplified diff against the origin default branch to git-diff-origin.' \
    gla   'Show decorated graph history for all refs; -me shows only your commits.' \
    glf   'Show graph history plus changed filenames; -me shows only your commits.' \
    glo   'Show every commit that has not made it into the tracked upstream branch; -me shows only yours.' \
    glao  'Write what gla shows to git-log-all (or a named file); -me keeps only your commits.' \
    glfo  'Write what glf shows to git-log-files (or a named file); -me keeps only your commits.' \
    gloo  'Write what glo shows to git-log-origin (or a named file); -me keeps only yours.' \
    clone 'Clone the configured default work repository.'

# === Editors & Vim sessions ===================================================

unalias v 2>/dev/null  # the older alias would expand inside the function definition below

# v [-g|--glow] [vim args...]: terminal Vim. -g or --glow as the first argument reads Markdown through glow instead
# (v -g README.md is glow README.md), in place of Vim's own -g (GVim, which g opens).
v() {
    [[ $1 == (-g|--glow) ]] || { command vim "$@"; return }
    (( $+functions[glow] )) || { print -u2 'v: -g needs glow: pacman -S glow, then sz'; return 127 }
    shift; glow "$@"
}
compdef v=vim
_custom-register Editors v 'Open terminal Vim; -g or --glow first reads Markdown through glow.'

_custom-alias Editors \
    g      gvim            'Open GVim.' \
    vv     'vim -O'        'Open files in side-by-side Vim splits.' \
    vs     'vim -o'        'Open files in stacked Vim splits.' \
    vimv   'vim ~/.vimrc'  'Edit ~/.vimrc in Vim.' \
    gvimv  'gvim ~/.vimrc' 'Edit ~/.vimrc in GVim.' \
    sv     sudoedit        'Edit a privileged file through sudoedit.'

# _by-path root: REPLY=root/by-path/<physical cwd> ("/" is __root__), where vl sessions are kept per directory.
_by-path() { REPLY=${${PWD:A}#/}; REPLY=$1/by-path/${REPLY:-__root__} }

# vl/gl [name | path | -- vim-args]: resume $OBSESSION_ROOT/named/<name>.vim, a session file, or this directory's
# $OBSESSION_ROOT/by-path/<physical cwd>/Session.vim, in terminal Vim (vl) or in GVim (gl). A name is a named session
# (.vim optional); a word with a / in it, or a file here that no named session shares a name with, is a session file.
# No -S: Vim takes the session lock before sourcing.
_session-load() {  # vim|gvim [name | path | -- vim-args]
    local editor=$1 session; shift
    if (( $# )) && [[ $1 != -- ]]; then
        session=$1; shift
        if [[ $session != */* && ( -f $OBSESSION_ROOT/named/${session%.vim}.vim || ! -f $session ) ]]; then
            session=$OBSESSION_ROOT/named/${session%.vim}.vim
        elif [[ ! -f $session && $session != *.vim ]]; then
            session+=.vim
        fi
    else
        [[ $1 == -- ]] && shift
        _by-path $OBSESSION_ROOT
        session=$REPLY/Session.vim
    fi
    [[ -f $session ]] || { print -u2 "No saved session:\n\t$session"; return 1 }
    OBSESSION_LOAD_SESSION=${session:a} command $editor "$@"
}
vl() { _session-load vim "$@" }
gl() { _session-load gvim "$@" }
# Tab after vl/gl: the named sessions (not once the word has a /), and session files (*.vim) by path.
_session-complete() {
    if (( CURRENT == 2 )); then
        local ret=1
        local -a sessions=($OBSESSION_ROOT/named/*.vim(N:t:r))
        [[ $PREFIX == */* ]] || { (( $#sessions )) && _describe -t named-sessions 'named session' sessions && ret=0 }
        _files -g '*.vim(-.)' && ret=0
        return ret
    fi
    _files
}
compdef _session-complete vl gl

# dirdiff dir-a dir-b: diff two directories with ZFDirDiff in terminal Vim, but without NERDTree, Obsession (no session
# is tracked), or GitGutter; q in the diff tree quits Vim. The paths reach Vim through the environment, so quoting
# cannot break them.
dirdiff() {
    (( $# == 2 )) || { print -u2 'usage: dirdiff <dir-a> <dir-b>'; return 2 }
    local d
    for d; do [[ -d $d ]] || { print -u2 "dirdiff: not a directory: $d"; return 1 }; done
    OBSESSION_AUTO=0 ZFDIRDIFF_A=$1 ZFDIRDIFF_B=$2 command vim \
        --cmd 'let g:loaded_nerd_tree = 1 | let g:loaded_obsession = 1 | let g:loaded_gitgutter = 1' \
        -c 'call ZFDirDiff($ZFDIRDIFF_A, $ZFDIRDIFF_B)' \
        -c 'autocmd TabClosed * if tabpagenr("$") == 1 && !exists("t:ZFDirDiff_taskData") | call timer_start(0, {-> execute("qa")}) | endif'
}
compdef _directories dirdiff

# Obsession before upstream 5d63e5b inserts legacy `let` lines into Vim 9.2's vim9script sessions, which then fail to
# restore (E1126). Fast-forward the plugin and repair sessions saved that way. The old ob-fix (an alias) patched those
# lines out of the plugin with sed instead; that edit, the clone's only one, is undone first so that the pull can
# fast-forward.
unalias ob-fix 2>/dev/null
ob-fix() {
    local dir=~/.vim/pack/plugins/start/obsession f first
    [[ -d $dir/.git ]] || { print -u2 "ob-fix: no Obsession clone in $dir"; return 1 }
    [[ -z $(git -C $dir diff -U0 -- plugin/obsession.vim | grep '^[-+] ' | grep -v 'g:this_[a-z]* = v:this_session') ]] &&
        git -C $dir checkout --quiet -- plugin/obsession.vim
    git -C $dir pull --ff-only --quiet || return
    for f in $OBSESSION_ROOT/**/*.vim(N.); do
        read -r first < $f
        [[ $first == vim9script ]] && grep -q '^let g:this_[a-z]* = v:this_session$' $f || continue
        sed -i 's/^let \(g:this_[a-z]* = v:this_session\)$/\1/' $f && print -r -- "Repaired $f"
    done
}

_custom-register Editors \
    vl      "Load this directory's default session, a named session, or a session file, in terminal Vim." \
    gl      "Load this directory's default session, a named session, or a session file, in GVim." \
    dirdiff 'Diff two directories in Vim (ZFDirDiff), without NERDTree, Obsession, or GitGutter.' \
    ob-fix  'Update Vim Obsession for Vim 9 sessions and repair sessions it broke.'

# === Packages =================================================================

_custom-alias Packages \
    pi 'sudo pacman -S'   'Install packages with pacman.' \
    pr 'sudo pacman -Rsu' 'Remove packages and unneeded dependencies with pacman.' \
    ps 'pacman -Ss'       'Search official Arch repositories.' \
    pu 'sudo pacman -Syu' 'Upgrade installed repository packages.' \
    pq 'pacman -Qn'       'List installed repository packages.' \
    pl 'pacman -Qqen'     'List explicitly installed repository packages.'
(( $+commands[yay] )) && _custom-alias Packages \
    yi 'yay -S'       'Install a package through yay.' \
    yr 'yay -Rns'     'Remove packages, unneeded dependencies and saved configs through yay.' \
    ys 'yay -Ss'      'Search repositories and the AUR through yay.' \
    yu 'yay'          'Run yay with no preset arguments.' \
    yq 'pacman -Qm'   'List installed foreign/AUR packages.' \
    yl 'pacman -Qqem' 'List explicitly installed foreign/AUR packages.'

# Runs inside update's PTY (zsh -ic), so everything shares one sudo authentication.
_update-body() {
    local rc=0 keepalive
    printf '\n=== Arch Update: %s ===\n\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    sudo -v || { printf '\n--- Sudo authentication failed; stopping ---\n\n'; return 1 }
    # Keep the sudo timestamp fresh so yay/env-save/checkservices never re-prompt during a long pacman run.
    ( while sleep 60; do sudo -n -v >/dev/null 2>&1 || exit; done ) &!
    keepalive=$!
    # Every prompt takes its default answer: proceed, exclude nothing, no clean builds, no diffs.
    # A prompt that defaults to "no" (e.g. a package conflict) stops the update; pu/yu stay interactive.
    {
        printf '\n--- Updating via Pacman ---\n\n'
        if sudo pacman -Syu --noconfirm; then
            (( $+commands[yay] )) && { printf '\n--- Updating via Yay ---\n\n'; yay --answerupgrade None --answerclean None --answerdiff None --noconfirm; rc=$? }
            # Before env-save, so that its Vim plugin inventory has the new commits.
            (( $+functions[plugin-update] )) && { printf '\n--- Updating Vim and tmux Plugins ---\n\n'; plugin-update }
            (( $+commands[env-save] )) && { printf '\n--- Saving Environment State ---\n\n'; env-save }
            # Lists services still running replaced files. -P skips the interactive pacdiff, -L leaves systemd to
            # pacman's own hooks, and -R restarts nothing: restarting the login manager would end the session.
            printf '\n--- Checking Services ---\n\n'
            if (( $+commands[checkservices] )); then sudo checkservices -P -L -R; else print 'checkservices not found; install archlinux-contrib.'; fi
        else
            printf '\n--- Pacman update failed; stopping ---\n\n'; rc=1
        fi
    } always { kill $keepalive 2>/dev/null }
    return $rc
}

# Terminal transcript → plain log: strip control sequences and pacman redraw noise, keeping
# one line per completed package step.
_update-log-clean() {
    perl -ne '
        s/\r\n/\n/g; s/\e\].*?(?:\a|\e\\)//g; s/\e\[[0-?]*[ -\/]*[@-~]//g; s/\x08//g; s/\r/\n/g; s/\n\z//;
        my @lines = split /\n/, $_, -1; @lines = ("") unless @lines;
        for my $line (@lines) {
            if ($line =~ /\[[#=-]+\]\s*\d{1,3}%\s*\z/) {                                  # progress bar
                if ($line =~ /^\s*\(\s*(\d+)\/(\d+)\)\s+(.+?)\s+\[[#=-]+\]\s*100%\s*\z/) {
                    my ($done, $total, $task) = ($1, $2, $3);
                    if ($task =~ /^(?:upgrading|installing|downgrading|reinstalling|removing)\b/
                        || ($done == $total && $task =~ /^(?:checking|loading)\b/)) {
                        my $summary = sprintf("(%d/%d) %s", $done, $total, $task);
                        print "$summary\n" unless $seen{$summary}++;
                        $blank = 0;
                    }
                }
                $after_progress = 1; next;
            }
            if    ($line =~ /^:: Synchronizing package databases/) { ($sync, $retrieving) = (1, 0) }
            elsif ($line =~ /^:: Retrieving packages/)             { ($sync, $retrieving) = (0, 1) }
            elsif ($line =~ /^:: /)                                { $sync = $retrieving = 0 }
            next if $sync && $line =~ /^\s*(?:core|extra|multilib)\s*\z/;                 # redraw leftovers
            if ($retrieving && $line =~ /^\s+\S+-\S+-(?:x86_64|any|i686)\s*\z/) { $after_progress = 1; next }
            if ($line =~ /^\s*\z/) { next if $blank || $after_progress; $blank = 1 }
            else                   { $blank = $after_progress = 0 }
            print "$line\n";
        }'
}

update() {
    local log_dir=$HOME/.updates update_rc completion_rc
    local log=$log_dir/update.$(date '+%y%m%d-%H%M%S').log
    mkdir -p $log_dir
    ln -sfn $log ~/update.log  # always the latest log
    # script gives the whole interactive update one PTY; tee shows the raw stream and logs a cleaned copy.
    script -qefc 'zsh -ic _update-body' /dev/null 2>&1 | tee >(_update-log-clean > $log)
    update_rc=$pipestatus[1]
    # The completion refresh has to change *this* shell, so it runs outside the PTY.
    { printf '\n--- Refreshing Shell Completions ---\n\n'; completion-refresh } > >(tee >(_update-log-clean >> $log)) 2>&1
    completion_rc=$?
    (( update_rc )) && return $update_rc
    return $completion_rc
}

# Read-only preview of update. checkupdates syncs a throwaway copy of the databases, so the real
# sync DB never gets ahead of the installed packages (no sudo, no partial-upgrade risk).
update-check() {
    local rc=0 news pending color=never pacman_count=0 aur_count=0
    local -a lines updates
    # Pinned so _update-totals reads the same database checkupdates just synced.
    local -x CHECKUPDATES_DB=${CHECKUPDATES_DB:-${TMPDIR:-/tmp}/checkup-db-$UID/}
    [[ -t 1 ]] && color=always
    printf '\n--- Pending Pacman Updates ---\n\n'
    if (( $+commands[checkupdates] )); then
        pending=$(checkupdates)
        case $? in
            0) print -r -- $pending | _update-colorize; lines=(${(f)pending}); updates+=($lines); pacman_count=$#lines ;;
            2) print 'Nothing to update.' ;;
            *) rc=1 ;;
        esac
    else
        print 'checkupdates not found; install pacman-contrib.'; rc=1
    fi
    if (( $+commands[yay] )); then
        printf '\n--- Pending AUR Updates ---\n\n'
        if pending=$(yay -Qua --color never); then
            print -r -- $pending | _update-colorize; lines=(${(f)pending}); updates+=($lines); aur_count=$#lines
        else
            print 'Nothing to update.'
        fi
        # News, totals and the restart verdict go last so they stay on screen; yay only prints news items
        # newer than the last database sync.
        printf '\n--- Arch News Since the Last Update ---\n\n'
        if news=$(yay -Pw --color $color); then print -r -- ${news:-Nothing new.}; else print 'Could not fetch the Arch news feed.'; rc=1; fi
    fi
    printf '\n--- Totals ---\n\n'
    _update-totals $pacman_count $aur_count
    printf '\n--- Restart Required? ---\n\n'
    _update-restart $updates
    return $rc
}

# "name old -> new" update lists: old version, arrow and new version each start on one column across
# the list. Name and arrow are yellow; versions split into whole numbers, letter runs and separators,
# and only the parts that differ (what is left after the common prefix and suffix) are coloured, red
# in the old version and green in the new. Colour on a terminal only.
_update-colorize() {
    perl -MList::Util=max,min -0777 -pe '
        sub mark { my ($pre, $suf, $color, @v) = @_;
            join("", @v[0 .. $pre - 1]) . "\e[${color}m" . join("", @v[$pre .. $#v - $suf]) . "\e[0m" . join("", @v[@v - $suf .. $#v]) }
        my $name_width = max(0, map length, /^(\S+) \S+ -> /mg);
        my $old_width = max(0, map length, /^\S+ (\S+) -> /mg);
        s{^(\S+) (\S+) -> (\S+)}{
            my ($name, $old, $new) = ($1, $2, $3);
            my @o = $old =~ /\d+|[[:alpha:]]+|./g; my @n = $new =~ /\d+|[[:alpha:]]+|./g;
            my ($max, $pre, $suf) = (min(scalar @o, scalar @n), 0, 0);
            $pre++ while $pre < $max && $o[$pre] eq $n[$pre];
            $suf++ while $suf < $max - $pre && $o[-1 - $suf] eq $n[-1 - $suf];
            my ($name_pad, $old_pad) = (" " x ($name_width - length $name), " " x ($old_width - length $old));
            "\e[33m$name\e[0m$name_pad " . mark($pre, $suf, 31, @o) . "$old_pad \e[33m->\e[0m " . mark($pre, $suf, 32, @n)
        }mge;
        s/\e\[\d+m//g unless -t STDOUT'
}

# Update counts, with the pacman sizes indented under them. pacman -p can never commit anything, and its
# targets include new dependencies, so the sizes cover what -Syu would really do. %s is the download size
# less anything already cached; installed sizes only exist as rounded text in -Si and -Qi.
_update-totals() {
    local pacman_count=$1 aur_count=$2 mib=1048576.0 download=0 installed removed target note dep_word=dependencies
    local -a targets
    if (( pacman_count )); then
        targets=(${(f)"$(pacman -Sup --dbpath $CHECKUPDATES_DB --logfile /dev/null --print-format '%r/%n %s' 2>/dev/null)"})
    fi
    local new_deps=$(( $#targets - pacman_count ))
    (( new_deps == 1 )) && dep_word=dependency
    (( new_deps > 0 )) && note=" (+$new_deps new $dep_word)"
    printf 'Pacman Updates: %d%s\n' $pacman_count "$note"
    if (( $#targets )); then
        for target in $targets; do (( download += ${target##* } )); done
        installed=$(LC_ALL=C pacman -Si --dbpath $CHECKUPDATES_DB ${targets%% *} | _update-isize-sum)
        removed=$(LC_ALL=C pacman -Qi ${${targets%% *}#*/} 2>/dev/null | _update-isize-sum)
        printf '\t%-21s %.2f MiB\n' 'Total Download Size:' $(( download / mib )) 'Total Installed Size:' $(( installed / mib )) 'Net Upgrade Size:' $(( (installed - removed) / mib ))
    elif (( pacman_count )); then
        print '\tSizes unavailable: pacman could not plan the upgrade.'
    fi
    (( $+commands[yay] )) || return
    note=''
    (( aur_count )) && note=' (sizes are only known after building)'
    printf '\nAUR Updates: %d%s\n' $aur_count "$note"
}

# Adds up the "Installed Size" fields of pacman -Si/-Qi output, in bytes.
_update-isize-sum() {
    perl -ne '
        BEGIN { %power = (B => 0, KiB => 1, MiB => 2, GiB => 3) }
        $sum += $1 * 1024 ** $power{$2} if /^Installed Size\s*:\s*([\d.]+) (\S+)/;
        END { printf "%.0f", $sum }'
}

# Restart verdict for pending "name old -> new" updates, checked against the running system. A reboot is
# needed for the packages that own the running kernel's module directory (the kernel and its prebuilt
# modules), DKMS modules, and NVIDIA libraries whose new version won't match the loaded driver. One is
# recommended for CPU microcode and core components running processes keep using. Plasma, KDE Frameworks
# and Qt otherwise only need a fresh session.
_update-restart() {
    local kernel=$(uname -r) kernel_pkg nvidia line name version width=0 session_count=0 i
    local -a running session required recommended reasons
    kernel_pkg=$(pacman -Qoq /usr/lib/modules/$kernel/vmlinuz 2>/dev/null)
    running=(${(f)"$(pacman -Qoq /usr/lib/modules/$kernel 2>/dev/null)"})
    session=(${(f)"$(pacman -Qgq plasma kf6 2>/dev/null)"})
    [[ -r /sys/module/nvidia/version ]] && nvidia=$(</sys/module/nvidia/version)
    [[ -d /usr/lib/modules/$kernel ]] || required+=($kernel 'running kernel was already replaced by an earlier update')
    for line in "$@"; do
        name=${line%% *} version=${${${line#* -> }%% *}#*:}
        version=${version%-*}
        if [[ $name == $kernel_pkg ]]; then required+=($name "running kernel ($kernel)")
        elif [[ $name != *-headers ]] && (( $running[(Ie)$name] )); then required+=($name 'kernel module for the running kernel')
        elif [[ $name == *-dkms ]]; then required+=($name 'DKMS kernel module; the loaded one stays old')
        elif [[ $name == (lib32-|)nvidia-utils && -n $nvidia && $version != $nvidia ]]; then required+=($name "NVIDIA $version libraries won't match the loaded $nvidia driver")
        elif [[ $name == (amd|intel)-ucode ]]; then recommended+=($name 'CPU microcode only loads at boot')
        elif [[ $name == (systemd|glibc|dbus|dbus-broker) ]]; then recommended+=($name 'core component that running processes keep using')
        elif [[ $name == qt6-* ]] || (( $session[(Ie)$name] )); then (( session_count++ ))
        fi
    done
    if (( $#required )); then print 'Yes, reboot after updating:'
    elif (( $#recommended )); then print 'Recommended, reboot after updating:'
    elif (( session_count )); then print "Log out and back in after updating ($session_count KDE Plasma, KDE Frameworks and Qt packages)."
    else print 'No.'
    fi
    reasons=($required $recommended)
    for (( i = 1; i < $#reasons; i += 2 )); do (( width = $#reasons[i] > width ? $#reasons[i] : width )); done
    (( $#reasons )) && printf "\t%-${width}s  %s\n" $reasons
}

search() {
    print '--- From Pacman ---'; pacman -Ss "$@"
    if (( $+commands[yay] )); then print '\n--- From AUR ---'; yay -Ss "$@"; fi
}

_custom-register Packages \
    update       'Upgrade the system with pacman/yay without prompting, then Vim/tmux plugins, env-save and checkservices.' \
    update-check 'List pending pacman and AUR updates, Arch news and totals without installing anything.' \
    search       'Search official Arch repositories and the AUR when yay is available.'

# === System ===================================================================

wineprefix() {
    (( $# == 1 )) || { print 'Usage: wineprefix <name>'; return 1 }
    export WINEPREFIX=$HOME/.wine-$1
    print -r -- "Using Wine prefix: $WINEPREFIX"
}
_wineprefix() {
    (( CURRENT == 2 )) || return
    local dir; local -a prefixes
    for dir in ~/.wine-*(N/); do prefixes+=("${${dir:t}#.wine-}:$dir"); done
    if (( $#prefixes )); then _describe 'Wine prefix' prefixes; else _message 'no ~/.wine-* prefixes found'; fi
}
compdef _wineprefix wineprefix
_custom-register System wineprefix 'Select a named Wine prefix under ~/.wine-<name>.'

_custom-alias System \
    mount-windows   'sudo mount -t ntfs-3g UUID=369CE5FA9CE5B491 /mnt/windows' 'Mount the configured Windows NTFS volume.' \
    unmount-windows 'sudo umount /mnt/windows'                                 'Unmount /mnt/windows.'

diskcheck() {
    print '=== ROOT ===';                   findmnt /
    print '\n=== HOME ===';                 findmnt /home
    print '\n=== LVM LOGICAL VOLUMES ===';  sudo lvs -o lv_name,vg_name,lv_size,devices
    print '\n=== LVM PHYSICAL VOLUMES ==='; sudo pvs -o pv_name,pv_size,pv_free,vg_name
    print '\n=== PHYSICAL DISKS ===';       lsblk -d -o NAME,SIZE,MODEL,SERIAL
}
_custom-register System diskcheck 'Show root/home mounts, LVM state, and physical disks.'

# === Applications & tools =====================================================

[[ -f ~/trading-dashboard/main.py ]] && _custom-alias Applications td 'python ~/trading-dashboard/main.py &' 'Launch the Trading Dashboard.'

(( $+commands[kitten] )) && _custom-alias Tools icat 'kitten icat' 'Display an image in Kitty.'
[[ -f ~/.config/kitty/kitty.conf ]] && _custom-alias Tools vimk 'vim ~/.config/kitty/kitty.conf' 'Edit the Kitty configuration.'
(( $+commands[btop] )) && _custom-alias Tools monitor btop 'Open btop system monitoring.'
_custom-alias Tools \
    view          'feh --auto-zoom --image-bg black --scale-down'        'View images scaled to fit on a black background.' \
    mouse-battery 'solaar show 2>/dev/null | grep "Battery:" | tail -1' 'Show the mouse battery level reported by Solaar.'

# noti [-f] <command> [args...] | noti [-f] -c|-- '<shell expression>': run it in the background with output in its own
# log, $NOTI_LOG_DIR/by-path/<physical cwd>/noti.<name>.<time>[.N].log (so tn can find it from the same directory), then
# email the result plus the log's tail to $NOTI_EMAIL; -f runs it here in the foreground instead. noti.py, a Python
# program in ~/env-config/scripts that other shells can run alone, makes the log, its header and the email (through
# mailx or mail); the docstring at its top describes them. This function keeps what only zsh can do. The job is this
# same noti call, eval'd so that jobs lists it as typed (noti make -j8) and kill %N stops it; it finds the log and start
# time noti.py _start printed in _noti_job_log. The command runs in a subshell of the job, so kill %N (TERM), a hang-up
# or INT ends all of it and the email says which, with no stdin, so a read gets EOF instead of stopping the job. -f
# evaluates it in this shell itself, so a cd stays. The command sees no positional parameters, as at the prompt, and
# this function's locals all start with _noti_, so an expression sees the shell's own variables (noti -c 'make >$log'
# writes your $log, not the noti log).
noti() {
    local _noti_usage="Usage:\tnoti [-f] <command> [args...]\n\tnoti [-f] -c '<shell expression>'\n\tnoti [-f] -- '<shell expression>'\nOptions:\n\t-f, --foreground\tRun here and wait instead of in the background."
    local -i _noti_fg=0 _noti_rc
    local _noti_job=$_noti_job_log _noti_job_log _noti_cmd _noti_name _noti_out _noti_signal _noti_dir=$PWD
    [[ $1 == (-f|--foreground) ]] && { _noti_fg=1; shift }
    (( $# )) || { print -u2 $_noti_usage; return 2 }
    if [[ $1 == (-c|--) ]]; then
        (( $# == 2 )) || { print -u2 $_noti_usage; return 2 }
        _noti_cmd=$2 _noti_name=${${(z)2}[1]:t}
        _noti_name=${_noti_name:-shell}
    else
        _noti_cmd=${(j: :)${(q)@}} _noti_name=${1:t}
    fi
    if [[ -n $_noti_job ]]; then
        trap '_noti_signal=HUP' HUP; trap '_noti_signal=INT' INT; trap '_noti_signal=TERM' TERM
        ( trap - HUP INT TERM; shift $#; eval -- "$_noti_cmd" ) </dev/null >>${_noti_job%%$'\n'*} 2>&1
        _noti_rc=$?
        NOTI_PROG=noti noti.py _end "$_noti_name" ${_noti_job%%$'\n'*} ${_noti_job#*$'\n'} $_noti_rc "$_noti_signal" </dev/null >>${_noti_job%%$'\n'*} 2>&1
        return $_noti_rc
    fi
    whence -p noti.py >/dev/null || { print -u2 'noti: noti.py not found on PATH (it is in ~/env-config/scripts)'; return 127 }
    if (( _noti_fg )); then
        _noti_out=$(NOTI_PROG=noti noti.py _start --foreground "$_noti_name" "$_noti_cmd") || return
        shift $#
        eval -- "$_noti_cmd"
        _noti_rc=$?
        NOTI_PROG=noti noti.py _end "$_noti_name" - $_noti_out $_noti_rc '' "$_noti_cmd" "$_noti_dir"
        return $_noti_rc
    fi
    _noti_out=$(NOTI_PROG=noti NOTI_LOG_DIR=$NOTI_LOG_DIR noti.py _start "$_noti_name" "$_noti_cmd") || return
    _noti_job_log=$_noti_out
    eval "noti ${(j: :)${(@q+)@}} &"
    print -r -- "noti: $_noti_name running in the background; log: ${_noti_out%%$'\n'*}"
}

# tn [N | name] | tn -l: follow the log of a noti started in this directory (physical path, as vl finds sessions): the
# newest one still running, else the newest; name looks only at that command's logs, and N takes the Nth newest, as
# numbered by tn -l. tn stops when the job ends and prints its result; Ctrl+C stops only tn. It is noti.py --tail (tn -l
# is noti.py --list), which other shells can run too.
tn() {
    whence -p noti.py >/dev/null || { print -u2 'tn: noti.py not found on PATH (it is in ~/env-config/scripts)'; return 127 }
    if [[ $1 == (-l|--list) ]]; then NOTI_PROG=tn NOTI_LOG_DIR=$NOTI_LOG_DIR noti.py --list
    else NOTI_PROG=tn NOTI_LOG_DIR=$NOTI_LOG_DIR noti.py --tail "$@"; fi
}
# The numbers with each run's status, start time and command, then the command names (noti.py _complete).
_tn() {
    local line; local -a logs names
    for line in ${(f)"$(NOTI_LOG_DIR=$NOTI_LOG_DIR noti.py _complete 2>/dev/null)"}; do
        case ${line%%$'\t'*} in
            log)  logs+=("${line#*$'\t'}") ;;
            name) names+=("${line#*$'\t'}") ;;
        esac
    done
    _arguments '(1)'{-l,--list}"[list this directory's noti logs]" \
        '(-l --list)1: :{_describe -V -t logs "noti log" logs; _describe -t names "command name" names}'
}
compdef _tn tn

_custom-register Tools \
    noti 'Run a command or shell expression in the background (-f here), then email its result (noti.py).' \
    tn   'Follow the newest running noti log from this directory; tn -l lists them, tn N picks one (noti.py).'

# tp: tmux sessions per project (tmux-project from ~/env-config/scripts; prefix g is the same picker).
if (( $+commands[tmux-project] )); then
    _custom-alias Tools tp tmux-project 'Go to a project tmux session: pick (no argument) or name a session, directory or zoxide query.'
    _tmux-project() {
        local -a sessions=(${(f)"$(tmux list-sessions -F '#{session_name}' 2>/dev/null)"})
        _alternative "sessions:tmux session:(${(q)sessions})" 'directories:directory:_directories'
    }
    compdef _tmux-project tmux-project
fi

# tmux-kill [server]: save the server's sessions (tmux-resurrect, when it has it loaded; the next server restores them),
# then tmux -L <server> kill-server, which ends its sessions and closes every terminal attached to it; without an
# argument, the server this shell is in (else the default one). It is tmux-kill.py, a Python program in
# ~/env-config/scripts beside tmux-project that any shell can run; tmux-kill.py --list lists the running servers, as Tab
# offers them here.
tmux-kill() {
    whence -p tmux-kill.py >/dev/null ||
        { print -u2 'tmux-kill: tmux-kill.py not found on PATH (it is in ~/env-config/scripts)'; return 127 }
    TMUX_KILL_PROG=tmux-kill tmux-kill.py "$@"
}
_tmux-kill() {
    (( CURRENT == 2 )) || return 1
    local line; local -a servers
    for line in ${(f)"$(tmux-kill.py --list 2>/dev/null)"}; do
        servers+=("${${line%%$'\t'*}//:/\\:}:sessions: ${line##*$'\t'}")
    done
    _describe 'tmux server' servers
}
compdef _tmux-kill tmux-kill tmux-kill.py
unfunction _tmux-servers 2>/dev/null   # tmux-kill.py replaced it
_custom-register Tools tmux-kill 'Save a tmux server (tmux-resurrect), then end it and close its terminals; no argument: the server this shell is in.'

# plugin-update [plugin...]: bring each plugin clone, Vim's in ~/.vim/pack/*/{start,opt} (vim:<name>) and tmux's in
# ~/.tmux/plugins (tmux:<name>), to the newest commit of its repository's default branch (the one GitHub shows, where a
# project publishes its newest code; its release tags are behind it), as work's tool-update vim-plugins does; a plugin
# is named as listed or by its bare name. The default branch is asked of the remote every run, so a repository that
# moves it (master to main) is followed. A clone on that branch is fast-forwarded; one detached at a commit or on
# another branch whose commits are all on it is moved onto it, as a local branch tracking it. A clone with local edits
# or commits of its own, or on a branch with no upstream (held there), is skipped and left as it is. The clones are
# checked (and fetched) at once. An update logs the commit it replaced and how to go back to it in
# ~/.cache/plugin-update.log (the last run only), and rebuilds a Vim plugin's help tags, which are also rebuilt when
# missing. update runs it after pacman and yay.

# _plugin-clones: reply=(vim:<name> dir tmux:<name> dir ...), the plugin clones in order of name.
_plugin-clones() {
    local d; local -A by
    for d in ~/.vim/pack/*/(start|opt)/*/.git(N:h); do by[vim:${d:t}]=$d; done
    for d in ~/.tmux/plugins/*/.git(N:h); do by[tmux:${d:t}]=$d; done
    reply=(); for d in ${(ko)by}; do reply+=($d $by[$d]); done
}

# _plugin-head dir: REPLY=the commit (7 characters) checked out in the clone at dir, read from its .git files; empty when
# they do not say.
_plugin-head() {
    local g=$1/.git ref line
    REPLY=
    if [[ -f $g ]]; then read -r ref < $g; g=${ref#gitdir: }; [[ $g == /* ]] || g=$1/$g; fi
    { read -r ref < $g/HEAD } 2>/dev/null || return 1
    if [[ $ref != 'ref: '* ]]; then REPLY=$ref
    elif [[ -f $g/${ref#ref: } ]]; then read -r REPLY < $g/${ref#ref: }
    elif [[ -r $g/packed-refs ]]; then
        for line in ${(f)"$(<$g/packed-refs)"}; do [[ $line == *" ${ref#ref: }" ]] && { REPLY=${line%% *}; break }; done
    fi
    REPLY=${REPLY[1,7]}
    [[ -n $REPLY ]]
}

# _plugin-check dir: ask the remote of the clone at dir for its default branch, fetch it, then print "head commit ref
# action [count | why]": its commit and the one it would move to, that branch's ref (- when unknown), and up-to-date,
# ff (its branch, which tracks that one, fast-forwards), onto (detached, or on another branch: it moves onto that one),
# skip or fail, then the number of new commits, or why it is skipped or failed. Runs in a subshell: it changes directory.
_plugin-check() {
    local line branch upstream remote target action err
    local -a sha lines found
    builtin cd -q $1 2>/dev/null || { print -r -- "- - - fail cannot enter $1"; return }
    sha=(${(f)"$(git rev-parse HEAD 2>/dev/null)"})
    [[ $sha[1] =~ '^[0-9a-f]{40}$' ]] || { print -r -- '- - - fail not a git clone'; return }
    for line in ${(f)"$(git for-each-ref --format='%(HEAD)|%(refname:short)|%(upstream:short)' refs/heads)"}; do
        [[ $line == '*|'* ]] && { line=${line#*|}; branch=${line%%|*} upstream=${line#*|}; break }
    done
    [[ -z $branch || -n $upstream ]] || { print -r -- "$sha[1] - - skip its branch $branch tracks no upstream (held there)"; return }
    remote=${${upstream%%/*}:-origin}
    # git's own reason for a failure (fatal: or error:), else its last line.
    if ! err=$(GIT_TERMINAL_PROMPT=0 git ls-remote --symref $remote HEAD 2>&1); then
        lines=(${(f)err}) found=(${(M)lines:#(fatal|error): *})
        print -r -- "$sha[1] - - fail could not reach $remote: ${found[1]:-$lines[-1]}"; return
    fi
    lines=(${(f)err}) found=(${(M)lines:#ref: refs/heads/*})
    target=${${found[1]#ref: refs/heads/}%%[[:space:]]*}
    [[ -n $target ]] || { print -r -- "$sha[1] - - fail $remote names no default branch"; return }
    target=$remote/$target
    if ! err=$(GIT_TERMINAL_PROMPT=0 git fetch --quiet $remote 2>&1); then
        lines=(${(f)err}) found=(${(M)lines:#(fatal|error): *})
        print -r -- "$sha[1] - $target fail could not fetch $remote: ${found[1]:-$lines[-1]}"; return
    fi
    sha=(${(f)"$(git rev-parse HEAD $target 2>/dev/null)"})
    [[ $sha[2] =~ '^[0-9a-f]{40}$' ]] || { print -r -- "$sha[1] - $target fail $target is not a commit"; return }
    [[ $sha[1] == $sha[2] ]] && { print -r -- "$sha[1] $sha[2] $target up-to-date"; return }
    line="$sha[1] $sha[2] $target skip"
    git diff --quiet HEAD -- 2>/dev/null   # its exit status, not its output: 1 when tracked files differ from HEAD
    case $? in
        0) ;;
        1) print -r -- "$line local edits (git status lists them)"; return ;;
        *) print -r -- "$sha[1] $sha[2] $target fail could not check it for local edits (git diff HEAD)"; return ;;
    esac
    [[ -z ${(M)${(f)"$(git ls-files -v)"}:#[a-zS] *} ]] ||
        { print -r -- "$line files marked assume-unchanged or skip-worktree"; return }
    if ! git merge-base --is-ancestor HEAD $target; then
        if [[ -n $branch ]]; then print -r -- "$line its branch $branch has commits of its own, not on $target"
        else print -r -- "$line detached at a commit that is not on $target"; fi
        return
    fi
    if [[ -n $branch && $upstream == $target ]]; then
        action=ff
    else
        action=onto
        if [[ $branch != ${target#*/} ]] && git show-ref --verify --quiet refs/heads/${target#*/} &&
           ! git merge-base --is-ancestor refs/heads/${target#*/} $target; then
            print -r -- "$line its branch ${target#*/} has commits of its own, not on $target"; return
        fi
    fi
    print -r -- "$sha[1] $sha[2] $target $action $(git rev-list --count HEAD..$target)"
}

# _plugin-move dir ref ff|onto: move the clone at dir to ref, as _plugin-check found it can: fast-forward its branch,
# or (onto) check out ref's branch, made or moved there and tracking ref. Runs in a subshell.
_plugin-move() {
    builtin cd -q $1 || return
    if [[ $3 == ff ]]; then git merge --ff-only --quiet $2; else git checkout --quiet -B ${2#*/} --track $2; fi
}

# _plugin-helptags dir: rebuild the help tags (doc/tags) of the Vim plugin at dir, as after it was cloned.
_plugin-helptags() {
    [[ -d $1/doc ]] || return 0
    PLUGIN_DOC=$1/doc command vim -u NONE -i NONE -N -es -c 'execute "helptags" fnameescape($PLUGIN_DOC)' -c 'qa!' </dev/null
}

# _plugin-row name installed latest result: one row of plugin-update's table, its first column pw wide (the caller's).
# On a terminal, a result ending in ... (still working) is drawn without a newline, so the row's next state replaces it;
# elsewhere it is skipped.
_plugin-row() {
    local row
    printf -v row "%-${pw:-12}s %-10s %-10s %s" "$@"
    if [[ -t 1 ]]; then printf '\r%s\e[K' $row; [[ $4 == *... ]] || print
    elif [[ $4 != *... ]]; then print -r -- $row
    fi
}

plugin-update() {
    local name dir line head commit ref action rest have latest state result note back
    local log=${XDG_CACHE_HOME:-$HOME/.cache}/plugin-update.log
    local -i pw=12
    local -a reply names summary
    local -A dirs check count
    [[ $1 == (-h|--help) ]] && { print 'Usage: plugin-update [plugin...]   (vim:<name> or tmux:<name>, or a bare <name>)'; return 0 }
    _plugin-clones; dirs=($reply)
    (( $#dirs )) || { print 'plugin-update: no plugin clones in ~/.vim/pack or ~/.tmux/plugins'; return 0 }
    if (( $# )); then
        for name; do
            if (( $+dirs[$name] )); then names+=($name)
            elif [[ -n ${(M)${(k)dirs}:#*:$name} ]]; then names+=(${(M)${(k)dirs}:#*:$name})
            else print -u2 "plugin-update: no plugin clone named $name (Tab lists them)"; return 2; fi
        done
        names=(${(u)names})
    else
        names=(${(ko)dirs})
    fi
    mkdir -p ${log:h} && : >| $log || { print -u2 "plugin-update: cannot write $log"; return 1 }
    for name in $names; do (( $#name > pw )) && pw=$#name; done
    _plugin-row PLUGIN INSTALLED LATEST RESULT
    _plugin-row plugins - - "checking $#names clones..."
    for line in ${(f)"$(for name in $names; do print -r -- "$name $(_plugin-check $dirs[$name] 2>/dev/null)" & done; wait)"}; do
        check[${line%% *}]=${line#* }
    done
    for name in $names; do
        dir=$dirs[$name] head= commit= ref= action= rest= note=
        read -r head commit ref action rest <<< ${check[$name]-}
        have=${${head:#-}[1,7]} latest=${${commit:#-}[1,7]}
        print -rl -- '' "=== $name ===" "$dir: ${head:--} (following ${ref:--}: ${commit:--}) ${action:-no result} $rest" >> $log
        case $action in
            up-to-date) state='up to date' ;;
            ff|onto)
                _plugin-row $name ${have:--} ${latest:--} updating...
                if ( _plugin-move $dir $ref $action ) >> $log 2>&1; then
                    state=updated note="$rest commit${${rest:#1}:+s}"
                    [[ $action == onto ]] && note+=", now on its branch ${ref#*/}"
                    if [[ $action == ff ]]; then back="git reset --keep $head"; else back="git checkout --detach $head"; fi
                    print -r -- "Updated from $head; to go back: cd $dir && $back" >> $log
                else
                    state=failed note="git could not move it to $ref (see the log)"
                fi ;;
            skip) state=skipped note=$rest ;;
            *)    state=failed note=${rest:-its check did not finish} ;;
        esac
        if [[ $name == vim:* && -d $dir/doc && ( $state == updated || $state == 'up to date' && ! -e $dir/doc/tags ) ]]; then
            if _plugin-helptags $dir >> $log 2>&1; then [[ $state == updated ]] || note='help tags rebuilt'
            else note+="${note:+; }could not rebuild its help tags"; fi
        fi
        if [[ $state == (skipped|failed) ]]; then result="$state: $note"; else result=$state${note:+ ($note)}; fi
        count[$state]=$(( ${count[$state]:-0} + 1 ))
        _plugin-row $name ${have:--} ${latest:--} $result
    done
    for state in updated 'up to date' skipped failed; do
        (( ${count[$state]:-0} )) && summary+=("$count[$state] $state")
    done
    print "\n${(j:, :)summary}"
    (( ${count[failed]:-0} + ${count[skipped]:-0} )) && print "Details: $log"
    (( ! ${count[failed]:-0} ))
}
_plugin-update() {
    local -a reply names
    _plugin-clones; names=(${${(M)reply:#(vim|tmux):*}//:/\\:})   # vim\:<name>: _arguments takes a bare colon as a separator
    _arguments '(- *)'{-h,--help}'[show usage]' "*:plugin clone:(${names})"
}
compdef _plugin-update plugin-update
_custom-register Tools plugin-update 'Update the Vim and tmux plugin clones (all, or the named ones) to the newest commit of their default branch.'

tool-status() {
    local tool d REPLY
    local -i tw=10
    local -a reply
    _plugin-clones
    for tool d in $reply; do (( $#tool > tw )) && tw=$#tool; done
    printf "%-${tw}s %s\n" TOOL STATUS ${(l:tw::-:)} ------------------------------
    for tool in atuin bat btop dust env-save eza fd fzf gh git glow kitten pacman rg tree uvx wl-copy xclip xdotool yay zoxide zsh; do
        printf "%-${tw}s %s\n" $tool ${commands[$tool]:-MISSING}
    done
    for tool d in $reply; do _plugin-head $d; printf "%-${tw}s %s\n" $tool "${REPLY:-?} $d"; done
}
_custom-register Tools tool-status "Show installed paths or MISSING for useful command-line tools, and each plugin clone's commit."
