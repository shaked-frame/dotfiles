-- ┌────────────────────┐
-- │ LSP config example │
-- └────────────────────┘
--
-- This file contains configuration of 'lua_ls' language server.
-- Source: https://github.com/LuaLS/lua-language-server
--
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`.
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.
--
-- This config is designed for Lua's activity around Neovim. It provides only
-- basic config and can be further improved.
return {
  on_attach = function(client, buf_id)
    -- Reduce very long list of triggers for better 'mini.completion' experience
    client.server_capabilities.completionProvider.triggerCharacters =
      { '.', ':', '#', '(' }

    -- Use this function to define buffer-local mappings and behavior that depend
    -- on attached client or only makes sense if there is language server attached.
  end,
  -- LuaLS Structure of these settings comes from LuaLS, not Neovim
  settings = {
    Lua = {
      -- Define runtime properties. Use 'LuaJIT', as it is built into Neovim.
      runtime = { version = 'LuaJIT', path = vim.split(package.path, ';') },
      workspace = {
        -- Don't analyze code from submodules
        ignoreSubmodules = true,
        -- Add Neovim's methods for easier code writing
        library = { vim.env.VIMRUNTIME },
      },
      diagnostics = {
        -- Globals created at runtime, which static analysis cannot infer:
        -- - `Config` is this config's own table, defined in 'init.lua'.
        -- - `Mini*` are set by 'mini.nvim' modules when they are `setup()` up,
        --   so they exist only after startup. Without listing them, every
        --   `MiniPick.…` / `MiniFiles.…` call in 'plugin/' is reported as an
        --   undefined global.
        globals = {
          'Config',
          'MiniAi',
          'MiniBufremove',
          'MiniClue',
          'MiniCompletion',
          'MiniDeps',
          'MiniDiff',
          'MiniExtra',
          'MiniFiles',
          'MiniGit',
          'MiniHues',
          'MiniIcons',
          'MiniJump2d',
          'MiniKeymap',
          'MiniMisc',
          'MiniNotify',
          'MiniPick',
          'MiniSessions',
          'MiniSnippets',
          'MiniStarter',
          'MiniTrailspace',
          'MiniVisits',
        },
      },
    },
  },
}
