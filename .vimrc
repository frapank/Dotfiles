"|--- Design ---|"

" Cursor shape
let &t_SI = "\e[6 q"
let &t_EI = "\e[2 q"

" Syntax colors
syntax on
set background=dark
if has("termguicolors")
    set termguicolors
endif

" Theme
set background=dark
colorscheme habamax
highlight Normal guibg=#000000
highlight LineNr guibg=#000000
highlight StatusLine guifg=#ffffff guibg=#000000
highlight StatusLineNC guifg=#888888 guibg=#000000
highlight TabLine guibg=#000000
highlight TabLineFill guibg=#000000

" Window separator bar
hi LineNr guibg=bg
hi foldcolumn guibg=bg
hi VertSplit guibg=bg guifg=bg

" Highlight trailing whitespace and show listchars
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s+$/
set list
set listchars=tab:▸\ ,trail:·,nbsp:␣

" Status line
set laststatus=2
set statusline=%f\ %y\ %m%r%=%{fnamemodify(getcwd(),':t')}\ \ [%p%%]\ %l:%c


"|- Functional -|"

set path=.,**
set wildmenu
set wildoptions=pum
set wildignore=*.exe,*.dll,*.pdb,*.class
set shortmess+=FI
set updatetime=300
set timeoutlen=500
set ttimeoutlen=10
set hidden
set backspace=indent,eol,start
set tabstop=4
set shiftwidth=4
set expandtab
set smartcase
set clipboard=unnamedplus
set gp=git\ grep\ -n
set mouse=a
set nobackup
set nowritebackup
set noswapfile
set undofile
set undodir=~/.vim/undo//
packadd! termdebug
set autoindent
set smartindent
filetype plugin indent on
set number
set relativenumber
autocmd InsertEnter * set norelativenumber
autocmd InsertLeave * set relativenumber

" Tree
let g:netrw_banner = 0
let g:netrw_keepdir = 0
let g:netrw_winsize = 20
let g:netrw_liststyle = 3
let g:netrw_localcopydircmd = 'cp -r'
hi! link netrwMarkFile Search


" Filetype-specific settings and commands
augroup filetype_specific
    autocmd!
    " C: .c .cpp
    autocmd FileType c,cpp setlocal shiftwidth=4 tabstop=4 expandtab
    " Python: .py
    autocmd FileType python setlocal omnifunc=python3complete#Complete
    autocmd FileType python setlocal makeprg=python3\ %
    " Git: .git
    autocmd FileType gitcommit setlocal spell wrap linebreak
augroup END


"|--- Keymaps ---|"

let mapleader=" "
nnoremap <leader>g  :grep<Space>
nnoremap <leader>f  :find<Space>

nnoremap <leader>q :copen<CR>
nnoremap <leader>n :cnext<CR>
nnoremap <leader>p :cprev<CR>

nnoremap <leader>e  :Lexplore<CR>

nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

nnoremap <leader>b  :ls<CR>
nnoremap <leader>x  :bd<CR>
nnoremap <Tab>      :bnext<CR>
nnoremap <S-Tab>    :bprev<CR>

nnoremap <leader>l :vsplit<CR>
nnoremap <leader>j :split<CR>
nnoremap <leader>k :close<CR>
