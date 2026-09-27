""" Timmseh's Incredible VIMRC """

"" List of Used Plugins and the commands to clone them and populate their helptags
" git clone https://github.com/preservim/nerdtree.git ~/.vim/pack/plugins/start/nerdtree
" vim -u NONE -c "helptags ~/.vim/pack/plugins/start/nerdtree/doc" -c q
" git clone https://github.com/tpope/vim-obsession.git  ~/.vim/pack/plugins/start/obsession
" vim -u NONE -c "helptags ~/.vim/pack/plugins/start/obsession/doc" -c q
" git clone https://github.com/vim-airline/vim-airline.git  ~/.vim/pack/plugins/start/airline
" vim -u NONE -c "helptags ~/.vim/pack/plugins/start/airline/doc" -c q
" git clone https://github.com/vim-airline/vim-airline-themes.git  ~/.vim/pack/plugins/start/airline-themes
" vim -u NONE -c "helptags ~/.vim/pack/plugins/start/airline-themes/doc" -c q
" git clone https://github.com/ctrlpvim/ctrlp.vim.git  ~/.vim/pack/plugins/start/ctrlp
" vim -u NONE -c "helptags ~/.vim/pack/plugins/start/ctrlp/doc" -c q
" git clone https://github.com/tpope/vim-fugitive.git  ~/.vim/pack/plugins/start/fugitive
" vim -u NONE -c "helptags ~/.vim/pack/plugins/start/fugitive/doc" -c q
" git clone https://github.com/airblade/vim-gitgutter.git  ~/.vim/pack/plugins/start/gitgutter
" vim -u NONE -c "helptags ~/.vim/pack/plugins/start/gitgutter/doc" -c q

"" A couple of VIM things
let mapleader = '.'
set nocompatible
set hidden
set wildmode=list:longest
set wildmenu
set clipboard=unnamedplus
"set clipboard=
vnoremap <Leader>y "+y
nnoremap <Leader>p "+p
set belloff=all
" Sessions should restore workspace state, not override global vimrc settings.
set sessionoptions-=options
set sessionoptions+=localoptions

"" Editor Configuration
set number
set smarttab
set shiftwidth=4
set tabstop=4
set expandtab
set softtabstop=4
set nowrap
set autoindent
set copyindent
set ruler
set mouse=a
set mousemodel=extend
set showcmd
set backspace=indent,eol,start
set splitright
set splitbelow
set nofoldenable
syntax on
colorscheme industry

"" Search functionality modifications
set incsearch
set hlsearch
set showmatch
set showmode
set ignorecase
set smartcase
noremap <silent> <Space> :silent noh<Bar>echo<CR>
cnoreabbrev ev :e ~/.vimrc
cnoreabbrev ea :e ~/.aliases

"" Maps colon to semi-colon and switches 'j' and 'k' for navigation purposes
noremap ; :
noremap : ;
noremap j k
noremap k j

"" Maps 'jj' to Escape for exiting text in Insert mode
inoremap jj <Esc>

"" Working with buffers (based on mapleader set above, in my case '.')
nnoremap <Leader>b :buffers<CR>:buffer<Space>
nnoremap <Leader>f :bnext<CR>
nnoremap <Leader>a :bprev<CR>
nnoremap <Leader>q :bfirst<CR>
nnoremap <Leader>z :blast<CR>
nnoremap <Leader>r :b#<CR>
nnoremap <Leader>va :vertical ball<CR>
nnoremap <Leader>v :vertical sbuffer<Space>
nnoremap <Leader>sa :ball<CR>
nnoremap <Leader>s :sbuffer<Space>
cnoremap bd :bprevious <bar> bdelete #

"" Additional navigation changes
noremap K G
noremap J gg
noremap L $
noremap H 0
noremap <Esc>k )
noremap <Esc>j (
noremap <Esc>l w
noremap <Esc>h b

"" Bindings for moving the cursor within a VIM window without shifting context (T for top of window, B for bottom of window, G for middle of window)
noremap T H
noremap G M
noremap B L

"" Move cursor to the middle of the current line (horizontally)
noremap M :call cursor(0, virtcol('$')/2)<CR>

"" Maps multiple VIM windows controls to CTRL+direction using:
" h=left, j=up, k=down, l=right

" Moving cursor to windows:
noremap <C-h> <C-w>h
noremap <C-j> <C-w>k
noremap <C-k> <C-w>j
noremap <C-l> <C-w>l
noremap <C-c> <C-w>c
noremap <C-r> <C-w>p
noremap <C-[> <C-w>t
noremap <C-]> <C-w>b

" Changes if Vim is opening man
if !empty($VIM_MANPAGER)
    set nonumber
    set norelativenumber
    set noshowmode
endif

" Resize splits
noremap <Leader>, <C-w><
noremap <Leader>. <C-w>>

" Set all splits equal again
noremap <C-\> <C-w>=

" Split file under cursor into either horizontal or vertical split
noremap sf <C-w>f
noremap vf <C-w>f \| <C-w>L

"" Changes default print behavior to printing before the current character
noremap p P
noremap P p

"" Maps '//' to search whatever text is highlighted in visual mode
vnoremap // y/\V<C-r>"<CR>

"" Increase default history and undo levels
set history=1000
set undolevels=1000

"" Add simple status line showing mode, filename, position (Note: This is likely unnecessary now that I'm using Airline)
set laststatus=2

set statusline=%f\ \|\ CursorLoc:{%l,%c\ %p%%}

" Statusline setup
set statusline=
set statusline +=%1*\ %n\ %*            "buffer number
set statusline +=%5*%{&ff}%*            "file format
set statusline +=%3*%y%*                "file type
set statusline +=%4*\ %<%F%*            "full path
set statusline +=%2*%m%*                "modified flag
set statusline +=%1*%=%5l%*             "current line
set statusline +=%2*/%L%*               "total lines
set statusline +=%1*%4v\ %*             "virtual column number
set statusline +=%2*0x%04B\ %*          "character under cursor

" Statusline Colors (cterm)
hi User1 ctermfg=214 ctermbg=236
hi User2 ctermfg=160 ctermbg=236
hi User3 ctermfg=201 ctermbg=236
hi User4 ctermfg=148 ctermbg=236
hi User5 ctermfg=226 ctermbg=236


"" VIM Aliases
" Show name of current file in bottom bar temporarily
cnoreabbrev name :echo expand('%:p') " Type ':name' in VIM command line list file name
" Copy current filename
cnoreabbrev cf :let @+=expand("%:p")
cnoreabbrev ws w !sudo tee %
cnoreabbrev so :setlocal syntax=off 

function! s:EqualizeSplits() abort
  wincmd =
endfunction
command! WindowResize call s:EqualizeSplits()

" Map equalizing size of all open buffers (NERDTree excluded)
noremap <Leader>wr :WindowResize<CR>

" Modifications to quitting files to handle NERDTree smoothly
cnoreabbrev a :qa
cnoreabbrev aa :qa!
cnoreabbrev wa :w<CR>:qa

" Extra mappings for undo/redo
nnoremap - u
nnoremap = <C-r>

"" GVIM Settings
if has("gui_running")
    set guioptions-=m
    " set guifont=Monospace\ 12.5
    set guifont=Monospace\ 15

    " Statusline Colors
    hi User1 guifg=#eea040 guibg=#333333
    hi User2 guifg=#dd3333 guibg=#333333
    hi User3 guifg=#ff66ff guibg=#333333
    hi User4 guifg=#a0ee40 guibg=#333333
    hi User5 guifg=#eeee40 guibg=#333333

    " Custom diff colors for GVim
    highlight DiffAdd    gui=BOLD guifg=NONE    guibg=#005f00
    highlight DiffDelete gui=BOLD guifg=NONE    guibg=#5f0000
    highlight DiffChange gui=BOLD guifg=NONE    guibg=#005f5f
    highlight DiffText   gui=BOLD guifg=#ff00ff guibg=#005f5f
endif

" Change GVim font size without changing the font.
function! SetFontSize(size)
    if &guifont =~# ':h\d\+$'
        let &guifont = substitute(&guifont, ':h\d\+$', ':h' . a:size, '')
    elseif &guifont =~# ' \d\+$'
        let &guifont = substitute(&guifont, ' \d\+$', ' ' . a:size, '')
    else
        echoerr 'Could not determine font size from guifont: ' . &guifont
    endif
endfunction

command! -nargs=1 FS call SetFontSize(<args>)

" Convenient lowercase aliases.
cnoreabbrev <expr> fs
    \ getcmdtype() ==# ':' && getcmdline() ==# 'fs'
    \ ? 'FS'
    \ : 'fs'

cnoreabbrev <expr> size
    \ getcmdtype() ==# ':' && getcmdline() ==# 'size'
    \ ? 'set guifont?'
    \ : 'size'

"" VIM diff settings
set diffopt+=vertical,iwhite,foldcolumn:0,algorithm:histogram,indent-heuristic

" Diff shortcuts
noremap <Leader>dt :diffthis
noremap <Leader>do :diffoff
noremap <Leader>du :diffupdate
noremap <Leader>ds :diffsplit<Space>
noremap <Leader>df ]c
noremap <Leader>da [c
noremap [1 :diffget 1<CR>
noremap [2 :diffget 2<CR>
noremap [3 :diffget 3<CR>
noremap [4 :diffget 4<CR>
noremap [5 :diffget 5<CR>
noremap ]1 :diffput 1<CR>
noremap ]2 :diffput 2<CR>
noremap ]3 :diffput 3<CR>
noremap ]4 :diffput 4<CR>
noremap ]5 :diffput 5<CR>

" Folding shortcuts
noremap zx zM
noremap zz zR

" Custom diff colors
highlight DiffAdd    cterm=BOLD ctermfg=NONE ctermbg=22
highlight DiffDelete cterm=BOLD ctermfg=NONE ctermbg=52
highlight DiffChange cterm=BOLD ctermfg=NONE ctermbg=23
highlight DiffText   cterm=BOLD ctermfg=13 ctermbg=23

" QuickFix settings
function! ToggleQuickfix()
  for win in getwininfo()
    if win.quickfix
      cclose
      return
    endif
  endfor

  " Open the quickfix window without moving focus into it.
  let l:curwin = win_getid()
  execute "copen | resize " . (&lines / 4)
  call win_gotoid(l:curwin)
endfunction

nnoremap <silent> <Leader>c :call ToggleQuickfix()<CR>
noremap <Leader>k :cnext<CR>
noremap <Leader>j :cprev<CR>

function! SearchToQuickfix()
  let l:pattern = getreg('/')

  if empty(l:pattern)
    echo "No search pattern"
    return
  endif

  " Clear the previous quickfix list.
  call setqflist([], 'r')

  try
    " g = include every match on a line
    " j = do not jump to the first match
    execute 'silent vimgrep /' . escape(l:pattern, '/\') . '/gj %'
  catch /^Vim\%((\a\+)\)\=:E480/
    echo "No matches found for: " . l:pattern
    return
  endtry

  " Open the quickfix window without moving focus into it.
  let l:current_window = win_getid()
  execute "copen | resize " . (&lines / 4)
  call win_gotoid(l:current_window)
endfunction

nnoremap <silent> <Leader>/ :call SearchToQuickfix()<CR>

"""" Plugin Configuration

"" NERDTree Configuration
let g:NERDTreeWinSize = 30

" True if any window in the current tab is a NERDTree window
function! s:NERDTreeIsOpen() abort
  for w in range(1, winnr('$'))
    if getwinvar(w, '&filetype') ==# 'nerdtree'
      return 1
    endif
  endfor
  return 0
endfunction

function! s:NERDTreeWinNr() abort
  for w in range(1, winnr('$'))
    if getwinvar(w, '&filetype') ==# 'nerdtree'
      return w
    endif
  endfor
  return -1
endfunction

function! NERDTreeResize() abort
  let l:nerdtree_win = s:NERDTreeWinNr()
  if l:nerdtree_win == -1
    return
  endif

  let l:curwin = winnr()

  " Move to NERDTree, resize that window, then move back
  execute l:nerdtree_win . 'wincmd w'
  execute 'vertical resize ' . g:NERDTreeWinSize
  execute l:curwin . 'wincmd w'

  call s:EqualizeSplits()
endfunction

command! NERDTreeResize call NERDTreeResize()

" NERDTree shortcut mapping
nnoremap <C-n> :NERDTreeFocus<CR>
nnoremap <Leader>nf :NERDTreeFind<CR>
nnoremap <Leader>nt :NERDTreeToggle<CR>
nnoremap <Leader>nr :NERDTreeResize<CR>

"" Airline Configuration
" Airline Options
let g:airline_inactive_collapse=0

" Set up Airline Theme
let g:airline_theme='solarized_flood'

" Custom Airline Theme color patching
let g:airline_theme_patch_func = 'AirlineThemePatch'

function! AirlineThemePatch(palette)
  if g:airline_theme ==# 'solarized_flood'
    for mode in ['normal','insert','replace','visual','commandline','terminal']
      if has_key(a:palette, mode)
        " Remove italics from A / B / C / Z
        let a:palette[mode].airline_a[4] = ''
        let a:palette[mode].airline_b[4] = ''
        let a:palette[mode].airline_c[4] = ''
        let a:palette[mode].airline_z[4] = ''

        " Only change backgrounds for b/c/x/y to match inactive theme:
        " B + Y -> ctermbg=235, guibg=#262626
        let a:palette[mode].airline_b[1] = '#262626'
        let a:palette[mode].airline_b[3] = 235
        let a:palette[mode].airline_y[1] = '#262626'
        let a:palette[mode].airline_y[3] = 235

        " C + X -> ctermbg=236, guibg=#303030 let a:palette[mode].airline_c[1] = '#303030' let a:palette[mode].airline_c[3] = 236
        let a:palette[mode].airline_x[1] = '#303030'
        let a:palette[mode].airline_x[3] = 236
      endif
    endfor

    " Change text color in C / X to green in INSERT mode
    if has_key(a:palette, 'insert')
        let a:palette.insert.airline_c[0] = '#859900'
        let a:palette.insert.airline_c[2] = 106

        let a:palette.insert.airline_x[0] = '#859900'
        let a:palette.insert.airline_x[2] = 106
    endif
  endif
endfunction

" Set up custom Airline symbols
if !exists('g:airline_symbols')
  let g:airline_symbols = {}
endif

"let g:airline_symbols_ascii = 1
let g:airline_powerline_fonts = 1
let g:airline_symbols.linenr = ' Line:'
let g:airline_symbols.colnr = ' Col:'
let g:airline_symbols.maxlinenr = ''

let g:airline#extensions#default#layout = [
    \ [ 'a', 'b', 'c' ],
    \ [ 'x', 'y', 'z' ]
    \ ]

" Create custom Obsession status bar to be plugged into Airline
function! CustomObsessionStatus()
    let session = filereadable(v:this_session)
    if exists('g:this_obsession') && session
        let session_name = fnamemodify(g:this_obsession, ':t')
        return printf('[Live: %s]', session_name)
    elseif session
        let session_name = fnamemodify(g:this_session, ':t')
        return printf('[Paused: %s]', session_name)
    else
        return '[No Session]'
    endif
endfunction

" Custom Airline section creation
let g:airline_section_y = airline#section#create(['%{CustomObsessionStatus()}'])

" Disable Airline/Obsession integration since I'm using a customized solution above
let g:airline#extensions#obsession#enabled = 0

"" GitGutter Configuration
noremap <Leader>gta :GitGutterToggle<CR>
noremap <Leader>gt :GitGutterBufferToggle<CR>
noremap <Leader>gth :GitGutterLineHighlightsToggle<CR>
noremap <Leader>gd :GitGutterDiffOrig<CR>
noremap <Leader>gq :GitGutterQuickFix<CR>
noremap <Leader>hd <Plug>(GitGutterPreviewHunk)
noremap <Leader>hs <Plug>(GitGutterStageHunk)
noremap <Leader>hu <Plug>(GitGutterUndoHunk)
noremap <Leader>hf <Plug>(GitGutterNextHunk)
noremap <Leader>ha <Plug>(GitGutterPrevHunk)
set updatetime=100
set foldtext=gitgutter#fold#foldtext()
let g:gitgutter_async = 1
let g:gitgutter_max_signs = -1
let g:gitgutter_diff_base = 'origin/main'
let g:gitgutter_preview_win_location = 'bel'

" Automatically disable GitGutter while a buffer is in Vim diff mode.
function! SyncGitGutterWithDiff() abort
    if exists(':GitGutterBufferDisable') != 2
        return
    endif

    if &diff
        " Only remember disables performed automatically by this function.
        if !get(b:, 'gitgutter_disabled_for_diff', 0)
            silent! GitGutterBufferDisable
            let b:gitgutter_disabled_for_diff = 1
        endif
    elseif get(b:, 'gitgutter_disabled_for_diff', 0)
        silent! GitGutterBufferEnable
        unlet b:gitgutter_disabled_for_diff
    endif
endfunction

" Synchronize GitGutter for every visible Vim window.
function! SyncAllGitGutterDiffWindows() abort
    for l:win in getwininfo()
        call win_execute(l:win.winid, 'call SyncGitGutterWithDiff()')
    endfor
endfunction

"" Obsession Configuration

" ============================================================================
" Session locations
" ============================================================================

" All sessions are centralized here.
"
" Default/path-based sessions:
"   ~/obsessions/by-path/<launch-directory>/Session.vim
"
" Explicitly named sessions:
"   ~/obsessions/named/<name>.vim
let g:obsession_root = expand(
    \ empty($OBSESSION_ROOT)
    \ ? '~/obsessions'
    \ : $OBSESSION_ROOT
    \ )


" Normalize a directory the same way the shell does with `pwd -P`.
function! s:NormalizeObsessionDir(path) abort
    let l:path = resolve(fnamemodify(a:path, ':p'))
    let l:path = substitute(l:path, '/\+$', '', '')

    return empty(l:path) ? '/' : l:path
endfunction


" Capture where this Vim instance was launched.
"
" This deliberately never changes, even if :cd is used later.
let g:obsession_start_dir = s:NormalizeObsessionDir(getcwd())


" Turn an absolute path into a path that can live below by-path/.
"
" /home/caleb/project
" becomes:
" home/caleb/project
function! s:ObsessionPathKey(path) abort
    let l:key = substitute(a:path, '^/\+', '', '')

    return empty(l:key) ? '__root__' : l:key
endfunction


" Return this launch directory's default session.
function! s:DefaultObsessionPath() abort
    return g:obsession_root
        \ . '/by-path/'
        \ . s:ObsessionPathKey(g:obsession_start_dir)
        \ . '/Session.vim'
endfunction


" Return the centralized path for an explicitly named session.
function! s:NamedObsessionPath(name) abort
    let l:file = fnamemodify(a:name, ':t')

    if l:file !~# '\.vim$'
        let l:file .= '.vim'
    endif

    return g:obsession_root . '/named/' . l:file
endfunction


" ============================================================================
" Session locking
" ============================================================================

" Determine whether a session lock belongs to a running Vim.
"
" Same host:
"   Check whether the recorded PID still exists.
"
" Different host:
"   Conservatively assume the session is still active.
function! s:ObsessionLockIsActive(lock_dir) abort
    if !isdirectory(a:lock_dir)
        return 0
    endif

    let l:owner_file = a:lock_dir . '/owner'

    " Unknown/incomplete locks are treated as active for safety.
    if !filereadable(l:owner_file)
        return 1
    endif

    let l:owner = readfile(l:owner_file)

    if len(l:owner) < 2
        return 1
    endif

    let l:host = l:owner[0]
    let l:pid  = l:owner[1]

    " A different machine may still legitimately own this session.
    if l:host !=# hostname()
        return 1
    endif

    if l:pid !~# '^\d\+$'
        return 1
    endif

    " Same host and PID still exists.
    if isdirectory('/proc/' . l:pid)
        return 1
    endif

    " Same host but dead PID: remove the stale lock.
    call delete(a:lock_dir, 'rf')
    return 0
endfunction


" Atomically claim a session.
"
" Returns the lock directory on success.
" Returns '' when another Vim already owns the session.
function! s:TryClaimObsession(session) abort
    let l:session = fnamemodify(a:session, ':p')
    let l:session_dir = fnamemodify(l:session, ':h')
    let l:lock = l:session . '.lock'

    call mkdir(l:session_dir, 'p')

    if s:ObsessionLockIsActive(l:lock)
        return ''
    endif

    " mkdir is our atomic claim operation.
    try
        let l:created = mkdir(l:lock)
    catch
        return ''
    endtry

    if !l:created
        return ''
    endif

    try
        call writefile(
            \ [
            \   hostname(),
            \   string(getpid()),
            \   g:obsession_start_dir
            \ ],
            \ l:lock . '/owner'
            \ )
    catch
        call delete(l:lock, 'rf')
        return ''
    endtry

    return l:lock
endfunction


" Release a lock only if this Vim actually owns it.
function! s:ReleaseObsessionLockDir(lock_dir) abort
    if empty(a:lock_dir) || !isdirectory(a:lock_dir)
        return
    endif

    let l:owner_file = a:lock_dir . '/owner'

    if !filereadable(l:owner_file)
        return
    endif

    let l:owner = readfile(l:owner_file)

    if len(l:owner) < 2
        return
    endif

    if l:owner[0] ==# hostname()
        \ && l:owner[1] ==# string(getpid())
        call delete(a:lock_dir, 'rf')
    endif
endfunction


function! s:ReleaseCurrentObsessionLock() abort
    let l:lock = get(g:, 'obsession_lock_dir', '')

    call s:ReleaseObsessionLockDir(l:lock)

    unlet! g:obsession_lock_dir
    unlet! g:obsession_lock_session
endfunction


" ============================================================================
" Start / switch Obsession
" ============================================================================

function! s:TrackObsession(session, force) abort
    if exists(':Obsession') != 2
        return 0
    endif

    let l:session = fnamemodify(a:session, ':p')

    " We already own and track this exact session.
    if get(g:, 'obsession_lock_session', '') ==# l:session
        \ && exists('g:this_obsession')
        \ && fnamemodify(g:this_obsession, ':p') ==# l:session
        return 1
    endif

    " Claim the new session before telling Obsession to use it.
    let l:new_lock = s:TryClaimObsession(l:session)

    if empty(l:new_lock)
        echohl WarningMsg
        echom 'Obsession already active: ' . l:session
        echohl None
        return 0
    endif

    let l:old_lock = get(g:, 'obsession_lock_dir', '')

    try
        if a:force
            execute 'silent Obsession! ' . fnameescape(l:session)
        else
            execute 'silent Obsession ' . fnameescape(l:session)
        endif
    catch
        call s:ReleaseObsessionLockDir(l:new_lock)
        echoerr v:exception
        return 0
    endtry

    " Make sure Obsession actually accepted the requested session.
    if !exists('g:this_obsession')
        \ || fnamemodify(g:this_obsession, ':p') !=# l:session
        call s:ReleaseObsessionLockDir(l:new_lock)

        echohl WarningMsg
        echom 'Could not start Obsession: ' . l:session
        echohl None
        return 0
    endif

    let g:obsession_lock_dir = l:new_lock
    let g:obsession_lock_session = l:session

    " We successfully switched sessions, so the old lock can go.
    if !empty(l:old_lock) && l:old_lock !=# l:new_lock
        call s:ReleaseObsessionLockDir(l:old_lock)
    endif

    return 1
endfunction


" ============================================================================
" Restore an existing session
" ============================================================================

function! s:LoadObsession(session) abort
    let l:session = fnamemodify(a:session, ':p')

    if !filereadable(l:session)
        echohl WarningMsg
        echom 'No saved session: ' . l:session
        echohl None
        return 0
    endif

    " The important part: lock BEFORE loading the session.
    let l:lock = s:TryClaimObsession(l:session)

    if empty(l:lock)
        echohl WarningMsg
        echom 'Session already active: ' . l:session
        echohl None
        return 0
    endif

    let l:old_session = v:this_session

    try
        " Make :source behave like loading through -S.
        "
        " Obsession-generated sessions restore g:this_obsession from
        " v:this_session, so this must be set before sourcing.
        let v:this_session = l:session

        execute 'silent source ' . fnameescape(l:session)
        
        let v:this_session = l:session
        
        " Sessions are restored during VimEnter, after normal syntax startup.
        " Re-run the existing FileType -> Syntax hookup for all restored buffers
        " without reloading the colorscheme.
        doautoall syntaxset FileType

        " If this was not originally an Obsession-generated session,
        " start tracking it now.
        if !exists('g:this_obsession')
            \ || fnamemodify(g:this_obsession, ':p') !=# l:session
            execute 'silent Obsession ' . fnameescape(l:session)
        endif

    catch
        " Pause this session if loading got far enough to activate Obsession.
        if exists('g:this_obsession')
            \ && fnamemodify(g:this_obsession, ':p') ==# l:session
            silent! Obsession
        endif

        let v:this_session = l:old_session
        call s:ReleaseObsessionLockDir(l:lock)

        echoerr v:exception
        return 0
    endtry

    let g:obsession_lock_dir = l:lock
    let g:obsession_lock_session = l:session

    return 1
endfunction


" ============================================================================
" Protect sessions loaded manually with vim -S / gvim -S
" ============================================================================

function! s:ClaimLoadedObsession() abort
    if !exists('g:this_obsession') || empty(g:this_obsession)
        return 1
    endif

    let l:session = fnamemodify(g:this_obsession, ':p')
    let l:lock = s:TryClaimObsession(l:session)

    if empty(l:lock)
        " The session was already sourced, but don't let this Vim keep
        " writing to a session owned by another Vim.
        silent! Obsession

        echohl WarningMsg
        echom 'Session already active; Obsession paused: ' . l:session
        echohl None
        return 0
    endif

    let g:obsession_lock_dir = l:lock
    let g:obsession_lock_session = l:session

    return 1
endfunction


" ============================================================================
" :ob / :od commands
" ============================================================================

" :ob
"     Track the default Session.vim belonging to the directory Vim
"     was originally launched from.
"
" :ob NAME
"     Track ~/obsessions/named/NAME.vim.
function! s:ObWrapper(force, name) abort
    if empty(a:name)
        call s:TrackObsession(
            \ s:DefaultObsessionPath(),
            \ a:force
            \ )
    else
        call s:TrackObsession(
            \ s:NamedObsessionPath(a:name),
            \ a:force
            \ )
    endif
endfunction

command! -bang -nargs=? Ob call s:ObWrapper(<bang>0, <q-args>)


" Pause Obsession and release this Vim's lock.
"
" Unlike :Obsession!, this does NOT delete the saved session.
function! s:PauseObsession() abort
    if exists('g:this_obsession')
        silent! Obsession
    endif

    call s:ReleaseCurrentObsessionLock()
endfunction

command! ObPause call s:PauseObsession()


" Show exactly where bare :ob / vl / gl maps for this launch directory.
command! ObPath echo s:DefaultObsessionPath()


" Convenient lowercase aliases.
cnoreabbrev <expr> ob
    \ getcmdtype() ==# ':' && getcmdline() ==# 'ob'
    \ ? 'Ob'
    \ : 'ob'

cnoreabbrev <expr> od
    \ getcmdtype() ==# ':' && getcmdline() ==# 'od'
    \ ? 'ObPause'
    \ : 'od'

"" Ctrl-P Congiguration
let g:ctrlp_map = '<C-f>'
let g:ctrlp_show_hidden = 1
let g:ctrlp_prompt_mappings = {
  \ 'PrtSelectMove("j")': ['<c-k>', '<down>'],
  \ 'PrtSelectMove("k")': ['<c-j>', '<up>'],
  \ 'ToggleType(1)':      ['<c-up>'],
  \ 'PrtExit()':          ['<esc>', '<c-f>'],
  \ }


" Resize all open buffers to be equally split (accounts for NERDTree opening and taking space on the left-most side of the screen)
augroup ResizeSplits
  autocmd!
  autocmd VimEnter,BufNew,BufAdd,BufDelete,WinNew,WinClosed,VimResized * call s:EqualizeSplits()
augroup END

""" Autocommand Configuration

function! s:MaybeStartObsession() abort
    " Temporary viewer instances should never participate in Obsession.
    if !empty($KITTY_SCROLLBACK) || !empty($VIM_MANPAGER)
        return
    endif

    if exists(':Obsession') != 2
        return
    endif

    " vl/gl use this variable instead of -S so we can acquire the
    " session lock BEFORE sourcing the session.
    if !empty($OBSESSION_LOAD_SESSION)
        let l:session = $OBSESSION_LOAD_SESSION

        " Don't let shells/programs launched from Vim inherit this request.
        let $OBSESSION_LOAD_SESSION = ''

        call s:LoadObsession(l:session)
        return
    endif

    " Handle an Obsession session that was loaded manually with -S.
    if exists('g:this_obsession') && !empty(g:this_obsession)
        call s:ClaimLoadedObsession()
        return
    endif

    " Some unrelated/non-Obsession Vim session was loaded.
    if !empty(v:this_session)
        return
    endif

    " Normal Vim/GVim startup:
    " begin tracking this launch directory's default Session.vim.
    call s:TrackObsession(s:DefaultObsessionPath(), 0)
endfunction

function! s:SafePluginStartup() abort
    " Don't run workspace-oriented startup behavior for temporary viewers.
    if !empty($KITTY_SCROLLBACK) || !empty($VIM_MANPAGER)
        return
    endif

    if exists(':GitGutterAll') == 2
        silent! GitGutterAll
    endif

    if exists(':GitGutterLineHighlightsEnable') == 2
        silent! GitGutterLineHighlightsEnable
    endif

    if exists(':NERDTree') == 2
        try
            silent NERDTree
            silent! wincmd p
        catch
            " Ignore inaccessible directories and other NERDTree startup errors.
        endtry
    endif
endfunction

augroup SafePluginStartup
  autocmd!
  autocmd VimEnter * call s:MaybeStartObsession()
  autocmd VimEnter * call s:SafePluginStartup()
augroup END

" Obsession performs its final save during VimLeavePre.
" Release our lock afterward.
augroup ObsessionLock
    autocmd!
    autocmd VimLeave * call s:ReleaseCurrentObsessionLock()
augroup END

augroup GitGutterDiffMode
    autocmd!
    autocmd OptionSet diff call SyncAllGitGutterDiffWindows()
    autocmd WinEnter,BufEnter,WinNew * call SyncAllGitGutterDiffWindows()
    autocmd VimEnter * call SyncAllGitGutterDiffWindows()
augroup END
