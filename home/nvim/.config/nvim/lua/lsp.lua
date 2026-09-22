-- Servers are started only if their binary is on PATH.
local servers = {
    clangd = {
        cmd = {
            "clangd",
            "--background-index",
            "-j=" .. math.max(2, math.floor(vim.uv.available_parallelism() / 2)),
            "--clang-tidy",
            "--completion-style=detailed",
            "--header-insertion=iwyu",
            "--header-insertion-decorators", -- marks which candidates add an #include
            "--all-scopes-completion",
            "--function-arg-placeholders=0", -- foo(), not foo(${1:int a})
            "--pch-storage=memory",
            "--malloc-trim", -- a C++ index gets big; hand the pages back
        },
        filetypes = { "c", "cpp" },

        root_dir = function(bufnr, on_dir)
            local fname = vim.api.nvim_buf_get_name(bufnr)
            if fname == "" then return on_dir(nil) end

            local pinned = vim.fs.root(fname, { "compile_commands.json", "compile_flags.txt", ".clangd" })
            if pinned then return on_dir(pinned) end

            local outermost
            for dir in vim.fs.parents(fname) do
                if vim.uv.fs_stat(dir .. "/CMakeLists.txt") or vim.uv.fs_stat(dir .. "/meson.build") then
                    outermost = dir
                end
                if vim.uv.fs_stat(dir .. "/.git") then break end
            end
            on_dir(outermost or vim.fs.root(fname, { ".git", "Makefile" }))
        end,
    },
    ["rust-analyzer"] = {
        cmd = { "rust-analyzer" },
        filetypes = { "rust" },
        root_markers = { "Cargo.toml" },
    },
    zls = {
        cmd = { "zls" },
        filetypes = { "zig" },
        root_markers = { "build.zig", "build.zig.zon" },
    },
    taplo = {
        cmd = { "taplo", "lsp", "stdio" },
        filetypes = { "toml" },
        root_markers = { "taplo.toml", ".taplo.toml" },
    },
    bashls = {
        cmd = { "bash-language-server", "start" },
        filetypes = { "sh", "bash" },
        root_markers = {},
    },
    yamlls = {
        cmd = { "yaml-language-server", "--stdio" },
        filetypes = { "yaml" },
        root_markers = {},
    },
}

for name, cfg in pairs(servers) do
    if vim.fn.executable(cfg.cmd[1]) == 1 then
        if cfg.root_markers then -- clangd resolves its root with a function instead
            table.insert(cfg.root_markers, ".git")
        end
        vim.lsp.config[name] = cfg
        vim.lsp.enable(name)
    end
end

vim.diagnostic.config({
    virtual_text = true,
    signs = false,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
})

-- <C-n> LSP completion & fuzzy finder.
vim.opt.completeopt = { "menuone", "noselect", "fuzzy" }
vim.keymap.set("i", "<C-n>", function()
    if vim.fn.pumvisible() == 1 or vim.bo.omnifunc ~= "v:lua.vim.lsp.omnifunc" then
        return "<C-n>"
    end
    return "<C-x><C-o>"
end, { expr = true })

-- Enter confirms the highlighted suggestion, which is also what pulls in the automatic include
vim.keymap.set("i", "<CR>", function()
    if vim.fn.pumvisible() == 1 and vim.fn.complete_info({ "selected" }).selected ~= -1 then
        return "<C-y>"
    end
    return "<CR>"
end, { expr = true })

-- When a server attaches: fold by real code structure, plus a key to toggle the inline hints
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if not client then return end

        if client:supports_method("textDocument/foldingRange") then
            vim.wo[vim.api.nvim_get_current_win()][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
        end

        if client:supports_method("textDocument/inlayHint") then
            vim.keymap.set("n", "<leader>h", function()
                local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf })
                vim.lsp.inlay_hint.enable(not enabled, { bufnr = ev.buf })
            end, { buffer = ev.buf, desc = "Toggle inlay hints" })
        end
    end,
})
