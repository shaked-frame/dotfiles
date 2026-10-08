-- ┌──────────────────────────┐
-- │ Markdown & MDX rendering │
-- └──────────────────────────┘
--
-- 'render-markdown.nvim' renders markdown directly in the buffer (headings,
-- code blocks, lists, checkboxes, tables, quotes). Pure Lua, no build step.
-- Editing stays native: anti-conceal reveals markup on the cursor row.
--
-- MDX shims (Neovim detects no `*.mdx` filetype out of the box, and the
-- tree-sitter autostart in 'plugin/40_plugins.lua' only covers `markdown`):
-- - `vim.filetype.add` maps `*.mdx` to the `mdx` filetype
-- - the `markdown` parser is registered for `mdx` and started on `FileType`

vim.filetype.add({ extension = { mdx = 'mdx' } })

local add = vim.pack.add
local later = Config.later

later(function()
  add({ 'https://github.com/MeanderingProgrammer/render-markdown.nvim' })

  -- Parse MDX and Octo (GitHub PR/comment) buffers with the markdown grammar.
  vim.treesitter.language.register('markdown', { 'mdx', 'octo' })
  local ts_start = function(ev) vim.treesitter.start(ev.buf) end
  Config.new_autocmd('FileType', { 'mdx', 'octo' }, ts_start, 'Start tree-sitter for MDX/Octo')

  require('render-markdown').setup({
    file_types = { 'markdown', 'mdx', 'octo' },
    html = {
      tag = {
        details = { icon = '' },
        summary = { icon = '▸ ', highlight = 'RenderMarkdownH6' },
        a = { icon = '󰌹 ', highlight = 'RenderMarkdownLink' },
        img = { icon = '󰥶 ', highlight = 'RenderMarkdownLink' },
      },
    },
  })
end)
