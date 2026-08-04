-- OPTIONS
local o = vim.opt

o.hlsearch, o.incsearch, o.ignorecase, o.smartcase = true, true, true, true
o.splitbelow, o.splitright, o.confirm, o.undofile = true, true, true, true
o.tabstop, o.shiftwidth, o.expandtab, o.smartindent = 4, 4, true, true
o.wrap, o.startofline, o.joinspaces = false, false, false
o.scrolloff, o.sidescroll, o.sidescrolloff = 4, 1, 5
o.ttimeout, o.ttimeoutlen, o.updatetime = true, 25, 300

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
o.guicursor = "a:block" -- block in every mode, like terminal vim

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
if vim.fn.executable("fzf") == 1 then
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
    or "grep -n -R -I -E --exclude-dir=.git" -- -E, not -P: BSD grep has no perl regex

-- COMMANDS
local cmd = vim.api.nvim_create_user_command

cmd("Debug", function(opts)
    vim.cmd("packadd termdebug")
    vim.cmd("Termdebug " .. opts.args)
end, { nargs = "*", complete = "file" })

cmd("FZF", function()
    local lines = {}
    vim.fn.jobstart({ "sh", "-c", "fzf --no-multi --no-cycle" }, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            for _, v in ipairs(data or {}) do
                if v ~= "" then table.insert(lines, v .. ":1:1") end
            end
        end,
        on_exit = function(_, status)
            if status ~= 0 or #lines == 0 then return end
            vim.fn.setqflist({}, " ", { title = "FZF", lines = lines })
            vim.cmd("copen | cfirst")
        end,
    })
end, {})

cmd("HexToggle", function()
    if vim.bo.binary and vim.bo.filetype == "xxd" then
        vim.cmd("silent %!xxd -r")
        vim.bo.filetype = ""
    elseif vim.bo.modified then
        vim.notify("HexToggle: save changes first", vim.log.levels.WARN)
    else
        vim.bo.binary = true
        vim.cmd("silent edit")
        vim.cmd("silent %!xxd -g1")
        vim.bo.filetype = "xxd"
    end
end, {})

require("lsp")
require("terminal")
