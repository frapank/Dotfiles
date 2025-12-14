" Theme
syntax off
set background=dark
set termguicolors
colorscheme habamax
hi Normal guibg=#000000
hi LineNr guibg=#000000
hi StatusLine guifg=#ffffff guibg=#000000
hi StatusLineNC guifg=#888888 guibg=#000000
hi TabLine guibg=#000000
hi TabLineFill guibg=#000000
hi VertSplit guibg=bg guifg=bg
hi Pmenu ctermbg=black guibg=black
hi ExtraWhitespace ctermbg=red guibg=red

match ExtraWhitespace /\s+$/
set list
set listchars=tab:▸\ ,trail:·,nbsp:␣

" Status line
set laststatus=2
set statusline=%f\ %y\ %m%r%=%{fnamemodify(getcwd(),':t')}\ \ [%p%%]\ %l:%c

" General
set path=.,**
set wildmenu
set wildoptions=pum
set wildignore+=*.exe,*.dll,*.pdb,*.class,*.o,*.d
set wildignore+=*/.git/*,*/node_modules/*,*/dist/*,*/build/*,*/target/*
set wildignorecase
set shortmess+=FI
set hidden
set backspace=indent,eol,start
set tabstop=4
set shiftwidth=4
set expandtab
set smartcase
set clipboard=unnamedplus
set gp=git\ grep\ -n
set mouse=a
set undofile
set undodir=~/.vim/undo/
filetype plugin indent on
packadd! termdebug
set number
set relativenumber
autocmd InsertEnter * set norelativenumber
autocmd InsertLeave * set relativenumber

" Language
autocmd FileType python set makeprg=python3\ %
autocmd FileType sh setlocal makeprg=bash\ %

" Tree
let g:netrw_banner = 0
let g:netrw_keepdir = 0
let g:netrw_winsize = 17
let g:netrw_liststyle = 3
let g:netrw_localcopydircmd = 'cp -r'
hi! link netrwMarkFile Search

" Keymaps
let mapleader=" "
nnoremap <leader>g  :grep<Space>
nnoremap <leader>f  :find<Space>

nnoremap <leader>q :copen<CR>
nnoremap <leader>n :cnext<CR>
nnoremap <leader>p :cprev<CR>

nnoremap <leader>e  :Lexplore<CR>

nnoremap <Tab>      :bnext<CR>
nnoremap <S-Tab>    :bprev<CR>
