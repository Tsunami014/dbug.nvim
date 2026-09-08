vim.g.mapleader = " "
vim.opt.number = true

-- Resolve the plugin root as the parent of this file's directory
local this_file = debug.getinfo(1, "S").source:sub(2)
local test_dir = vim.fn.fnamemodify(this_file, ":h")
local plugin_dir = vim.fn.fnamemodify(test_dir, ":h")

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- Disable netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("lazy").setup({
    { "nvim-tree/nvim-tree.lua" },
    {
        "dbug.nvim",
        name = "dbug",
        main = "dbug",
        dev = true,
        dir = plugin_dir,
        opts = {
            use_dap = true, -- flip to false to test the no-dap path
        },
        dependencies = {
            "mfussenegger/nvim-dap",
            "rcarriga/nvim-dap-ui",
            "nvim-neotest/nvim-nio", -- required by nvim-dap-ui
            "akinsho/toggleterm.nvim",
            -- "mfussenegger/nvim-dap-python", -- only needed for the Python template
        },
    },
}, {
    root = vim.fn.stdpath("data") .. "/lazy",
})

require("nvim-tree").setup({
  git = {
    enable = true,
    ignore = false,
  },
  filters = {
    git_ignored = false,
    dotfiles = false,
  },
})

require("toggleterm").setup()

local dap = require("dap")
local dapui = require("dapui")
dapui.setup()

local dbug = require("dbug.debug")
local envf = require("dbug.envfile")


vim.keymap.set("n", "Q", "<cmd>q<cr>", { desc = ":q" })

vim.keymap.set("n", "<F4>", dbug.stop, { desc = "Stop debugging" })
vim.keymap.set("n", "<F5>", dbug.continue_or_start, { desc = "Continue or start debugging" })
vim.keymap.set("n", "<F6>", dbug.run_last, { desc = "Run last debug" })
vim.keymap.set("n", "<F9>", dap.step_into, { desc = "DAP step into" })
vim.keymap.set("n", "<F10>", dap.step_over, { desc = "DAP step over" })
vim.keymap.set("n", "<F11>", dap.step_out, { desc = "DAP step out" })

vim.keymap.set("n", "<leader>E", "<cmd>NvimTreeOpen<cr>", { desc = "Open file tree" })

vim.keymap.set("n", "<leader>dd", dbug.toggle_terminal, { desc = "Toggle debug terminal" })
vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "DAP UI toggle" })
vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })

vim.keymap.set("n", "<leader>ee", envf.dirch, { desc = "Reload env files" })
vim.keymap.set("n", "<leader>eE", envf.genfile, { desc = "Create template env file" })
vim.keymap.set("n", "<leader>et", envf.untrust, { desc = "Remove config trust" })
