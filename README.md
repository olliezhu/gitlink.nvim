# gitlink.nvim

Copy or open a permalink to the current line or selection, pinned to a commit SHA, on its repository's forge.

## Requirements

- `git`
- Neovim ≥ 0.11
- A clipboard provider

Supported forges (cloud or self-hosted):
- Bitbucket (Cloud or Server/Data Center)
- GitHub
- GitLab

## Install (lazy.nvim)

```lua
{
  "olliezhu/gitlink.nvim",
  cmd = "GitLink",
  keys = {
    { "<leader>gl", function() require("gitlink").copy() end, mode = { "n", "x" }, desc = "git copy permalink" },
    { "<leader>gL", function() require("gitlink").open() end, mode = { "n", "x" }, desc = "git open permalink" },
  },
  opts = {
    -- Only needed for self-hosted servers whose hostname doesn't say what they are; e.g.,
    -- hosts = { ["git.acme.xxx"] = "github" }, -- github | gitlab | bitbucket_cloud | bitbucket_server
  },
}
```

## Testing

```sh
nvim -l tests/hosts_spec.lua
```

## License

MIT. See [LICENSE](LICENSE).
