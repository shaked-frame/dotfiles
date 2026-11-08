local M = {}
local disabled = { dashboard = true, alpha = true, ministarter = true, snacks_dashboard = true }

-- Literal paths, branch names and terminal titles must not become status items.
local escape = function(text) return (text:gsub('%%', '%%%%')) end
local highlight = function(group, text) return '%#' .. group .. '#' .. escape(text) end

local relative_to = function(path, directory)
  local prefix = directory == '/' and '/' or directory .. '/'
  if path:sub(1, #prefix) == prefix then return path:sub(#prefix + 1) end
end

-- Keep the filename intact. Collapse middle directories only when space is tight.
local shorten = function(path, budget)
  if vim.fn.strdisplaywidth(path) <= budget then return path end
  local parts = vim.split(path, '/', { plain = true })
  if #parts > 3 then
    path = table.concat({ parts[1], '…', parts[#parts - 1], parts[#parts] }, '/')
  end
  if vim.fn.strdisplaywidth(path) > budget then
    local directory, filename = path:match('^(.*)/([^/]+)$')
    if directory then path = vim.fn.pathshorten(directory) .. '/' .. filename end
  end
  return path
end

M.pretty_path = function()
  local name = vim.api.nvim_buf_get_name(0)
  local path, root_label
  if vim.bo.buftype == 'terminal' then
    path = vim.b.term_title or 'Terminal'
  elseif name == '' then
    path = '[No Name]'
  elseif vim.bo.buftype ~= '' or name:match('^%w+://') then
    path = vim.fn.fnamemodify(name, ':t')
  else
    local cwd = vim.fn.getcwd()
    -- Mini already tracks the worktree root. No filesystem/git calls on redraw.
    local root = (vim.b.minigit_summary or {}).root or cwd
    path = relative_to(name, cwd) or relative_to(name, root) or vim.fn.fnamemodify(name, ':~')
    if root ~= cwd then root_label = '󱉭 ' .. vim.fs.basename(root) end
    path = shorten(path, math.max(20, math.floor(vim.o.columns * 0.45)))
  end

  local directory, filename = path:match('^(.*[/])([^/]+)$')
  filename = filename or path
  local text = directory and highlight('ConfigStatuslineDirectory', directory) or ''
  text = text .. highlight(vim.bo.modified and 'ConfigStatuslineModified' or 'ConfigStatuslineFilename', filename)
  if vim.bo.readonly then text = text .. highlight('ConfigStatuslineModified', ' 󰌾') end

  if _G.MiniIcons and name ~= '' and vim.bo.buftype == '' then
    local icon, hl = MiniIcons.get('file', name)
    text = highlight(hl, icon) .. ' ' .. text
  end
  if root_label and not MiniStatusline.is_truncated(100) then
    text = highlight('ConfigStatuslineRoot', root_label) .. ' ' .. text
  end
  return text
end

local diff = function()
  if MiniStatusline.is_truncated(90) then return '' end
  local summary, parts = vim.b.minidiff_summary or {}, {}
  for _, item in ipairs({
    { 'add', '+', 'MiniDiffSignAdd' },
    { 'change', '~', 'MiniDiffSignChange' },
    { 'delete', '-', 'MiniDiffSignDelete' },
  }) do
    local count = summary[item[1]] or 0
    if count > 0 then parts[#parts + 1] = highlight(item[3], item[2] .. count) end
  end
  return table.concat(parts, ' ')
end

M.active = function()
  if disabled[vim.bo.filetype] then return '' end
  local status = MiniStatusline
  local mode, mode_hl = status.section_mode({ trunc_width = 100 })
  local git = vim.b.minigit_summary or {}
  local branch = git.head_name or ''
  if branch == 'HEAD' then branch = (git.head or 'HEAD'):sub(1, 7) end
  branch = branch ~= '' and not status.is_truncated(70) and ' ' .. branch or ''
  -- Adjacent Powerline cells: each arrow uses the previous fill as foreground
  -- and the next fill as background. Keep these outside combine_groups padding.
  local mode_group = mode_hl:gsub('MiniStatusline', 'ConfigStatusline')
  local left = highlight(mode_group, ' ' .. mode:upper() .. ' ')
    .. highlight(mode_group .. (branch ~= '' and 'ToBranch' or 'ToFilename'), '')
  if branch ~= '' then
    left = left .. highlight('ConfigStatuslineBranch', ' ' .. branch .. ' ')
      .. highlight('ConfigStatuslineBranchToFilename', '')
  end
  local recording = vim.fn.reg_recording()
  recording = recording ~= '' and highlight('DiagnosticWarn', '󰑋 @' .. recording) or ''
  local diagnostics = vim.trim(status.section_diagnostics({ trunc_width = 80, icon = '',
    signs = {
      ERROR = '%#DiagnosticError# ', WARN = '%#DiagnosticWarn# ',
      INFO = '%#DiagnosticInfo# ', HINT = '%#DiagnosticHint#󰌵 ',
    },
  }))

  return status.combine_groups({
    left,
    '%<',
    { hl = 'MiniStatuslineFilename', strings = { M.pretty_path() } },
    '%=',
    { hl = 'MiniStatuslineFileinfo', strings = { recording, diagnostics, diff() } },
    { hl = 'MiniStatuslineFileinfo', strings = { '%p%%' } },
    { hl = mode_hl, strings = { '%l:%2v' } },
  })
end

M.setup = function()
  require('mini.statusline').setup({ content = { active = M.active } })
  local highlights = function()
    local get = function(name) return vim.api.nvim_get_hl(0, { name = name, link = false }) end
    local base, comment, modified = get('MiniStatuslineFilename'), get('Comment'), get('MatchParen')
    local normal = get('Normal')
    local branch_bg = normal.fg or base.fg
    local text = normal.bg or 0x282c34
    vim.api.nvim_set_hl(0, 'ConfigStatuslineBranch', { fg = text, bg = branch_bg })
    vim.api.nvim_set_hl(0, 'ConfigStatuslineBranchToFilename', { fg = branch_bg, bg = base.bg })
    for mode, color in pairs({
      Normal = 'Function', Insert = 'String', Visual = 'Statement',
      Replace = 'DiagnosticError', Command = 'DiagnosticWarn', Other = 'Special',
    }) do
      local fill = get(color).fg or get('MiniStatuslineMode' .. mode).bg or branch_bg
      local group = 'ConfigStatuslineMode' .. mode
      vim.api.nvim_set_hl(0, group, { fg = text, bg = fill })
      vim.api.nvim_set_hl(0, group .. 'ToBranch', { fg = fill, bg = branch_bg })
      vim.api.nvim_set_hl(0, group .. 'ToFilename', { fg = fill, bg = base.bg })
    end
    vim.api.nvim_set_hl(0, 'ConfigStatuslineDirectory', { fg = comment.fg or base.fg, bg = base.bg })
    vim.api.nvim_set_hl(0, 'ConfigStatuslineFilename', { fg = base.fg, bg = base.bg, bold = true })
    vim.api.nvim_set_hl(0, 'ConfigStatuslineModified', { fg = modified.fg or get('DiagnosticWarn').fg, bg = base.bg, bold = true })
    vim.api.nvim_set_hl(0, 'ConfigStatuslineRoot', { fg = get('Special').fg, bg = base.bg })
  end
  local group = vim.api.nvim_create_augroup('config-statusline', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = highlights })
  vim.api.nvim_create_autocmd({ 'RecordingEnter', 'RecordingLeave' }, {
    group = group,
    callback = vim.schedule_wrap(function() vim.cmd.redrawstatus() end),
  })
  highlights()
end

return M
