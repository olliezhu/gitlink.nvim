-- gitlink.nvim: permalinks to the current line/range on forge
local hosts = require "gitlink.hosts"

local M = {}

local config = {
  --- host -> type for self-hosted instances the heuristics can't identify
  --- types: "github" | "gitlab" | "bitbucket_cloud" | "bitbucket_server"
  hosts = {},
  --- remote to use when the current branch has no upstream
  remote = "origin",
}

local warned = {}

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
  local lowered = {}
  for h, t in pairs(config.hosts) do
    assert(hosts.format[t], ("gitlink: unknown host type %q for %s"):format(t, h))
    lowered[h:lower()] = t
  end
  config.hosts = lowered
end

local function git(dir, args)
  local res = vim.system(vim.list_extend({ "git", "-C", dir }, args), { text = true }):wait()
  if res.code ~= 0 then
    return nil
  end
  return vim.trim(res.stdout)
end

local function encode(path)
  return (path:gsub("[^%w%-%._~/]", function(c)
    return ("%%%02X"):format(c:byte())
  end))
end

--- Current buffer's repo root and repo-relative path
local function context()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    return nil, "buffer has no file"
  end
  local file = vim.uv.fs_realpath(name) or name
  local dir = vim.fs.dirname(file)
  local root = git(dir, { "rev-parse", "--show-toplevel" })
  if not root then
    return nil, "not in a git repo"
  end
  root = vim.uv.fs_realpath(root) or root
  return { dir = dir, root = root, rel = vim.fs.relpath(root, file) }
end

local function lines(opts)
  if opts and opts.range and opts.range > 0 then
    return opts.line1, opts.line2
  end
  if vim.fn.mode():match "[vV\22]" then
    local a, b = vim.fn.line "v", vim.fn.line "."
    vim.api.nvim_feedkeys(vim.keycode "<Esc>", "n", false)
    return math.min(a, b), math.max(a, b)
  end
  local l = vim.fn.line "."
  return l, l
end

--- Build the link for the current buffer and line range
--- @return string? url, string? err
function M.url(opts)
  local l1, l2 = lines(opts)
  local ctx, err = context()
  if not ctx then
    return nil, err
  end

  local branch = git(ctx.dir, { "branch", "--show-current" }) or ""
  local remote_name = branch ~= "" and git(ctx.dir, { "config", "--get", "branch." .. branch .. ".remote" }) or nil
  if not remote_name or remote_name == "." then
    remote_name = config.remote
  end
  local remote_url = git(ctx.dir, { "remote", "get-url", remote_name })
  if not remote_url then
    return nil, "no remote '" .. remote_name .. "'"
  end
  local r = hosts.parse(remote_url)
  if not r then
    return nil, "can't parse remote URL: " .. remote_url
  end

  local kind, guessed = hosts.detect(r, config.hosts)
  if guessed and not warned[r.host] then
    warned[r.host] = true
    vim.notify(
      ("gitlink: unknown host %s, assuming GitHub-style URLs. Set it in setup({ hosts = { [%q] = \"<type>\" } })"):format(r.host, r.host),
      vim.log.levels.WARN
    )
  end

  local sha = git(ctx.dir, { "rev-parse", "HEAD" })
  if not sha then
    return nil, "no commits yet"
  end
  if (git(ctx.dir, { "branch", "-r", "--contains", sha }) or "") == "" then
    vim.notify("gitlink: HEAD " .. sha:sub(1, 8) .. " isn't on any remote branch; the link may 404", vim.log.levels.WARN)
  end

  local url = hosts.format[kind](r, sha, encode(ctx.rel), l1, l2)
  if not url then
    return nil, ("can't build a %s URL from remote %s"):format(kind, remote_url)
  end
  return url
end

function M.copy(opts)
  local url, err = M.url(opts)
  if not url then
    return vim.notify("gitlink: " .. err, vim.log.levels.ERROR)
  end
  vim.fn.setreg("+", url)
  vim.notify("Copied: " .. url)
end

function M.open(opts)
  local url, err = M.url(opts)
  if not url then
    return vim.notify("gitlink: " .. err, vim.log.levels.ERROR)
  end
  vim.ui.open(url)
end

return M
