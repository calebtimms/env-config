""" Timmseh's Incredible VIMRC """
" Plugins: git clone https://github.com/<repo> ~/.vim/pack/plugins/start/<dir>
"          vim -u NONE -c 'helptags ~/.vim/pack/plugins/start/<dir>/doc' -c q
"   nerdtree        preservim/nerdtree                obsession     tpope/vim-obsession
"   airline         vim-airline/vim-airline           fugitive      tpope/vim-fugitive
"   airline-themes  vim-airline/vim-airline-themes    gitgutter     airblade/vim-gitgutter
"   ctrlp           ctrlpvim/ctrlp.vim
"   zfdirdiff       ZSaberLv0/ZFVimDirDiff            zfjob         ZSaberLv0/ZFVimJob (required by zfdirdiff)
"   zfignore        ZSaberLv0/ZFVimIgnore             zfbackup      ZSaberLv0/ZFVimBackup

set nocompatible
let mapleader = '.'

"" Options
set hidden belloff=all mouse=a mousemodel=extend clipboard=unnamedplus
set number ruler showcmd showmode nowrap nofoldenable splitright splitbelow
set expandtab smarttab tabstop=4 softtabstop=4 shiftwidth=4 autoindent copyindent backspace=indent,eol,start
set incsearch hlsearch showmatch ignorecase smartcase wildmenu wildmode=list:longest
set history=1000 undolevels=1000
set ttimeout ttimeoutlen=100   " Esc leaves Insert mode at once; maps like <Esc>h still wait timeoutlen
set sessionoptions-=options sessionoptions+=localoptions   " sessions restore the workspace, not vimrc settings
" Man pages: ftplugins give every page followed with Ctrl+] the man maps (Ctrl+] / Ctrl+T), not just the first.
if !empty($VIM_MANPAGER) | set nonumber norelativenumber noshowmode | filetype plugin on | endif
" Inside tmux (TERM tmux-256color), terminal Vim gets what it gives xterm: SGR mouse (clicks past column 223), focus
" events (FocusGained refreshes Airline's Git state) and bracketed paste.
if &term =~# '^\%(tmux\|screen\)'
  set ttymouse=sgr
  let &t_fe = "\e[?1004h" | let &t_fd = "\e[?1004l"
  let &t_BE = "\e[?2004h" | let &t_BD = "\e[?2004l" | let &t_PS = "\e[200~" | let &t_PE = "\e[201~"
  execute "set <FocusGained>=\e[I <FocusLost>=\e[O"
endif

"" Appearance (custom highlights are reapplied whenever a colorscheme loads)
function! s:Highlights() abort
  hi DiffAdd    cterm=bold ctermfg=NONE ctermbg=22 gui=bold guifg=NONE    guibg=#005f00
  hi DiffDelete cterm=bold ctermfg=NONE ctermbg=52 gui=bold guifg=NONE    guibg=#5f0000
  hi DiffChange cterm=bold ctermfg=NONE ctermbg=23 gui=bold guifg=NONE    guibg=#005f5f
  hi DiffText   cterm=bold ctermfg=13   ctermbg=23 gui=bold guifg=#ff00ff guibg=#005f5f
  " ZFDirDiff's trees (below) in the same colors: a name on one side only is DiffAdd there and DiffDelete filler on the
  " other, a file that differs DiffText, a dir with differences inside DiffChange, an identical one plain.
  hi! link ZFDirDiffHL_FileOnlyHere DiffAdd
  hi! link ZFDirDiffHL_DirOnlyHere  DiffAdd
  hi! link ZFDirDiffFiller          DiffDelete
  hi! link ZFDirDiffHL_FileDiff     DiffText
  hi! link ZFDirDiffHL_DirDiff      DiffChange
  hi! link ZFDirDiffHL_FileSame     Normal
  hi! link ZFDirDiffHL_DirSame      Normal
  " Git logs (gitgraph, below): git's own colors, which a terminal takes from its palette (GVim: xterm's)
  hi gitLogHash      cterm=NONE        ctermfg=1 gui=NONE        guifg=#cd0000
  hi gitLogAge       cterm=NONE        ctermfg=2 gui=NONE        guifg=#00cd00
  hi gitLogSubject   cterm=NONE        ctermfg=7 gui=NONE        guifg=#e5e5e5
  hi gitLogAuthor    cterm=bold,italic ctermfg=7 gui=bold,italic guifg=#ffffff
  hi gitLogRefs      cterm=NONE        ctermfg=3 gui=NONE        guifg=#cdcd00
  hi gitLogRefHead   cterm=bold        ctermfg=6 gui=bold        guifg=#00ffff
  hi gitLogRefBranch cterm=bold        ctermfg=2 gui=bold        guifg=#00ff00
  hi gitLogRefRemote cterm=bold        ctermfg=1 gui=bold        guifg=#ff0000
  hi gitLogRefTag    cterm=bold        ctermfg=3 gui=bold        guifg=#ffff00
  hi gitLogRefStash  cterm=bold        ctermfg=5 gui=bold        guifg=#ff00ff
  let l:lanes = [['#cd0000', '#ff0000'], ['#00cd00', '#00ff00'], ['#cdcd00', '#ffff00'], ['#5c5cff', '#8787ff'],
        \ ['#cd00cd', '#ff00ff'], ['#00cdcd', '#00ffff']]
  for l:k in range(12)   " git's column colors: red, green, yellow, blue, magenta, cyan, then the same bold
    execute printf('hi gitGraphLane%d cterm=%s ctermfg=%d gui=%s guifg=%s', l:k, l:k < 6 ? 'NONE' : 'bold',
          \ l:k % 6 + 1, l:k < 6 ? 'NONE' : 'bold', l:lanes[l:k % 6][l:k / 6])
  endfor
endfunction
augroup CustomHighlights
  autocmd!
  autocmd ColorScheme * call s:Highlights()
augroup END
syntax on
colorscheme industry

" GUI font: Monospace at the size saved in ~/.vim/gvim_font_size (default 15).
" :FS <size> (or :fs) changes and saves the size, keeping the face; bare :FS or :size shows the font.
let s:font_file = expand('~/.vim/gvim_font_size')
let s:saved = get(filereadable(s:font_file) ? readfile(s:font_file, '', 1) : [], 0, '')
let g:gvim_font_size = s:saved =~# '^\d\+$' && str2nr(s:saved) > 0 ? str2nr(s:saved) : 15
unlet s:saved
if has('gui_running') | set guioptions-=m | let &guifont = 'Monospace ' . g:gvim_font_size | endif

function! SetFontSize(size) abort
  if empty(a:size) | set guifont? | return | endif
  let l:size = a:size =~# '^\d\+$' ? str2nr(a:size) : 0
  if l:size <= 0 | echoerr 'Invalid font size: ' . a:size | return | endif
  let l:pat = &guifont =~# ':h\d\+$' ? ':h\zs\d\+$' : ' \zs\d\+$'
  if &guifont !~# l:pat | echoerr 'Could not determine font size from guifont: ' . &guifont | return | endif
  let &guifont = substitute(&guifont, l:pat, l:size, '')
  let g:gvim_font_size = l:size
  call writefile([l:size], s:font_file)
  echo 'GVim font size set to ' . l:size
endfunction
command! -bar -nargs=? FS call SetFontSize(<q-args>)

" GVim starts maximized, filling the screen at any resolution and staying maximized through :FS. It first sizes itself
" to fill the screen: it would otherwise open at the size of the terminal or tmux pane it was started from, and keep
" that size when the window manager drops the maximize. xdotool windowstate takes one state per call, and needs an X
" window: GVim on XWayland has one, a native Wayland GVim (v:windowid 0) only the size.
if has('gui_running') | set lines=999 columns=999 | endif
augroup GuiMaximize
  autocmd!
  autocmd GUIEnter * if v:windowid && executable('xdotool')
        \ | call system(printf('xdotool windowstate --add MAXIMIZED_VERT %d windowstate --add MAXIMIZED_HORZ %d',
        \   v:windowid, v:windowid)) | endif
augroup END

"" Editing: ; and : swap, j/k swap (j = up), jj leaves insert mode, p/P swap, - / = undo/redo
noremap ; :
noremap : ;
noremap j k
noremap k j
inoremap jj <Esc>
noremap p P
noremap P p
nnoremap - u
nnoremap = <C-r>
noremap <silent> <Space> <Cmd>nohlsearch<Bar>echo<CR>
vnoremap <Leader>y "+y
nnoremap <Leader>p "+p
vnoremap // y/\V<C-r>=escape(@", '/\')<CR><CR>

"" Movement: J/K file top/bottom, H/L line start/end, Alt+j/k sentence, Alt+h/l word,
""           T/G/B window top/middle/bottom, M middle of the line
noremap K G
noremap J gg
noremap L $
noremap H 0
if has('gui_running')   " GVim receives Alt+key as <M-key>; a terminal sends Esc, then the key
  noremap <M-k> )
  noremap <M-j> (
  noremap <M-l> w
  noremap <M-h> b
else
  noremap <Esc>k )
  noremap <Esc>j (
  noremap <Esc>l w
  noremap <Esc>h b
endif
noremap T H
noremap G M
noremap B L
" M goes to the middle screen column, also on lines with tabs.
noremap <expr> M max([1, virtcol('$') / 2]) . '<Bar>'

"" Windows: Ctrl+h/j/k/l move (j = up), Ctrl+c close, Ctrl+r previous, Ctrl+[ (GVim only) / Ctrl+]
""          top / bottom, Ctrl+\ or .wr equalize, ., / .. narrower / wider
noremap <C-h> <C-w>h
noremap <C-j> <C-w>k
noremap <C-k> <C-w>j
noremap <C-l> <C-w>l
noremap <C-c> <C-w>c
noremap <C-r> <C-w>p
if has('gui_running')   " a terminal sends Esc for Ctrl+[, so there Esc would jump windows too
  noremap <C-[> <C-w>t
endif
" Ctrl+] still follows links in help windows; g Ctrl+] follows tags anywhere.
noremap <expr> <C-]> &buftype ==# 'help' ? "\<C-]>" : "\<C-w>b"
noremap <C-\> <C-w>=
noremap <Leader>, <C-w><
noremap <Leader>. <C-w>>
command! WindowResize wincmd =
noremap <Leader>wr <Cmd>WindowResize<CR>

"" Buffers: .B lists them and asks for one (by Vim's buffer number, as listed), .v/.s split one vertically/horizontally
""          (by its number on the top line, 0 the last, or its name), .va/.sa all of them, .vf/.sf the file named under
""          the cursor (or selected)
" :Vsb / :Sb N split buffer N as the top line numbers it (the key .N shows it), not Vim's buffer number, which drifts
" from it as buffers are deleted; a name or part of one works as for :sbuffer. Without the top line (the man page,
" scrollback and glow viewers) N is Vim's buffer number, as :sbuffer takes it.
function! s:SplitBuffer(mods, arg) abort
  let l:arg = trim(a:arg)
  if l:arg =~# '^\d\+$' && get(g:, 'airline#extensions#tabline#enabled', 0)
    let l:list = airline#extensions#tabline#buflist#list()
    let l:nr = get(l:list, l:arg ==# '0' ? -1 : str2nr(l:arg) - 1, 0)
    if !l:nr
      echohl ErrorMsg | echo printf('No buffer %s on the top line (1 to %d)', l:arg, len(l:list)) | echohl None
      return
    endif
    let l:arg = l:nr
  endif
  execute a:mods 'sbuffer' l:arg
endfunction
command! -nargs=1 -complete=buffer Vsb call s:SplitBuffer('vertical', <q-args>)
command! -nargs=1 -complete=buffer Sb call s:SplitBuffer('', <q-args>)
nnoremap <Leader>B :buffers<CR>:buffer<Space>
nnoremap <Leader>f :bnext<CR>
nnoremap <Leader>a :bprev<CR>
nnoremap <Leader>q :bfirst<CR>
nnoremap <Leader>z :blast<CR>
nnoremap <Leader>r :b#<CR>
nnoremap <Leader>v :Vsb<Space>
nnoremap <Leader>va :vertical ball<CR>
noremap <Leader>vf <C-w>f<C-w>L
nnoremap <Leader>s :Sb<Space>
nnoremap <Leader>sa :ball<CR>
noremap <Leader>sf <C-w>f

"" Diff & folds: .dt/.do/.du/.ds this/off/update/split, .dd A B two directories, .df/.da next/prev change,
""               [N / ]N get from / put to buffer N, zx / zz close / open all folds
set diffopt+=vertical,iwhite,foldcolumn:0,algorithm:histogram,indent-heuristic
noremap <Leader>dt :diffthis
noremap <Leader>do :diffoff
noremap <Leader>du :diffupdate
noremap <Leader>ds :diffsplit<Space>
nnoremap <Leader>dd :ZFDirDiff<Space>
noremap <Leader>df ]c
noremap <Leader>da [c
for s:n in range(1, 5)
  execute printf('noremap [%d :diffget %d<CR>', s:n, s:n)
  execute printf('noremap ]%d :diffput %d<CR>', s:n, s:n)
endfor
unlet s:n
noremap zx zM
noremap zz zR

"" Git logs: the files zsh's glao, glfo and gloo write, colored as git log --graph colors them in a terminal
" They are plain text, so grep, diff and mail see only the text, like the diffs gdco and gdoo write, which Vim colors
" with its own diff syntax (it knows them by their first line). These get a syntax of their own, gitgraph: files named
" git-log-all, git-log-files or git-log-origin (and git-log, glao's file until 2026-11-03), and any file whose first line
" is one of their commit lines (glao FILE). As git colors them: the hash red, the age green, the subject white,
" "- author" bold italic, and the refs as git decorates them (HEAD cyan, branches green, origin/ and upstream/ red, tags
" yellow, the stash magenta, all bold; the brackets and arrows plain yellow). Git draws each line of the graph in its
" own branch's color, which the text does not keep, so here each column takes git's colors in their order. The colors
" are set with the others, in s:Highlights.
function! s:GitGraphSyntax() abort
  for l:k in range(40)   " the graph's column k: its | at screen column 2k + 1, and a / \ or _ just left of it (* plain)
    execute printf('syntax match gitGraphLane%d #\%%%dc[|/\\_]%s# contained', l:k % 12, 2 * l:k + 1,
          \ l:k ? printf('\|\%%%dc[/\\_]', 2 * l:k) : '')
  endfor
  syntax match gitGraph #^[*|/\\_ ]\+# contains=gitGraphLane\d\+
  syntax match gitLogHash #\x\{40}\ze - (# nextgroup=gitLogDash
  syntax match gitLogDash # - # contained nextgroup=gitLogAge
  syntax match gitLogAge #([^)]*)# contained nextgroup=gitLogSubject skipwhite
  syntax match gitLogSubject #.*\ze - # contained nextgroup=gitLogAuthor skipwhite
  syntax match gitLogAuthor #- .\{-}\ze\%( ([^()]*)\)\=$# contained nextgroup=gitLogRefs
  " At the same column the ref defined last wins: a branch, unless it is a remote's, the stash, HEAD or a tag.
  syntax match gitLogRefBranch #\%((\|, \|-> \)\@<=[^ ,()]\+# contained
  syntax match gitLogRefRemote #\%((\|, \|-> \)\@<=\%(origin\|upstream\)/[^ ,()]\+# contained
  syntax match gitLogRefStash #\%((\|, \)\@<=refs/stash\># contained
  syntax match gitLogRefHead #\%((\|, \)\@<=HEAD\># contained
  syntax match gitLogRefTag #\%((\|, \)\@<=tag: [^,()]\+# contained
  syntax match gitLogRefs # ([^()]*)$# contained
        \ contains=gitLogRefBranch,gitLogRefRemote,gitLogRefStash,gitLogRefHead,gitLogRefTag
  let b:current_syntax = 'gitgraph'
endfunction
augroup GitGraphFiles
  autocmd!
  autocmd BufNewFile,BufRead git-log-all,git-log-files,git-log-origin,git-log setfiletype gitgraph
  autocmd BufRead * if empty(&filetype) && getline(1) =~# '^[*|/\\_ ]*\x\{40} - (' | setfiletype gitgraph | endif
  autocmd Syntax gitgraph call s:GitGraphSyntax()
augroup END

"" Quickfix: .c toggle, .k/.j next/prev, ./ list every match of the last search in this file
function! s:OpenQuickfix() abort   " quarter height, without moving the cursor into it
  let l:win = win_getid()
  execute 'copen | resize' (&lines / 4)
  call win_gotoid(l:win)
endfunction
function! ToggleQuickfix() abort
  if getqflist({'winid': 0}).winid | cclose | else | call s:OpenQuickfix() | endif
endfunction
function! SearchToQuickfix() abort
  if empty(@/) | echo 'No search pattern' | return | endif
  call setqflist([], 'r')
  try
    silent vimgrep //gj %
  catch /E480/
    echo 'No matches found for: ' . @/
    return
  endtry
  call s:OpenQuickfix()
endfunction
nnoremap <silent> <Leader>c :call ToggleQuickfix()<CR>
nnoremap <silent> <Leader>/ :call SearchToQuickfix()<CR>
noremap <Leader>k <Cmd>cnext<CR>
noremap <Leader>j <Cmd>cprev<CR>

"" Command-line shorthands, expanded by Enter only when they are the entire ':' command, so searches,
"" prompts and commands with arguments (:wa!, :so %, :bd 3) run unchanged. fs and ob are command
"" names: their arguments carry over (:fs 14, :ob name, :ob!).
let s:shorthands = {'ev': 'e ~/.vimrc', 'ea': 'e ~/.aliases', 'name': "echo expand('%:p')",
      \ 'cf': 'let @+ = expand("%:p")', 'ws': 'w !sudo tee %', 'so': 'setlocal syntax=off',
      \ 'bd': 'bprevious | bdelete #', 'a': 'qa', 'aa': 'qa!', 'wa': 'w | qa', 'size': 'set guifont?', 'od': 'ObPause'}
let s:shorthand_commands = {'fs': 'FS', 'ob': 'Ob'}
function! s:ExpandShorthand() abort   " the keys Enter sends: retype a shorthand, then <CR>
  let l:line = getcmdline()
  let l:name = matchstr(l:line, '^\a\+\ze\%([ !]\|$\)')
  if getcmdtype() !=# ':'
    return "\<CR>"
  elseif has_key(s:shorthands, l:line)
    return "\<C-e>\<C-u>" . s:shorthands[l:line] . "\<CR>"
  elseif has_key(s:shorthand_commands, l:name)
    return "\<C-b>" . repeat("\<Del>", len(l:name)) . s:shorthand_commands[l:name] . "\<CR>"
  endif
  return "\<CR>"
endfunction
cnoremap <expr> <CR> <SID>ExpandShorthand()

"" NERDTree (closed at startup): Ctrl+n focus, .nf find file, .nt toggle, .nr restore width. In its tree: s / v
""           split / vsplit, ot / OT tab (OT stays here), fo / fs / fv preview, a / z first / last child, J root,
""           U / u up a directory (u keeps the old root open), tb bookmarks, fi filters; in its m menu j is up
" .nf opens the tree on the current file: Vim's directory when the file is under it, else the file's own directory.
let g:NERDTreeWinSize = 30
" The tree's keys move off the ones this vimrc gives its own meaning (J/K top/bottom, T/B window top/bottom, j/k
" swapped) and match .s/.v for splits. Set here, not in the plugin, so a NERDTree update keeps them.
let g:NERDTreeMapOpenSplit = 's'
let g:NERDTreeMapOpenVSplit = 'v'
let g:NERDTreeMapOpenInTab = 'ot'
let g:NERDTreeMapOpenInTabSilent = 'OT'
let g:NERDTreeMapPreview = 'fo'
let g:NERDTreeMapPreviewSplit = 'fs'
let g:NERDTreeMapPreviewVSplit = 'fv'
let g:NERDTreeMapJumpFirstChild = 'a'
let g:NERDTreeMapJumpLastChild = 'z'
let g:NERDTreeMapJumpRoot = 'J'
let g:NERDTreeMapUpdir = 'U'
let g:NERDTreeMapUpdirKeepOpen = 'u'
let g:NERDTreeMapToggleBookmarks = 'tb'
let g:NERDTreeMapToggleFilters = 'fi'
let g:NERDTreeMenuDown = 'k'
let g:NERDTreeMenuUp = 'j'
function! NERDTreeResize() abort   " restore NERDTree's width, then equalize the other splits
  for l:id in gettabinfo(tabpagenr())[0].windows
    if getbufvar(winbufnr(l:id), '&filetype') ==# 'nerdtree'
      call win_execute(l:id, 'vertical resize ' . g:NERDTreeWinSize)
      wincmd =
      return
    endif
  endfor
endfunction
command! NERDTreeResize call NERDTreeResize()
nnoremap <C-n> :NERDTreeFocus<CR>
nnoremap <Leader>nf :NERDTreeFind<CR>
nnoremap <Leader>nt :NERDTreeToggle<CR>
nnoremap <Leader>nr :NERDTreeResize<CR>

"" Airline: section b shows the file's Git state (below), section y the Obsession session; the top line lists the
""          buffers: .1-.9 show the Nth there in this window, .0 the last, a click the one clicked; .b1-.b9/.b0 only
""          move to the window on screen that shows it
let g:airline_theme = 'solarized_flood'
let g:airline_theme_patch_func = 'AirlineThemePatch'
let g:airline_inactive_collapse = 0
let g:airline_powerline_fonts = 1
let g:airline_symbols = extend(get(g:, 'airline_symbols', {}), {'linenr': ' Line:', 'colnr': ' Col:', 'maxlinenr': ''})
let g:airline#extensions#default#layout = [['a', 'b', 'c'], ['x', 'y', 'z']]
let g:airline#extensions#branch#enabled = 0      " replaced by AirlineGitFileState()
let g:airline#extensions#obsession#enabled = 0   " replaced by CustomObsessionStatus()
augroup AirlineSections
  autocmd!
  autocmd User AirlineAfterInit let g:airline_section_b = airline#section#create(['%{AirlineGitFileState()}'])
        \ | let g:airline_section_y = airline#section#create(['%{CustomObsessionStatus()}'])
augroup END
" The top line (Airline's tabline) lists the buffers in buffer-number order, as .f/.a step through them, each numbered
" by its place: .1 to .9 show the first nine, .0 the last however many there are, and a left click the one clicked (Vim
" 9.2.0338 or later; a middle click deletes it, in GVim only: work's xfce4-terminal keeps middle clicks). A name is the
" file's alone, with the parent directories that tell it apart from another of the same name (hub/top.sv,
" fabric/top.sv); the current buffer is purple (AirlineThemePatch), and a modified one ends in +. It is one line: with
" more buffers than fit, it shows those around the current one, with ... where it cuts them off. While there are several
" tab pages (ZFDirDiff, NERDTree's ot), it lists the tab pages instead, and the same keys pick tab pages. NERDTree,
" ZFDirDiff's trees and the quickfix list ignore the keys, so no file replaces them. Not in the man page, scrollback and
" glow viewers (one buffer). GVim draws the same line in place of its GTK tabs (Airline takes e out of 'guioptions').
" Each kind has its own look (AirlineThemePatch): the current buffer a purple block, one shown in another window a gray
" block in bold white, a hidden one teal on the bar, a modified one bold yellow. Between every two buffers is an orange
" chevron (208, the zsh listings' directory color) with each block's color right up to it: two cells, the left block's
" arrow on orange, then an orange arrow on the right block's background (AirlineTabline below). Before each name is
" its number, the key .1-.9 that shows it, in green (the zsh listings' executable color), bold where the name is:
" 1 README.md (s:TablineColors).
let g:airline#extensions#tabline#enabled = empty($VIM_MANPAGER . $VIM_SCROLLBACK . $VIM_ANSI . $KITTY_SCROLLBACK)
let g:airline#extensions#tabline#formatter = 'unique_tail_improved'
let g:airline#extensions#tabline#fnamemod = ':t'
let g:airline#extensions#tabline#buffer_idx_mode = 1
let g:airline#extensions#tabline#show_close_button = 0
let g:airline#extensions#tabline#keymap_ignored_filetypes = ['nerdtree', 'ZFDirDiff', 'qf']
" Separators two cells wide, so that Airline counts them when it fits the names to the window: between two kinds its
" arrow, then a marked one (AirlineTabline() makes both the orange chevron, or, where a buffer meets the bar or a
" label, a blank of the second); between two of one kind two marked arrows (Airline would draw them in the text's
" color).
let g:airline#extensions#tabline#left_sep = "\ue0b0%#AirlineTabAltSep#\ue0b0"
let g:airline#extensions#tabline#right_sep = "\ue0b2%#AirlineTabAltSep#\ue0b2"
let g:airline#extensions#tabline#left_alt_sep = "%#AirlineTabAltSep#\ue0b0\ue0b0"
let g:airline#extensions#tabline#right_alt_sep = "%#AirlineTabAltSep#\ue0b2\ue0b2"
" Each digit of a number in the accent bufnum, then back to the buffer's own colors and a blank: Airline makes
" %#__accent_bufnum# the group <buffer's group>_bufnum and %#__restore__# the buffer's group (as in section x, below).
" Airline formats a number digit by digit, so AirlineTabline() keeps only the last digit's blank. In the tab-pages
" view the numbers are the tab pages', which .1-.9 pick there (AirlineTabNr; Airline puts the blank after it).
let g:airline#extensions#tabline#buffer_idx_format = {}
for s:n in range(10)
  let g:airline#extensions#tabline#buffer_idx_format[s:n] = '%#__accent_bufnum#' . s:n . '%#__restore__# '
endfor
unlet s:n
let g:airline#extensions#tabline#tabnr_formatter = 'AirlineTabNr'
function! AirlineTabNr(tabnr, buffers) abort
  return ' %#__accent_bufnum#' . a:tabnr . '%#__restore__#'
endfunction
" For each kind (and its _right twin, the tab-pages view's window list), on its background: <group>_bufnum, bright
" green (10, #55ff55: 4.8:1 on purple, 6.3:1 on gray, 11.5:1 on the bar; the zsh listings' plain green would be 2:1 on
" purple), bold when the kind's name is; and for the chevrons <group>_sepin, its background's color on orange
" (#ff8700), and <group>_sepout, orange on its background.
let s:tab_groups = ['airline_tabsel', 'airline_tabmod', 'airline_tab', 'airline_tabhid', 'airline_tabmod_unsel']
function! s:TablineColors() abort
  for l:group in s:tab_groups + map(copy(s:tab_groups), 'v:val . "_right"')
    let l:id = synIDtrans(hlID(l:group))
    let l:term = synIDattr(l:id, 'bg', 'cterm')
    let l:gui = synIDattr(l:id, 'bg#', 'gui')
    let [l:term, l:gui] = [empty(l:term) ? 'NONE' : l:term, empty(l:gui) ? 'NONE' : l:gui]
    let l:bold = synIDattr(l:id, 'bold', has('gui_running') ? 'gui' : 'cterm') ? 'bold' : 'NONE'
    execute printf('hi %s_bufnum cterm=%s ctermfg=10 ctermbg=%s gui=%s guifg=#55ff55 guibg=%s', l:group, l:bold, l:term,
          \ l:bold, l:gui)
    execute printf('hi %s_sepin cterm=NONE ctermfg=%s ctermbg=208 gui=NONE guifg=%s guibg=#ff8700', l:group, l:term,
          \ l:gui)
    execute printf('hi %s_sepout cterm=NONE ctermfg=208 ctermbg=%s gui=NONE guifg=#ff8700 guibg=%s', l:group, l:term,
          \ l:gui)
  endfor
  hi! link AirlineTabAltSep airline_tabhid_sepout
endfunction
function! s:Chevron(from, to, arrow) abort   " the orange chevron between buffers of groups from and to, two cells
  if a:arrow ==# "\ue0b2"   " the right part of the line, pointing left: an orange arrow, then the right one's on orange
    return '%#' . a:from . '_sepout#' . a:arrow . '%#' . a:to . '_sepin#' . a:arrow . '%#' . a:to . '#'
  endif
  return '%#' . a:from . '_sepin#' . a:arrow . '%#' . a:to . '_sepout#' . a:arrow . '%#' . a:to . '#'
endfunction
function! s:TabSep(from, to, arrow) abort   " a change of colors: the chevron between buffers, else Airline's arrow
  let l:kinds = '^airline_tab\%(sel\|mod\|hid\|mod_unsel\)\=\%(_right\)\=$'
  if a:from =~# l:kinds && a:to =~# l:kinds && hlexists(a:from . '_sepin')
    return s:Chevron(a:from, a:to, a:arrow)
  endif
  return '%#' . a:from . '_to_' . a:to . '#' . a:arrow . '%#' . a:to . '# '   " the bar or a label: a blank after it
endfunction
" Airline's tabline with its separators made orange chevrons. After a separator between two of one kind Airline does
" not set the next one's colors again; this does. It also drops the blank after each digit but a number's last.
" Airline sets 'tabline' to its own function when it starts and when :AirlineToggle turns it on; this takes over after
" both.
function! AirlineTabline() abort
  let l:line = substitute(airline#extensions#tabline#get(),
        \ '%#\(airline_\w\{-}\)_to_\(airline_\w\+\)#\(.\)%#AirlineTabAltSep#.%#\2#',
        \ '\=s:TabSep(submatch(1), submatch(2), submatch(3))', 'g')
  let l:line = substitute(l:line, '%#\w\+_bufnum#\d%#\w\+#\zs \ze%#\w\+_bufnum#', '', 'g')
  let l:parts = split(l:line, '%#AirlineTabAltSep#', 1)
  let l:group = ''
  for l:i in range(1, len(l:parts) - 1)   " each part after a marker starts with its arrows; its kind is the one before
    let l:last = matchstr(l:parts[l:i - 1], '.*%#\zs[^#]\+\ze#')
    let l:group = empty(l:last) ? l:group : l:last
    let l:arrows = matchstr(l:parts[l:i], '^..')
    if !empty(l:group) && hlexists(l:group . '_sepin')
      let l:parts[l:i] = s:Chevron(l:group, l:group, matchstr(l:arrows, '^.')) . l:parts[l:i][len(l:arrows):]
    endif
  endfor
  return join(l:parts, '')
endfunction
function! s:WrapTabline() abort
  if &tabline ==# '%!airline#extensions#tabline#get()' | let &tabline = '%!AirlineTabline()' | endif
endfunction
augroup AirlineTablineColors
  autocmd!
  autocmd User AirlineAfterTheme call s:TablineColors()
  autocmd User AirlineAfterInit call s:WrapTabline()
        \ | autocmd AirlineTablineColors User AirlineToggledOn call s:WrapTabline()
augroup END
" .b1-.b9 and .b0 move the cursor to the window on screen (this tab page's) that shows the top line's buffer N, and
" otherwise only say so: unlike .N they never change what a window shows. N is the buffer's place as .v/.s count it,
" also in the tab-pages view. .b alone does nothing, so that a pause after it can't repeat the last change (.) and
" move back a word (b).
function! s:GotoBuffer(n) abort
  let l:list = airline#extensions#tabline#buflist#list()
  let l:nr = get(l:list, a:n ? a:n - 1 : -1, 0)
  if !l:nr
    echohl ErrorMsg | echo printf('No buffer %d on the top line (1 to %d)', a:n, len(l:list)) | echohl None
    return
  endif
  let l:wins = filter(range(1, winnr('$')), 'winbufnr(v:val) == l:nr')
  if empty(l:wins)
    let l:name = airline#extensions#tabline#get_buffer_name(l:nr, l:list)
    let l:hint = tabpagenr('$') == 1 ? printf(' (.%d shows it in this one)', a:n) : ''
    echohl WarningMsg | echo printf('%s is not open in a window%s', l:name, l:hint) | echohl None
  elseif index(l:wins, winnr()) < 0
    execute l:wins[0] 'wincmd w'
  endif
endfunction
if g:airline#extensions#tabline#enabled
  for s:n in range(1, 9)
    execute printf('nmap <Leader>%d <Plug>AirlineSelectTab%d', s:n, s:n)
  endfor
  nmap <Leader>0 <Plug>AirlineSelectLastTab
  for s:n in range(10)
    execute printf('nnoremap <silent> <Leader>b%d <Cmd>call <SID>GotoBuffer(%d)<CR>', s:n, s:n)
  endfor
  unlet s:n
  nnoremap <Leader>b <Nop>
endif

" solarized_flood: no italics in a/b/c/z, b/y and c/x backgrounds match the inactive theme,
" c/x text turns green in insert mode, normal mode is purple (below). Palette entries are [guifg, guibg, ctermfg,
" ctermbg, attr]. Every theme: the accent dirdiff_scan, bold yellow as tmux's messages, for ZFDirDiff's scanning...
" (below).
function! AirlineThemePatch(palette) abort
  let a:palette.accents = extend(get(a:palette, 'accents', {}), {'dirdiff_scan': ['#ffff00', '', 226, '', 'bold']})
  if g:airline_theme !=# 'solarized_flood' | return | endif
  for l:mode in ['normal', 'insert', 'replace', 'visual', 'commandline', 'terminal']
    if !has_key(a:palette, l:mode) | continue | endif
    let l:p = a:palette[l:mode]
    for l:s in ['a', 'b', 'c', 'z'] | let l:p['airline_' . l:s][4] = '' | endfor
    for [l:s, l:gui, l:term] in [['b', '#262626', 235], ['y', '#262626', 235], ['c', '#303030', 236], ['x', '#303030', 236]]
      let l:p['airline_' . l:s][1] = l:gui
      let l:p['airline_' . l:s][3] = l:term
    endfor
  endfor
  if has_key(a:palette, 'insert')
    for l:s in ['c', 'x']
      let a:palette.insert['airline_' . l:s][0] = '#859900'
      let a:palette.insert['airline_' . l:s][2] = 106
    endfor
  endif
  " Normal mode is purple, the magenta of tmux's current window and active border and of the zsh prompt arrow (terminal
  " color 5, #aa00aa in work's xfce4-terminal palette), not the theme's yellow-green: bold white on it in section a and
  " for the current buffer on the top line (contrast 6.4:1), which keeps it when modified (Airline would use insert's
  " cyan), and z's text bright magenta (13, #ff55ff: 6.5:1 on the bar, where magenta itself would be 2.7:1). The top
  " line's other kinds of buffer each look different, on a bar darker than the windows' (235): one shown in another
  " window a gray block (239) in bold white (7.2:1), a hidden one teal (5.4:1), a modified one bold yellow, tmux's
  " highlight color (226, 14:1).
  if has_key(a:palette, 'normal')
    let a:palette.normal.airline_a = ['#ffffff', '#aa00aa', 231, 5, 'bold']
    let a:palette.normal.airline_z[0] = '#ff55ff'
    let a:palette.normal.airline_z[2] = 13
    let l:shown = ['#eeeeee', '#4e4e4e', 255, 239, 'bold']
    let l:hidden = ['#2aa198', '#262626', 36, 235, '']
    let l:modified = ['#ffff00', '#262626', 226, 235, 'bold']
    let a:palette.tabline = extend(get(a:palette, 'tabline', {}), {
          \ 'airline_tabsel': a:palette.normal.airline_a, 'airline_tabsel_right': a:palette.normal.airline_a,
          \ 'airline_tabmod': a:palette.normal.airline_a, 'airline_tabmod_right': a:palette.normal.airline_a,
          \ 'airline_tab': l:shown, 'airline_tab_right': l:shown, 'airline_tabhid': l:hidden,
          \ 'airline_tabhid_right': l:hidden, 'airline_tabmod_unsel': l:modified,
          \ 'airline_tabmod_unsel_right': l:modified, 'airline_tabfill': ['#9e9e9e', '#262626', 247, 235, '']})
  endif
endfunction

function! CustomObsessionStatus() abort
  if !filereadable(v:this_session) | return '[No Session]' | endif
  return exists('g:this_obsession')
        \ ? '[Live: ' . fnamemodify(g:this_obsession, ':t') . ']'
        \ : '[Paused: ' . fnamemodify(get(g:, 'this_session', v:this_session), ':t') . ']'
endfunction

" Git state of the file vs origin: ✓ ORIGIN, ≠ CHANGED, + NEW (tracked, not on origin), ? UNTRACKED,
" ! NO ORIGIN, or ● UNSAVED. A background job computes it on enter/write/focus; the statusline only
" reads the cached result. Origin is origin/HEAD, else origin/main or origin/master (the first ref
" for-each-ref lists). The job runs in the file's physical directory with a relative path, so
" symlinked paths work; it makes at most three Git calls because each one is slow on NFS.
let s:git_state_labels = {'ORIGIN': '✓ ORIGIN', 'CHANGED': '≠ CHANGED', 'NEW': '+ NEW',
      \ 'UNTRACKED': '? UNTRACKED', 'NOORIGIN': '! NO ORIGIN'}
let s:origin_refs = 'refs/remotes/origin/HEAD refs/remotes/origin/main refs/remotes/origin/master'   " also GitGutter's
let s:git_state_script = join([
      \ 'case "$1/" in */.git/*) echo NOGIT; exit;; esac',
      \ 'cd "$1" 2>/dev/null || { echo NOGIT; exit; }',
      \ 'export GIT_LITERAL_PATHSPECS=1',
      \ 'origin=$(git for-each-ref --count=1 --format="%(refname)" ' . s:origin_refs . ' 2>/dev/null) || { echo NOGIT; exit; }',
      \ '[ -n "$origin" ] || { echo NOORIGIN; exit; }',
      \ 'change=$(git diff --no-color --name-status "$origin" -- "$2" 2>/dev/null) || { echo NOGIT; exit; }',
      \ 'case $change in',
      \ '  A*) echo NEW;;',
      \ '  ?*) echo CHANGED;;',
      \ '  *) if git cat-file -e "$origin:./$2" 2>/dev/null; then echo ORIGIN; else echo UNTRACKED; fi;;',
      \ 'esac'], "\n")

function! AirlineGitFileState() abort
  if !empty(&buftype) || empty(expand('%')) | return '' | endif
  return &modified ? '● UNSAVED' : get(b:, 'airline_git_file_state', '')
endfunction

function! RefreshAirlineGitFileState() abort
  if !empty(&buftype) || empty(expand('%')) | let b:airline_git_file_state = '' | return | endif
  if exists('b:airline_git_state_job') && job_status(b:airline_git_state_job) ==# 'run'
    call job_stop(b:airline_git_state_job)
  endif
  let b:airline_git_state_generation = get(b:, 'airline_git_state_generation', 0) + 1
  let l:file = resolve(expand('%:p'))
  let b:airline_git_state_job = job_start(
        \ ['sh', '-c', s:git_state_script, 'airline-git-state', fnamemodify(l:file, ':h'), fnamemodify(l:file, ':t')],
        \ {'out_cb': function('s:GitStateResult', [bufnr(), b:airline_git_state_generation]), 'err_io': 'null'})
endfunction

function! s:GitStateResult(buf, generation, channel, msg) abort   " ignore gone buffers and superseded jobs
  if !bufexists(a:buf) || getbufvar(a:buf, 'airline_git_state_generation', 0) != a:generation | return | endif
  call setbufvar(a:buf, 'airline_git_file_state', get(s:git_state_labels, a:msg, ''))
  if bufnr() == a:buf | redrawstatus | endif
endfunction

"" GitGutter: .gta/.gt toggle all/buffer, .gth line highlights, .gd diff vs base, .gq quickfix,
""            .hd/.hs/.hu preview/stage/undo hunk, .hf/.ha next/prev hunk
set updatetime=100 foldtext=gitgutter#fold#foldtext()
let g:gitgutter_async = 1
let g:gitgutter_max_signs = -1
let g:gitgutter_diff_base = 'origin/HEAD'
let g:gitgutter_preview_win_location = 'bel'
noremap <Leader>gta <Cmd>GitGutterToggle<CR>
noremap <Leader>gt <Cmd>GitGutterBufferToggle<CR>
noremap <Leader>gth <Cmd>GitGutterLineHighlightsToggle<CR>
noremap <Leader>gd <Cmd>GitGutterDiffOrig<CR>
noremap <Leader>gq <Cmd>let g:gitgutter_diff_base = <SID>OriginBase(getcwd()) <Bar> GitGutterQuickFix<CR>
map <Leader>hd <Plug>(GitGutterPreviewHunk)
map <Leader>hs <Plug>(GitGutterStageHunk)
map <Leader>hu <Plug>(GitGutterUndoHunk)
map <Leader>hf <Plug>(GitGutterNextHunk)
map <Leader>ha <Plug>(GitGutterPrevHunk)

" Each file diffs against its own repo's origin as section b finds it (origin/HEAD, else origin/main or origin/master),
" and against the index (what is staged) in a repo with none, where origin/HEAD alone would fail with
" g:gitgutter_diff_base (origin/HEAD) is invalid and mark every line added. GitGutter keeps one diff base for every
" buffer (g:gitgutter_diff_base, used now only if this takeover stops matching it), so this replaces its
" gitgutter#utility#get_diff_base() right after Vim loads that file (once, as GitGutter's plugin starts), keeping its
" Fugitive rule (a past revision diffs against its parent). The replacement is made with execute(): a :function of that
" name written inside another function would load GitGutter's file while this one is still being read, before the
" autocommand exists. A buffer's base is found once, with one Git call, and again when the file is read again (:e).
" .gq lists the hunks of the repo Vim's working directory is in, against that repo's base.
function! s:OriginBase(dir) abort   " origin/HEAD, origin/main or origin/master, else '' (the index)
  let l:ref = system('git -C ' . shellescape(a:dir) . ' for-each-ref --count=1 --format="%(refname)" ' . s:origin_refs)
  return v:shell_error ? '' : substitute(trim(l:ref), '^refs/remotes/', '', '')
endfunction
function! GitGutterDiffBase(bufnr) abort
  let l:revision = matchstr(resolve(expand('#' . a:bufnr . ':p')), '\v^fugitive:/.*/\zs\x{40,}\ze/')
  if !empty(l:revision) | return l:revision . '^' | endif
  if type(getbufvar(a:bufnr, 'gitgutter_origin_base', v:null)) != v:t_string
    let l:dir = fnamemodify(resolve(expand('#' . a:bufnr . ':p')), ':h')
    call setbufvar(a:bufnr, 'gitgutter_origin_base', s:OriginBase(l:dir))
  endif
  return getbufvar(a:bufnr, 'gitgutter_origin_base')
endfunction
augroup GitGutterDiffBase
  autocmd!
  autocmd SourcePost */autoload/gitgutter/utility.vim call execute(['function! gitgutter#utility#get_diff_base(bufnr)',
        \ 'return GitGutterDiffBase(a:bufnr)', 'endfunction'])
  autocmd BufReadPost * unlet! b:gitgutter_origin_base
augroup END

" Suspend GitGutter in buffers shown in diff mode; re-enable only what this suspended.
function! SyncGitGutterWithDiff() abort
  if exists(':GitGutterBufferDisable') != 2 | return | endif
  if &diff && !get(b:, 'gitgutter_disabled_for_diff', 0)
    silent! GitGutterBufferDisable
    let b:gitgutter_disabled_for_diff = 1
  elseif !&diff && get(b:, 'gitgutter_disabled_for_diff', 0)
    silent! GitGutterBufferEnable
    unlet b:gitgutter_disabled_for_diff
  endif
endfunction
function! SyncAllGitGutterDiffWindows() abort
  for l:win in getwininfo() | call win_execute(l:win.winid, 'call SyncGitGutterWithDiff()') | endfor
endfunction

"" CtrlP: Ctrl+f opens and closes it; Ctrl+k/j move down/up in the list
let g:ctrlp_map = '<C-f>'
let g:ctrlp_show_hidden = 1
let g:ctrlp_prompt_mappings = {
      \ 'PrtSelectMove("j")': ['<c-k>', '<down>'],
      \ 'PrtSelectMove("k")': ['<c-j>', '<up>'],
      \ 'ToggleType(1)':      ['<c-up>'],
      \ 'PrtExit()':          ['<esc>', '<c-f>'],
      \ }

"" ZFDirDiff: .dd A B diffs two directories. In its tree: o open, .df/.da (]c/[c, DK/DJ) next/prev diff,
""            Dk/Dj next/prev changed file, .du refresh, zx/zz close all/open changed, do/dp sync, q quit
" Keep its companions from changing every buffer: ZFVimBackup does not back up each write, and ZFVimIgnore leaves
" 'wildignore' (CtrlP, completion, glob()) alone. ZFDirDiff 37847db never asks ZFVimBackup for a backup, despite its
" docs, so do/dp/dd overwrite and delete without one; :call ZFBackupSave(path) first when it matters.
let g:ZFBackup_autoEnable = 0
let g:ZFIgnore_apply_wildignore = 0
" The tree's keys follow this vimrc: the diff leader keys, and j/k = up/down (upstream DJ/Dj go down).
let g:ZFDirDiffKeymap_diffNext = [']c', 'DK', '<Leader>df']
let g:ZFDirDiffKeymap_diffPrev = ['[c', 'DJ', '<Leader>da']
let g:ZFDirDiffKeymap_diffNextFile = ['Dk']
let g:ZFDirDiffKeymap_diffPrevFile = ['Dj']
let g:ZFDirDiffKeymap_update = ['<Leader>du']
let g:ZFDirDiffKeymap_foldCloseAll = ['X', 'zx']
let g:ZFDirDiffKeymap_foldOpenAllDiff = ['O', 'zz']
" Colored like a Vim diff (the colors are set with the others, in s:Highlights). The side a name is missing from shows -
" filler where it would be, as a diff fills a deleted line; the plugin colors only the names, not whole rows.
function! ZFDirDiffUI_cbDiffLine(taskData, node, depth, isLeft, isDir) abort   " the plugin's row text, with the filler
  if a:isDir != -1
    return ZFDirDiffUI_cbDiffLineDefault(a:taskData, a:node, a:depth, a:isLeft, a:isDir)
  endif
  let l:there = ZFDirDiffUI_cbDiffLineDefault(a:taskData, a:node, a:depth, !a:isLeft,
        \ index([g:ZFDirDiff_T_DIR_LEFT, g:ZFDirDiff_T_DIR_RIGHT], a:node.type) >= 0)
  let l:indent = matchstr(l:there, '^ *')
  return l:indent . repeat('-', strdisplaywidth(l:there) - len(l:indent))
endfunction
" With Airline, section x of each tree (the filetype elsewhere) says whether the scan still runs: scanning... until
" every file and directory below has been compared, then done: differences or done: identical. .du scans again.
" scanning... is in the accent dirdiff_scan (AirlineThemePatch), which keeps the section's background; like every
" accent, Airline drops it in the pane without focus. The text is in %{} items: Vim drops a %(...%) group, as Airline
" wraps each section in, that holds no %{} item and ends in the highlight it started in.
let s:zfdirdiff_scan = '%#__accent_dirdiff_scan#%{AirlineDirDiffScan(1)}%#__restore__#%{AirlineDirDiffScan(0)}'
" The tab's diff, as its top level rolls it up: -1 while anything below is unchecked, else 1 if any differs, else 0.
" The plugin redraws after each batch of results, the last one included, so the text follows the scan with no timer.
function! AirlineDirDiffScan(running) abort   " section x's running part (scanning...) or finished part (done: ...)
  let l:diff = get(get(t:, 'ZFDirDiff_taskData', {}), 'diff', -2)
  if a:running
    return l:diff == -1 ? 'scanning…' : ''
  endif
  return l:diff == 1 ? 'done: differences' : l:diff == 0 ? 'done: identical' : ''
endfunction
function! s:ZFDirDiffAirline(builder, context) abort   " an Airline statusline funcref, for focused and other panes
  if getbufvar(a:context.bufnr, '&filetype') ==# 'ZFDirDiff'
    call setwinvar(a:context.winnr, 'airline_section_x', s:zfdirdiff_scan)
  elseif getwinvar(a:context.winnr, 'airline_section_x', '') ==# s:zfdirdiff_scan   " now showing another buffer
    call win_execute(win_getid(a:context.winnr), 'unlet w:airline_section_x')
  endif
  return 0
endfunction
" A new diff (.dd, zsh's dirdiff, DM on two directories) starts in the left tree, not the right one the plugin's
" ZFDirDiff() ends in: once it has returned, on the same line (cursorbind syncs the trees only after a key, so the line
" is carried over). U, u and cd, which re-root the trees, still end in the right one: the plugin's highlight cleanup
" leaves the cursor there.
function! s:ZFDirDiffStartLeft() abort
  if bufnr() == get(t:, 'ZFDirDiff_bufnrR', -1) && exists('t:ZFDirDiff_bufnrL')
    let l:line = line('.')
    call ZFDirDiffUI_jumpWin(t:ZFDirDiff_bufnrL, 1)
    call cursor(l:line, 1)
  endif
endfunction
augroup ZFDirDiffTree
  autocmd!
  autocmd Syntax ZFDirDiff syntax match ZFDirDiffFiller /^ *\zs-\+$/
  if exists('##SafeState')
    autocmd FileType ZFDirDiff autocmd ZFDirDiffTree SafeState * ++once call s:ZFDirDiffStartLeft()
  endif
  autocmd User AirlineAfterInit call airline#add_statusline_funcref(function('s:ZFDirDiffAirline'), 0)
        \ | call airline#add_inactive_statusline_funcref(function('s:ZFDirDiffAirline'), 0)
        \ | call airline#highlighter#add_accent('dirdiff_scan')
augroup END

"" Obsession sessions: one live session per Vim, guarded by a lock directory.
""   :ob [name]  (:Ob[!])  track $OBSESSION_ROOT/named/<name>.vim, or with no name this launch
""                         directory's $OBSESSION_ROOT/by-path/<dir>/Session.vim  (! = overwrite)
""   :od  (:ObPause)       stop tracking and release the lock (the session file is kept)
""   :ObUnlock [name]      force-remove a stale lock left by another Vim
""   :ObPath               show the default session path
"" $OBSESSION_ROOT defaults to ~/obsessions. zsh's vl/gl pass $OBSESSION_LOAD_SESSION
"" instead of -S so the lock is taken before sourcing. $OBSESSION_AUTO=0 (zsh's EDITOR, for git
"" commit and sudoedit) skips tracking the launch directory's session, so its saved layout survives.
let g:obsession_root = expand(empty($OBSESSION_ROOT) ? '~/obsessions' : $OBSESSION_ROOT)
let g:obsession_start_dir = substitute(resolve(fnamemodify(getcwd(), ':p')), '/\+$', '', '')   " like `pwd -P`; fixed at launch
if empty(g:obsession_start_dir) | let g:obsession_start_dir = '/' | endif

function! s:SessionPath(name) abort   " '' → the launch directory's default session
  if !empty(a:name)
    let l:file = fnamemodify(a:name, ':t')
    return g:obsession_root . '/named/' . l:file . (l:file =~# '\.vim$' ? '' : '.vim')
  endif
  let l:key = substitute(g:obsession_start_dir, '^/\+', '', '')
  return g:obsession_root . '/by-path/' . (empty(l:key) ? '__root__' : l:key) . '/Session.vim'
endfunction

function! s:Warn(msg) abort
  echohl WarningMsg | echom a:msg | echohl None
endfunction

function! s:Tracking(session) abort   " Obsession is recording exactly this session
  return exists('g:this_obsession') && fnamemodify(g:this_obsession, ':p') ==# a:session
endfunction

" Locks: <session>.lock/owner holds [hostname, pid, launch dir]; mkdir() is the atomic claim.
function! s:LockOwner(lock) abort   " [host, pid], or [] when missing/incomplete
  let l:file = a:lock . '/owner'
  let l:owner = filereadable(l:file) ? readfile(l:file) : []
  return len(l:owner) >= 2 ? l:owner[:1] : []
endfunction

function! s:LockIsActive(lock) abort
  if !isdirectory(a:lock) | return 0 | endif
  let l:owner = s:LockOwner(a:lock)
  " An unknown owner, another host or a live PID all count as active; only a dead local PID is stale.
  if empty(l:owner) || l:owner[0] !=# hostname() || l:owner[1] !~# '^\d\+$' || isdirectory('/proc/' . l:owner[1])
    return 1
  endif
  call delete(a:lock, 'rf')
  return 0
endfunction

function! s:ClaimLock(session) abort   " → the lock dir, or '' when another Vim owns the session
  let l:lock = fnamemodify(a:session, ':p') . '.lock'
  call mkdir(fnamemodify(l:lock, ':h'), 'p')
  if s:LockIsActive(l:lock) | return '' | endif
  try
    if !mkdir(l:lock) | return '' | endif
  catch
    return ''
  endtry
  try
    call writefile([hostname(), string(getpid()), g:obsession_start_dir], l:lock . '/owner')
  catch
    call delete(l:lock, 'rf')
    return ''
  endtry
  return l:lock
endfunction

function! s:ReleaseLock(lock) abort   " only if this Vim owns it
  if !empty(a:lock) && s:LockOwner(a:lock) ==# [hostname(), string(getpid())]
    call delete(a:lock, 'rf')
  endif
endfunction

function! s:ReleaseCurrentLock() abort
  call s:ReleaseLock(get(g:, 'obsession_lock_dir', ''))
  unlet! g:obsession_lock_dir g:obsession_lock_session
endfunction

function! s:HoldLock(lock, session) abort
  let [g:obsession_lock_dir, g:obsession_lock_session] = [a:lock, a:session]
  return 1
endfunction

function! s:TrackObsession(session, force) abort
  if exists(':Obsession') != 2 | return 0 | endif
  let l:session = fnamemodify(a:session, ':p')
  if get(g:, 'obsession_lock_session', '') ==# l:session && s:Tracking(l:session) | return 1 | endif
  let l:lock = s:ClaimLock(l:session)   " claim before Obsession touches the file
  if empty(l:lock) | call s:Warn('Obsession already active: ' . l:session) | return 0 | endif
  let l:old_lock = get(g:, 'obsession_lock_dir', '')
  try
    execute 'silent Obsession' . (a:force ? '!' : '') fnameescape(l:session)
  catch
    call s:ReleaseLock(l:lock)
    echoerr v:exception
    return 0
  endtry
  if !s:Tracking(l:session)
    call s:ReleaseLock(l:lock)
    call s:Warn('Could not start Obsession: ' . l:session)
    return 0
  endif
  call s:HoldLock(l:lock, l:session)
  if !empty(l:old_lock) && l:old_lock !=# l:lock | call s:ReleaseLock(l:old_lock) | endif
  return 1
endfunction

function! s:LoadObsession(session) abort
  let l:session = fnamemodify(a:session, ':p')
  if !filereadable(l:session) | call s:Warn('No saved session: ' . l:session) | return 0 | endif
  let l:lock = s:ClaimLock(l:session)   " lock BEFORE sourcing
  if empty(l:lock) | call s:Warn('Session already active: ' . l:session) | return 0 | endif
  let l:old_session = v:this_session
  try
    " Behave like -S: Obsession sessions restore g:this_obsession from v:this_session.
    let v:this_session = l:session
    execute 'silent source' fnameescape(l:session)
    let v:this_session = l:session
    " Sessions load after startup syntax setup; rerun FileType → Syntax for every restored buffer.
    doautoall syntaxset FileType
    if !s:Tracking(l:session) | execute 'silent Obsession' fnameescape(l:session) | endif
  catch
    if s:Tracking(l:session) | silent! Obsession | endif   " pause if loading got that far
    let v:this_session = l:old_session
    call s:ReleaseLock(l:lock)
    echoerr v:exception
    return 0
  endtry
  return s:HoldLock(l:lock, l:session)
endfunction

function! s:ClaimLoadedObsession() abort   " a session sourced by `vim -S`
  let l:session = fnamemodify(g:this_obsession, ':p')
  let l:lock = s:ClaimLock(l:session)
  if empty(l:lock)
    silent! Obsession   " it's loaded, but another Vim is already writing it
    call s:Warn('Session already active; Obsession paused: ' . l:session)
    return 0
  endif
  return s:HoldLock(l:lock, l:session)
endfunction

function! s:Unlock(name) abort
  let l:session = fnamemodify(s:SessionPath(a:name), ':p')
  let l:lock = l:session . '.lock'
  if get(g:, 'obsession_lock_session', '') ==# l:session
    echoerr 'This Vim currently owns that session lock.'
  elseif isdirectory(l:lock)
    call delete(l:lock, 'rf')
    echom 'Removed session lock: ' . l:lock
  else
    echom 'No session lock exists: ' . l:session
  endif
endfunction

command! -bang -nargs=? Ob call s:TrackObsession(s:SessionPath(<q-args>), <bang>0)
command! ObPause if exists('g:this_obsession') | silent! Obsession | endif | call s:ReleaseCurrentLock()
command! -nargs=? ObUnlock call s:Unlock(<q-args>)
command! ObPath echo s:SessionPath('')

"" Startup
" Man pages (zsh's MANPAGER), Kitty or tmux scrollback and glow never touch sessions or plugin UI.
function! s:IsViewer() abort
  return !empty($KITTY_SCROLLBACK) || !empty($VIM_MANPAGER) || !empty($VIM_SCROLLBACK) || !empty($VIM_ANSI)
endfunction

function! s:ScrollbackViewer() abort   " tmux's prefix e: a read-only scratch buffer without the blank tail, at the end
  setlocal buftype=nofile bufhidden=wipe noswapfile noreadonly
  silent! keeppatterns %s/\s\+$//e
  silent! keeppatterns %s/\(\n\s*\)\+\%$//e
  setlocal nomodifiable nomodified nonumber norelativenumber   " no line numbers, as in man pages
  normal! G
endfunction

" zsh's glow: Markdown rendered with ANSI escape sequences arrives on stdin (glow wraps each word in its own color and
" pads every line with colored blanks). The sequences come out of the text and their colors and attributes become text
" properties, so searches, motions and yanks see plain text; other sequences (glow's OSC 8 links) are dropped. Blanks
" that show nothing are trimmed from line ends, and 24-bit colors become the nearest of the terminal's 256. These are
" compiled :def functions: glow writes some 60 sequences a line, which took legacy script 12 s for a 2,250-line page.
" A Vim without them shows the sequences as they are.
let s:ansi_bit = [0, 1, 0, 2, 4, 0, 0, 8, 0, 16]   " SGR code → bit: 1 bold, 3 italic, 4 underline, 7 reverse, 9 strike
let s:ansi_bits = [[1, 'bold'], [2, 'italic'], [4, 'underline'], [8, 'reverse'], [16, 'strikethrough']]
if has('vim9script') && exists('*prop_add_list')
  def s:Ansi256(r: number, g: number, b: number): number   # the 256-color index nearest r g b: the cube's or a gray's
    var rgb = [r, g, b]
    var q = rgb->mapnew((_, v) => v < 48 ? 0 : v < 115 ? 1 : (v - 35) / 40)
    var gray = min([23, max([0, ((r + g + b) / 3 - 3) / 10])])
    var dcube = 0
    var dgray = 0
    for i in range(3)
      var level = q[i] > 0 ? 55 + 40 * q[i] : 0
      dcube += (rgb[i] - level) * (rgb[i] - level)
      dgray += (rgb[i] - 8 - 10 * gray) * (rgb[i] - 8 - 10 * gray)
    endfor
    return dgray < dcube ? 232 + gray : 16 + 36 * q[0] + 6 * q[1] + q[2]
  enddef

  def s:AnsiSgr(fg0: number, bg0: number, attr0: number, params: string): list<number>   # [fg, bg, attr] after an SGR
    var [fg, bg, attr] = [fg0, bg0, attr0]
    var p = split(params, '[;:]', true)->mapnew((_, v) => str2nr(v))
    var i = 0
    while i < len(p)
      var c = p[i]
      if c == 0
        [fg, bg, attr] = [-1, -1, 0]
      elseif c == 1 || c == 3 || c == 4 || c == 7 || c == 9
        attr = or(attr, s:ansi_bit[c])
      elseif c == 22 || c == 23 || c == 24 || c == 27 || c == 29
        attr = and(attr, invert(s:ansi_bit[c == 22 ? 1 : c - 20]))
      elseif c >= 30 && c <= 37 || c >= 90 && c <= 97
        fg = c - (c < 90 ? 30 : 82)
      elseif c >= 40 && c <= 47 || c >= 100 && c <= 107
        bg = c - (c < 100 ? 40 : 92)
      elseif c == 39
        fg = -1
      elseif c == 49
        bg = -1
      elseif c == 38 || c == 48   # 38;5;N (256 colors) or 38;2;R;G;B (24-bit); 48 is the same for the background
        var kind = get(p, i + 1)
        var color = kind == 5 ? get(p, i + 2, -1)
          : kind == 2 ? s:Ansi256(get(p, i + 2), get(p, i + 3), get(p, i + 4)) : -1
        if c == 38
          fg = color
        else
          bg = color
        endif
        i += kind == 5 ? 2 : kind == 2 ? 4 : 0
      endif
      i += 1
    endwhile
    return [fg, bg, attr]
  enddef

  def s:AnsiType(fg: number, bg: number, attr: number): string   # the property type for a state, defined on first use
    var name = $'Ansi_{fg + 1}_{bg + 1}_{attr}'   # + 1: a name has no minus sign
    if empty(prop_type_get(name))
      var cterm = s:ansi_bits->copy()->filter((_, b) => and(attr, b[0]) > 0)->mapnew((_, b) => b[1])->join(',')
      execute $'hi {name} ctermfg={fg < 0 ? "NONE" : string(fg)} ctermbg={bg < 0 ? "NONE" : string(bg)}'
        .. $' cterm={cterm == "" ? "NONE" : cterm}'
      prop_type_add(name, {highlight: name})
    endif
    return name
  enddef

  def s:AnsiRender(raw: list<string>)   # the buffer's text and text properties, from lines with escape sequences
    var [fg, bg, attr] = [-1, -1, 0]   # carried from line to line, as in a terminal
    var sgr: dict<list<number>> = {}   # a state and SGR parameters → the next state, each worked out once
    var types: dict<string> = {}       # a state → its text property type
    var runs: dict<list<list<number>>> = {}   # a type → its runs, [lnum, col, lnum, end col]
    var lines: list<string> = []
    for line in raw
      var text = ''
      var keep = 0   # the length up to the last thing that shows
      var last: list<number> = []   # the line's last run, which a next word in the same style extends
      var lasttype = ''
      var after = false
      for part in split(line, "\e", true)
        var seg = part
        if after   # after an escape: CSI (SGR when it ends in m), OSC to its BEL (an ST leaves a \), or a short one
          if part[0] == '['
            var e = matchend(part, '^\[[0-?]*[ -/]*[@-~]')
            if e > 0 && part[e - 1] == 'm'
              var key = $'{fg},{bg},{attr};{strpart(part, 1, e - 2)}'
              if !has_key(sgr, key)
                sgr[key] = s:AnsiSgr(fg, bg, attr, strpart(part, 1, e - 2))
              endif
              [fg, bg, attr] = sgr[key]
            endif
            seg = strpart(part, max([e, 1]))
          elseif part[0] == ']'
            var e = stridx(part, "\x07")
            seg = e < 0 ? '' : strpart(part, e + 1)
          else
            seg = strpart(part, part[0] =~ '[()*+]' ? 2 : 1)
          endif
        endif
        after = true
        if seg == ''
          continue
        endif
        var col = strlen(text) + 1
        text ..= seg
        if bg >= 0 || and(attr, 28) > 0   # a background, underline, reverse or strikethrough shows on blanks too
          keep = strlen(text)
        elseif trim(seg, " \t", 2) != ''
          keep = col - 1 + strlen(trim(seg, " \t", 2))
        endif
        if fg >= 0 || bg >= 0 || attr > 0
          var state = $'{fg},{bg},{attr}'
          if !has_key(types, state)
            types[state] = s:AnsiType(fg, bg, attr)
            runs[types[state]] = []
          endif
          if types[state] == lasttype && last[3] == col
            last[3] += strlen(seg)
          else
            last = [len(lines) + 1, col, len(lines) + 1, col + strlen(seg)]
            lasttype = types[state]
            add(runs[lasttype], last)
          endif
        endif
      endfor
      add(lines, strpart(text, 0, keep))
    endfor
    while len(lines) > 1 && lines[-1] !~ '\S'
      remove(lines, -1)
    endwhile
    setlocal modifiable
    silent :%delete _
    setline(1, lines)
    for [type, list] in items(runs)   # a run the trimming cut ends at its line's end
      filter(list, (_, r) => r[0] <= len(lines) && r[1] <= strlen(lines[r[0] - 1]))
      map(list, (_, r) => [r[0], r[1], r[2], min([r[3], strlen(lines[r[0] - 1]) + 1])])
      if !empty(list)
        prop_add_list({type: type}, list)
      endif
    endfor
    setlocal nomodifiable nomodified
  enddef

  def s:AnsiViewer()
    setlocal buftype=nofile bufhidden=wipe noswapfile noreadonly
    s:AnsiRender(getline(1, '$'))
    b:ansi_width = winwidth(0)
    if $VIM_ANSI != '1'   # the name it was given, for the status line
      silent! execute 'file ' .. fnameescape($VIM_ANSI)
    endif
    setlocal nonumber norelativenumber
    cursor(1, 1)   # the top-left corner, where gg would stop on the first non-blank (inside a heading's banner)
  enddef

  " A window that changes size (a tmux pane zoomed or dragged) has $VIM_ANSI_CMD (zsh's glow, without -w) render the
  " text again at the new width, with the cursor kept on the same text where it can be. At once, in VimResized: a
  " timer started there would wait for the next key, as Vim was already waiting for one.
  def s:AnsiWords(line: string): string   # a line's text without the blanks a width changes (margins, table padding)
    return substitute(trim(line), '\s\+', ' ', 'g')
  enddef

  def s:AnsiSame(a: string, b: string): bool   # the same text, or the start of it (a wider table row goes on)
    return b != '' && (a == b || stridx(a, b) == 0 && strlen(b) >= 8 || stridx(b, a) == 0)
  enddef

  def s:AnsiRerender()
    if empty($VIM_ANSI_CMD) || !exists('b:ansi_width') || winwidth(0) == b:ansi_width
      return
    endif
    var out = systemlist($VIM_ANSI_CMD .. ' -w ' .. winwidth(0) .. ' </dev/null')
    if v:shell_error != 0 || empty(out)
      return
    endif
    var anchor = s:AnsiWords(getline('.'))
    var share = (line('.') - 1.0) / max([1, line('$') - 1])
    var row = winline()
    s:AnsiRender(out)
    b:ansi_width = winwidth(0)
    var guess = float2nr(round(share * (line('$') - 1))) + 1
    var best = guess   # the line with the cursor's text nearest to the same share of the page, else that share
    for d in range(line('$'))
      if strlen(anchor) < 8 || guess - d < 1 && guess + d > line('$')
        break
      elseif guess - d >= 1 && s:AnsiSame(anchor, s:AnsiWords(getline(guess - d)))
        best = guess - d
        break
      elseif guess + d <= line('$') && s:AnsiSame(anchor, s:AnsiWords(getline(guess + d)))
        best = guess + d
        break
      endif
    endfor
    cursor(best, 1)
    normal! zt
    if row > 1   # back on the screen row it was on
      execute "normal! " .. (row - 1) .. "\<C-y>"
    endif
  enddef
endif

function! s:MaybeStartObsession() abort
  if s:IsViewer() || exists(':Obsession') != 2 | return | endif
  if !empty($OBSESSION_LOAD_SESSION)   " vl/gl; don't let child shells inherit the request
    let l:session = $OBSESSION_LOAD_SESSION
    let $OBSESSION_LOAD_SESSION = ''
    call s:LoadObsession(l:session)
  elseif !empty(get(g:, 'this_obsession', ''))
    call s:ClaimLoadedObsession()
  elseif empty(v:this_session) && $OBSESSION_AUTO !=# '0'   " plain startup; non-Obsession sessions are left alone
    call s:TrackObsession(s:SessionPath(''), 0)
  endif
endfunction

function! s:SafePluginStartup() abort
  if s:IsViewer() | return | endif
  silent! GitGutterAll
  silent! GitGutterLineHighlightsEnable
endfunction

"" Autocommands (VimEnter order matters: equalize, session, plugin UI, GitGutter/diff sync)
augroup ResizeSplits
  autocmd!
  autocmd VimEnter,BufNew,BufAdd,BufDelete,WinNew,WinClosed,VimResized * wincmd =
augroup END
augroup SafePluginStartup
  autocmd!
  autocmd VimEnter * call s:MaybeStartObsession()
  autocmd VimEnter * call s:SafePluginStartup()
  autocmd VimEnter * if !empty($VIM_SCROLLBACK) | call s:ScrollbackViewer() | endif
  autocmd VimEnter * if !empty($VIM_ANSI) && exists('*s:AnsiViewer') | call s:AnsiViewer() | endif
  autocmd VimResized * if !empty($VIM_ANSI) && exists('*s:AnsiRerender') | call s:AnsiRerender() | endif
augroup END
" Obsession saves on VimLeavePre, so the lock is released afterwards.
augroup ObsessionLock
  autocmd!
  autocmd VimLeave * call s:ReleaseCurrentLock()
augroup END
augroup GitGutterDiffMode
  autocmd!
  autocmd OptionSet diff call SyncAllGitGutterDiffWindows()
  autocmd VimEnter,WinEnter,BufEnter,WinNew * call SyncAllGitGutterDiffWindows()
augroup END
augroup AirlineGitFileState
  autocmd!
  autocmd BufEnter,BufWritePost,FocusGained * call RefreshAirlineGitFileState()
augroup END

