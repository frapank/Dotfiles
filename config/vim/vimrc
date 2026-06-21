vim9script


# CORE SETTINGS
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
set sidescroll=1 sidescrolloff=5


# UI & COLORS
set termguicolors
syntax on
colorscheme dot
set listchars=tab:·\ ,trail:·,nbsp:␣
set laststatus=2
set nojoinspaces


# COMPLETION
set completeopt=menu,popup
set complete=.,w,b,u,t


# STATUSLINE
augroup VrcStatusline
    autocmd!
    autocmd DirChanged * g:cwd_tail = fnamemodify(getcwd(), ':t')
augroup END
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
def RunFZF()
    var lines: list<string> = []

    def OnOut(ch: channel, msg: string)
        lines->add(msg)
    enddef

    def OnExit(job: job, status: number)
        if status != 0
            return
        endif
        lines = filter(lines, (_, v) => v != '')
        if empty(lines)
            return
        endif
        setqflist([], ' ', {
            title: 'FZF',
            lines: lines->map((_, v) => v .. ':1:1')
        })
        copen
        cfirst
    enddef

    var cmd = 'fzf --no-multi --cycle'

    job_start(['sh', '-c', cmd], {
        in_io:   'null',
        out_cb:  OnOut,
        exit_cb: OnExit,
        err_cb:  OnOut,
    })
enddef
command! -nargs=? FZF RunFZF()
