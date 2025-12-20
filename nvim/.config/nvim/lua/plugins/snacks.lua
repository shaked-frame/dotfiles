return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      hidden = true, -- show hidden files
      sources = {
        files = {
          hidden = true, -- show hidden files
          ignored = true,
          exclude = { "node_modules", ".next", ".husky", "migrations", ".turbo", ".vercel", "bin", "dist", ".git" },
        },
        grep = {
          hidden = true, -- search in hidden files
          ignored = true,
          exclude = { "node_modules", ".next", ".husky", "migrations", ".turbo", ".vercel", "bin", "dist", ".git" },
        },
      },
    },
    dashboard = {
      enabled = true,
      sections = {
        {
          section = "terminal",
          cmd = "chafa ~/.config/logo.png; sleep .1",
          height = 20,
          padding = 1,
        },
        {
          pane = 2,
          { section = "keys", gap = 1, padding = 1 },
          { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = { 2, 2 } },
        },
        {
          pane = 2,
          icon = " ",
          title = "Open PRs",
          cmd = "gh pr list -L 3",
          key = "P",
          action = function()
            vim.fn.jobstart("gh pr list --web", { detach = true })
          end,
          height = 7,
        },
      },
    },
  },
}
