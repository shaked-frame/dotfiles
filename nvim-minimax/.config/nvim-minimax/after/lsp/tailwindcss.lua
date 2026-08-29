-- ┌────────────────────────────┐
-- │ Tailwind CSS Language Server │
-- └────────────────────────────┘
--
-- Keep this close to the stock lspconfig setup and only add the monorepo-
-- specific pieces needed for Frame's Tailwind v4 shared CSS entrypoint.

local util = require("lspconfig.util")

return {
  settings = {
    tailwindCSS = {
      hovers = true,
      suggestions = true,
      validate = true,
      classFunctions = {
        "cn",
        "cva",
        "clsx",
        "twMerge",
      },
      experimental = {
        configFile = "/Users/shakedhagag/frame/frontend/packages/ui/src/styles/globals.css",
      },
    },
  },
  before_init = function(_, config)
    config.settings = vim.tbl_deep_extend("keep", config.settings or {}, {
      editor = {
        tabSize = vim.lsp.util.get_effective_tabstop(),
      },
    })
  end,
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local root_files = {
      "tailwind.config.js",
      "tailwind.config.cjs",
      "tailwind.config.mjs",
      "tailwind.config.ts",
      "postcss.config.js",
      "postcss.config.cjs",
      "postcss.config.mjs",
      "postcss.config.ts",
      ".git",
    }

    root_files = util.insert_package_json(root_files, "tailwindcss", fname)
    on_dir(vim.fs.dirname(vim.fs.find(root_files, { path = fname, upward = true })[1]))
  end,
}
