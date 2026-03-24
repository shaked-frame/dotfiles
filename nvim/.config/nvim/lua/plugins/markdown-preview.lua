return {
  {
    'iamcco/markdown-preview.nvim',
    init = function()
      vim.g.mkdp_filetypes = { 'markdown', 'markdown.mdx', 'mdx' }
    end,
  },
}
