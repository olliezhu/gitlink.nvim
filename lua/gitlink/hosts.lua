-- Remote URL parsing, host-type detection, and per-host permalink formats.
local M = {}

M.known = {
  ["github.com"] = "github",
  ["gitlab.com"] = "gitlab",
  ["bitbucket.org"] = "bitbucket_cloud",
}

function M.parse(url)
  local scheme, rest = url:match "^(%a[%w+.-]*)://(.+)$"
  local host, port, path
  if scheme then
    rest = rest:gsub("^[^@/]+@", "") -- drop user[:token]@
    host, port, path = rest:match "^([^/:]+):?(%d*)/(.*)$"
  else
    host, path = url:match "^[^@/]*@?([^:/]+):(.+)$"
    scheme = "ssh"
  end
  if not host or not path then
    return nil
  end
  path = path:gsub("^/+", ""):gsub("/+$", ""):gsub("%.git$", "")
  return { scheme = scheme, host = host, port = (port ~= "" and port or nil), path = path }
end

--- Decide which URL format a remote uses
--- @param r table parsed remote
--- @param user_hosts table<string,string> host -> type, from setup()
--- @return string type, boolean guessed
function M.detect(r, user_hosts)
  local h = r.host:lower()
  if user_hosts[h] then
    return user_hosts[h], false
  end
  if M.known[h] then
    return M.known[h], false
  end
  -- Bitbucket Server/Data Center: SSH on 7999, or HTTPS clone paths under /scm/.
  if r.port == "7999" or r.path:match "^scm/" or r.path:match "/scm/" then
    return "bitbucket_server", false
  end
  -- Hostname hints for self-hosted instances. Self-hosted Bitbucket is always Server/DC.
  for _, hint in ipairs { { "gitlab", "gitlab" }, { "bitbucket", "bitbucket_server" }, { "github", "github" } } do
    if h:find(hint[1], 1, true) then
      return hint[2], false
    end
  end
  return "github", true
end

local function origin(r)
  local web = r.scheme == "http" and "http" or "https"
  local port = (r.scheme == "http" or r.scheme == "https") and r.port and (":" .. r.port) or ""
  return web .. "://" .. r.host .. port
end

--- Formatters: (remote, sha, encoded_file_path, line1, line2) -> url
M.format = {
  github = function(r, sha, file, a, b)
    return ("%s/%s/blob/%s/%s#L%d%s"):format(origin(r), r.path, sha, file, a, a == b and "" or ("-L" .. b))
  end,
  gitlab = function(r, sha, file, a, b)
    return ("%s/%s/-/blob/%s/%s#L%d%s"):format(origin(r), r.path, sha, file, a, a == b and "" or ("-" .. b))
  end,
  bitbucket_cloud = function(r, sha, file, a, b)
    return ("%s/%s/src/%s/%s#lines-%d%s"):format(origin(r), r.path, sha, file, a, a == b and "" or (":" .. b))
  end,
  -- Clone URLs:  ssh://git@host:7999/proj/repo  |  https://host[/context]/scm/proj/repo
  -- Web URL:     https://host[/context]/projects/PROJ/repos/repo/browse/file?at=sha#10-20
  -- Personal repos use a ~user project key and live under /users/user/
  bitbucket_server = function(r, sha, file, a, b)
    local context, key, repo = r.path:match "^(.-)scm/([^/]+)/([^/]+)$"
    if not key then
      context, key, repo = "", r.path:match "^([^/]+)/([^/]+)$"
    end
    if not key then
      return nil
    end
    local ns = key:sub(1, 1) == "~" and ("users/" .. key:sub(2)) or ("projects/" .. key:upper())
    return ("%s/%s%s/repos/%s/browse/%s?at=%s#%d%s"):format(
      origin(r), context, ns, repo, file, sha, a, a == b and "" or ("-" .. b))
  end,
}

return M
