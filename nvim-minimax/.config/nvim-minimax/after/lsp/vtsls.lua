-- ┌─────────────────────┐
-- │ TypeScript via VTSLS │
-- └─────────────────────┘
--
-- This config tunes TypeScript/JavaScript auto-imports for monorepos with
-- subpath exports, like `@frame/ui/components/button`.

local import_preferences = {
  importModuleSpecifier = "non-relative",
  importModuleSpecifierEnding = "minimal",
  includePackageJsonAutoImports = "on",
  preferTypeOnlyAutoImports = true,
  jsxAttributeCompletionStyle = "auto",
  autoImportFileExcludePatterns = {
    "**/.next/**",
    "**/dist/**",
    "**/.turbo/**",
  },
}

local suggest_settings = {
  enabled = true,
  autoImports = true,
  includeCompletionsForImportStatements = true,
}

return {
  root_dir = function(bufnr, on_dir)
    local root = vim.fs.root(bufnr, {
      "pnpm-workspace.yaml",
      "turbo.json",
      "nx.json",
      ".git",
    })

    if root == nil then
      root = vim.fs.root(bufnr, { "package.json" })
    end

    on_dir(root or vim.fn.getcwd())
  end,
  settings = {
    vtsls = {
      autoUseWorkspaceTsdk = true,
    },
    typescript = {
      suggest = suggest_settings,
      preferences = import_preferences,
      suggestionActions = {
        enabled = true,
      },
    },
    javascript = {
      suggest = suggest_settings,
      preferences = import_preferences,
      suggestionActions = {
        enabled = true,
      },
    },
  },
}
