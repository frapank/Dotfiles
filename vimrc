vim9script

# General
set nocompatible
set path=.,**
set hlsearch incsearch ignorecase smartcase
set wildignore+=*.exe,*.dll,*.pdb,*.class,*.o,*.d
set wildignore+=*/.git/*,*/node_modules/*,*/dist/*,*/build/*,*/target/*
set wildignorecase
set grepformat=%f:%l:%m
set splitbelow splitright
set shortmess+=IcC
set ttimeout ttimeoutlen=25
set updatetime=300 redrawtime=1500
set hidden confirm lazyredraw
set backspace=indent,eol,start
set tabstop=4 shiftwidth=4 expandtab
set autoindent softtabstop=-1
set fileformat=unix
set fileformats=unix,dos
set nrformats=bin,hex,unsigned
set virtualedit=block nostartofline
set switchbuf=useopen
set clipboard=unnamedplus
filetype plugin indent on

# Wrapping / scrolling
set nowrap
set linebreak
set breakindent breakindentopt=sbr,list:-1
set display=lastline
set smoothscroll
set sidescroll=1 sidescrolloff=3

# Completion
set completeopt=menu,popup
set complete=o^10,.^10,w^5,b^5,u^3,t^3

# UI / Theme
colorscheme lain
set listchars=tab:·\ ,trail:·,nbsp:␣
set laststatus=2
set nojoinspaces

# Statusline
autocmd DirChanged * g:cwd_tail = fnamemodify(getcwd(), ':t')
g:cwd_tail = fnamemodify(getcwd(), ':t')
set statusline=%#StatusLine#\ %f\ %m%r%=%{g:cwd_tail}\ %L\ %l:%c\ 

# netrw
g:netrw_banner = 0
g:netrw_keepdir = 0
g:netrw_winsize = 17
g:netrw_fastbrowse = 2
g:netrw_liststyle = 3
g:netrw_localcopydircmd = 'cp -r'

# Keys
g:mapleader = ' '
nnoremap <leader>f          :find<Space>
nnoremap <silent> <leader>q :copen<CR>
nnoremap <silent> <leader>n :cnext<CR>
nnoremap <silent> <leader>p :cprev<CR>
nnoremap <silent> <leader>e :Lexplore<CR>
nnoremap <silent> <Tab>     :bnext<CR>
nnoremap <silent> <S-Tab>   :bprevious<CR>
nnoremap <silent> <leader>/ :nohlsearch<CR>

# Reimplementation
&grepprg = [
    'grep',
    '--line-number',
    '--recursive',
    '--ignore-case',
    '--perl-regexp',
    '--exclude-dir .git',
    '--binary-files=without-match',
    '$*'
]->join()
