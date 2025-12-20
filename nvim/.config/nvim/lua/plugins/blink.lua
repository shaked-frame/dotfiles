return {
  "saghen/blink.cmp",
  opts = {
    keymap = {
      ["<Tab>"] = {
        "snippet_forward",
        function()
          return require("sidekick").nes_jump_or_apply()
        end,
        "fallback",
      },
    },
  },
}
