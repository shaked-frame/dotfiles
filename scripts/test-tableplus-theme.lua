-- Run: nvim --headless -u NONE -l scripts/test-tableplus-theme.lua
local root = 'home/dot_config/'
local theme = vim.json.decode(table.concat(vim.fn.readfile(root .. 'tableplus/themes/solarized-osaka-vivid.json'), '\n'))
local ghostty = table.concat(vim.fn.readfile(root .. 'ghostty/themes/solarized-osaka-vivid'), '\n')
assert(theme.name == 'Solarized Osaka Vivid' and theme.base == 'dark', 'Use a named dark TablePlus theme')
assert(theme.version == '1.0.0' and type(theme.author.name) == 'string', 'Missing theme metadata')
assert(type(theme.icons) == 'table' and vim.tbl_isempty(theme.icons), 'Keep the default TablePlus icons')
local expected = [[
AppChartPaletteColor1 AppChartPaletteColor2 AppChartPaletteColor3 AppChartPaletteColor4 AppChartPaletteColor5
AppConnectionColorPreset1 AppConnectionColorPreset2 AppConnectionColorPreset3 AppConnectionColorPreset4 AppConnectionColorPreset5
AppConnectionStatusBorder AppConnectionStatusDefaultBackground AppConnectionStatusDisconnectedBackground
AppConnectionStatusErrorBackground AppConnectionStatusReconnectingBackground AppContentBackground AppControlBackground
AppControlBorder AppInputInvalidBackground AppInputValidBackground AppLogText AppNotificationErrorBackground
AppNotificationSuccessBackground AppNotificationWarningBackground AppPluginUpdateText AppQueryMessageText AppSeparator
AppSidebarBackground AppTabBackground AppTabButtonHoverBackground AppTabHoverBackground AppTabSelectedBackground
AppTabSelectedBarInactiveText AppTabSelectedWindowInactiveBackground AppTabSelectedWindowInactiveText AppTabUnselectedText
AppWelcomeButtonBackground AppWindowBackground ContentDeletedRowBackground ContentInsertedBackground ContentModifiedBackground
EditorBacktickQuotedText EditorBracketQuotedText EditorCommentText EditorCurrentQueryBackground EditorDoubleQuotedText
EditorErrorBackground EditorFunctionText EditorIdentifierText EditorInvisibleCharacterText EditorKeywordText
EditorMatchingBracketBackground EditorNumberText EditorSelectionBackground EditorSingleQuotedText EditorText
GridAccessoryForeground GridCellSelectionBorder GridDateTimeText GridDropdownText GridEvenRowBackground GridHeaderBackground
GridHeaderText GridIconCellText GridInactiveSelectionText GridLinkText GridNumberText GridOddRowBackground GridPlaceholderText
GridRowDetailText GridRowHeaderForeground GridSeparator GridText JSONKeyText SearchResultCountText SpatialPreviewGeometryStroke
SpatialPreviewPolygonFill1 SpatialPreviewPolygonFill2 SpatialPreviewPolygonFill3
]]
local count = 0
for key in expected:gmatch('%S+') do
  assert((theme.colors[key] or ''):match('^#%x%x%x%x%x%x$'), 'Missing or invalid TablePlus color: ' .. key)
  count = count + 1
end
assert(vim.tbl_count(theme.colors) == count, 'Unexpected TablePlus color keys')
assert(theme.colors.AppContentBackground == ghostty:match('\nbackground = (#%x+)'), 'Background differs from Ghostty')
assert(theme.colors.EditorText == ghostty:match('\nforeground = (#%x+)'), 'Foreground differs from Ghostty')
assert(theme.colors.EditorSelectionBackground == ghostty:match('\nselection%-background = (#%x+)'), 'Selection differs from Ghostty')
local function ansi(n) return ghostty:match('\npalette = ' .. n .. '=(#%x+)') end
assert(theme.colors.EditorKeywordText == ansi(2), 'SQL keywords should use Osaka green')
assert(theme.colors.EditorFunctionText == ansi(4), 'SQL functions should use Osaka blue')
assert(theme.colors.EditorSingleQuotedText == ansi(6), 'SQL strings should use Osaka cyan')
assert(theme.colors.EditorNumberText == ansi(5), 'SQL numbers should use Osaka magenta')
print('TablePlus theme: complete color schema and Ghostty palette OK')
