" Theme
syntax off
set background=dark
colorscheme wildcharm
set listchars=tab:·\ ,trail:·,nbsp:␣
set cursorline laststatus=2
set statusline=%#StatusLine#\ %f\ %m%r%=%{fnamemodify(getcwd(),':t')}\ %l:%c\  

" General
set path=.,**
set wildignore+=*.exe,*.dll,*.pdb,*.class,*.o,*.d
set wildignore+=*/.git/*,*/node_modules/*,*/dist/*,*/build/*,*/target/*
set wildignorecase
set splitbelow splitright
set shortmess+=FI
set number relativenumber
set mouse=n
set hidden
set backspace=indent,eol,start
set tabstop=4 shiftwidth=4 expandtab
set smartcase
set clipboard=unnamedplus
set undofile undodir=~/.vim/undo/
filetype plugin indent on

" Tree
let g:netrw_banner = 0
let g:netrw_keepdir = 0
let g:netrw_winsize = 17
let g:netrw_liststyle = 3
let g:netrw_localcopydircmd = 'cp -r'

" Keymaps
let mapleader=" "
nnoremap <leader>f :find<Space>
nnoremap <leader>q :copen<CR>
nnoremap <leader>n :cnext<CR>
nnoremap <leader>p :cprev<CR>
nnoremap <leader>e :Lexplore<CR>
nnoremap <Tab>     :bnext<CR>
nnoremap <S-Tab>   :bprev<CR>
