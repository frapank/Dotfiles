-- PERFORMANCE
vim.loader.enable()

for _, provider in ipairs({ "perl", "ruby", "node", "python3" }) do
    vim.g["loaded_" .. provider .. "_provider"] = 0
end

vim.api.nvim_create_autocmd("BufReadPre", {
    callback = function(a)
        local stat = vim.uv.fs_stat(a.file)
        if stat and stat.size > 5 * 1024 * 1024 then
            vim.b[a.buf].large_file = true
            vim.opt_local.undofile = false
            vim.opt_local.swapfile = false
        end
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    callback = function(a)
        if vim.b[a.buf].large_file then
            vim.defer_fn(function()
                if vim.api.nvim_buf_is_valid(a.buf) then
                    pcall(vim.treesitter.stop, a.buf)
                    vim.bo[a.buf].syntax = "OFF"
                end
            end, 50)
        end
    end,
})

-- OPTIONS
local o = vim.opt

o.hlsearch, o.incsearch, o.ignorecase, o.smartcase = true, true, true, true
o.splitbelow, o.splitright, o.confirm, o.undofile = true, true, true, true
o.tabstop, o.shiftwidth, o.expandtab, o.smartindent = 4, 4, true, true
o.wrap, o.startofline, o.joinspaces = false, false, false
o.scrolloff, o.sidescroll, o.sidescrolloff = 4, 1, 5
o.ttimeout, o.ttimeoutlen, o.updatetime = true, 25, 300
o.clipboard = "unnamedplus"

o.wildignore:append({ "*.exe", "*.dll", "*.pdb", "*.class", "*.o", "*.d" })
o.wildignore:append({ "*/.git/*", "*/node_modules/*", "*/dist/*", "*/build/*", "*/target/*" })
o.wildignorecase = true
o.shortmess:append("IcC")

o.grepformat = "%f:%l:%m"
o.fileformats = { "unix", "dos" }
o.nrformats = { "bin", "hex", "unsigned" }
o.virtualedit = "block"
o.tags = "./tags;,tags;"
o.listchars = { tab = "· ", trail = "·", nbsp = "␣" }
o.laststatus = 2
o.guicursor = "a:block"

if vim.fn.has("nvim-0.10") == 0 then o.termguicolors = true end
vim.cmd("colorscheme dot")

-- STATUSLINE
local function cwd_tail() vim.g.cwd_tail = vim.fn.fnamemodify(vim.fn.getcwd(), ":t") end
vim.api.nvim_create_autocmd("DirChanged", { callback = cwd_tail })
cwd_tail()

function _G.CleanBufferName()
    if vim.bo.buftype == "terminal" then return "Magic" end
    local name = vim.fn.expand("%")
    return name == "" and "[No Name]" or name
end

o.statusline = "%#StatusLine# %{v:lua.CleanBufferName()} %m%r%=%{g:cwd_tail} %L %l:%c "

-- KEYMAPS
vim.g.mapleader = " "
local map = vim.keymap.set

map("n", "<leader>e", ":e ")
map("n", "<leader>d", ":cd ")
map("n", "<leader>g", ":grep ")
map("n", "<leader>q", ":copen<CR>", { silent = true })
map("n", "<leader>n", ":cnext<CR>", { silent = true })
map("n", "<leader>p", ":cprev<CR>", { silent = true })
map("n", "<leader>t", ":Sex<CR>", { silent = true })
map("n", "<leader>m", ":make<CR>", { silent = true })
map("n", "<leader>/", ":nohlsearch<CR>", { silent = true })
map("n", "<Tab>", ":bnext<CR>", { silent = true })
map("n", "<S-Tab>", ":bprevious<CR>", { silent = true })

-- FIND / GREP
if vim.fn.executable("fzf") == 1 and vim.fn.globpath(vim.o.runtimepath, "plugin/fzf.vim") ~= "" then
    vim.env.FZF_DEFAULT_COMMAND = vim.fn.executable("fd") == 1
        and 'fd . --exclude build --exclude .git'
        or 'find . \\( -path "*/build/*" -o -path "*/.git/*" \\) -prune -o -type f -print'
    map("n", "<leader>f", ":FZF<CR>")
else
    o.path = ".,**"
    map("n", "<leader>f", ":find ")
end

o.grepprg = vim.fn.executable("rg") == 1
    and 'rg --vimgrep --smart-case --glob "!.git/*"'
    or "grep -n -R -I -E --exclude-dir=.git"

-- COMMANDS
local cmd = vim.api.nvim_create_user_command

cmd("Debug", function(opts)
    vim.cmd("packadd termdebug")
    vim.cmd("Termdebug " .. opts.args)
end, { nargs = "*", complete = "file" })

require("lsp")
require("terminal")
