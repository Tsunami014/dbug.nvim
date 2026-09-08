# dbug.nvim
A debugger wrapper that can integrate with `nvim-dap`, with per-project configuration files!

## Features
- Launch terminals, including popup terminals or terminals on the sides of the screen
- Choose what debug action to run
- Create environment files to add per-project debug configurations (or just neovim configurations as a whole)
- Uses `vim.secure` so untrusted repos don't run code silently
- Includes some premade example/reference environment file options
- Includes premade debugger options for some filetypes (Though they require external packages to run, but you can always override it with your own config!)
- Super easy to use and run!
- Optionally combines well with `nvim-dap`, including all dap's configs in the debugger options!

## Requirements
- Neovim >= 0.10
- Optional [nvim-dap](https://github.com/mfussenegger/nvim-dap) for DAP features. Will not use dap if not available or if manually disabled (see config)
- Optional, only needed if you want the corresponding features (and you can always override them with your own debugging configuration):
  - `pandoc` - for compiling markdown
  - `texfot` + `latexmk`, and [sioyek](https://sioyek.info/) - for compiling and viewing LaTeX
  - `g++` - for compiling the current C/C++ file
  - `python3` (no packages) - for starting a local http server for HTML files

None of these are hard dependencies of the plugin itself — if a tool isn't
installed, the corresponding action just isn't offered (or notifies you and
no-ops), it won't break anything else.

## Installation
Here is an example of how to set it up using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "Tsunami014/dbug.nvim",
    dependencies = {
        "mfussenegger/nvim-dap", -- optional
    },
    opts = {
        -- see Configuration below
    },
}
```

If you're not using a plugin manager's `opts`/`config` auto-call, just make
sure `require("dbug").setup(...)` runs somewhere in your config.

## Configuration
Here is the default config (you do not have to include these keys unless you are changing something):

```lua
require("dbug").setup({
    -- If false, will not automatically include dap features
    use_dap = true,
})
```

## Usage
### Debugging
```lua
local dbug = require("dbug.debug")
```

- `dbug.pick()` - Opens the action picker for the buffer's filetype
- `dbug.continue_or_start()` - Continues an active dap session, otherwise opens the picker (use this for a "run/continue" keybind regardless of `use_dap`)
- `dbug.run_last()` - Re-run the last action (also remembers what file and directory was open)
- `dbug.stop()` - Stop the managed terminal and disconnect from any active dap sessions
- `dbug.toggle_terminal()` - Toggles the floating terminal used for build/run output
- `dbug.close_terminal()` - Closes the floating terminal if open

#### Example keymaps
```lua
local dbug = require("dbug.debug")

vim.keymap.set("n", "<F5>", dbug.continue_or_start, { desc = "Continue or start debugging" })
vim.keymap.set("n", "<F4>", dbug.stop, { desc = "Stop debugging" })
vim.keymap.set("n", "<F6>", dbug.run_last, { desc = "Run last debug action" })
vim.keymap.set("n", "<leader>dd", dbug.toggle_terminal, { desc = "Toggle debug terminal" })
```

#### The `Dbug` global table
These are helpers for convenience when creating custom debug configurations.
See `:DbugTemplates` for the example debug templates to copy off of for usages of these functions.

- `Dbug.new_terminal(cmd, opts)` - Launches a terminal running the command
- `Dbug.launch_cpp_dap(program)` - Launches `program` under `nvim-dap`'s `cppdbg` adapter
- `Dbug.latex_compile(file)` - Returns a shell command that compiles `file` with latexmk
- `Dbug.latex_view(file)` - Opens `file`'s compiled PDF in sioyek with synctex!
- `Dbug.run_debug(action)` - Runs the debug action as if the user pressed it in the dialog


### Environment files
```lua
local envf = require("dbug.envfile")
```

- `envf.genfile()` - Prompts for which template to use and writes it to the corresponding file in the current directory
- `envf.dirch()` - Load the current directory's `.nvim.lua`/`.nvimrc`, if any. Called automatically whenever the directory changes and on startup.
- `env.showfile()` - Open a buffer of the current directory's environment file
- `envf.untrust()` - Removes Neovim's trust decision for the current directory's env file, so you'll be prompted again.

This is loaded when `require("dbug").setup()` is called, and sets up the directory change and startup hooks automatically. It also sets up the `:DbugTemplates` command

#### Example keymaps
```lua
local envf = require("dbug.envfile")

vim.keymap.set("n", "<leader>ee", envf.dirch, { desc = "Reload env files" })
vim.keymap.set("n", "<leader>eE", envf.genfile, { desc = "Create template env file" })
vim.keymap.set("n", "<leader>eo", envf.showfile, { desc = "Edit env file" })
vim.keymap.set("n", "<leader>et", "<cmd>DbugTemplates<cr>", { desc = "Display debug templates" })
vim.keymap.set("n", "<leader>eT", envf.untrust, { desc = "Remove env file trust" })
```

#### Writing your own environment file
Use `:DbugTemplates` to see all the environment file templates to get an idea as to how they are created and used.


## Testing this plugin locally
Run `test/run.sh` to run an isolated Nvim config with this folder as a plugin.
See `test/init.lua` for keybinds and other config.
