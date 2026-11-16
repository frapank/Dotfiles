-- typos underlined in amber; Italian too where its spell file is installed
vim.opt_local.spell = true
vim.opt_local.spelllang = "en"
if #vim.api.nvim_get_runtime_file("spell/it.utf-8.spl", false) > 0 then
    vim.opt_local.spelllang:append("it")
end
