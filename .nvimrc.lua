-- Plugins
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
require("lazy").setup({{ "neoclide/coc.nvim", branch = "release" },})

-- Theme
vim.cmd("syntax off")
vim.o.background = "dark"
vim.cmd("colorscheme wildcharm")
vim.cmd("highlight Normal ctermfg=White guifg=#ffffff guibg=NONE")
vim.o.listchars = "tab:·\\ ,trail:·,nbsp:␣"
vim.o.laststatus = 2
vim.o.statusline =
  "%#StatusLine# %f %m%r%=%{fnamemodify(getcwd(),':t')} %l:%c  "

-- General
vim.o.path = ".,**"
vim.o.wildignore =
  "*.exe,*.dll,*.pdb,*.class,*.o,*.d," ..
  "*/.git/*,*/node_modules/*,*/dist/*,*/build/*,*/target/*"
vim.o.wildignorecase = true
vim.o.splitbelow = true
vim.o.splitright = true
vim.o.shortmess = vim.o.shortmess .. "FI"
vim.o.mouse = "n"
vim.o.hidden = true
vim.o.lazyredraw = true
vim.o.backspace = "indent,eol,start"
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true
vim.o.smartcase = true
vim.o.clipboard = "unnamedplus"
vim.o.undofile = true
vim.o.undodir = vim.fn.expand("~/.vim/undo/")
vim.cmd("filetype plugin indent on")

-- Tree (netrw)
vim.g.netrw_banner = 0
vim.g.netrw_keepdir = 0
vim.g.netrw_winsize = 17
vim.g.netrw_liststyle = 3
vim.g.netrw_localcopydircmd = "cp -r"

-- Keymaps
vim.g.mapleader = " "
local map = vim.keymap.set
local opts = { noremap = true, silent = true }
map("n", "<leader>f", ":find ", { noremap = true })
map("n", "<leader>q", ":copen<CR>", opts)
map("n", "<leader>n", ":cnext<CR>", opts)
map("n", "<leader>p", ":cprev<CR>", opts)
map("n", "<leader>e", ":Lexplore<CR>", opts)
map("n", "<Tab>", ":bnext<CR>", opts)
map("n", "<S-Tab>", ":bprev<CR>", opts)
