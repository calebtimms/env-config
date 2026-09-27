""" Timmseh's Incredible VIMRC """
" Plugins: git clone https://github.com/<repo> ~/.vim/pack/plugins/start/<dir>
"          vim -u NONE -c 'helptags ~/.vim/pack/plugins/start/<dir>/doc' -c q
"   nerdtree        preservim/nerdtree                obsession   tpope/vim-obsession
"   airline         vim-airline/vim-airline           fugitive    tpope/vim-fugitive
"   airline-themes  vim-airline/vim-airline-themes    gitgutter   airblade/vim-gitgutter
"   ctrlp           ctrlpvim/ctrlp.vim

set nocompatible
let mapleader = '.'

"" Options
set hidden belloff=all mouse=a mousemodel=extend clipboard=unnamedplus
set number ruler showcmd showmode nowrap nofoldenable splitright splitbelow
set expandtab smarttab tabstop=4 softtabstop=4 shiftwidth=4 autoindent copyindent backspace=indent,eol,start
set incsearch hlsearch showmatch ignorecase smartcase wildmenu wildmode=list:longest
set history=1000 undolevels=1000
set sessionoptions-=options sessionoptions+=localoptions   " sessions restore the workspace, not vimrc settings
if !empty($VIM_MANPAGER) | set nonumber norelativenumber noshowmode | endif

"" Appearance (custom highlights are reapplied whenever a colorscheme loads)
function! s:Highlights() abort
  hi User1 ctermfg=214 ctermbg=236 guifg=#eea040 guibg=#333333
  hi User2 ctermfg=160 ctermbg=236 guifg=#dd3333 guibg=#333333
  hi User3 ctermfg=201 ctermbg=236 guifg=#ff66ff guibg=#333333
  hi User4 ctermfg=148 ctermbg=236 guifg=#a0ee40 guibg=#333333
  hi User5 ctermfg=226 ctermbg=236 guifg=#eeee40 guibg=#333333
  hi DiffAdd    cterm=bold ctermfg=NONE ctermbg=22 gui=bold guifg=NONE    guibg=#005f00
  hi DiffDelete cterm=bold ctermfg=NONE ctermbg=52 gui=bold guifg=NONE    guibg=#5f0000
  hi DiffChange cterm=bold ctermfg=NONE ctermbg=23 gui=bold guifg=NONE    guibg=#005f5f
  hi DiffText   cterm=bold ctermfg=13   ctermbg=23 gui=bold guifg=#ff00ff guibg=#005f5f
endfunction
augroup CustomHighlights
  autocmd!
  autocmd ColorScheme * call s:Highlights()
augroup END
syntax on
colorscheme industry
if has('gui_running') | set guioptions-=m guifont=Monospace\ 15 | endif

" Fallback statusline (Airline replaces it):
"   buffer │ fileformat │ filetype │ full path │ modified ══ line / total │ virtual column │ char code
set laststatus=2
let &statusline = '%1* %n %*%5*%{&ff}%*%3*%y%*%4* %<%F%*%2*%m%*%1*%=%5l%*%2*/%L%*%1*%4v %*%2*0x%04B %*'

" :FS <size> (or :fs) sets the GUI font size and keeps the face; :size shows the font.
function! SetFontSize(size)
  let l:pat = &guifont =~# ':h\d\+$' ? ':h\zs\d\+$' : ' \zs\d\+$'
  if &guifont =~# l:pat
    let &guifont = substitute(&guifont, l:pat, a:size, '')
  else
    echoerr 'Could not determine font size from guifont: ' . &guifont
  endif
endfunction
command! -nargs=1 FS call SetFontSize(<args>)

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
noremap <silent> <Space> :silent noh<Bar>echo<CR>
vnoremap <Leader>y "+y
nnoremap <Leader>p "+p
vnoremap // y/\V<C-r>=escape(@", '/\')<CR><CR>

"" Movement: J/K file top/bottom, H/L line start/end, Alt+j/k sentence, Alt+h/l word,
""           T/G/B window top/middle/bottom, M middle of the line
noremap K G
noremap J gg
noremap L $
noremap H 0
noremap <Esc>k )
noremap <Esc>j (
noremap <Esc>l w
noremap <Esc>h b
noremap T H
noremap G M
noremap B L
noremap M :call cursor(0, virtcol('$')/2)<CR>

"" Windows: Ctrl+h/j/k/l move (j = up), Ctrl+c close, Ctrl+r previous, Ctrl+[ / Ctrl+] top / bottom,
""          Ctrl+\ or .wr equalize, ., / .. narrower / wider, sf / vf open file under cursor in a split
noremap <C-h> <C-w>h
noremap <C-j> <C-w>k
noremap <C-k> <C-w>j
noremap <C-l> <C-w>l
noremap <C-c> <C-w>c
noremap <C-r> <C-w>p
noremap <C-[> <C-w>t
noremap <C-]> <C-w>b
noremap <C-\> <C-w>=
noremap <Leader>, <C-w><
noremap <Leader>. <C-w>>
noremap sf <C-w>f
noremap vf <C-w>f<C-w>L
command! WindowResize wincmd =
noremap <Leader>wr :WindowResize<CR>

"" Buffers
nnoremap <Leader>b :buffers<CR>:buffer<Space>
nnoremap <Leader>f :bnext<CR>
nnoremap <Leader>a :bprev<CR>
nnoremap <Leader>q :bfirst<CR>
nnoremap <Leader>z :blast<CR>
nnoremap <Leader>r :b#<CR>
nnoremap <Leader>v :vertical sbuffer<Space>
nnoremap <Leader>va :vertical ball<CR>
nnoremap <Leader>s :sbuffer<Space>
nnoremap <Leader>sa :ball<CR>

"" Diff & folds: .dt/.do/.du/.ds this/off/update/split, .df/.da next/prev change,
""               [N / ]N get from / put to buffer N, zx / zz close / open all folds
set diffopt+=vertical,iwhite,foldcolumn:0,algorithm:histogram,indent-heuristic
noremap <Leader>dt :diffthis
noremap <Leader>do :diffoff
noremap <Leader>du :diffupdate
noremap <Leader>ds :diffsplit<Space>
noremap <Leader>df ]c
noremap <Leader>da [c
for s:n in range(1, 5)
  execute printf('noremap [%d :diffget %d<CR>', s:n, s:n)
  execute printf('noremap ]%d :diffput %d<CR>', s:n, s:n)
endfor
unlet s:n
noremap zx zM
noremap zz zR

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
noremap <Leader>k :cnext<CR>
noremap <Leader>j :cprev<CR>

"" Command-line shorthands. Each expands only when it is the entire ':' command, never inside
"" searches, file names or other commands. CTRL-\ e rewrites the line; <expr> abbreviations
"" can't be used because one-letter ones never fire on <CR>.
function! s:Shorthand(lhs, rhs) abort
  return getcmdtype() ==# ':' && getcmdline() ==# a:lhs ? a:rhs : getcmdline()
endfunction
for [s:lhs, s:rhs] in [
      \ ['ev', 'e ~/.vimrc'], ['ea', 'e ~/.aliases'], ['name', "echo expand('%:p')"],
      \ ['cf', 'let @+ = expand("%:p")'], ['ws', 'w !sudo tee %'], ['so', 'setlocal syntax=off'],
      \ ['bd', 'bprevious <Bar> bdelete #'], ['a', 'qa'], ['aa', 'qa!'], ['wa', 'w <Bar> qa'],
      \ ['fs', 'FS'], ['size', 'set guifont?'], ['ob', 'Ob'], ['od', 'ObPause']]
  execute printf('cnoreabbrev %s %s<C-\>e<SID>Shorthand(%s, %s)<CR>', s:lhs, s:lhs, string(s:lhs), string(s:rhs))
endfor
unlet s:lhs s:rhs

"" NERDTree: Ctrl+n focus, .nf find file, .nt toggle, .nr restore width
let g:NERDTreeWinSize = 30
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

"" Airline
let g:airline_theme = 'solarized_flood'
let g:airline_theme_patch_func = 'AirlineThemePatch'
let g:airline_inactive_collapse = 0
let g:airline_powerline_fonts = 1
let g:airline_symbols = extend(get(g:, 'airline_symbols', {}), {'linenr': ' Line:', 'colnr': ' Col:', 'maxlinenr': ''})
let g:airline#extensions#default#layout = [['a', 'b', 'c'], ['x', 'y', 'z']]
let g:airline#extensions#obsession#enabled = 0   " section y shows CustomObsessionStatus() instead

" solarized_flood: no italics in a/b/c/z, b/y and c/x backgrounds match the inactive theme,
" c/x text turns green in insert mode. Palette entries are [guifg, guibg, ctermfg, ctermbg, attr].
function! AirlineThemePatch(palette) abort
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
endfunction

function! CustomObsessionStatus() abort
  if !filereadable(v:this_session) | return '[No Session]' | endif
  return exists('g:this_obsession')
        \ ? '[Live: ' . fnamemodify(g:this_obsession, ':t') . ']'
        \ : '[Paused: ' . fnamemodify(get(g:, 'this_session', v:this_session), ':t') . ']'
endfunction
augroup AirlineObsession
  autocmd!
  autocmd User AirlineAfterInit let g:airline_section_y = airline#section#create(['%{CustomObsessionStatus()}'])
augroup END

"" GitGutter: .gta/.gt toggle all/buffer, .gth line highlights, .gd diff vs base, .gq quickfix,
""            .hd/.hs/.hu preview/stage/undo hunk, .hf/.ha next/prev hunk
set updatetime=100 foldtext=gitgutter#fold#foldtext()
let g:gitgutter_async = 1
let g:gitgutter_max_signs = -1
let g:gitgutter_diff_base = 'origin/main'
let g:gitgutter_preview_win_location = 'bel'
noremap <Leader>gta :GitGutterToggle<CR>
noremap <Leader>gt :GitGutterBufferToggle<CR>
noremap <Leader>gth :GitGutterLineHighlightsToggle<CR>
noremap <Leader>gd :GitGutterDiffOrig<CR>
noremap <Leader>gq :GitGutterQuickFix<CR>
map <Leader>hd <Plug>(GitGutterPreviewHunk)
map <Leader>hs <Plug>(GitGutterStageHunk)
map <Leader>hu <Plug>(GitGutterUndoHunk)
map <Leader>hf <Plug>(GitGutterNextHunk)
map <Leader>ha <Plug>(GitGutterPrevHunk)

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

"" Obsession sessions: one live session per Vim, guarded by a lock directory.
""   :ob [name]  (:Ob[!])  track ~/obsessions/named/<name>.vim, or with no name this launch
""                         directory's ~/obsessions/by-path/<dir>/Session.vim  (! = overwrite)
""   :od  (:ObPause)       stop tracking and release the lock (the session file is kept)
""   :ObPath               show the default session path
"" zsh's vl/gl pass $OBSESSION_LOAD_SESSION instead of -S so the lock is taken before sourcing.
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

command! -bang -nargs=? Ob call s:TrackObsession(s:SessionPath(<q-args>), <bang>0)
command! ObPause if exists('g:this_obsession') | silent! Obsession | endif | call s:ReleaseCurrentLock()
command! ObPath echo s:SessionPath('')

"" Startup
function! s:IsViewer() abort   " man pages and kitty scrollback never touch sessions or plugin UI
  return !empty($KITTY_SCROLLBACK) || !empty($VIM_MANPAGER)
endfunction

function! s:MaybeStartObsession() abort
  if s:IsViewer() || exists(':Obsession') != 2 | return | endif
  if !empty($OBSESSION_LOAD_SESSION)   " vl/gl; don't let child shells inherit the request
    let l:session = $OBSESSION_LOAD_SESSION
    let $OBSESSION_LOAD_SESSION = ''
    call s:LoadObsession(l:session)
  elseif !empty(get(g:, 'this_obsession', ''))
    call s:ClaimLoadedObsession()
  elseif empty(v:this_session)   " plain startup; non-Obsession sessions are left alone
    call s:TrackObsession(s:SessionPath(''), 0)
  endif
endfunction

function! s:SafePluginStartup() abort
  if s:IsViewer() | return | endif
  silent! GitGutterAll
  silent! GitGutterLineHighlightsEnable
  try   " ignore inaccessible directories and other NERDTree startup errors
    silent NERDTree
    silent! wincmd p
  catch
  endtry
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
