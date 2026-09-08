function DebugActions(actions)
    local ft = vim.bo.filetype
    table.insert(actions, 1, {
        label = "Test",
        terminal = "./test/run.sh",
    })
end
