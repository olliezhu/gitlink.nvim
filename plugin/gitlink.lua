-- :GitLink [copy|open], accepts a range (e.g. :'<,'>GitLink)
if vim.g.loaded_gitlink then
  return
end
vim.g.loaded_gitlink = true

vim.api.nvim_create_user_command("GitLink", function(opts)
  local action = opts.args ~= "" and opts.args or "copy"
  local gitlink = require "gitlink"
  if not gitlink[action] or action == "setup" or action == "url" then
    return vim.notify("GitLink: unknown action " .. action, vim.log.levels.ERROR)
  end
  gitlink[action](opts)
end, {
  nargs = "?",
  range = true,
  complete = function()
    return { "copy", "open" }
  end,
  desc = "Copy/open a permalink to the current line(s)",
})
