-- Make :terminal behave like Vim's: <C-w> window nav, autoinsert, autoclose.

local api = vim.api

local function keycode(s)
    return api.nvim_replace_termcodes(s, true, false, true)
end

-- Direction key (incl. Ctrl-variants and arrows) -> winnr() direction letter.
local WIN_DIR = {
    h = "h", [keycode("<C-h>")] = "h", [keycode("<Left>")] = "h",
    j = "j", [keycode("<C-j>")] = "j", [keycode("<Down>")] = "j",
    k = "k", [keycode("<C-k>")] = "k", [keycode("<Up>")] = "k",
    l = "l", [keycode("<C-l>")] = "l", [keycode("<Right>")] = "l",
}

local LITERAL = keycode("<C-w>")

-- <C-w><dir>: leave terminal mode and move, like Vim's terminal does.
-- <C-w><C-w>/w: cycle windows. <C-w>. sends a literal <C-w> to the job.
vim.keymap.set("t", "<C-w>", function()
    local ch = vim.fn.getcharstr()

    if ch == "." then
        return api.nvim_feedkeys(LITERAL, "n", false)
    end

    local dir = WIN_DIR[ch]
    if dir then
        vim.cmd("wincmd " .. dir)
    elseif ch == "w" or ch == keycode("<C-w>") then
        vim.cmd("wincmd w")
    end

    if vim.bo.buftype == "terminal" then
        vim.cmd("startinsert")
    end
end)

local group = api.nvim_create_augroup("terminal_vim_style", { clear = true })

api.nvim_create_autocmd("TermOpen", {
    group = group,
    callback = function(a)
        if vim.bo[a.buf].buflisted then
            vim.cmd.startinsert()
        end
    end,
})

-- Re-enter insert mode when returning to a terminal window left in insert mode.
api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
        if vim.bo.buftype == "terminal" and api.nvim_get_mode().mode ~= "t" then
            vim.cmd.startinsert()
        end
    end,
})

-- Close the window on a normal shell exit (0) or Ctrl-C (130), like Vim does.
-- One-off command terminals (:term <cmd>) are left open so output stays visible.
api.nvim_create_autocmd("TermClose", {
    group = group,
    callback = function(a)
        local shell_cmd = a.file:gsub("^%S*:", "")
        local code = vim.v.event.status
        if shell_cmd == vim.o.shell and (code == 0 or code == 130) and api.nvim_buf_is_valid(a.buf) then
            vim.api.nvim_buf_delete(a.buf, { force = true })
        end
    end,
})

vim.cmd([[
cnoreabbrev <expr> term (getcmdtype() == ':' && getcmdline() == 'term') ? 'split <bar> term' : 'term'
cnoreabbrev <expr> terminal (getcmdtype() == ':' && getcmdline() == 'terminal') ? 'split <bar> term' : 'terminal'
]])
