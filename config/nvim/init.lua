-- CORE SETTINGS
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.wildignore:append({ "*.exe", "*.dll", "*.pdb", "*.class", "*.o", "*.d" })
vim.opt.wildignore:append({ "*/.git/*", "*/node_modules/*", "*/dist/*", "*/build/*", "*/target/*" })
vim.opt.wildignorecase = true

vim.opt.grepformat = "%f:%l:%m"
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.shortmess:append("IcC")
vim.opt.ttimeout = true
vim.opt.ttimeoutlen = 25
vim.opt.updatetime = 300
vim.opt.confirm = true

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.fileformats = { "unix", "dos" }
vim.opt.nrformats = { "bin", "hex", "unsigned" }
vim.opt.virtualedit = "block"
vim.opt.startofline = false

-- WRAPPING & SCROLLING
vim.opt.wrap = false
vim.opt.sidescroll = 1
vim.opt.sidescrolloff = 5

-- UI & COLORS
vim.opt.termguicolors = true
vim.opt.listchars = { tab = "· ", trail = "·", nbsp = "␣" }
vim.opt.laststatus = 3
vim.opt.joinspaces = false
vim.cmd("colorscheme dot")

-- STATUSLINE
local status_group = vim.api.nvim_create_augroup("VrcStatusline", { clear = true })
vim.api.nvim_create_autocmd("DirChanged", {
    group = status_group,
    pattern = "*",
    callback = function()
        vim.g.cwd_tail = vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
    end
})
vim.g.cwd_tail = vim.fn.fnamemodify(vim.fn.getcwd(), ':t')

function _G.CleanBufferName()
    if vim.bo.buftype == 'terminal' then
        return "Magic"
    else
        local name = vim.fn.expand('%')
        return name == '' and '[No Name]' or name
    end
end

vim.opt.statusline = "%#StatusLine# %{v:lua.CleanBufferName()} %m%r%=%{g:cwd_tail} %L %l:%c "

-- KEYMAPS
vim.g.mapleader = ' '
local map = vim.keymap.set

map('n', '<leader>e', ':e ', { desc = "Edit" })
map('n', '<leader>d', ':cd ', { desc = "Cd" })
map('n', '<leader>g', ':grep ', { desc = "Grep" })
map('n', '<leader>q', ':copen<CR>', { silent = true })
map('n', '<leader>n', ':cnext<CR>', { silent = true })
map('n', '<leader>p', ':cprev<CR>', { silent = true })
map('n', '<leader>t', ':Sex<CR>', { silent = true })
map('n', '<Tab>', ':bnext<CR>', { silent = true })
map('n', '<S-Tab>', ':bprevious<CR>', { silent = true })
map('n', '<leader>/', ':nohlsearch<CR>', { silent = true })

-- FUZZY FINDER (FZF / FALLBACK)
if vim.fn.executable('fzf') == 1 then
    if vim.fn.executable('fd') == 1 then
        vim.env.FZF_DEFAULT_COMMAND = 'fd . --exclude build --exclude .git'
    else
        vim.env.FZF_DEFAULT_COMMAND = 'find . \\( -path "*/build/*" -o -path "*/.git/*" \\) -prune -o -type f ! -perm -111 -print'
    end
    map('n', '<leader>f', ':FZF<CR>')
else
    vim.opt.path = ".,**"
    map('n', '<leader>f', ':find ')
end

-- SEARCH / GREP TOOLS
if vim.fn.executable('rg') == 1 then
    vim.opt.grepprg = 'rg --vimgrep --smart-case --glob "!.git/*"'
else
    vim.opt.grepprg = 'grep -nR --ignore-case --perl-regexp --exclude-dir=.git --binary-files=without-match'
end

-- CUSTOM FUNCTIONS (FZF in Quickfix)
vim.api.nvim_create_user_command('FZF', function()
    local lines = {}
    local cmd = 'fzf --no-multi --no-cycle'

    vim.fn.jobstart({'sh', '-c', cmd}, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            if data then
                for _, v in ipairs(data) do
                    if v ~= "" then
                        table.insert(lines, v)
                    end
                end
            end
        end,
        on_exit = function(_, status)
            if status ~= 0 or #lines == 0 then return end

            local qf_lines = {}
            for _, v in ipairs(lines) do
                table.insert(qf_lines, v .. ':1:1')
            end

            vim.fn.setqflist({}, ' ', {
                title = 'FZF',
                lines = qf_lines
            })
            vim.cmd('copen')
            vim.cmd('cfirst')
        end
    })
end, { nargs = "?" })

-- VIM TERM
vim.cmd([[
cnoreabbrev <expr> term (getcmdtype() == ':' && getcmdline() == 'term') ? 'split <bar> term' : 'term'
cnoreabbrev <expr> terminal (getcmdtype() == ':' && getcmdline() == 'terminal') ? 'split <bar> term' : 'terminal'
]])

local term_group = vim.api.nvim_create_augroup("TerminalBehavior", { clear = true })

vim.api.nvim_create_autocmd("TermOpen", {
    group = term_group,
    pattern = "*",
    command = "startinsert",
})

-- LSP
-- clangd (C / C++)
vim.api.nvim_create_autocmd("FileType", {
    group = lsp_group,
    pattern = { "c", "cpp" },
    callback = function()
        vim.lsp.start({
            name     = "clangd",
            cmd      = { "clangd" },
            root_dir = vim.fs.root(0, { "compile_commands.json", ".clangd", ".git" }),
        })
    end,
})

-- rust-analyzer
vim.api.nvim_create_autocmd("FileType", {
    group = lsp_group,
    pattern = "rust",
    callback = function()
        vim.lsp.start({
            name     = "rust-analyzer",
            cmd      = { "rust-analyzer" },
            root_dir = vim.fs.root(0, { "Cargo.toml", ".git" }),
        })
    end,
})

-- config
vim.diagnostic.config({
    virtual_text     = true,
    signs            = false,
    underline        = true,
    update_in_insert = false,
})
