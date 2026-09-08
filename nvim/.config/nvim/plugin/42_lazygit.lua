-- ┌─────────────────────┐
-- │ LazyGit Integration │
-- └─────────────────────┘
--
-- Keep LazyGit-specific runtime behavior here instead of in '40_plugins.lua'.
--
-- Goal:
-- - Open LazyGit in a Neovim float via 'lazygit.nvim'.
-- - When pressing `e` inside LazyGit, reuse the current Neovim instance.
-- - Open the target file in a normal editing window/buffer, not inside the
--   LazyGit terminal float.
-- - Close the LazyGit float after opening the file.
--
-- Approach:
-- - Start an RPC server for the current Neovim instance if needed.
-- - Write a small LazyGit overlay config to the Neovim cache directory.
-- - Override LazyGit's edit commands to use `nvim --server ... --remote-send`.
-- - The remote command jumps to the previous window, `:drop`s the file there,
--   then jumps back and closes the LazyGit float.

local ensure_nvim_server = function()
	if vim.v.servername ~= "" then
		return vim.v.servername
	end

	local server = vim.fs.joinpath("/tmp", ("nvim-minimax-%d.sock"):format(vim.fn.getpid()))
	local ok, result = pcall(vim.fn.serverstart, server)
	if ok then
		return result
	end

	vim.notify("Failed to start Neovim RPC server for LazyGit remote editing", vim.log.levels.WARN)
	return ""
end

local ensure_lazygit_remote_config = function()
	local config_path = vim.fs.joinpath(vim.fn.stdpath("cache"), "lazygit-nvim-remote.yml")
	local lines = {
		"os:",
		"  edit: 'sh -c ''if [ -n \"$NVIM\" ]; then nvim --server \"$NVIM\" --remote-send \"<C-\\\\><C-N><C-w>p:drop $(printf %q \"$1\")<CR><C-w>p:close<CR>\"; else nvim \"$1\"; fi'' sh {{filename}}'",
		"  editAtLine: 'sh -c ''if [ -n \"$NVIM\" ]; then nvim --server \"$NVIM\" --remote-send \"<C-\\\\><C-N><C-w>p:drop $(printf %q \"$1\")<CR>:{{line}}<CR><C-w>p:close<CR>\"; else nvim +{{line}} \"$1\"; fi'' sh {{filename}}'",
		"  editAtLineAndWait: 'sh -c ''if [ -n \"$NVIM\" ]; then nvim --server \"$NVIM\" --remote-send \"<C-\\\\><C-N><C-w>p:drop $(printf %q \"$1\")<CR>:{{line}}<CR><C-w>p:close<CR>\"; else nvim +{{line}} \"$1\"; fi'' sh {{filename}}'",
		"  editInTerminal: false",
		"promptToReturnFromSubprocess: false",
	}
	vim.fn.writefile(lines, config_path)
	return config_path
end

local open_lazygit = function()
	local server = ensure_nvim_server()
	if server ~= "" then
		vim.env.NVIM = server
	end

	local config_files = {}
	local default_config = vim.fs.joinpath(vim.env.HOME, ".config/lazygit/config.yml")
	if vim.uv.fs_stat(default_config) then
		table.insert(config_files, default_config)
	end
	table.insert(config_files, ensure_lazygit_remote_config())
	vim.env.LG_CONFIG_FILE = table.concat(config_files, ",")

	vim.cmd("LazyGit")
end

vim.keymap.set("n", "<Leader>gg", open_lazygit, { desc = "Open LazyGit" })
