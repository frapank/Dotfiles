vim9script

# =========================
# Theme
# =========================
colorscheme lain
set listchars=tab:·\ ,trail:·,nbsp:␣
set laststatus=2
g:cwd_tail = fnamemodify(getcwd(), ':t')
autocmd DirChanged * let g:cwd_tail = fnamemodify(getcwd(), ':t')
set statusline=%#StatusLine#\ %f\ %m%r%=%{g:cwd_tail}\ %L\ %l:%c\ 

# =========================
# General Settings
# =========================
set path=.,**
set wildignore+=*.exe,*.dll,*.pdb,*.class,*.o,*.d
set wildignore+=*/.git/*,*/node_modules/*,*/dist/*,*/build/*,*/target/*
set wildignorecase
set splitbelow splitright
set shortmess+=IcC
set ttimeout ttimeoutlen=25
set updatetime=300 redrawtime=1500
set hidden confirm lazyredraw
set backspace=indent,eol,start
set tabstop=4 shiftwidth=4 expandtab
set autoindent softtabstop=-1
set hlsearch incsearch ignorecase smartcase
set clipboard=unnamedplus
set nowrap
set breakindent breakindentopt=sbr,list:-1
set linebreak
set nojoinspaces
set display=lastline
set smoothscroll
set sidescroll=1 sidescrolloff=3
set fileformat=unix
set fileformats=unix,dos
set nrformats=bin,hex,unsigned
set completeopt=menu,popup
set complete=o^10,.^10,w^5,b^5,u^3,t^3
set virtualedit=block nostartofline
set switchbuf=useopen
filetype plugin indent on

# =========================
# NetRW / Tree Settings
# =========================
g:netrw_banner = 0
g:netrw_keepdir = 0
g:netrw_winsize = 17
g:netrw_liststyle = 3
g:netrw_localcopydircmd = 'cp -r'

# =========================
# Keymaps
# =========================
g:mapleader = ' '
nnoremap <leader>f          :find<Space>
nnoremap <silent> <leader>q :copen<CR>
nnoremap <silent> <leader>n :cnext<CR>
nnoremap <silent> <leader>p :cprev<CR>
nnoremap <silent> <leader>e :Lexplore<CR>
nnoremap <silent> <Tab>     :bnext<CR>
nnoremap <silent> <S-Tab>   :bprevious<CR>
nnoremap <silent> <leader>/ :nohlsearch<CR>
