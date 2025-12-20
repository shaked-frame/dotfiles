return {
  "folke/snacks.nvim",
  opts = {
    picker = {
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
  },
}
