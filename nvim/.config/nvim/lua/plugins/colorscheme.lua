return {
  {
    "projekt0n/github-nvim-theme",
    lazy = false,
    priority = 1000,
  },
  {
    "vague-theme/vague.nvim",
    lazy = false, -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other plugins
    config = function()
      require("vague").setup({
        -- optional configuration here
      })
      vim.cmd("colorscheme vague")
    end,
  },
  {
    "craftzdog/solarized-osaka.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
    config = function()
      require("vague").setup({
        -- optional configuration here
        transparent = true,
      })
      vim.cmd("colorscheme solarized-osaka")
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "solarized-osaka",
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },
}
