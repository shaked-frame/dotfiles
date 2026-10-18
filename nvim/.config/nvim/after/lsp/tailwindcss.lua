-- ┌────────────────────────────┐
-- │ Tailwind CSS Language Server │
-- └────────────────────────────┘
--
-- Keep this close to the stock lspconfig setup and resolve Frame's Tailwind v4
-- shared CSS entrypoint from `Config.frame_root()` so worktrees under
-- `~/worktrees/frame/<name>/frame` use their own checkout's `globals.css`.

local util = require('lspconfig.util')

local function frame_globals_css(fname)
  local start = fname and fname ~= '' and vim.fs.dirname(fname) or nil
  local root = (Config and Config.frame_root and (Config.frame_root(start) or Config.frame_root()))
    or (vim.env.HOME and (vim.env.HOME .. '/frame'))
  return root and (root .. '/frontend/packages/ui/src/styles/globals.css') or nil
end

return {
  settings = {
    tailwindCSS = {
      hovers = true,
      suggestions = true,
      validate = true,
      classFunctions = {
        'cn',
        'cva',
        'clsx',
        'twMerge',
      },
      experimental = {
        configFile = frame_globals_css(),
      },
    },
  },
  before_init = function(params, config)
    local root_uri = params and params.rootUri
    local root_path = root_uri and vim.uri_to_fname(root_uri) or nil
    local css_file = frame_globals_css(root_path)
    config.settings = vim.tbl_deep_extend('keep', config.settings or {}, {
      editor = {
        tabSize = vim.lsp.util.get_effective_tabstop(),
      },
    })
    if css_file and config.settings.tailwindCSS and config.settings.tailwindCSS.experimental then
      config.settings.tailwindCSS.experimental.configFile = css_file
    end
  end,
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local root_files = {
      'tailwind.config.js',
      'tailwind.config.cjs',
      'tailwind.config.mjs',
      'tailwind.config.ts',
      'postcss.config.js',
      'postcss.config.cjs',
      'postcss.config.mjs',
      'postcss.config.ts',
      '.git',
    }

    root_files = util.insert_package_json(root_files, 'tailwindcss', fname)
    on_dir(vim.fs.dirname(vim.fs.find(root_files, { path = fname, upward = true })[1]))
  end,
}
