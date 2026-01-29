" Theme
colorscheme lain
highlight Normal ctermfg=White guifg=#ffffff guibg=NONE
set listchars=tab:·\ ,trail:·,nbsp:␣
set laststatus=2
set statusline=%#StatusLine#\ %f\ %m%r%=%{fnamemodify(getcwd(),':t')}\ %L\ %l:%c\ 

" General
set path=.,**
set wildignore+=*.exe,*.dll,*.pdb,*.class,*.o,*.d
set wildignore+=*/.git/*,*/node_modules/*,*/dist/*,*/build/*,*/target/*
set wildignorecase
set splitbelow splitright
set shortmess+=FI
set hidden lazyredraw
set backspace=indent,eol,start
set tabstop=4 shiftwidth=4 expandtab
set smartcase
set clipboard=unnamedplus
filetype plugin indent on

" Tree
let g:netrw_banner = 0
let g:netrw_keepdir = 0
let g:netrw_winsize = 17
let g:netrw_liststyle = 3
let g:netrw_localcopydircmd = 'cp -r'

" Keymaps
let mapleader=" "
nnoremap <leader>f          :find<Space>
nnoremap <silent> <leader>q :copen<CR>
nnoremap <silent> <leader>n :cnext<CR>
nnoremap <silent> <leader>p :cprev<CR>
nnoremap <silent> <leader>e :Lexplore<CR>
nnoremap <silent> <Tab>     :bnext<CR>
nnoremap <silent> <S-Tab>   :bprevious<CR>
