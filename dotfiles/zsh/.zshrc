# ~/.zshrc — Arch workstation configuration
[[ -o interactive ]] || return

# === Environment ==============================================================

typeset -U path fpath
path-prepend() { [[ -d $1 ]] && path=($1 $path) }
path-prepend ~/env-config/scripts

export EDITOR=vim SUDO_EDITOR=vim
export OBSESSION_ROOT=${OBSESSION_ROOT:-$HOME/obsessions}
export MANROFFOPT='-c -rU0' MANPAGER='env VIM_MANPAGER=1 vim +MANPAGER --not-a-term -'

# === Options & history ========================================================

setopt autocd extendedglob interactivecomments typesetsilent prompt_subst no_beep globdots
HISTFILE=${HISTFILE:-$HOME/.zsh_history} HISTSIZE=1000000 SAVEHIST=1000000
setopt share_history hist_ignore_dups hist_find_no_dups hist_reduce_blanks hist_verify extended_history

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

# Full compinit (security audit + fpath rescan) at most once a day. compinit never rewrites an
# up-to-date dump, so touch it to restart the 24h window.
autoload -Uz compinit
_ZCOMPDUMP=${ZDOTDIR:-$HOME}/.zcompdump
if [[ -n $_ZCOMPDUMP(#qN.mh-24) ]]; then compinit -C -d $_ZCOMPDUMP
else compinit -d $_ZCOMPDUMP && touch $_ZCOMPDUMP; fi
completion-refresh() { rehash; rm -f $_ZCOMPDUMP $_ZCOMPDUMP.zwc; compinit -d $_ZCOMPDUMP }

# List ambiguous matches; never cycle through or auto-accept them.
unsetopt automenu
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
zle_highlight+=(paste:none)

# Alt+Backspace kills one path segment: "/" is a word boundary for this widget only.
backward-kill-path-segment() { local WORDCHARS=${WORDCHARS//\/}; zle backward-kill-word }
zle -N backward-kill-path-segment

() {
    local key widget
    for key widget in \
        '^H'  beginning-of-line       '^L'  end-of-line \
        '^[h' vi-backward-word        '^[l' vi-forward-word \
        '^[j' up-line-or-history      '^[k' down-line-or-history \
        '^[J' beginning-of-history    '^[K' end-of-history \
        '^W'  backward-kill-word      '^U'  backward-kill-line \
        '^[d' kill-word               '^[x' backward-kill-word \
        '^[u' undo                    '^[r' redo \
        '^[^?' backward-kill-path-segment
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
# Tab: a word containing ** → fzf; a word containing * ? or [ → glob completion; otherwise → normal.
# Glob completion never expands the line. The cursor acts as a trailing *, as in normal completion:
# Tab fills in whatever every match has in common next, then lists the matches (never cycles).
#   *.lat<Tab> → *.latest     .venv*/li<Tab> → .venv*/lib     Do*<Tab> → lists Documents Downloads
# A glob in a parent component offers only children present under *every* matched parent:
#   .venv*/lib64/<Tab> → .venv*/lib64/python3.12/
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
    setopt localoptions extendedglob
    local dir leaf base hit name tail REPLY
    local -i nparents
    local -a parents dirs files dir_words file_words match mbegin mend
    local -A count dir_count
    compstate[list]='list force'
    # parents: glob-quoted directory prefixes ending in / ('' for the current directory).
    if [[ $PREFIX == */* ]]; then
        dir=${PREFIX%/*} leaf=${PREFIX##*/}
        _glob-expand-path $dir
        if [[ $dir == *[\*\?\[]* ]]; then
            parents=(${~REPLY}(N-/))
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
    # Each surviving name completes to the word as typed plus the rest of the name after what the
    # typed glob matched (*.lat + est), so the common part of those words is what Tab fills in.
    for name in ${(ko)count}; do
        (( $count[$name] == nparents )) || continue
        [[ $name == (#b)${~leaf}(*) ]] && tail=$match[-1] || tail=
        if (( ${dir_count[$name]:-0} == nparents )); then dirs+=($name) dir_words+=("$leaf${tail:+${(q)tail}}")
        else files+=($name) file_words+=("$leaf${tail:+${(q)tail}}"); fi
    done
    if (( $#dirs + $#files == 0 )); then
        if (( nparents > 1 )); then
            compadd -x "no ${leaf//\%/%%}* under all $nparents directories matching ${dir//\%/%%}"
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
    local word
    [[ $LBUFFER == *[[:space:]] ]] || word=${${(z)LBUFFER}[-1]}
    if [[ $word == *'**'* ]] && (( $+widgets[_fzf-completion-original] )); then zle _fzf-completion-original
    elif [[ $word == *[\*\?\[]* ]]; then zle _glob-list-widget
    else zle complete-word; fi
}
zle -N _smart-tab-completion
bindkey -M emacs '^I' _smart-tab-completion

# === Pickers ==================================================================
# ^F all history · ^R this directory's history · ^T files · ^G directories. The same keys switch
# pickers inside fzf (the active picker's key closes it); ^D deletes the highlighted history entry.

_atuin-history-rows() {
    (( $+commands[atuin] )) || return 1
    atuin search "$@" --reverse --human --format $'{command}\x1f{relativetime}\x1f{exit}\x1f{duration}\x1f{directory}' |
        awk -F $'\x1f' -v OFS=$'\x1f' -v home="$HOME" '
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
                print $1, sprintf("%s%-7s%s │ %s%-8s%s │ %s%-10s%s │ %s%-28s%s │ %s%s%s",
                    dim, $2, reset, color, status, reset, dim, $4, reset, cyan, short($5), reset, white, $1, reset)
            }'
}

# Delete every history entry exactly equal to $1 (regex-escaped, including "/" for atuin's r/…/).
_atuin-history-delete-exact() {
    local regex=${1//(#m)[][\\.^\$|?*+(){}\/]/\\$MATCH}
    [[ -n $regex ]] && atuin search --delete --search-mode fuzzy -- "r/^${regex}$/"
}

_fzf-switcher() {
    (( $+commands[fzf] )) || return 1
    local mode=$1 next result label fd preview file cols
    local -a lines picked cwd extra
    local -A needs=(history atuin directory_history atuin files fd directories fd)
    local -A key_mode=(ctrl-f history ctrl-r directory_history ctrl-t files ctrl-g directories)
    local nav='Ctrl+F: All History  Ctrl+R: Directory History  Ctrl+T: Files  Ctrl+G: Directories'
    local search="Search: fuzzy=foo  exact='foo  word='foo'" logic='exclude=!foo  │  AND=foo bar  OR=foo | bar'
    printf -v cols '%-7s │ %-8s │ %-10s │ %-28s │ %s' AGE STATUS DURATION DIRECTORY COMMAND
    while true; do
        (( $+commands[$needs[$mode]] )) || return 1
        if [[ $mode == *history ]]; then
            cwd=(); [[ $mode == directory_history ]] && cwd=(--cwd .)
            result=$(_atuin-history-rows $cwd |
                fzf --ansi --scheme=history --no-hscroll --delimiter=$'\x1f' --with-nth=2 --accept-nth=1 \
                    --header="$nav  │  Ctrl+D: Delete"$'\n'"$search  $logic"$'\n'"$cols" \
                    --prompt="${cwd:+Directory }History> " --expect=ctrl-f,ctrl-r,ctrl-t,ctrl-g,ctrl-d)
        else
            if [[ $mode == files ]]; then
                label=Files fd="$commands[fd] --type f" extra=(--multi)
                if (( $+commands[bat] )); then preview="$commands[bat] --color=always --style=numbers -- {} 2>/dev/null"
                else preview="sed -n '1,250p' -- {} 2>/dev/null"; fi
            else
                label=Directories fd="$commands[fd] --type d" extra=()
                if (( $+commands[eza] )); then preview="$commands[eza] --tree --level=2 --icons=auto --color=always -- {} 2>/dev/null"
                elif (( $+commands[tree] )); then preview="$commands[tree] -a -L 2 {} 2>/dev/null"
                else preview='find {} -maxdepth 2 -print 2>/dev/null | head -200'; fi
            fi
            fd+=' --hidden --exclude .git --exclude .cache'
            # ^L toggles following symlinks and ^O toggles ignored files; the prompt carries the state.
            result=$(FZF_DEFAULT_COMMAND=$fd fzf $extra --scheme=path --no-hscroll --prompt="$label> " \
                --header="$nav  │  Ctrl+L: Links  Ctrl+O: Ignored  Ctrl+P: Preview"$'\n'"$search  start=^foo  end=foo\$  $logic" \
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
                --expect=ctrl-f,ctrl-r,ctrl-t,ctrl-g </dev/tty)
        fi
        [[ -n $result ]] || break
        lines=("${(@f)result}") picked=("${(@)lines[2,-1]}")
        next=${key_mode[$lines[1]]-}
        if [[ -n $next ]]; then
            (( $+commands[$needs[$next]] )) || continue
            [[ $next == $mode ]] && break
            mode=$next; zle reset-prompt; zle -R; continue
        elif [[ $lines[1] == ctrl-d ]]; then
            [[ -n ${picked[1]-} ]] && _atuin-history-delete-exact $picked[1]
            continue
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

# === Files ====================================================================

if (( $+commands[eza] )); then
    _custom-alias Files \
        ls  'eza -a --icons=auto'                            'List all files using eza when available.' \
        ll  'eza -la --icons=auto'                           'Long file listing including hidden entries.' \
        lt  'eza -la --icons=auto --sort=modified'           'Long listing sorted newest first.' \
        ltr 'eza -la --icons=auto --sort=modified --reverse' 'Long listing sorted oldest first.' \
        lg  'eza -la --git --icons=auto'                     'Long eza listing with Git status.' \
        et  'eza --tree --icons=auto'                        'Show an eza directory tree.'
else
    _custom-alias Files \
        ls  'command ls -AF --color=auto'    'List all files using eza when available.' \
        ll  'command ls -lAF --color=auto'   'Long file listing including hidden entries.' \
        lt  'command ls -lAFt --color=auto'  'Long listing sorted newest first.' \
        ltr 'command ls -lAFrt --color=auto' 'Long listing sorted oldest first.'
fi
(( $+commands[tree] )) && _custom-alias Files tree 'tree -a' 'Show directory trees including hidden entries.'
(( $+commands[dust] )) && _custom-alias Files dust 'dust -r' 'Show disk usage in reverse size order.'

# === Search ===================================================================

_custom-alias Search grep 'grep --color=auto' 'Run GNU grep with automatic color.'
# grep's "file\0line:text" (ANSI-colored) becomes "file : line : text".
_grep-pretty() { perl -pe 'BEGIN { $ansi = qr/\e\[[0-9;]*[A-Za-z]/ } s/\0/ : /; s/( : (?:$ansi)*[0-9]+(?:$ansi)*):/$1 : /' }
e()  { grep -Z -EHsiInr --color=always "$@" | _grep-pretty }
ep() { grep -Z -EHsiIn --color=always "$@" | _grep-pretty }
z()  { zgrep -HsiIn --color=always "$@" | _grep-pretty }
hs()   { (( $# )) || { print 'Usage: hs <history-search-pattern>'; return 1 }; fc -l 1 | grep -EHiIn --color=auto -- "$*" }
fdir() { (( $# )) || { print 'Usage: fdir <directory-name-pattern>'; return 1 }; find . -type d -iname "*$1*" }
ff()   { (( $# )) || { print 'Usage: ff <file-name-pattern>'; return 1 }; find . -type f -iname "*$1*" }
_custom-register Search \
    e    'Recursive case-insensitive grep with formatted file/line output.' \
    ep   'Search explicitly supplied files with formatted grep output.' \
    z    'Search compressed files with formatted zgrep output.' \
    hs   'Search shell history with a regular expression.' \
    fdir 'Find directories by case-insensitive name substring.' \
    ff   'Find files by case-insensitive name substring.'

# === Git ======================================================================

gg() { git grep -in --color=always "$@" | sed -e 's/:/ : /1' -e 's/:/ : /2' }
_custom-register Git gg 'Search tracked Git content with formatted output.'
_custom-alias Git \
    gf   'git ls-files | rg'                        'Search tracked Git filenames with ripgrep.' \
    gm   'git config pull.rebase false && git pull' 'Set pull to merge for this repo, then pull.' \
    gr   'git config pull.rebase true && git pull'  'Set pull to rebase for this repo, then pull.' \
    gdc  'git diff'                                 'Show the working-tree Git diff.' \
    gdco 'git diff > gitdiff_to_commit'             'Write the working-tree diff to gitdiff_to_commit.' \
    gs   'git status'                               'Show Git working-tree status.' \
    ga   'git add .'                                'Stage all changes under the current directory.'
gc() { git commit -m "$*" }

# origin's default branch: origin/HEAD, else the first of origin/main, origin/master, origin.
_git-origin-ref() {
    local ref
    ref=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) && { print -r -- $ref; return }
    for ref in origin/main origin/master origin; do
        git rev-parse --verify --quiet $ref >/dev/null && { print -r -- $ref; return }
    done
    print -u2 'No origin remote-tracking reference found.'; return 1
}
gdo() { local ref; ref=$(_git-origin-ref) || return; git diff $ref "$@" }

# gdoo [outfile] [diff-args]: per-file headers become "diff <path>", hunks become "@ Hunk N @".
gdoo() {
    local out=./gitdiff_to_origin ref
    if [[ $# -gt 0 && $1 != -- ]]; then out=$1; shift; elif [[ $1 == -- ]]; then shift; fi
    ref=$(_git-origin-ref) || return
    git diff $ref "$@" | awk '
        /^diff --git / { if (files++) print ""; path = $3; sub(/^[abcw]\//, "", path); print "diff " path; hunk = 0; header = 1; next }
        header && /^(index |new file mode |--- |\+\+\+ )/ { next }
        /^@@ / { header = 0; print "@ Hunk " (++hunk) " @"; next }
        { print }' > $out
}

_glog_format='%C(red)%H%C(reset) - %C(green)(%ar)%C(reset) %C(white)%s%C(reset) %C(bold italic white)- %an%C(reset)%C(auto)%d%C(reset)'
glog()  { git log --graph --decorate --format="format:$_glog_format" --all "$@" }
glogf() { glog --name-only "$@" }

DEFAULT_CLONE_REPO=${DEFAULT_CLONE_REPO:-/nfs/site/disks/ttl.git.zsc10.001/ttlh78/hub-ttlh78-a0}
clone() { git clone $DEFAULT_CLONE_REPO "$@" }

_custom-register Git \
    gc    'Commit staged changes using the arguments as the message.' \
    gdo   'Show a diff against the origin default branch.' \
    gdoo  'Write a simplified diff against the origin default branch.' \
    glog  'Show decorated graph history for all refs.' \
    glogf 'Show graph history plus changed filenames.' \
    clone 'Clone the configured default work repository.'

# === Editors & Vim sessions ===================================================

_custom-alias Editors \
    v      vim             'Open terminal Vim.' \
    g      gvim            'Open GVim.' \
    vv     'vim -O'        'Open files in side-by-side Vim splits.' \
    vs     'vim -o'        'Open files in stacked Vim splits.' \
    vimv   'vim ~/.vimrc'  'Edit ~/.vimrc in Vim.' \
    gvimv  'gvim ~/.vimrc' 'Edit ~/.vimrc in GVim.' \
    sv     sudoedit        'Edit a privileged file through sudoedit.' \
    ob-fix "sed -i \"s/'let \(g:this_[a-z]* = v:this_session'\)/'\1/\" ~/.vim/pack/plugins/start/obsession/plugin/obsession.vim" \
                           'Patch Vim Obsession for the installed Vim version.'

# vl/gl [name | -- vim-args]: resume ~/obsessions/named/<name>.vim, or this directory's
# ~/obsessions/by-path/<physical cwd>/Session.vim. No -S: Vim takes the session lock before sourcing.
_session-load() {
    local editor=$1 session; shift
    if (( $# )) && [[ $1 != -- ]]; then
        session=${1:t}; shift
        [[ $session == *.vim ]] || session+=.vim
        session=$OBSESSION_ROOT/named/$session
    else
        [[ $1 == -- ]] && shift
        session=${${PWD:A}#/}
        session=$OBSESSION_ROOT/by-path/${session:-__root__}/Session.vim
    fi
    [[ -f $session ]] || { print -u2 -l 'No saved session:' "  $session"; return 1 }
    OBSESSION_LOAD_SESSION=$session command $editor "$@"
}
vl() { _session-load vim "$@" }
gl() { _session-load gvim "$@" }
_session-complete() {
    if (( CURRENT == 2 )); then
        local -a sessions=($OBSESSION_ROOT/named/*.vim(N:t:r))
        (( $#sessions )) && _describe 'named session' sessions
    else
        _files
    fi
}
compdef _session-complete vl gl
_custom-register Editors vl 'Open a saved Vim session.' gl 'Open a saved GVim session.'

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
    # Keep the sudo timestamp fresh so yay/env-save never re-prompt during a long pacman run.
    ( while sleep 60; do sudo -n -v >/dev/null 2>&1 || exit; done ) &!
    keepalive=$!
    {
        printf '\n--- Updating via Pacman ---\n\n'
        if sudo pacman -Syu; then
            (( $+commands[yay] )) && { printf '\n--- Updating via Yay ---\n\n'; yay; rc=$? }
            (( $+commands[env-save] )) && { printf '\n--- Saving Environment State ---\n\n'; env-save }
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

search() {
    print '--- From Pacman ---'; pacman -Ss "$@"
    if (( $+commands[yay] )); then print '\n--- From AUR ---'; yay -Ss "$@"; fi
}

_custom-register Packages \
    update 'Upgrade the system with pacman/yay, then run env-save if available.' \
    search 'Search official Arch repositories and the AUR when yay is available.'

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

tool-status() {
    local tool
    printf '%-10s %s\n' TOOL STATUS ---------- ------------------------------
    for tool in atuin bat btop dust env-save eza fd fzf gh git kitten pacman rg tree uvx yay zoxide zsh; do
        printf '%-10s %s\n' $tool ${commands[$tool]:-MISSING}
    done
}
_custom-register Tools tool-status 'Show installed paths or MISSING status for useful command-line tools.'
