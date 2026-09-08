local M = {}
local templates = require("dbug.templates")

-- Reset some common directory environment things
local function resetEnv()
    if type(_G.EnvReset) == "function" then
        EnvReset()
        _G.EnvReset = nil
    end
    _G.DebugActions = nil
end

local function allfiles()
    local cwd = vim.fn.getcwd()
    return { cwd .. "/.nvimrc", cwd .. "/.nvim.lua" }
end

function M.dirch(ignorefail)
    resetEnv()
    local cwd = vim.fn.getcwd()
    local lua_rc = cwd .. "/.nvim.lua"
    local vim_rc = cwd .. "/.nvimrc"

    if vim.fn.filereadable(lua_rc) == 1 then
        local content = vim.secure.read(lua_rc)
        if content then
            local chunk, err = load(content, "@" .. lua_rc)
            if chunk then
                local ok, run_err = pcall(chunk)
                if not ok then
                    vim.notify("Error running .nvim.lua: " .. run_err, vim.log.levels.ERROR)
                end
            else
                vim.notify("Error parsing .nvim.lua: " .. err, vim.log.levels.ERROR)
            end
        end
    elseif vim.fn.filereadable(vim_rc) == 1 then
        local content = vim.secure.read(vim_rc)
        if content then
            vim.cmd(content)
        end
    elseif not ignorefail then
        vim.notify("No .nvim.lua or .nvimrc found in current directory.")
    end
end

function M.untrust(ignorefail)
    local cwd = vim.fn.getcwd()
    local lua_rc = cwd .. "/.nvim.lua"
    local vim_rc = cwd .. "/.nvimrc"

    if vim.fn.filereadable(lua_rc) == 1 then
        vim.secure.trust({ action = 'remove', path = ".nvim.lua" })
    elseif vim.fn.filereadable(vim_rc) == 1 then
        vim.secure.trust({ action = 'remove', path = ".nvimrc" })
    elseif not ignorefail then
        vim.notify("No .nvim.lua or .nvimrc found in current directory.")
    end
end

local keys = {}
for k, _ in pairs(templates.options) do
    table.insert(keys, k)
end
table.sort(keys)

function M.show_templates()
    local lines = {}
    for _, name in ipairs(keys) do
        local content = templates.options[name][1]
        table.insert(lines, string.format("------ %s ------", name))
        if content == "" then
            table.insert(lines, "-- (empty file)")
        else
            for _, line in ipairs(vim.split(content, "\n", { plain = true })) do
                table.insert(lines, line)
            end
        end
        table.insert(lines, "")
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = "lua"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false

    vim.cmd.split()
    vim.api.nvim_win_set_buf(0, buf)
end

function M.setup()
    local augroup = vim.api.nvim_create_augroup("DbugEnvfile", { clear = true })
    vim.api.nvim_create_autocmd("DirChanged", {
        group = augroup,
        pattern = "*",
        callback = function() M.dirch(true) end,
    })

    if vim.v.vim_did_enter == 1 then
        M.dirch(true)
    else
        vim.api.nvim_create_autocmd("VimEnter", {
            group = augroup,
            once = true,
            callback = function() M.dirch(true) end,
        })
    end

    vim.api.nvim_create_user_command("DbugTemplates", M.show_templates, {
        desc = "Show all built-in dbug.nvim env-file templates",
    })
end

function M.genfile()
    local fles = allfiles()
    for _, f in ipairs(fles) do
        if vim.fn.filereadable(f) == 1 then
            if vim.fn.confirm("Environment file already exists, do you want to replace it?", "&Yes\n&No") == 1 then
                if vim.fn.delete(f) ~= 0 then
                    vim.notify("Error: Failed to delete environment file.")
                    return
                end
            else
                vim.notify("Not deleting.")
                return
            end
        end
    end
    vim.ui.select(keys, {
        prompt = "Select an option:",
    }, function(choice)
        if choice then
            vim.schedule(function()
                local o = templates.options[choice]
                local fname = fles[o[2]]
                local file = io.open(fname, "w")
                if file then
                    file:write(o[1])
                    file:close()
                    vim.cmd.edit(fname)
                else
                    vim.notify("Error: Could not open file for writing.")
                end
            end)
        end
    end)
end

function M.showfile()
    local fles = allfiles()
    local readf
    local av = 0
    for _, f in ipairs(fles) do
        if vim.fn.filereadable(f) == 1 then
            av = av+1
            readf = f
        end
    end
    if av == 0 then
        vim.notify("No environment files exist!")
    elseif av ~= 1 then
        vim.notify("More than one environment file exists, I don't know which to open!")
    else
        vim.cmd.edit(readf)
    end
end

return M
