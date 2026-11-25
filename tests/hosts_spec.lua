-- Run: nvim -l tests/hosts_spec.lua   (from the repo root)
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path
local hosts = require "gitlink.hosts"

local SHA = "6e72591734ad15ef4bc48d82dda3b5f860677d60"
local cases = {
  -- { remote, user_hosts, line1, line2, expected }
  { "git@github.com:a/b.git", {}, 5, 5, "https://github.com/a/b/blob/" .. SHA .. "/f.lua#L5" },
  { "https://github.com/a/b", {}, 5, 9, "https://github.com/a/b/blob/" .. SHA .. "/f.lua#L5-L9" },
  { "git@git.acme.xxx:team/repo.git", { ["git.acme.xxx"] = "github" }, 221, 221,
    "https://git.acme.xxx/team/repo/blob/" .. SHA .. "/f.lua#L221" },
  { "git@gitlab.com:grp/sub/repo.git", {}, 5, 9, "https://gitlab.com/grp/sub/repo/-/blob/" .. SHA .. "/f.lua#L5-9" },
  { "https://gitlab.acme.xxx/grp/repo.git", {}, 5, 5, "https://gitlab.acme.xxx/grp/repo/-/blob/" .. SHA .. "/f.lua#L5" },
  { "git@bitbucket.org:team/repo.git", {}, 5, 9, "https://bitbucket.org/team/repo/src/" .. SHA .. "/f.lua#lines-5:9" },
  { "ssh://git@bitbucket.acme.xxx:7999/proj/repo.git", {}, 5, 9,
    "https://bitbucket.acme.xxx/projects/PROJ/repos/repo/browse/f.lua?at=" .. SHA .. "#5-9" },
  { "https://user@bitbucket.acme.xxx/scm/proj/repo.git", {}, 5, 5,
    "https://bitbucket.acme.xxx/projects/PROJ/repos/repo/browse/f.lua?at=" .. SHA .. "#5" },
  { "https://code.acme.xxx/bitbucket/scm/proj/repo.git", {}, 5, 5,
    "https://code.acme.xxx/bitbucket/projects/PROJ/repos/repo/browse/f.lua?at=" .. SHA .. "#5" },
  { "ssh://git@code.acme.xxx:7999/~jdoe/dotfiles.git", {}, 5, 5,
    "https://code.acme.xxx/users/jdoe/repos/dotfiles/browse/f.lua?at=" .. SHA .. "#5" },
  { "https://git.acme.xxx:8443/u/r.git", { ["git.acme.xxx"] = "gitlab" }, 5, 5,
    "https://git.acme.xxx:8443/u/r/-/blob/" .. SHA .. "/f.lua#L5" },
}

local fail = 0
for _, c in ipairs(cases) do
  local r = assert(hosts.parse(c[1]), "parse failed: " .. c[1])
  local kind = hosts.detect(r, c[2])
  local got = hosts.format[kind](r, SHA, "f.lua", c[3], c[4])
  if got ~= c[5] then
    fail = fail + 1
    print(("FAIL %s\n  want %s\n  got  %s"):format(c[1], c[5], got))
  end
end
local _, guessed = hosts.detect(hosts.parse "git@git.unknown.com:a/b.git", {})
if not guessed then
  fail = fail + 1
  print "FAIL unknown host should be flagged as guessed"
end
print(("%d/%d passed"):format(#cases + 1 - fail, #cases + 1))
os.exit(fail == 0 and 0 or 1)
