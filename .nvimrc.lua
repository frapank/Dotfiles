-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data')..'/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  'neovim/nvim-lspconfig',
  'williamboman/mason.nvim',
  'williamboman/mason-lspconfig.nvim',
  'hrsh7th/nvim-cmp',
  'hrsh7th/cmp-nvim-lsp',
  'L3MON4D3/LuaSnip',
})

-- Basic options
local o = vim.opt
o.syntax = 'on'
if vim.fn.has('termguicolors') == 1 then o.termguicolors = true end
o.background = 'dark'
pcall(vim.cmd, 'colorscheme habamax')
vim.cmd('hi Normal guibg=#000000')
vim.cmd('hi LineNr guibg=#000000')
vim.cmd("hi StatusLine guifg=#ffffff guibg=#000000")
vim.cmd("hi StatusLineNC guifg=#888888 guibg=#000000")
vim.cmd('hi TabLine guibg=#000000')
vim.cmd('hi TabLineFill guibg=#000000')
vim.cmd('hi VertSplit guibg=bg guifg=bg')
vim.cmd('hi Pmenu ctermbg=black guibg=black')
vim.cmd('hi ExtraWhitespace ctermbg=red guibg=red')
vim.cmd([[match ExtraWhitespace /\s+$/]])
o.list = true
o.listchars = {tab = '▸ ', trail = '·', nbsp = '␣'}

-- statusline
o.laststatus = 2
vim.o.statusline = '%f %y %m%r%=%{fnamemodify(getcwd(),\':t\')}  [%p%%] %l:%c'

-- general
o.path = '.,**'
o.wildmenu = true
o.wildoptions = 'pum'
o.wildignore = '*.exe,*.dll,*.pdb,*.class'
o.shortmess:append('FI')
o.hidden = true
o.backspace = 'indent,eol,start'
o.tabstop = 4
o.shiftwidth = 4
o.expandtab = true
o.smartcase = true
o.clipboard = 'unnamedplus'
o.mouse = 'a'
o.undofile = true
o.undodir = vim.fn.stdpath('data')..'/undo/'
vim.cmd('filetype plugin indent on')
vim.cmd('packadd! termdebug')

o.number = true
o.relativenumber = true
vim.api.nvim_create_autocmd('InsertEnter', {pattern='*', command='set norelativenumber'})
vim.api.nvim_create_autocmd('InsertLeave', {pattern='*', command='set relativenumber'})

-- netrw
vim.g.netrw_banner = 0
vim.g.netrw_keepdir = 0
vim.g.netrw_winsize = 20
vim.g.netrw_liststyle = 3
vim.g.netrw_localcopydircmd = 'cp -r'
vim.cmd('hi! link netrwMarkFile Search')

-- Keymaps
vim.g.mapleader = ' '
local km = vim.api.nvim_set_keymap
local opts = {noremap=true, silent=false}
km('n', '<leader>g', ':grep ', opts)
km('n', '<leader>f', ':find ', opts)
km('n', '<leader>q', ':copen<CR>', opts)
km('n', '<leader>n', ':cnext<CR>', opts)
km('n', '<leader>p', ':cprev<CR>', opts)
km('n', '<leader>e', ':Lexplore<CR>', opts)
km('n', '<C-h>', '<C-w>h', opts)
km('n', '<leader>?', ':lua vim.diagnostic.open_float()<CR>', opts)
km('n', '<C-j>', '<C-w>j', opts)
km('n', '<C-k>', '<C-w>k', opts)
km('n', '<C-l>', '<C-w>l', opts)
km('n', '<leader>x', ':bd<CR>', opts)
km('n', '<Tab>', ':bnext<CR>', opts)
km('n', '<S-Tab>', ':bprev<CR>', opts)
km('n', '<leader>l', ':vsplit<CR>', opts)
km('n', '<leader>j', ':split<CR>', opts)
km('n', '<leader>k', ':close<CR>', opts)

-- Mason
require('mason').setup()
require('mason-lspconfig').setup({
  ensure_installed = { 'clangd', 'bashls', 'pyright', 'jdtls' },
})

local lspconfig = require('lspconfig')
local servers = { 'clangd', 'bashls', 'pyright', 'jdtls' }

-- nvim-cmp
local cmp = require('cmp')
local luasnip = require('luasnip')
cmp.setup{
  snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
  sources = {
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
  },
}
