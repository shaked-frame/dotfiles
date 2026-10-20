-- ┌────────────────────────┐
-- │ Oxlint language server │
-- └────────────────────────┘
--
-- Two overrides over stock 'nvim-lspconfig' ('lsp/oxlint.lua'):
-- 1. `root_dir`: prefer the monorepo root ('pnpm-workspace.yaml', '.git')
--    before nested '.oxlintrc.json' files (such as 'frontend/apps/web/.oxlintrc.json',
--    which extends '../../../.oxlintrc.json'). That way one 'oxlint --lsp'
--    instance covers the workspace, finds hoisted 'node_modules/.bin/oxlint'
--    and JS plugins, and uses oxlint's built-in nested config support.
-- 2. `typeAware = false`: '.oxlintrc.json' sets `typeAware: true` for CLI
--    `pnpm lint`, and upstream's `before_init` also auto-enables
--    `typeAware = true` when `tsgolint` is installed. Inside the editor,
--    `tsc --lsp` (TypeScript 7) already runs live type-checking; running a
--    second `tsgolint` pass inside `oxlint --lsp` on every keystroke takes
--    1.5-1.8s per edit and blocks `vim.lsp.buf.code_action()` (`gra` /
--    `<Leader>la`), which waits for all attached codeAction servers to respond.

---@type vim.lsp.Config
return {
  root_dir = function(bufnr, on_dir)
    if not vim.fs.root(bufnr, { '.oxlintrc.json', '.oxlintrc.jsonc', 'oxlint.config.ts' }) then
      return
    end
    local root = vim.fs.root(bufnr, {
      'pnpm-workspace.yaml',
      '.git',
      '.oxlintrc.json',
      '.oxlintrc.jsonc',
      'oxlint.config.ts',
    })
    if root then on_dir(root) end
  end,
  settings = {
    typeAware = false,
  },
  before_init = function(init_params, config)
    local settings = vim.tbl_extend('force', config.settings or {}, {
      typeAware = false,
    })
    local init_options = config.init_options or {}
    init_options.settings = vim.tbl_extend('force', init_options.settings or {}, settings)
    init_params.initializationOptions = init_options
  end,
}
