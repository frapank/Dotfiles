"+--------------+"
"|    Design    |"
"+--------------+"

" Cursor shape
let &t_SI = "\e[6 q"
let &t_EI = "\e[2 q"
set guicursor=n-v-c:ver25
set guicursor+=i:ver25
set guicursor+=r:ver25
set guicursor+=o:ver25
set guicursor+=v:block


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

" Better diff display
set diffopt+=vertical
set diffopt+=algorithm:patience
set diffopt+=indent-heuristic
set diffopt+=iwhite

" Status line
set laststatus=2
set statusline=%f\ %y\ %m%r%=%{fnamemodify(getcwd(),':t')}\ \ [%p%%]\ %l:%c

" Welcome message
set shortmess+=I

"+--------------+"
"|     Tree     |"
"+--------------+"

" netrw
let g:netrw_banner = 0
let g:netrw_keepdir = 0
let g:netrw_winsize = 20
let g:netrw_liststyle = 3
let g:netrw_localcopydircmd = 'cp -r'
hi! link netrwMarkFile Search

"+--------------+"
"|  Functional  |"
"+--------------+"

" filesystem & search path
set path=.,**

" menu completion
set wildmenu
set wildmode=longest,full

" Update time
set updatetime=300
set timeoutlen=500
set ttimeoutlen=10

" Hide tab and dont force close
set hidden

" Backspace behavior
set backspace=indent,eol,start

" Mouse and swap/backup files
set mouse=a
set nobackup
set nowritebackup
set noswapfile
set undofile
set undodir=~/.vim/undo//

" Tabs and indentation
set tabstop=4
set shiftwidth=4
set expandtab

" Auto indent and filetype-based indenting
set autoindent
set smartindent
filetype plugin indent on

" Line numbers: absolute + relative; disable relative in Insert
set number
set relativenumber
autocmd InsertEnter * set norelativenumber
autocmd InsertLeave * set relativenumber

" Case-insensitive search unless uppercase used
set smartcase

" Copy on clipboard
set clipboard=unnamedplus

" Ignore files
if executable('rg')
    set grepprg=rg\ --vimgrep\ --no-ignore\ --glob\ '!*.exe'\ --glob\ '!*.bin'\ --glob\ '!*.out'
endif

" Filetype-specific settings and commands
augroup filetype_specific
    autocmd!
    " Python: .py
    autocmd FileType python setlocal shiftwidth=4 tabstop=4 expandtab
    autocmd FileType python setlocal makeprg=python3\ %

    " Markdown: .md
    autocmd FileType markdown setlocal wrap
    autocmd FileType markdown setlocal linebreak
    autocmd FileType make setlocal noexpandtab tabstop=4 shiftwidth=4

    " Git: .git
    autocmd FileType gitcommit setlocal spell wrap linebreak
augroup END


"+--------------+"
"|    Keymaps   |"
"+--------------+"

" Key mappings (leader is space)
let mapleader=" "
nnoremap <leader>g  :grep<Space>
nnoremap <leader>f  :find<Space>
nnoremap <leader>m  :make<CR>
nnoremap <leader>m  :make<CR>

nnoremap <leader>q :copen<CR>
nnoremap <leader>n :cnext<CR>
nnoremap <leader>p :cprev<CR>

nnoremap <leader>t  :terminal<CR>
nnoremap <leader>e  :Lexplore<CR>

nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

nnoremap <leader>b  :ls<CR>
nnoremap <leader>x  :bd<CR>
nnoremap <Tab>      :bnext<CR>
nnoremap <S-Tab>    :bprev<CR>

nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
nnoremap <leader>l :vsplit<CR>
nnoremap <leader>j :split<CR>
nnoremap <leader>k :close<CR>

nnoremap <C-A-h> :vertical resize -2<CR>
nnoremap <C-A-l> :vertical resize +2<CR>
nnoremap <C-A-j> :resize +2<CR>
nnoremap <C-A-k> :resize -2<CR>

" Disable history keys
nnoremap q: <nop>
nnoremap q/ <nop>
nnoremap q? <nop>
