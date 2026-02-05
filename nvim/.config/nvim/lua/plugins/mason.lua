return {
  "williamboman/mason.nvim",
  opts = {},
  config = function(_, opts)
    require("mason").setup(opts)

    -- Auto-resign native modules after Mason updates to fix macOS code signing issues
    vim.api.nvim_create_autocmd("User", {
      pattern = "MasonUpdateAllComplete",
      callback = function()
        vim.notify("Re-signing native modules after Mason update...", vim.log.levels.INFO)
        vim.fn.jobstart(vim.fn.expand("~/.local/bin/nvim-resign-modules"), {
          detach = true,
          on_exit = function(_, code)
            if code == 0 then
              vim.notify("✓ Native modules re-signed successfully", vim.log.levels.INFO)
            end
          end,
        })
      end,
    })
  end,
}
