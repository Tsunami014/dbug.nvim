local M = {}

local config = require("dbug.config")


M.debug = require("dbug.debug")
M.envfile = require("dbug.envfile")

function M.setup(opts)
    opts = opts or {}
    for k, v in pairs(opts) do
        config[k] = v
    end

    M.envfile.setup() -- Required to load first
end

return M
