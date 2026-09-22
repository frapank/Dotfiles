vim.opt_local.cindent = true
vim.opt_local.cinoptions = ":0,l1,t0,g0"

-- Sourced for cpp too: runtime ftplugin/cpp.vim does `runtime! ftplugin/c.{vim,lua}`,
-- which reaches this after/ directory as well.

-- errorformat for gcc/clang. :compiler sets errorformat only, never makeprg.
-- Ninja interleaves progress lines, "FAILED:", the full compiler command and
-- caret diagrams with the diagnostics; without this the quickfix list is ~11
-- entries per error instead of 1.
vim.g.compiler_gcc_ignore_unmatched_lines = 1
vim.cmd("compiler gcc")

-- A CMake tree cannot be built by bare `make`, and the build directory is not
-- the cwd. Look for a *configured* build dir in the file's ancestors rather
-- than for CMakeLists.txt, which add_subdirectory() leaves in every subdir.
local fname = vim.api.nvim_buf_get_name(0)
if fname ~= "" then
    for dir in vim.fs.parents(fname) do
        for _, build in ipairs({ "build", "cmake-build-debug", "out/build" }) do
            if vim.uv.fs_stat(dir .. "/" .. build .. "/CMakeCache.txt") then
                vim.opt_local.makeprg = "cmake --build " .. vim.fn.fnameescape(dir .. "/" .. build)
                return
            end
        end
        if vim.uv.fs_stat(dir .. "/.git") then break end
    end
end
