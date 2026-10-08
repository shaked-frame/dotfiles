-- vim-herdr-navigation — Neovim side loader.
--
-- Loads the editor integration shipped with the herdr plugin so `<C-h/j/k/l>`
-- moves between Neovim splits and, at a split edge, crosses into the
-- neighbouring herdr pane (see plugin README: vim-herdr-navigation).
--
-- Lives in `after/plugin` so it wins over the `<C-hjkl>` window mappings from
-- `mini.basics` (plugin/30_mini.lua). Resolves the plugin checkout by glob so
-- it survives `herdr plugin update` (the checkout dir contains a version
-- hash). Silently no-ops when the plugin is not installed — the
-- `mini.basics` mappings keep working.

local matches = vim.fn.globpath(
  vim.fn.expand('~/.config/herdr/plugins/github'),
  'vim-herdr-navigation-*/editor/nvim.lua',
  false,
  true
)
if type(matches) == 'table' and #matches > 0 and vim.fn.filereadable(matches[1]) == 1 then
  dofile(matches[1])
end
