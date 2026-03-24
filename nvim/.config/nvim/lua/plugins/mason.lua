return {
  "mason-org/mason.nvim",
  opts = {},
  config = function(_, opts)
    require("mason").setup(opts)

    local function resign_modules(reason)
      local script = vim.fn.expand("~/.local/bin/nvim-resign-modules")
      if vim.fn.executable(script) ~= 1 then
        vim.notify("nvim-resign-modules script not found", vim.log.levels.WARN)
        return
      end

      vim.notify("Re-signing native modules " .. reason .. "...", vim.log.levels.INFO)
      vim.fn.jobstart({ script }, {
        detach = true,
        on_exit = function(_, code)
          if code == 0 then
            vim.notify("Native modules re-signed successfully", vim.log.levels.INFO)
          else
            vim.notify("Failed to re-sign native modules", vim.log.levels.ERROR)
          end
        end,
      })
    end

    -- Keep compatibility with mason-tool-installer if it is installed.
    vim.api.nvim_create_autocmd("User", {
      pattern = { "MasonUpdateAllComplete", "MasonToolsUpdateCompleted" },
      callback = function()
        resign_modules("after Mason tools update")
      end,
    })

    -- Wrap :MasonUpdate so signing runs for plain Mason registries update flow too.
    local mason_api = require("mason.api.command")
    pcall(vim.api.nvim_del_user_command, "MasonUpdate")
    vim.api.nvim_create_user_command("MasonUpdate", function()
      mason_api.MasonUpdate()
      vim.defer_fn(function()
        resign_modules("after MasonUpdate")
      end, 2000)
    end, {
      desc = "Update Mason registries and re-sign native modules.",
    })

    vim.api.nvim_create_user_command("ResignModules", function()
      resign_modules("on demand")
    end, {
      desc = "Re-sign Neovim native modules.",
    })
  end,
}
