# ~/.zshrc — Arch workstation configuration

[[ -o interactive ]] || return

# === Custom command registry ==================================================

typeset -ga _CUSTOM_ORDER=()
typeset -ga _CUSTOM_GROUP_ORDER=(Shell Files Search Editors Git Packages System Applications Tools)
typeset -gA _CUSTOM_GROUP=() _CUSTOM_DESC=()
typeset -gA _CUSTOM_GROUP_SEEN=(Shell 1 Files 1 Search 1 Editors 1 Git 1 Packages 1 System 1 Applications 1 Tools 1)

_custom_register() {
    local group="$1" name desc
    shift

    if [[ -z ${_CUSTOM_GROUP_SEEN[$group]+x} ]]; then
        _CUSTOM_GROUP_ORDER+=("$group")
        _CUSTOM_GROUP_SEEN[$group]=1
    fi

    while (( $# >= 2 )); do
        name="$1"
        desc="$2"
        shift 2

        [[ -n ${_CUSTOM_DESC[$name]+x} ]] || _CUSTOM_ORDER+=("$name")
        _CUSTOM_GROUP[$name]="$group"
        _CUSTOM_DESC[$name]="$desc"
    done
}

list_custom() {
    local verbose=0 filter="" group name desc kind haystack
    local printed=0
    local -a matches

    while (( $# )); do
        case "$1" in
            -v|-verbose|--verbose) verbose=1 ;;
            -h|--help)
                print 'Usage: list_custom [-v|--verbose] [filter]'
                print 'Filter matches command name, category, or description.'
                return 0
                ;;
            -*)
                print -u2 "Unknown option: $1"
                return 2
                ;;
            *)
                [[ -z "$filter" ]] || {
                    print -u2 'Only one filter may be supplied.'
                    return 2
                }
                filter="$1"
                ;;
        esac
        shift
    done

    for group in "${_CUSTOM_GROUP_ORDER[@]}"; do
        matches=()

        for name in "${_CUSTOM_ORDER[@]}"; do
            [[ "${_CUSTOM_GROUP[$name]}" == "$group" ]] || continue
            desc="${_CUSTOM_DESC[$name]}"

            if [[ -n "$filter" ]]; then
                haystack="$name $group $desc"
                [[ "${(L)haystack}" == *"${(L)filter}"* ]] || continue
            fi

            matches+=("$name")
        done

        (( ${#matches} )) || continue

        if (( verbose )); then
            (( printed )) && print
            print -P "%B${group}%b"
            for name in "${matches[@]}"; do
                kind="$(whence -w "$name" 2>/dev/null)"
                kind="${kind##*: }"
                printf '  %-18s %-9s %s\n' "$name" "${kind:-command}" "${_CUSTOM_DESC[$name]}"
            done
        else
            print -r -- "${group}: ${(j: :)matches}"
        fi

        printed=1
    done

    (( printed )) || {
        print -u2 "No custom commands matched: $filter"
        return 1
    }
}

_custom_register Shell \
    list_custom 'List custom commands; use --verbose for descriptions.'

# === PATH =====================================================================

typeset -U path
path_prepend() {
    [[ -d "$1" ]] && path=("$1" $path)
}

path_prepend "$HOME/env_config/scripts"
export PATH


# === Obsession Setup ===================================================================
export OBSESSION_ROOT="${OBSESSION_ROOT:-$HOME/obsessions}"

# === Prompt ===================================================================

autoload -Uz vcs_info add-zsh-hook
setopt prompt_subst

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

# === Shell behavior / history =================================================

unsetopt beep
setopt autocd extendedglob nomatch notify interactivecomments
setopt typesetsilent auto_param_slash

HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=1000000
SAVEHIST=1000000
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS HIST_VERIFY EXTENDED_HISTORY

# === Completion ===============================================================

typeset -g ZSH_COMPLETION_DIR="$HOME/.local/share/zsh/site-functions"
mkdir -p "$ZSH_COMPLETION_DIR"
fpath=("$ZSH_COMPLETION_DIR" $fpath)

autoload -Uz compinit
typeset -g _ZCOMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump"
typeset -a _zcomp_mtime
typeset -i _zcomp_cached=0

if [[ -f "$_ZCOMPDUMP" ]] &&
   zmodload zsh/datetime 2>/dev/null &&
   zmodload zsh/stat 2>/dev/null &&
   zstat -A _zcomp_mtime +mtime "$_ZCOMPDUMP" 2>/dev/null &&
   (( EPOCHSECONDS - _zcomp_mtime[1] < 86400 )); then
    _zcomp_cached=1
fi

if (( _zcomp_cached )); then
    compinit -C -d "$_ZCOMPDUMP"
else
    compinit -d "$_ZCOMPDUMP"
fi
unset _zcomp_mtime _zcomp_cached

unsetopt recexact automenu menucomplete completealiases
setopt autolist list_ambiguous

zstyle ':completion:*' accept-exact false
zstyle ':completion:*' accept-exact-dirs false
zstyle ':completion:*' insert-tab false

# === Custom completions =======================================================

_list_custom() {
    local group name
    local -a filters

    for group in "${_CUSTOM_GROUP_ORDER[@]}"; do
        filters+=("$group:command category")
    done

    for name in "${_CUSTOM_ORDER[@]}"; do
        filters+=("$name:${_CUSTOM_DESC[$name]}")
    done

    _arguments \
        '(-v -verbose --verbose)-v[show command descriptions]' \
        '(-v -verbose --verbose)-verbose[show command descriptions]' \
        '(-v -verbose --verbose)--verbose[show command descriptions]' \
        '(-h --help)-h[show help]' \
        '(-h --help)--help[show help]' \
        '1:command or category:->filter'

    case "$state" in
        filter)
            _describe 'command or category' filters
            ;;
    esac
}

compdef _list_custom list_custom

_wineprefix() {
    # wineprefix accepts exactly one prefix name.
    (( CURRENT == 2 )) || return

    local dir name
    local -a prefixes

    for dir in "$HOME"/.wine-*(N/); do
        name="${dir:t}"
        name="${name#.wine-}"
        prefixes+=("$name:$dir")
    done

    if (( ${#prefixes} )); then
        _describe 'Wine prefix' prefixes
    else
        _message 'no ~/.wine-* prefixes found'
    fi
}

compdef _wineprefix wineprefix


# === ZLE keybindings ===========================================================

bindkey -e
zle_highlight+=(paste:none)

bindkey -M emacs '^H' beginning-of-line
bindkey -M emacs '^L' end-of-line
bindkey -M emacs '^[h' vi-backward-word
bindkey -M emacs '^[l' vi-forward-word
bindkey -M emacs '^[j' up-line-or-history
bindkey -M emacs '^[k' down-line-or-history
bindkey -M emacs '^[J' beginning-of-history
bindkey -M emacs '^[K' end-of-history
bindkey -M emacs '^W' backward-kill-word
bindkey -M emacs '^U' backward-kill-line
bindkey -M emacs '^[d' kill-word
bindkey -M emacs '^[x' backward-kill-word
bindkey -M emacs '^[u' undo
bindkey -M emacs '^[r' redo

# === ZLE editing =============================================================

# Alt+Backspace: delete one path segment at a time.
# Treat "/" as a word boundary only for this operation, leaving the global
# WORDCHARS behavior unchanged for other ZLE navigation/editing commands.
backward-kill-path-segment() {
    local WORDCHARS="${WORDCHARS//\//}"
    zle backward-kill-word
}

zle -N backward-kill-path-segment
bindkey '^[^?' backward-kill-path-segment

# === Modern tools =============================================================

if (( $+commands[fzf] )); then
    export FZF_DEFAULT_OPTS='--height=60% --layout=reverse --border --cycle --bind=ctrl-k:down --bind=ctrl-j:up --bind=ctrl-d:half-page-down --bind=ctrl-u:half-page-up'

    # Keep fzf completion, but reserve our custom history/file/directory bindings.
    FZF_CTRL_R_COMMAND= \
    FZF_CTRL_T_COMMAND= \
    FZF_ALT_C_COMMAND= \
    source <(fzf --zsh 2>/dev/null)

    # Preserve fzf's original Tab completion widget so **<Tab> still works.
    if zle -l fzf-completion >/dev/null 2>&1; then
        zle -A fzf-completion _fzf_completion_original
    fi

    # Completion helper for pathnames containing globs.
    #
    # Examples:
    #
    #   .venv*/li<Tab>
    #       -> .venv*/lib
    #
    #   .venv*/lib6<Tab>
    #       -> .venv*/lib64/
    #
    #   .venv*/lib64/<Tab>
    #       -> list contents found beneath all matching directories
    #
    # Ambiguous matches are listed, never cycled through individually.
    _glob_list_completer() {
        setopt localoptions nullglob
    
        local full_prefix dir_prefix leaf
        local parent_pattern leaf_pattern pattern
        local parent match name
        local -i parent_count
    
        local -a parents children matches dirs files
        local -A count dir_count seen_this kind
    
        full_prefix="$PREFIX"
    
        # Split the current pathname into:
        #
        #   .venv*/li
        #
        #     dir_prefix = .venv*
        #     leaf       = li
        #
        # For:
        #
        #   Do*/
        #
        #     dir_prefix = Do*
        #     leaf       = ""
        if [[ "$full_prefix" == */* ]]; then
            dir_prefix="${full_prefix%/*}"
            leaf="${full_prefix##*/}"
        else
            dir_prefix=""
            leaf="$full_prefix"
        fi
    
        # ------------------------------------------------------------------
        # Glob in an earlier path component.
        #
        # Here we want the INTERSECTION of children beneath every directory
        # matched by the glob.
        #
        # Examples:
        #
        #   Do*/
        #   .venv*/li
        #   foo*/bar*/baz
        # ------------------------------------------------------------------
        if [[ "$dir_prefix" == *\** ||
              "$dir_prefix" == *\?* ||
              "$dir_prefix" == *\[* ]]; then
    
            parent_pattern="$dir_prefix"
    
            # Parameter-expanded "~/" isn't automatically tilde-expanded when
            # we later activate it as a glob, so handle that explicitly.
            if [[ "$parent_pattern" == "~/"* ]]; then
                parent_pattern="$HOME/${parent_pattern#\~/}"
            fi
    
            # Only directories can act as the parents we're traversing.
            parents=( ${~parent_pattern}(N/) )
    
            parent_count=${#parents}
            (( parent_count )) || return 1
    
            # A glob in the final component is already a complete pattern.
            # Otherwise we're completing a normal partial name.
            if [[ "$leaf" == *\** ||
                  "$leaf" == *\?* ||
                  "$leaf" == *\[* ]]; then
                leaf_pattern="$leaf"
            else
                leaf_pattern="${leaf}*"
            fi
    
            # Count how many matched parent directories contain each child.
            for parent in "${parents[@]}"; do
                pattern="$parent/$leaf_pattern"
                children=( ${~pattern}(N) )
    
                # Defensive per-parent deduplication.
                seen_this=()
    
                for match in "${children[@]}"; do
                    name="${match:t}"
    
                    [[ -n ${seen_this[$name]+x} ]] && continue
                    seen_this[$name]=1
    
                    (( count[$name]++ ))
    
                    [[ -d "$match" ]] &&
                        (( dir_count[$name]++ ))
                done
            done
    
            # Keep a name only if it appeared beneath EVERY matched parent.
            for name in "${(@k)count}"; do
                (( count[$name] == parent_count )) || continue
    
                # Treat it as a directory only if it is a directory beneath
                # every matched parent. Otherwise don't offer "/" traversal.
                if (( dir_count[$name] == parent_count )); then
                    dirs+=("$name")
                else
                    files+=("$name")
                fi
            done
    
            (( ${#dirs} + ${#files} )) || return 1
    
            dirs=("${(@o)dirs}")
            files=("${(@o)files}")
    
            # Preserve everything through the final slash.
            compset -P '*/'
    
            # If the final component itself contains a glob, use that as a
            # display-only filter and leave the command line untouched.
            if [[ "$leaf" == *\** ||
                  "$leaf" == *\?* ||
                  "$leaf" == *\[* ]]; then
    
                compstate[insert]=''
                compstate[list]='list force'
    
                (( ${#dirs} )) &&
                    compadd -U -Q -S '/' -- "${dirs[@]}"
    
                (( ${#files} )) &&
                    compadd -U -Q -- "${files[@]}"
    
            else
                # Ordinary partial final component:
                # insert only the lowest common unambiguous portion.
                compstate[insert]='unambiguous'
                compstate[list]='list force'
    
                (( ${#dirs} )) &&
                    compadd -Q -S '/' -- "${dirs[@]}"
    
                (( ${#files} )) &&
                    compadd -Q -- "${files[@]}"
            fi
    
            return
        fi
    
        # ------------------------------------------------------------------
        # Glob only in the FINAL component.
        #
        # Example:
        #
        #   Do*
        #
        # In this case simply show what that glob itself matches.
        # ------------------------------------------------------------------
    
        pattern="$full_prefix"
    
        if [[ "$pattern" == "~/"* ]]; then
            pattern="$HOME/${pattern#\~/}"
        fi
    
        matches=( ${~pattern}(N) )
    
        for match in "${matches[@]}"; do
            name="${match:t}"
    
            if [[ -d "$match" ]]; then
                kind[$name]="dir"
            elif [[ -z ${kind[$name]+x} ]]; then
                kind[$name]="file"
            fi
        done
    
        (( ${#kind} )) || return 1
    
        for name in "${(@ok)kind}"; do
            if [[ "${kind[$name]}" == "dir" ]]; then
                dirs+=("$name")
            else
                files+=("$name")
            fi
        done
    
        compset -P '*/'
    
        # The final component itself is a glob, so preserve it exactly and
        # merely display what it matches.
        compstate[insert]=''
        compstate[list]='list force'
    
        (( ${#dirs} )) &&
            compadd -U -Q -S '/' -- "${dirs[@]}"
    
        (( ${#files} )) &&
            compadd -U -Q -- "${files[@]}"
    }

    # Real completion widget used specifically for globbed pathname listing.
    zle -C _glob_list_widget list-choices _glob_list_completer

    _smart_tab_completion() {
        local word
        local -a words

        if [[ "$LBUFFER" == *[[:space:]] ]]; then
            word=""
        else
            words=(${(z)LBUFFER})
            word="${words[-1]-}"
        fi

        # ** explicitly invokes fzf completion.
        if [[ "$word" == *'**'* ]] &&
           zle -l _fzf_completion_original >/dev/null 2>&1; then
            zle _fzf_completion_original

        # Any other pathname containing a glob gets our custom completion.
        elif [[ "$word" == *\** ||
                "$word" == *\?* ||
                "$word" == *\[* ]]; then
            zle _glob_list_widget

        # Everything else uses ordinary Zsh completion.
        else
            zle complete-word
        fi
    }

    zle -N _smart_tab_completion
    bindkey -M emacs '^I' _smart_tab_completion
fi

# Generic fzf invocations respect ignore files by default.
(( $+commands[fd] )) && export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git --exclude .cache'

# Preserve normal `cd` spelling while letting zoxide record navigation.
(( $+commands[zoxide] )) && eval "$(zoxide init zsh --cmd cd)"

if (( $+commands[atuin] )); then
    export ATUIN_NOBIND=true
    eval "$(atuin init zsh)"
fi

# === fzf / Atuin picker ========================================================

_atuin_history_rows() {
    (( $+commands[atuin] )) || return 1

    atuin search "$@" --reverse \
        --human \
        --format $'{command}\x1f{relativetime}\x1f{exit}\x1f{duration}\x1f{directory}' |
        awk -F $'\x1f' -v OFS=$'\x1f' -v home="$HOME" '
            function shorten_dir(dir, width) {
                if (dir == home)
                    dir = "~"
                else if (index(dir, home "/") == 1)
                    dir = "~" substr(dir, length(home) + 1)

                if (length(dir) > width)
                    dir = "…" substr(dir, length(dir) - width + 2)

                return dir
            }

            !seen[$1]++ {
                command = $1
                age = $2
                code = $3
                duration = $4
                directory = shorten_dir($5, 28)

                reset = "\033[0m"
                dim = "\033[90m"
                cyan = "\033[36m"
                bold_white = "\033[1;37m"

                if (code == "0") {
                    status_plain = "✓"
                    status_color = "\033[32m"
                } else if (code == "-1" || code == "") {
                    status_plain = "?"
                    status_color = "\033[90m"
                } else {
                    status_plain = "✗ " code
                    status_color = "\033[31m"
                }

                age_field = dim sprintf("%-7s", age) reset
                status_field = status_color sprintf("%-8s", status_plain) reset
                duration_field = dim sprintf("%-10s", duration) reset
                directory_field = cyan sprintf("%-28s", directory) reset
                command_field = bold_white command reset

                display = age_field " │ " status_field " │ " duration_field
                display = display " │ " directory_field " │ " command_field
                print command, display
            }
        '
}

_atuin_history_delete_exact() {
    local command="$1"
    local regex

    # Escape regex metacharacters, plus "/" because Atuin's regex
    # query syntax is r/.../.
    regex=$(
        python3 -c '
import sys

special = set(r"\.^$|?*+()[]{}\/")
s = sys.argv[1]

print(
    "".join("\\" + c if c in special else c for c in s),
    end=""
)
' "$command"
    ) || return 1

    [[ -n "$regex" ]] || return 1

    atuin search \
        --delete \
        --search-mode fuzzy \
        -- "r/^${regex}$/"
}

_fzf_switcher() {
    local mode="$1" result pressed selection file
    local fd_bin fd_files fd_files_follow fd_files_ignored fd_files_follow_ignored
    local fd_dirs fd_dirs_follow fd_dirs_ignored fd_dirs_follow_ignored
    local file_preview dir_preview
    local -a lines selections

    (( $+commands[fzf] )) || return 1

    while true; do
        case "$mode" in
            history)
                (( $+commands[atuin] )) || return 1
                result=$(
                    _atuin_history_rows |
                        fzf --ansi --scheme=history \
                            --no-hscroll \
                            --delimiter=$'\x1f' --with-nth=2 --accept-nth=1 \
                            --header="$(
                                printf '%s\n' \
                                    "Ctrl+F: All History  Ctrl+R: Directory History  Ctrl+T: Files  Ctrl+G: Directories  │  Ctrl+D: Delete"
                                printf '%s\n' \
                                    "Search: fuzzy=foo  exact='foo  word='foo'  exclude=!foo  │  AND=foo bar  OR=foo | bar"
                                printf '%-7s │ %-8s │ %-10s │ %-28s │ %s' \
                                    AGE STATUS DURATION DIRECTORY COMMAND
                            )" \
                            --prompt='History> ' \
                            --expect=ctrl-f,ctrl-r,ctrl-t,ctrl-g,ctrl-d
                )
                ;;

            directory_history)
                (( $+commands[atuin] )) || return 1
                result=$(
                    _atuin_history_rows --cwd . |
                        fzf --ansi --scheme=history \
                            --no-hscroll \
                            --delimiter=$'\x1f' --with-nth=2 --accept-nth=1 \
                            --header="$(
                                printf '%s\n' \
                                    "Ctrl+F: All History  Ctrl+R: Directory History  Ctrl+T: Files  Ctrl+G: Directories  │  Ctrl+D: Delete"
                                printf '%s\n' \
                                    "Search: fuzzy=foo  exact='foo  word='foo'  exclude=!foo  │  AND=foo bar  OR=foo | bar"
                                printf '%-7s │ %-8s │ %-10s │ %-28s │ %s' \
                                    AGE STATUS DURATION DIRECTORY COMMAND
                            )" \
                            --prompt='Directory History> ' \
                            --expect=ctrl-f,ctrl-r,ctrl-t,ctrl-g,ctrl-d
                )
                ;;

            files)
                (( $+commands[fd] )) || return 1
                fd_bin="${commands[fd]}"

                # Default: hidden files included, ignore rules respected, no symlink traversal.
                fd_files="$fd_bin --type f --hidden --exclude .git --exclude .cache"
                fd_files_follow="$fd_files --follow"
                fd_files_ignored="$fd_files --no-ignore"
                fd_files_follow_ignored="$fd_files --follow --no-ignore"

                if (( $+commands[bat] )); then
                    file_preview="${commands[bat]} --color=always --style=numbers -- {} 2>/dev/null"
                else
                    file_preview="sed -n '1,250p' -- {} 2>/dev/null"
                fi

                result=$(
                    FZF_DEFAULT_COMMAND="$fd_files" \
                        fzf --multi --scheme=path \
                            --no-hscroll \
                            --prompt='Files> ' \
                            --header="$(
                                printf '%s\n' \
                                    "Ctrl+F: All History  Ctrl+R: Directory History  Ctrl+T: Files  Ctrl+G: Directories  │  Ctrl+L: Links  Ctrl+O: Ignored  Ctrl+P: Preview"
                                printf '%s\n' \
                                    "Search: fuzzy=foo  exact='foo  word='foo'  start=^foo  end=foo\$  exclude=!foo  │  AND=foo bar  OR=foo | bar"
                            )" \
                            --preview="$file_preview" \
                            --preview-window='right:50%:hidden' \
                            --bind 'ctrl-p:toggle-preview' \
                            --bind 'alt-k:preview-down' \
                            --bind 'alt-j:preview-up' \
                            --bind 'alt-d:preview-half-page-down' \
                            --bind 'alt-u:preview-half-page-up' \
                            --bind 'alt-h:preview-top' \
                            --bind 'alt-g:preview-bottom' \
                            --bind "ctrl-l:transform:
                                case \"\$FZF_PROMPT\" in
                                    'Files> ')
                                        echo 'change-prompt(Files+Links> )+reload($fd_files_follow)'
                                        ;;
                                    'Files+Links> ')
                                        echo 'change-prompt(Files> )+reload($fd_files)'
                                        ;;
                                    'Files+Ignored> ')
                                        echo 'change-prompt(Files+Links+Ignored> )+reload($fd_files_follow_ignored)'
                                        ;;
                                    'Files+Links+Ignored> ')
                                        echo 'change-prompt(Files+Ignored> )+reload($fd_files_ignored)'
                                        ;;
                                esac
                            " \
                            --bind "ctrl-o:transform:
                                case \"\$FZF_PROMPT\" in
                                    'Files> ')
                                        echo 'change-prompt(Files+Ignored> )+reload($fd_files_ignored)'
                                        ;;
                                    'Files+Ignored> ')
                                        echo 'change-prompt(Files> )+reload($fd_files)'
                                        ;;
                                    'Files+Links> ')
                                        echo 'change-prompt(Files+Links+Ignored> )+reload($fd_files_follow_ignored)'
                                        ;;
                                    'Files+Links+Ignored> ')
                                        echo 'change-prompt(Files+Links> )+reload($fd_files_follow)'
                                        ;;
                                esac
                            " \
                            --expect=ctrl-f,ctrl-r,ctrl-t,ctrl-g \
                            < /dev/tty
                )
                ;;

            directories)
                (( $+commands[fd] )) || return 1
                fd_bin="${commands[fd]}"

                fd_dirs="$fd_bin --type d --hidden --exclude .git --exclude .cache"
                fd_dirs_follow="$fd_dirs --follow"
                fd_dirs_ignored="$fd_dirs --no-ignore"
                fd_dirs_follow_ignored="$fd_dirs --follow --no-ignore"

                if (( $+commands[eza] )); then
                    dir_preview="${commands[eza]} --tree --level=2 --icons=auto --color=always -- {} 2>/dev/null"
                elif (( $+commands[tree] )); then
                    dir_preview="${commands[tree]} -a -L 2 {} 2>/dev/null"
                else
                    dir_preview="find {} -maxdepth 2 -print 2>/dev/null | head -200"
                fi

                result=$(
                    FZF_DEFAULT_COMMAND="$fd_dirs" \
                        fzf --scheme=path \
                            --no-hscroll \
                            --prompt='Directories> ' \
                            --header="$(
                                printf '%s\n' \
                                    "Ctrl+F: All History  Ctrl+R: Directory History  Ctrl+T: Files  Ctrl+G: Directories  │  Ctrl+L: Links  Ctrl+O: Ignored  Ctrl+P: Preview"
                                printf '%s\n' \
                                    "Search: fuzzy=foo  exact='foo  word='foo'  start=^foo  end=foo\$  exclude=!foo  │  AND=foo bar  OR=foo | bar"
                            )" \
                            --preview="$dir_preview" \
                            --preview-window='right:50%:hidden' \
                            --bind 'ctrl-p:toggle-preview' \
                            --bind 'alt-k:preview-down' \
                            --bind 'alt-j:preview-up' \
                            --bind 'alt-d:preview-half-page-down' \
                            --bind 'alt-u:preview-half-page-up' \
                            --bind 'alt-h:preview-top' \
                            --bind 'alt-g:preview-bottom' \
                            --bind "ctrl-l:transform:
                                case \"\$FZF_PROMPT\" in
                                    'Directories> ')
                                        echo 'change-prompt(Directories+Links> )+reload($fd_dirs_follow)'
                                        ;;
                                    'Directories+Links> ')
                                        echo 'change-prompt(Directories> )+reload($fd_dirs)'
                                        ;;
                                    'Directories+Ignored> ')
                                        echo 'change-prompt(Directories+Links+Ignored> )+reload($fd_dirs_follow_ignored)'
                                        ;;
                                    'Directories+Links+Ignored> ')
                                        echo 'change-prompt(Directories+Ignored> )+reload($fd_dirs_ignored)'
                                        ;;
                                esac
                            " \
                            --bind "ctrl-o:transform:
                                case \"\$FZF_PROMPT\" in
                                    'Directories> ')
                                        echo 'change-prompt(Directories+Ignored> )+reload($fd_dirs_ignored)'
                                        ;;
                                    'Directories+Ignored> ')
                                        echo 'change-prompt(Directories> )+reload($fd_dirs)'
                                        ;;
                                    'Directories+Links> ')
                                        echo 'change-prompt(Directories+Links+Ignored> )+reload($fd_dirs_follow_ignored)'
                                        ;;
                                    'Directories+Links+Ignored> ')
                                        echo 'change-prompt(Directories+Links> )+reload($fd_dirs_follow)'
                                        ;;
                                esac
                            " \
                            --expect=ctrl-f,ctrl-r,ctrl-t,ctrl-g \
                            < /dev/tty
                )
                ;;
        esac

        [[ -n "$result" ]] || break

        lines=("${(@f)result}")
        pressed="${lines[1]}"
        selections=("${lines[@]:1}")

        case "$pressed" in
            ctrl-f)
                (( $+commands[atuin] )) || continue
                [[ "$mode" == history ]] && break
                mode=history
                zle reset-prompt
                zle -R
                continue
                ;;
            ctrl-r)
                (( $+commands[atuin] )) || continue
                [[ "$mode" == directory_history ]] && break
                mode=directory_history
                zle reset-prompt
                zle -R
                continue
                ;;
            ctrl-t)
                (( $+commands[fd] )) || continue
                [[ "$mode" == files ]] && break
                mode=files
                zle reset-prompt
                zle -R
                continue
                ;;
            ctrl-g)
                (( $+commands[fd] )) || continue
                [[ "$mode" == directories ]] && break
                mode=directories
                zle reset-prompt
                zle -R
                continue
                ;;
            ctrl-d)
                if [[ -n "${selections[1]-}" ]]; then
                    _atuin_history_delete_exact "${selections[1]}"
                fi
                continue
                ;;
        esac

        (( ${#selections} )) || break

        case "$mode" in
            history|directory_history)
                BUFFER="${selections[1]}"
                CURSOR=${#BUFFER}
                ;;
            files)
                for file in "${selections[@]}"; do
                    LBUFFER+="${(q)file} "
                done
                ;;
            directories)
                selection="${selections[1]}"
                [[ -n "$selection" ]] || break
                cd "$selection"
                ;;
        esac

        break
    done

    zle reset-prompt
    zle -R
}

_fzf_history_switcher() { _fzf_switcher history; }
_fzf_directory_history_switcher() { _fzf_switcher directory_history; }
_fzf_file_switcher() { _fzf_switcher files; }
_fzf_directory_switcher() { _fzf_switcher directories; }

zle -N _fzf_history_switcher
zle -N _fzf_directory_history_switcher
zle -N _fzf_file_switcher
zle -N _fzf_directory_switcher

if (( $+commands[fzf] && $+commands[atuin] )); then
    bindkey -M emacs '^F' _fzf_history_switcher
    bindkey -M emacs '^R' _fzf_directory_history_switcher
fi

if (( $+commands[fzf] && $+commands[fd] )); then
    bindkey -M emacs '^T' _fzf_file_switcher
    bindkey -M emacs '^G' _fzf_directory_switcher
fi

# === Modern Unix tools / listings ============================================

if (( $+commands[eza] )); then
    alias ls='eza -a --icons=auto'
    alias ll='eza -la --icons=auto'
    alias lt='eza -la --icons=auto --sort=modified'
    alias ltr='eza -la --icons=auto --sort=modified --reverse'
    alias lg='eza -la --git --icons=auto'
    alias et='eza --tree --icons=auto'
else
    alias ls='command ls -AF --color=auto'
    alias ll='command ls -lAF --color=auto'
    alias lt='command ls -lAFt --color=auto'
    alias ltr='command ls -lAFrt --color=auto'
fi

_custom_register Files \
    ls 'List all files using eza when available.' \
    ll 'Long file listing including hidden entries.' \
    lt 'Long listing sorted newest first.' \
    ltr 'Long listing sorted oldest first.'

if (( $+commands[eza] )); then
    _custom_register Files \
        lg 'Long eza listing with Git status.' \
        et 'Show an eza directory tree.'
fi

if (( $+commands[tree] )); then
    alias tree='tree -a'
    _custom_register Files tree 'Show directory trees including hidden entries.'
fi

if (( $+commands[dust] )); then
    alias dust='dust -r'
    _custom_register Files dust 'Show disk usage in reverse size order.'
fi

# === Search helpers ===========================================================

alias grep='grep --color=auto'

_grep_pretty() {
    perl -pe '
        my $ansi = qr/\e\[[0-9;]*[A-Za-z]/;
        s/\0/ : /;
        s/( : (?:$ansi)*[0-9]+(?:$ansi)*):/$1 : /;
    '
}

e() { grep -Z -EHsiInr --color=always "$@" | _grep_pretty; }
ep() { grep -Z -EHsiIn --color=always "$@" | _grep_pretty; }
z() { zgrep -HsiIn --color=always "$@" | _grep_pretty; }

hs() {
    (( $# )) || {
        print 'Usage: hs <history-search-pattern>'
        return 1
    }
    fc -l 1 | grep -EHiIn --color=auto -- "$*"
}

fdir() {
    (( $# )) || {
        print 'Usage: fdir <directory-name-pattern>'
        return 1
    }
    find . -type d -iname "*$1*"
}

ff() {
    (( $# )) || {
        print 'Usage: ff <file-name-pattern>'
        return 1
    }
    find . -type f -iname "*$1*"
}

_custom_register Search \
    grep 'Run GNU grep with automatic color.' \
    e 'Recursive case-insensitive grep with formatted file/line output.' \
    ep 'Search explicitly supplied files with formatted grep output.' \
    z 'Search compressed files with formatted zgrep output.' \
    hs 'Search shell history with a regular expression.' \
    fdir 'Find directories by case-insensitive name substring.' \
    ff 'Find files by case-insensitive name substring.'

# === Git helpers ==============================================================

gg() {
    git grep -in --color=always "$@" | sed -e 's/:/ : /1' -e 's/:/ : /2'
}

alias gf='git ls-files | rg'
alias gm='git config pull.rebase false && git pull'
alias gr='git config pull.rebase true && git pull'
alias gdc='git diff'
alias gdco='git diff > gitdiff_to_commit'
alias gs='git status'
alias ga='git add .'
gc() {
    git commit -m "$*"
}

_git_origin_ref() {
    local ref

    ref="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" && {
        print -r -- "$ref"
        return 0
    }

    if git rev-parse --verify --quiet origin/main >/dev/null; then
        print -r -- origin/main
    elif git rev-parse --verify --quiet origin/master >/dev/null; then
        print -r -- origin/master
    elif git rev-parse --verify --quiet origin >/dev/null; then
        print -r -- origin
    else
        print -u2 'No origin remote-tracking reference found.'
        return 1
    fi
}

gdo() {
    local ref
    ref="$(_git_origin_ref)" || return
    git diff "$ref" "$@"
}

gdoo() {
    local output_file='./gitdiff_to_origin' ref

    if [[ $# -gt 0 && "$1" != '--' ]]; then
        output_file="$1"
        shift
    elif [[ "$1" == '--' ]]; then
        shift
    fi

    ref="$(_git_origin_ref)" || return

    git diff "$ref" "$@" | awk '
        BEGIN { first_file = 1 }
        /^diff --git / {
            if (!first_file) print ""
            first_file = 0
            hunk = 0
            path = $3
            sub(/^[abcw]\//, "", path)
            print "diff " path
            next
        }
        /^index /         { next }
        /^new file mode / { next }
        /^--- /           { next }
        /^\+\+\+ /        { next }
        /^@@ / {
            hunk++
            print "@ Hunk " hunk " @"
            next
        }
        { print }
    ' > "$output_file"
}

typeset -g _glog_format='%C(red)%H%C(reset) - %C(green)(%ar)%C(reset) %C(white)%s%C(reset) %C(bold italic white)- %an%C(reset)%C(auto)%d%C(reset)'

glog() {
    git log --graph --decorate --format=format:"$_glog_format" --all "$@"
}

glogf() {
    git log --graph --decorate --format=format:"$_glog_format" --all --name-only "$@"
}

typeset -g DEFAULT_CLONE_REPO="${DEFAULT_CLONE_REPO:-/nfs/site/disks/ttl.git.zsc10.001/ttlh78/hub-ttlh78-a0}"
clone() {
    git clone "$DEFAULT_CLONE_REPO" "$@"
}

_custom_register Git \
    gg 'Search tracked Git content with formatted output.' \
    gf 'Search tracked Git filenames with ripgrep.' \
    gm 'Set pull to merge for this repo, then pull.' \
    gr 'Set pull to rebase for this repo, then pull.' \
    gdc 'Show the working-tree Git diff.' \
    gdco 'Write the working-tree diff to gitdiff_to_commit.' \
    gdo 'Show a diff against the origin default branch.' \
    gdoo 'Write a simplified diff against the origin default branch.' \
    glog 'Show decorated graph history for all refs.' \
    glogf 'Show graph history plus changed filenames.' \
    clone 'Clone the configured default work repository.'

# === Editors / shell configuration ===========================================

export EDITOR='vim'
export SUDO_EDITOR='vim'

# ============================================================================
# Vim / Obsession session loading
# ============================================================================

# Useful when re-sourcing ~/.zshrc after the old aliases already exist.
unalias vl gl 2>/dev/null


# Return the default Session.vim belonging to the current physical directory.
#
# Example:
#
#   PWD:
#       /home/timmseh/projects/foo
#
#   Session:
#       ~/obsessions/by-path/home/timmseh/projects/foo/Session.vim
#
_default_session_path() {
    local physical key

    physical="$(pwd -P)" || return 1
    physical="${physical%/}"

    [[ -n "$physical" ]] || physical="/"

    key="${physical#/}"
    [[ -n "$key" ]] || key="__root__"

    print -r -- "$OBSESSION_ROOT/by-path/$key/Session.vim"
}


# Shared loader used by both vl and gl.
_session_load() {
    local editor="$1"
    shift

    local session

    # "--" explicitly means:
    # use this directory's default session and pass everything after
    # "--" through to Vim.
    if (( $# )) && [[ "$1" == "--" ]]; then
        shift
        session="$(_default_session_path)" || return

    # An argument means a centralized named session.
    elif (( $# )); then
        session="${1:t}"
        shift

        [[ "$session" == *.vim ]] || session+=".vim"

        session="$OBSESSION_ROOT/named/$session"

    # No argument means this directory's default session.
    else
        session="$(_default_session_path)" || return
    fi

    if [[ ! -f "$session" ]]; then
        print -u2 "No saved session:"
        print -u2 "  $session"
        return 1
    fi

    # Deliberately do NOT use -S here.
    #
    # Vim receives the desired session path through the environment,
    # acquires its lock first, and only then sources Session.vim.
    OBSESSION_LOAD_SESSION="$session" \
        command "$editor" "$@"
}


# Terminal Vim.
vl() {
    _session_load vim "$@"
}


# GUI Vim.
gl() {
    _session_load gvim "$@"
}

_session_complete() {
    local file
    local -a sessions

    # First argument to vl/gl is an optional named session.
    if (( CURRENT == 2 )); then
        for file in "$OBSESSION_ROOT"/named/*.vim(N); do
            sessions+=("${file:t:r}")
        done

        (( ${#sessions} )) && _describe 'named session' sessions
    else
        _files
    fi
}

compdef _session_complete vl
compdef _session_complete gl

alias v='vim'
alias g='gvim'
alias vv='vim -O'
alias vs='vim -o'
alias vimv='vim ~/.vimrc'
alias gvimv='gvim ~/.vimrc'
alias sv='sudoedit'
alias ob_fix='sed -i -e "s/'\''let g:this_session = v:this_session'\''/'\''g:this_session = v:this_session'\''/" -e "s/'\''let g:this_obsession = v:this_session'\''/'\''g:this_obsession = v:this_session'\''/" ~/.vim/pack/plugins/start/obsession/plugin/obsession.vim'

_custom_register Editors \
    v 'Open terminal Vim.' \
    g 'Open GVim.' \
    vl 'Open a saved Vim session.' \
    gl 'Open a saved GVim session.' \
    vimv 'Edit ~/.vimrc in Vim.' \
    gvimv 'Edit ~/.vimrc in GVim.' \
    sv 'Edit a privileged file through sudoedit.' \
    ob_fix 'Patch Vim Obsession for the installed Vim version.'

alias sz='source ~/.zshrc'
alias vimz='vim ~/.zshrc'
alias type='type -a'

_custom_register Shell \
    sz 'Reload ~/.zshrc in the current shell.' \
    vimz 'Edit ~/.zshrc in Vim.' \
    type 'Show all resolutions for a command name.'

if (( $+commands[kitten] )); then
    alias icat='kitten icat'
    _custom_register Tools icat 'Display an image in Kitty.'
fi

[[ -f "$HOME/.config/kitty/kitty.conf" ]] && {
    alias vimk='vim ~/.config/kitty/kitty.conf'
    _custom_register Tools vimk 'Edit the Kitty configuration.'
}

if (( $+commands[btop] )); then
    alias monitor='btop'
    _custom_register Tools monitor 'Open btop system monitoring.'
fi

if (( $+commands[bat] )); then
    export MANROFFOPT="-c -rU0"
    export MANPAGER="env VIM_MANPAGER=1 vim +MANPAGER --not-a-term -"
fi

# === Miscellaneous aliases and functions  =====================================
alias view='feh --auto-zoom --image-bg black --scale-down'
alias mouse-battery='solaar show 2>/dev/null | grep "Battery:" | tail -1'


# === Package management =======================================================

alias pi='sudo pacman -S'
alias pr='sudo pacman -Rsu'
alias ps='pacman -Ss'
alias pu='sudo pacman -Syu'
alias pq='pacman -Qn'
alias pl='pacman -Qqen'

_custom_register Packages \
    pi 'Install packages with pacman.' \
    pr 'Remove packages and unneeded dependencies with pacman.' \
    ps 'Search official Arch repositories.' \
    pu 'Upgrade installed repository packages.' \
    pq 'List installed repository packages.' \
    pl 'List explicitly installed repository packages.'

if (( $+commands[yay] )); then
    alias yi='yay -S'
    alias yr='yay -Rns'
    alias ys='yay -Ss'
    alias yu='yay'
    alias yq='pacman -Qm'
    alias yl='pacman -Qqem'

    _custom_register Packages \
        yi 'Install a package through yay.' \
        ys 'Search repositories and the AUR through yay.' \
        yu 'Run yay with no preset arguments.' \
        yq 'List installed foreign/AUR packages.' \
        yl 'List explicitly installed foreign/AUR packages.'
fi

completion_refresh() {
    rehash
    rm -f "$_ZCOMPDUMP" "${_ZCOMPDUMP}.zwc"
    compinit -d "$_ZCOMPDUMP"
}


_update_body() {
    local yay_rc=0
    local rc=0
    local sudo_keepalive_pid

    printf '\n=== Arch Update: %s ===\n\n' "$(date '+%Y-%m-%d %H:%M:%S')"

    # Authenticate once, inside the single PTY used for the whole update.
    if ! sudo -v; then
        printf '\n--- Sudo authentication failed; stopping ---\n\n'
        return 1
    fi

    # Keep the sudo timestamp alive during long updates so Yay/env_save
    # don't ask again if Pacman takes longer than the sudo timeout.
    (
        while sleep 60; do
            sudo -n -v >/dev/null 2>&1 || exit
        done
    ) &!
    sudo_keepalive_pid=$!

    {
        printf '\n--- Updating via Pacman ---\n\n'

        if ! sudo pacman -Syu; then
            printf '\n--- Pacman update failed; stopping ---\n\n'
            rc=1
        else
            if (( $+commands[yay] )); then
                printf '\n--- Updating via Yay ---\n\n'
                yay
                yay_rc=$?
            fi

            if (( $+commands[env_save] )); then
                printf '\n--- Saving Environment State ---\n\n'
                env_save
            fi

            rc=$yay_rc
        fi
    } always {
        kill "$sudo_keepalive_pid" 2>/dev/null
    }

    return "$rc"
}

_update_log_clean() {
    perl -ne '
        # Normalize line endings and remove terminal control sequences.
        s/\r\n/\n/g;
        s/\e\].*?(?:\a|\e\\)//g;
        s/\e\[[0-?]*[ -\/]*[@-~]//g;
        s/\x08//g;
        s/\r/\n/g;
        s/\n\z//;

        my @lines = split /\n/, $_, -1;
        @lines = ("") unless @lines;

        for my $line (@lines) {

            # Recognize Pacman progress bars.
            if ($line =~ /\[[#=-]+\]\s*\d{1,3}%\s*\z/) {

                # Retain completed package operations and phase summaries.
                if ($line =~ /^\s*\(\s*(\d+)\/(\d+)\)\s+(.+?)\s+\[[#=-]+\]\s*100%\s*\z/) {
                    my ($done, $total, $task) = ($1, $2, $3);

                    if ($task =~ /^(?:upgrading|installing|downgrading|reinstalling|removing)\b/ ||
                        ($done == $total && $task =~ /^(?:checking|loading)\b/)) {

                        my $summary = sprintf("(%d/%d) %s", $done, $total, $task);

                        print "$summary\n" unless $seen{$summary}++;
                        $blank = 0;
                    }
                }

                $after_progress = 1;
                next;
            }

            # Track repository synchronization and package downloading.
            if ($line =~ /^:: Synchronizing package databases/) {
                $sync = 1;
                $retrieving = 0;
            } elsif ($line =~ /^:: Retrieving packages/) {
                $retrieving = 1;
                $sync = 0;
            } elsif ($line =~ /^:: /) {
                $sync = $retrieving = 0;
            }

            # Remove orphaned repository names left by terminal redraws.
            next if $sync && $line =~ /^\s*(?:core|extra|multilib)\s*\z/;

            # The package summary already contains these filenames.
            if ($retrieving &&
                $line =~ /^\s+\S+-\S+-(?:x86_64|any|i686)\s*\z/) {
                $after_progress = 1;
                next;
            }

            # Eliminate redundant blank lines.
            if ($line =~ /^\s*\z/) {
                next if $blank || $after_progress;
                $blank = 1;
            } else {
                $blank = 0;
                $after_progress = 0;
            }

            print "$line\n";
        }
    '
}

update() {
    local update_rc completion_rc
    local log_dir="$HOME/.updates"
    local log="$log_dir/update.$(date '+%y%m%d-%H%M%S').log"

    mkdir -p "$log_dir"

    # ~/update.log always points to the most recent update log.
    ln -sfn "$log" "$HOME/update.log"

    # `script` creates ONE PTY for the entire interactive update, but does not
    # create its own transcript file. tee displays the raw terminal stream while
    # the second branch creates a cleaned plain-text log.
    script -qefc 'zsh -ic _update_body' /dev/null 2>&1 |
        tee >(_update_log_clean > "$log")

    update_rc=${pipestatus[1]}

    # This needs to affect our current shell, so keep it outside the PTY shell.
    {
        printf '\n--- Refreshing Shell Completions ---\n\n'
        completion_refresh
    } > >(
        tee >(_update_log_clean >> "$log")
    ) 2>&1

    completion_rc=$?

    (( update_rc != 0 )) && return "$update_rc"
    return "$completion_rc"
}

_custom_register Shell \
    completion_refresh 'Rebuild Zsh command and completion caches.'

search() {
    print '--- From Pacman ---'
    pacman -Ss "$@"

    if (( $+commands[yay] )); then
        print
        print '--- From AUR ---'
        yay -Ss "$@"
    fi
}

_custom_register Packages \
    update 'Upgrade the system with pacman/yay, then run env_save if available.' \
    search 'Search official Arch repositories and the AUR when yay is available.'

# === System administration ====================================================

wineprefix() {
    (( $# == 1 )) || {
        print 'Usage: wineprefix <name>'
        return 1
    }

    export WINEPREFIX="$HOME/.wine-$1"
    print -r -- "Using Wine prefix: $WINEPREFIX"
}

alias mount_windows='sudo mount -t ntfs-3g UUID=369CE5FA9CE5B491 /mnt/windows'
alias unmount_windows='sudo umount /mnt/windows'

diskcheck() {
    print '=== ROOT ==='
    findmnt /

    print
    print '=== HOME ==='
    findmnt /home

    print
    print '=== LVM LOGICAL VOLUMES ==='
    sudo lvs -o lv_name,vg_name,lv_size,devices

    print
    print '=== LVM PHYSICAL VOLUMES ==='
    sudo pvs -o pv_name,pv_size,pv_free,vg_name

    print
    print '=== PHYSICAL DISKS ==='
    lsblk -d -o NAME,SIZE,MODEL,SERIAL
}

_custom_register System \
    wineprefix 'Select a named Wine prefix under ~/.wine-<name>.' \
    mount_windows 'Mount the configured Windows NTFS volume.' \
    unmount_windows 'Unmount /mnt/windows.' \
    diskcheck 'Show root/home mounts, LVM state, and physical disks.'

# === Applications =============================================================

if [[ -f "$HOME/trading-dashboard/main.py" ]]; then
    alias td='python ~/trading-dashboard/main.py &'
    _custom_register Applications td 'Launch the Trading Dashboard.'
fi

# === Capability check =========================================================

tool_status() {
    local tool
    local -a tools=(atuin bat btop dust env_save eza fd fzf gh git kitten pacman rg tree uvx yay zoxide zsh)

    printf '%-10s %s\n' TOOL STATUS
    printf '%-10s %s\n' '----------' '------------------------------'

    for tool in "${tools[@]}"; do
        if (( $+commands[$tool] )); then
            printf '%-10s %s\n' "$tool" "${commands[$tool]}"
        else
            printf '%-10s %s\n' "$tool" MISSING
        fi
    done
}

_custom_register Tools \
    tool_status 'Show installed paths or MISSING status for useful command-line tools.'
