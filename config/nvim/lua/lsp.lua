-- Servers are started only if their binary is on PATH.
local servers = {
    clangd = {
        cmd = { "clangd", "--background-index", "--clang-tidy" },
        filetypes = { "c", "cpp" },
        root_markers = { "compile_commands.json", ".clangd" },
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
        table.insert(cfg.root_markers, ".git")
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

-- <C-n>: LSP completion when a server is attached, plain keyword otherwise.
vim.opt.completeopt = { "menuone", "noselect" }
vim.keymap.set("i", "<C-n>", function()
    if vim.fn.pumvisible() == 1 or vim.bo.omnifunc ~= "v:lua.vim.lsp.omnifunc" then
        return "<C-n>"
    end
    return "<C-x><C-o>"
end, { expr = true })
