-- ┌────────────────────────┐
-- │ JSON Language Server   │
-- └────────────────────────┘
--
-- 'vscode-json-language-server' (Mason package: 'json-lsp').
-- Source: https://github.com/hrsh7th/vscode-langservers-extracted
--
-- Handles 'json' and 'jsonc' (lspconfig's stock filetypes for this server;
-- see 'nvim-lspconfig''s 'lsp/jsonls.lua'). On its own it only validates
-- against whatever `$schema` a file happens to declare. 'b0o/schemastore.nvim'
-- feeds it the full SchemaStore catalog so files like 'package.json' and
-- 'tsconfig.json' get schema-driven completion, hover docs, and validation
-- without a `$schema` field.
return {
  settings = {
    json = {
      schemas = require('schemastore').json.schemas(),
      -- See https://github.com/b0o/SchemaStore.nvim/issues/8 for why this is
      -- recommended even though it reads as redundant.
      validate = { enable = true },
    },
  },
}
