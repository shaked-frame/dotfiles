return {
  {
    "projekt0n/github-nvim-theme",
    lazy = true,
    priority = 1000,
  },
  {
    "vague-theme/vague.nvim",
    lazy = true,
    priority = 1000, -- make sure to load this before all the other plugins
    config = function()
      require("vague").setup({
        -- optional configuration here
      })
    end,
  },
  {
    "craftzdog/solarized-osaka.nvim",
    lazy = true,
    priority = 1000,
    opts = {},
    config = function()
      require("vague").setup({
        -- optional configuration here
        transparent = true,
      })
    end,
  },
  {
    "catppuccin/nvim",
    lazy = false,
    name = "catppuccin",
    opts = {
      lsp_styles = {
        underlines = {
          errors = { "undercurl" },
          hints = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
        },
      },
      integrations = {
        aerial = true,
        alpha = true,
        cmp = true,
        dashboard = true,
        flash = true,
        fzf = true,
        grug_far = true,
        gitsigns = true,
        headlines = true,
        illuminate = true,
        indent_blankline = { enabled = true },
        leap = true,
        lsp_trouble = true,
        mason = true,
        mini = true,
        navic = { enabled = true, custom_bg = "lualine" },
        neotest = true,
        neotree = true,
        noice = true,
        notify = true,
        snacks = true,
        telescope = true,
        treesitter_context = true,
        which_key = true,
      },
    },
    specs = {
      {
        "akinsho/bufferline.nvim",
        optional = true,
        opts = function(_, opts)
          if (vim.g.colors_name or ""):find("catppuccin") then
            opts.highlights = require("catppuccin.special.bufferline").get_theme()
          end
        end,
      },
    },
  },
  {
    "LazyVim/LazyVim",
    init = function()
      local function set_diagnostic_float_highlights()
        vim.api.nvim_set_hl(0, "DiagnosticFloatingError", { fg = "#ffd59e", bg = "NONE" })
      end

      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = set_diagnostic_float_highlights,
      })

      set_diagnostic_float_highlights()
    end,
    opts = {
      colorscheme = "catppuccin",
      transparent = true,
    },
  },
}
