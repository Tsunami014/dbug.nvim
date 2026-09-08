local M = {}

-- 1 = .nvimrc, 2 = .nvim.lua

M.options = {
    ["!Blank .nvimrc"] = {"", 1},
    ["!Blank .nvim.lua"] = {"", 2},
    ["!Simple debug template"] = {[[
function DebugActions(actions)
    local ft = vim.bo.filetype
    while #actions > 0 do table.remove(actions) end
    table.insert(actions, { -- 1, { -- For top of list
        label = "Name",
        terminal = "cmd",
        after = function() end,
        -- keep_open = true,
    })
end
]], 2},
    ["!Verbose debug template"] = {[[
function DebugActions(actions)
    local ft = vim.bo.filetype
    while #actions > 0 do table.remove(actions) end
    -- table.insert(actions, 1, { -- Insert at top of list
    table.insert(actions, { -- Insert at bottom of list
        label = "Name",
        terminal = "cmd",
        -- terminal = function() return "cmd" end,
        after = function() end,
        -- after = function(code) end, -- status code of terminal output
        -- keep_open = true, -- keep terminal open even on success; default false
    })
end
]], 2},
    ["C++ template"] = {[[
function DebugActions(actions)
    -- while #actions > 0 do table.remove(actions) end
    table.insert(actions, 1, {
        label = "Name",
        terminal = "make debug",
        after = function(code) if code == 0 then Dbug.launch_cpp_dap("file") end end,
    })
end
-- vim.g.askcppexec = "file" -- Instead of asking which executable to use, use this
]], 2},
    ["Python template"] = {[[
function DebugActions(actions)
    -- while #actions > 0 do table.remove(actions) end
    table.insert(actions, 1, {
        label = "Run file",
        after = function()
            require("dap").run({
                name = "Launch Python",
                type = "python",
                request = "launch",
                program = "file.py",
                -- args = {"arg", "here"},
                console = "integratedTerminal",
            })
        end,
    })
end
]], 2},
    ["Latex template"] = {[[
function DebugActions(actions)
    -- while #actions > 0 do table.remove(actions) end
    table.insert(actions, 1, {
        label = "Compile & view LaTeX",
        terminal = function() return Dbug.latex_compile("file.tex") end,
        after = function(code)
            if code == 0 then Dbug.latex_view("file.tex") end
        end
    })
end
]], 2},
    ["Run on save"] = {[[
local grp = vim.api.nvim_create_augroup("RunOnSave", { clear = true })

vim.api.nvim_create_autocmd("BufWritePost", {
  group = grp,
  pattern = "*/file.txt",
  callback = function(args)
    -- local dir = vim.fn.fnamemodify(args.file, ":h")
    vim.system({ "bash", "-c", "echo saved: " .. args.file }, {}, function(obj)
      vim.schedule(function()
        print(obj.stdout)
      end)
    end)
  end,
})

function EnvReset()
  vim.api.nvim_create_augroup("RunOnSave", { clear = true })
end
]], 2},
    ["Inline terminal"] = {[[
function DebugActions(actions)
    -- while #actions > 0 do table.remove(actions) end
    table.insert(actions, {
        label = "Open a non-floating terminal",
        after = function()
            Dbug.new_terminal("echo 'hello'", {
                -- dir = "vertical", size = 50, keep_open = true,
            })
        end
    })
end
]], 2},
}

return M
