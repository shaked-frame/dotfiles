-- ┌─────────────────────┐
-- │ Harper (prose lint) │
-- └─────────────────────┘
--
-- 'harper-ls' (Mason package: 'harper-ls'). Spelling + grammar diagnostics
-- with quickfix code actions for markdown — the built-in `spell` flagging in
-- 'after/ftplugin/markdown.lua' has no hover and no actions.
-- Source: https://writewithharper.com/docs/integrations/neovim
return {
  filetypes = { 'markdown' },
}
