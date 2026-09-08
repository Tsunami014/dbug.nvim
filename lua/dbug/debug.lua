local M = {}
local config = require("dbug.config")

-- Globals for use
_G.Dbug = _G.Dbug or {}
local Globl = _G.Dbug

local state = {
    buf = nil,
    win = nil,
    job = nil,

    action = nil,
    fname = nil,
    cwd = nil,
    line = nil,

    last_executable = "",
}

local function get_dap()
    if not config.use_dap then
        return nil
    end
    local ok, dap = pcall(require, "dap")
    if ok then
        return dap
    end
    return nil
end

-- Include a non-floating terminal for custom debug configs
function Globl.new_terminal(cmd, extra)
    extra = extra or {}
    local dir = extra.dir or "horizontal"

    -- Open a split in the requested direction
    vim.cmd(dir == "vertical" and "vsplit" or "split")

    local winid = vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(winid, bufnr)

    -- Apply requested size, if any
    if extra.size then
        if dir == "vertical" then
            vim.api.nvim_win_set_width(winid, extra.size)
        else
            vim.api.nvim_win_set_height(winid, extra.size)
        end
    end

    local job_id
    vim.api.nvim_buf_call(bufnr, function()
        job_id = vim.fn.termopen(cmd, {
            on_exit = function()
                if not extra.keep_open and vim.api.nvim_win_is_valid(winid) then
                    vim.api.nvim_win_close(winid, true)
                end
            end,
        })
    end)

    vim.cmd("startinsert")

    local group = vim.api.nvim_create_augroup("ServeTerm_" .. winid, { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        pattern = tostring(winid),
        once = true,
        callback = function()
            if job_id then
                vim.fn.jobstop(job_id)
            end
        end,
    })
end

-- Terminal
local function create_terminal_buffer()
    state.buf = vim.api.nvim_create_buf(false, true)

    vim.bo[state.buf].bufhidden = "hide"
    vim.bo[state.buf].filetype = "debugterm"
end

local function ensure_terminal_window()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
            vim.api.nvim_win_set_buf(state.win, state.buf)
        end
        return
    end

    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.7)

    state.win = vim.api.nvim_open_win(state.buf, true, {
        relative = "editor",
        style = "minimal",
        border = "rounded",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) * 0.5),
        col = math.floor((vim.o.columns - width) * 0.5),
    })
end

function M.close_terminal()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_close(state.win, true)
        state.win = nil
        return
    end
end

function M.toggle_terminal()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_close(state.win, true)
        state.win = nil
        return
    end

    if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
        create_terminal_buffer()
    end
    ensure_terminal_window()
    if state.job then
        vim.cmd.startinsert()
    end
end

-- Helpers
local function stop_terminal()
    if state.job then
        pcall(vim.fn.jobstop, state.job)
        pcall(vim.fn.chanclose, state.job)
        state.job = nil
    end

    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_close(state.win, true)
        state.win = nil
    end
end

local function stop_dap()
    local dap = get_dap()
    if dap then pcall(dap.disconnect) end
end

function M.stop()
    stop_terminal()
    stop_dap()
end

local function run_terminal(command, after)
    stop_terminal()
    -- Clear old buffer
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
        state.buf = nil
    end

    create_terminal_buffer()
    ensure_terminal_window()

    -- Ensure we run termopen inside the newly created terminal window
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_set_current_win(state.win)
    end

    state.job = vim.fn.termopen(command, {
        detach = 0,
        on_exit = function(_, code)
            state.job = nil
            vim.cmd.stopinsert()
            vim.schedule(function()
                if (not state.action.keep_open) and code == 0 then
                    M.close_terminal()
                end
                if after then after(code) end
            end)
        end,
    })

    vim.cmd.startinsert()
end

local function guess_executable()
    if state.last_executable ~= "" then
        return state.last_executable
    end

    local folder = vim.fn.fnamemodify(state.cwd, ":t")

    local guesses = {
        "./build/" .. folder,
        "./build/main",
        "./build/a.out",
        "./" .. folder,
    }
    for _, path in ipairs(guesses) do
        if vim.fn.executable(path) == 1 then
            return path
        end
    end
    return "./a.out"
end

local function ask_executable()
    if vim.g.askcppexec then
        return vim.g.askcppexec
    end
    local result = vim.fn.input({
        prompt = "Executable: ",
        default = guess_executable(),
        completion = "file",
    })
    if result ~= "" then
        state.last_executable = result
    end

    return result
end

function Globl.launch_cpp_dap(progr)
    local dap = get_dap()
    if not dap then
        vim.notify("myplugin: nvim-dap not available (or use_dap = false)", vim.log.levels.ERROR)
        return
    end

    dap.run({
        name = "Launch executable",
        type = "cppdbg",
        request = "launch",
        program = progr,
        cwd = "${workspaceFolder}",
        stopAtEntry = false,
        logging = {
            moduleLoad = false,
            programOutput = true,--false,
        },
        setupCommands = {
            { text = "-enable-pretty-printing" },
            { text = "set print pretty on" },
            { text = "set print array on" },
            { text = "set print elements unlimited" },
            { text = "set print thread-events off" },
            { text = "add-auto-load-safe-path /" },
        }
    })
end

function Globl.latex_compile(file)
    local outfle = vim.fn.shellescape("/tmp/" .. vim.fn.fnamemodify(file, ":t:r"))
    local onfail = " || { rm " .. outfle .. "*; exit 1; }"
    local build = "texfot latexmk -pdf -file-line-error -halt-on-error -synctex=1 -outdir=/tmp " .. vim.fn.shellescape(file)
    return build .. onfail
end

function Globl.latex_view(file)
    local outfname = "/tmp/" .. vim.fn.fnamemodify(file, ":t:r") .. ".pdf"
    local inverse_search = string.format(
        'nvim --server %s --remote-send "<C-\\><C-N>:e %%1<CR>:%%2<CR>"',
        vim.v.servername
    )
    vim.system({
        "sioyek",
        -- The current latex file and line in it
        "--forward-search-file", vim.fn.expand('%:p'),
        "--forward-search-line", tostring(vim.fn.line('.')),
        -- Connect it to the current nvim instance
        "--inverse-search", inverse_search,
        -- And display the output file
        outfname,
    })
end

-- Actions
local function get_actions()
    local actions = {}
    local ft = vim.bo.filetype
    local dap = get_dap()

    if dap and ft ~= "cpp" and ft ~= "c" then
        -- Auto import dap configs
        local bufnr = vim.api.nvim_get_current_buf()

        for _, provider in pairs(dap.providers.configs) do
            local confs = provider(bufnr) or {}
            for _, config_ in ipairs(confs) do
                table.insert(actions, {
                    label = "[dap] " .. config_.name,

                    after = function()
                        M.stop()
                        dap.run(config_)
                    end,
                })
            end
        end
    end

    -- Add extra
    if ft == "cpp" or ft == "c" or ft == "rust" then
        table.insert(actions, {
            label = "Run executable",
            after = function()
                M.stop()
                Globl.launch_cpp_dap(ask_executable())
            end,
        })
    end
    if ft == "cpp" or ft == "c" then
        table.insert(actions, {
            label = "Compile current file to /tmp and debug",

            terminal = function()
                return string.format(
                    "g++ -g %s -o /tmp/out -O0",
                    vim.fn.shellescape(state.fname)
                )
            end,
            after = function(code)
                if code == 0 then Globl.launch_cpp_dap("/tmp/out") end
            end,
        })
    end
    if ft == "cpp" or ft == "c" or ft == "make" then
        table.insert(actions, {
            label = "Build",

            terminal = function()
                return "make"
            end,
        })

        table.insert(actions, {
            label = "Build debug then run",

            terminal = function()
                return "make debug"
            end,
            after = function(code)
                if code == 0 then Globl.launch_cpp_dap(ask_executable()) end
            end,
        })
    end
    if ft == "tex" or ft == "plaintex" or ft == "latex" then
        table.insert(actions, {
            label = "Compile & view LaTeX",
            terminal = function() return Globl.latex_compile(state.fname) end,
            after = function(code)
                if code == 0 then Globl.latex_view(state.fname) end
            end
        })
        table.insert(actions, {
            label = "Compile LaTeX",
            terminal = function() return Globl.latex_compile(state.fname) end,
        })
    end
    if ft == "markdown" then
        table.insert(actions, {
            label = "Compile markdown",
            terminal = function()
                local outfname = vim.fn.shellescape("/tmp/" .. vim.fn.fnamemodify(state.fname, ":t:r") .. ".html")
                return string.format(
                    "cd %s && pandoc --standalone --embed-resources --resource-path=. --include-in-header=%s %s -o %s && xdg-open %s",
                    vim.fn.shellescape(vim.fn.fnamemodify(state.fname, ":h")),
                    [[<(printf '%s\n' '<link rel="stylesheet" href="https://unpkg.com/sakura.css/css/sakura.css">')]],
                    vim.fn.shellescape(vim.fn.fnamemodify(state.fname, ":t")),
                    outfname, outfname
                )
            end,
        })
    end
    if ft == "html" then
        table.insert(actions, {
            label = "View file",
            terminal = function()
                return "xdg-open " .. vim.fn.shellescape(state.fname)
            end
        })
        table.insert(actions, {
            label = "Run http server",
            terminal = "python3 -m http.server"
        })
    end

    return actions
end

-- Runner
local function execute()
    if state.action.terminal then
        local command = state.action.terminal
        if type(command) == "function" then
            command = command()
        end
        if not command then
            vim.notify("No build command found")
            return
        end

        run_terminal(command, state.action.after)
        return
    elseif state.action.after then
        state.action.after(0)
    end
end

function Globl.run_debug(action)
    state.fname = vim.fn.expand("%")
    state.cwd = vim.fn.getcwd()
    state.line = vim.fn.line(".")
    state.action = action
    execute()
end

-- Picker
function M.pick()
    local actions = get_actions()
    if type(_G.DebugActions) == "function" then
        DebugActions(actions)
    end
    if #actions == 0 then
        vim.notify("No file actions found for filetype: " .. vim.bo.filetype)
        return
    end
    vim.ui.select(actions, {
        prompt = "Debug",
        format_item = function(item)
            return item.label
        end,
    }, function(choice)
        if choice then
            vim.schedule(function() Globl.run_debug(choice) end)
        end
    end)
end

function M.run_last()
    if not state.action then
        vim.notify("No previous debug action")
        return
    end

    M.stop()
    vim.defer_fn(execute, 50)
end

function M.continue_or_start()
    local dap = get_dap()
    if dap and dap.session() then
        dap.continue()
    else
        M.pick()
    end
end

return M
