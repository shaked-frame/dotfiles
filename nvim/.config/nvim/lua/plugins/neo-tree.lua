return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      filtered_items = {
        visible = true, -- Show hidden files by default
        hide_dotfiles = false, -- Don't hide dotfiles
        hide_gitignored = false, -- Optionally show gitignored files too
      },
    },
  },
}
