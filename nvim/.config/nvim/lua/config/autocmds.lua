-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
--

vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost" }, {
  callback = function()
    if vim.bo.modified and vim.bo.buftype == "" then
      vim.cmd("silent! write")
    end
  end,
})

vim.o.winborder = "solid"

local mini_files = require("mini.files")
mini_files.setup()

local minifiles_group = vim.api.nvim_create_augroup("user_mini_files", { clear = true })

local set_frontend_app_bookmarks = function()
  local root = vim.fn.expand("~/frame/frontend")
  local id_pool = vim.split("123456789abcdefghijklmnopqrstuvwxyz", "", { trimempty = true })
  local app_names = {}
  local ignored_dirs = {
    [".git"] = true,
    [".next"] = true,
    [".turbo"] = true,
    ["dist"] = true,
    ["build"] = true,
    ["coverage"] = true,
    ["node_modules"] = true,
  }

  local iter = vim.uv.fs_scandir(root)
  if not iter then
    return
  end

  while true do
    local name, fs_type = vim.uv.fs_scandir_next(iter)
    if name == nil then
      break
    end
    if fs_type == "directory" and not ignored_dirs[name] and not vim.startswith(name, ".") then
      table.insert(app_names, name)
    end
  end

  table.sort(app_names)

  for i, name in ipairs(app_names) do
    local id = id_pool[i]
    if id == nil then
      break
    end
    mini_files.set_bookmark(id, root .. "/" .. name, { desc = "frontend/" .. name })
  end
end

local map_minifiles_split = function(buf_id, lhs, direction)
  vim.keymap.set("n", lhs, function()
    local current_target = mini_files.get_explorer_state().target_window
    local new_target = vim.api.nvim_win_call(current_target, function()
      vim.cmd(direction .. " split")
      return vim.api.nvim_get_current_win()
    end)

    mini_files.set_target_window(new_target)
    mini_files.go_in({ close_on_file = true })
  end, {
    buffer = buf_id,
    desc = "MiniFiles open in " .. direction .. " split",
  })
end

vim.api.nvim_create_autocmd("User", {
  pattern = "MiniFilesBufferCreate",
  group = minifiles_group,
  callback = function(args)
    local buf_id = args.data.buf_id
    map_minifiles_split(buf_id, "<C-s>", "belowright horizontal")
    map_minifiles_split(buf_id, "<C-v>", "belowright vertical")
    map_minifiles_split(buf_id, "<C-t>", "tab")
  end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "MiniFilesExplorerOpen",
  group = minifiles_group,
  callback = function()
    set_frontend_app_bookmarks()
  end,
})
