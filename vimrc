vim9script

# CORE SETTINGS
set clipboard=exclude:.*
set hlsearch incsearch ignorecase smartcase
set wildignore+=*.exe,*.dll,*.pdb,*.class,*.o,*.d
set wildignore+=*/.git/*,*/node_modules/*,*/dist/*,*/build/*,*/target/*
set wildignorecase
set grepformat=%f:%l:%m
set splitbelow splitright
set shortmess+=IcC
set ttimeout ttimeoutlen=25
set updatetime=300
set hidden confirm lazyredraw
set tabstop=4 shiftwidth=4 expandtab
set smartindent
set fileformats=unix,dos
set nrformats=bin,hex,unsigned
set virtualedit=block nostartofline
filetype plugin indent on


# WRAPPING & SCROLLING
set nowrap
set linebreak
set display=lastline
set sidescroll=1 sidescrolloff=3


# UI & COLORS
set termguicolors
syntax on
colorscheme lain
set listchars=tab:·\ ,trail:·,nbsp:␣
set laststatus=2
set nojoinspaces


# COMPLETION
set completeopt=menu,popup
set complete=o,.,w,b,u,t


# STATUSLINE
autocmd DirChanged * g:cwd_tail = fnamemodify(getcwd(), ':t')
g:cwd_tail = fnamemodify(getcwd(), ':t')
set statusline=%#StatusLine#\ %f\ %m%r%=%{g:cwd_tail}\ %L\ %l:%c\


# KEYMAPS
g:mapleader = ' '

nnoremap <leader>e          :e<Space>
nnoremap <leader>d          :cd<Space>
nnoremap <leader>g          :grep<Space>
nnoremap <silent> <leader>q :copen<CR>
nnoremap <silent> <leader>n :cnext<CR>
nnoremap <silent> <leader>p :cprev<CR>
nnoremap <silent> <leader>t :Sex<CR>
nnoremap <silent> <Tab>     :bnext<CR>
nnoremap <silent> <S-Tab>   :bprevious<CR>
nnoremap <silent> <leader>/ :nohlsearch<CR>


# FUZZY FINDER (FZF / FALLBACK)
if executable('fzf')
    $FZF_DEFAULT_OPTS = '--color=fg:#ffffff,bg:#000000,hl:#b0b0b0,fg+:#000000,bg+:#ffffff,hl+:#000000,border:#ffffff,header:#ffffff,gutter:#000000,spinner:#ffffff,info:#b0b0b0,pointer:#ffffff,marker:#ffffff,prompt:#ffffff,query:#ffffff,disabled:#666666,preview-fg:#ffffff,preview-bg:#000000'

    if executable('fd')
        $FZF_DEFAULT_COMMAND = 'fd . --exclude build --exclude .git'
    else
        $FZF_DEFAULT_COMMAND = 'find . \( -path "*/build/*" -o -path "*/.git/*" \) -prune -o -type f ! -perm -111 -print'
    endif

    nnoremap <leader>f :FZF<CR>
else
    set path=.,**
    nnoremap <leader>f :find<Space>
endif


# SEARCH / GREP TOOLS
if executable('rg')
    &grepprg = 'rg -n -P --no-heading --smart-case --glob "!.git/*"'
else
    &grepprg = 'grep -nR --ignore-case --perl-regexp --exclude-dir=.git --binary-files=without-match'
endif


# CUSTOM FUNCTIONS
def FZF()
    var lines = []

    def OnOut(job: job, data: list<string>)
        lines += data
    enddef

    def OnExit(job: job, status: number)
        lines = filter(copy(lines), 'v:val != ""')
        if !empty(lines)
            setqflist([], ' ', {
                lines: lines->map((_, v) => v .. ':1:1')
            })
            copen
        endif
    enddef

    job_start(['sh', '-c', 'fzf --multi --no-border'], {...})
        out_cb: OnOut,
        exit_cb: OnExit,
        err_cb: OnOut,
    })
enddef
