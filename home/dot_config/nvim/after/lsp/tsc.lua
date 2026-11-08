-- ┌────────────────────────────────────┐
-- │ TypeScript 7 language server (tsc) │
-- └────────────────────────────────────┘
--
-- Background, because there are three easily confused names:
-- - 'vtsls'  - wrapper around VS Code's TypeScript service, i.e. tsserver: the
--              original JavaScript implementation (TypeScript 5.x line). This is
--              the "old" server. Its config is kept, inert, in 'after/lsp/vtsls.lua'.
-- - 'tsgo'   - the native Go port while it was a preview, published as
--              '@typescript/native-preview'. Superseded: TypeScript 7 now ships
--              as the regular `typescript` npm package, whose `tsc` binary is the
--              native implementation. Nothing here needs 'tsgo' anymore.
-- - 'tsc'    - what to use. Installed via Mason as `typescript@7`, and also the
--              server name in nvim-lspconfig ('lsp/tsgo.lua' there is only a
--              deprecation shim forwarding to 'lsp/tsc.lua', slated for removal
--              in nvim-lspconfig 3.0.0).
--
-- The language server mode (`--lsp`) only exists in the native compiler,
-- TypeScript 7.0+. An older `tsc` (e.g. a project's own TypeScript 5.x in
-- 'node_modules/.bin') will silently fail to serve LSP, so any candidate binary
-- must be version-gated before use.
--
-- Why `cmd` and `root_dir` are both defined here:
-- Upstream's 'tsc' config discovers the binary inside its own `root_dir` and
-- stashes it for `cmd` to read. Overriding `root_dir` (done below, to prefer a
-- monorepo root) would leave that lookup unpopulated and `cmd` would fall back
-- to a bare `tsc`. So the two have to be replaced together.

--- Does `bin` support `--lsp`? True only for TypeScript >= 7.0.
--- Mirrors the check in nvim-lspconfig's 'lsp/tsc.lua'.
---@param bin string
---@return boolean
local supports_lsp = function(bin)
  if vim.fn.executable(bin) ~= 1 then return false end

  local out = vim.system({ bin, '--version' }, { text = true }):wait()
  if out.code ~= 0 then return false end

  -- Output looks like `Version 7.0.2`
  local ok, version = pcall(vim.version.parse, out.stdout or '')
  return ok and version ~= nil and version.major >= 7
end

-- Resolving spawns a short-lived `--version` process per candidate, so remember
-- the answer per project root.
local bin_cache = {} ---@type table<string, string>

--- Find a TypeScript 7+ binary for `root`.
---@param root string|nil
---@return string|nil
local resolve_tsc = function(root)
  if root and bin_cache[root] then return bin_cache[root] end

  local candidates = {}
  -- 1. The project's own TypeScript, so a repo pinning its version wins.
  if root then table.insert(candidates, vim.fs.joinpath(root, 'node_modules', '.bin', 'tsc')) end
  -- 2. Mason's copy, by absolute path. Using the path rather than relying on
  --    $PATH avoids a startup race: Mason only prepends its bin directory when
  --    `mason.setup()` runs, which is deferred when Neovim starts without file
  --    arguments (see the note in 'plugin/40_plugins.lua').
  table.insert(candidates, vim.fs.joinpath(vim.fn.stdpath('data'), 'mason', 'bin', 'tsc'))
  -- 3. Whatever is on $PATH.
  table.insert(candidates, 'tsc')

  for _, bin in ipairs(candidates) do
    if supports_lsp(bin) then
      if root then bin_cache[root] = bin end
      return bin
    end
  end
end

-- Auto-import tuning for monorepos with subpath exports, like
-- `@frame/ui/components/button`. Ported from the previous vtsls setup.
--
-- NOTE: this server takes a single unified `js/ts` settings section, unlike
-- vtsls which split settings across `typescript` / `javascript` / `vtsls`.
-- Every key below was checked against the binary's own config tags.
local preferences = {
  importModuleSpecifier = 'non-relative',
  importModuleSpecifierEnding = 'minimal',
  includePackageJsonAutoImports = 'on',
  preferTypeOnlyAutoImports = true,
  jsxAttributeCompletionStyle = 'auto',
  autoImportFileExcludePatterns = {
    '**/.next/**',
    '**/dist/**',
    '**/.turbo/**',
  },
}

-- Dropped in the port from vtsls, as this server has no equivalent:
-- - `vtsls.autoUseWorkspaceTsdk` - vtsls-specific, and moot: the binary chosen
--   above *is* the TypeScript being run, there is no separate tsdk to select.
-- - `typescript.suggestionActions.enabled` - no such setting.
-- - `typescript.suggest.enabled` - individual `suggest.*` keys exist (below),
--   but there is no master on/off switch.

---@type vim.lsp.Config
return {
  cmd = function(dispatchers, config)
    local bin = resolve_tsc(config and config.root_dir)
    if bin == nil then
      error('tsc: no binary supporting `--lsp` found (requires TypeScript 7.0+). Install it with `:Mason` -> tsc.')
    end
    return vim.lsp.rpc.start({ bin, '--lsp', '--stdio' }, dispatchers)
  end,

  -- Prefer an explicit monorepo root over the nearest package manager lockfile,
  -- so one server covers the whole workspace instead of one per package.
  root_dir = function(bufnr, on_dir)
    local root = vim.fs.root(bufnr, {
      'pnpm-workspace.yaml',
      'turbo.json',
      'nx.json',
      '.git',
    })

    if root == nil then root = vim.fs.root(bufnr, { 'package.json' }) end

    on_dir(root or vim.fn.getcwd())
  end,

  settings = {
    ['js/ts'] = {
      preferences = preferences,
      suggest = {
        autoImports = true,
        includeCompletionsForImportStatements = true,
      },
    },
  },
}
