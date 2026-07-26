vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
end
vim.o.background = "dark"

vim.g.colors_name = "dot"

-- Palette
local BG          = '#0a0a0a'
local FG          = '#e9e9e9'
local ACCENT      = '#9d9d9d'
local MUTED       = '#a8a8a8'
local NOISE       = '#737373'
local DIM         = '#7d7d7d'
local SPLIT       = '#1a1a1a'
local PMENU_BG    = '#0f0f0f'
local PMENU_FG    = '#e6e6e6'
local PMENU_SE    = '#cccccc'
local WILD_BG     = '#303030'
local SBAR_BG     = '#555555'
local THUMB_BG    = '#aaaaaa'
local CURSOR_BG   = '#141414'
local STATUS_BG   = '#1a1a1a'
local DIFF_ADD_BG = '#1a231a'
local DIFF_CHG_BG = '#1a1a23'
local DIFF_DEL_BG = '#231a1a'

-- cterm fallback
local function hex_to_rgb(hex)
    return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

local function rgb_to_xterm256(r, g, b)
    if r == g and g == b then
        if r < 8 then return 16 end
        if r > 248 then return 231 end
        return math.floor(((r - 8) / 247.0) * 24 + 0.5) + 232
    end
    local ir = math.floor(r / 255.0 * 5 + 0.5)
    local ig = math.floor(g / 255.0 * 5 + 0.5)
    local ib = math.floor(b / 255.0 * 5 + 0.5)
    return 16 + 36 * ir + 6 * ig + ib
end

-- Standard xterm default RGB values for the 16 basic ANSI colors
local ANSI16_RGB = {
    {0x00, 0x00, 0x00}, {0xcd, 0x00, 0x00}, {0x00, 0xcd, 0x00}, {0xcd, 0xcd, 0x00},
    {0x00, 0x00, 0xee}, {0xcd, 0x00, 0xcd}, {0x00, 0xcd, 0xcd}, {0xe5, 0xe5, 0xe5},
    {0x7f, 0x7f, 0x7f}, {0xff, 0x00, 0x00}, {0x00, 0xff, 0x00}, {0xff, 0xff, 0x00},
    {0x5c, 0x5c, 0xff}, {0xff, 0x00, 0xff}, {0x00, 0xff, 0xff}, {0xff, 0xff, 0xff},
}

local function rgb_to_ansi16(r, g, b)
    local best, best_dist = 0, math.huge
    for i = 1, 16 do
        local dr = r - ANSI16_RGB[i][1]
        local dg = g - ANSI16_RGB[i][2]
        local db = b - ANSI16_RGB[i][3]
        local dist = dr * dr + dg * dg + db * db
        if dist < best_dist then
            best_dist = dist
            best = i - 1
        end
    end
    return best
end

local USE_256 = (vim.env.TERM or ''):find('256col') ~= nil
local cterm_cache = {}

local function to_cterm(hex)
    if hex:sub(1, 1) ~= '#' then return 'NONE' end
    if cterm_cache[hex] then return cterm_cache[hex] end
    local result
    if USE_256 then
        result = tostring(rgb_to_xterm256(hex_to_rgb(hex)))
    else
        result = tostring(rgb_to_ansi16(hex_to_rgb(hex)))
    end
    cterm_cache[hex] = result
    return result
end

-- Helper
local function Hi(group, fg, bg, attr)
    attr = attr or 'NONE'
    vim.cmd(string.format("hi %s guifg=%s guibg=%s gui=%s cterm=%s ctermfg=%s ctermbg=%s",
        group, fg, bg, attr, attr, to_cterm(fg), to_cterm(bg)))
end

-- Base groups
local groups = {
      'Constant', 'Character', 'Number', 'Boolean', 'Float',
      'Identifier', 'Function',
      'Statement', 'Conditional', 'Repeat', 'Label', 'Operator', 'Keyword', 'Exception',
      'PreProc', 'Include', 'Define', 'Macro', 'PreCondit',
      'Type', 'StorageClass', 'Structure', 'Typedef',
      'Special', 'SpecialChar', 'Tag', 'Delimiter', 'Debug',
      'Underlined', 'Ignore',
      }
for _, g in ipairs(groups) do
    Hi(g, FG, BG)
end

-- Custom groups
Hi('Normal',         FG,       BG)

Hi('LineNr',         DIM,      BG)
Hi('EndOfBuffer',    BG,       BG)
Hi('NonText',        NOISE,    BG)
Hi('SpecialKey',     DIM,      BG)
Hi('VertSplit',      SPLIT,    BG)
Hi('WinSeparator',   SPLIT,    BG)

Hi('SignColumn',     DIM,      BG)
Hi('Folded',         NOISE,    SPLIT,   'italic')
Hi('FoldColumn',     DIM,      BG)
Hi('ColorColumn',    'NONE',   SPLIT)
Hi('Conceal',        NOISE,    BG)
Hi('QuickFixLine',   BG,       ACCENT)
Hi('Substitute',     BG,       ACCENT)

Hi('Whitespace',     SPLIT,    BG)

Hi('PmenuKind',      ACCENT,     PMENU_BG)
Hi('PmenuKindSel',   BG,       PMENU_SE)
Hi('PmenuExtra',     NOISE,    PMENU_BG)
Hi('PmenuExtraSel',  NOISE,    PMENU_SE)

Hi('NormalFloat',    PMENU_FG, PMENU_BG)
Hi('FloatBorder',    NOISE,    PMENU_BG)
Hi('FloatTitle',     ACCENT,     PMENU_BG, 'bold')

Hi('LineNrAbove',    NOISE,    BG)
Hi('LineNrBelow',    NOISE,    BG)

Hi('StatusLine',     FG,       STATUS_BG, 'bold')
Hi('StatusLineNC',   BG,       MUTED,   'bold')

Hi('CursorLine',     'NONE',   CURSOR_BG)
Hi('CursorLineNr',   ACCENT,     BG)
Hi('MatchParen',     ACCENT,     BG)

Hi('Cursor',         BG,       ACCENT)
Hi('lCursor',        BG,       ACCENT)
Hi('CursorIM',       BG,       ACCENT)

Hi('Visual',         BG,       ACCENT)
Hi('Search',         BG,       ACCENT)
Hi('CurSearch',      BG,       FG,      'bold')
Hi('IncSearch',      BG,       ACCENT)

Hi('Pmenu',          PMENU_FG, PMENU_BG)
Hi('PmenuSel',       BG,       PMENU_SE)
Hi('PmenuSbar',      PMENU_FG, SBAR_BG)
Hi('PmenuThumb',     PMENU_FG, THUMB_BG)
Hi('WildMenu',       PMENU_FG, WILD_BG)

Hi('TabLine',        MUTED,    SPLIT)
Hi('TabLineFill',    MUTED,    SPLIT)
Hi('TabLineSel',     BG,       FG,       'bold')

Hi('DiffAdd',        'NONE',   DIFF_ADD_BG)
Hi('DiffChange',     'NONE',   DIFF_CHG_BG)
Hi('DiffDelete',     'NONE',   DIFF_DEL_BG)
Hi('DiffText',       BG,       ACCENT,        'bold')

Hi('Directory',      FG,       BG,       'bold')
Hi('Title',          ACCENT,     BG,       'bold')
Hi('ModeMsg',        FG,       BG,       'bold')
Hi('MoreMsg',        DIM,      BG)
Hi('Question',       ACCENT,     BG)
Hi('WarningMsg',     ACCENT,     BG)

Hi('String',         MUTED,    BG)
Hi('Comment',        NOISE,    BG,      'italic')
Hi('Todo',           ACCENT,     BG,      'bold')
Hi('SpecialComment', ACCENT,     BG)

Hi('Error',          ACCENT,     BG,       'reverse')
Hi('ErrorMsg',       ACCENT,     BG,       'reverse')

-- Diagnostics (LSP) - keep the monochrome black & grey look
Hi('DiagnosticError',          ACCENT,   BG)
Hi('DiagnosticWarn',           MUTED,  BG)
Hi('DiagnosticInfo',           DIM,    BG)
Hi('DiagnosticHint',           NOISE,  BG)
Hi('DiagnosticOk',             DIM,    BG)
Hi('DiagnosticUnderlineError', 'NONE', BG, 'undercurl')
Hi('DiagnosticUnderlineWarn',  'NONE', BG, 'undercurl')
Hi('DiagnosticUnderlineInfo',  'NONE', BG, 'underline')
Hi('DiagnosticUnderlineHint',  'NONE', BG, 'underline')
vim.cmd('hi DiagnosticUnderlineError guisp=' .. ACCENT)
vim.cmd('hi DiagnosticUnderlineWarn guisp=' .. MUTED)

-- Terminal colors
local T_RED     = '#cc6666'
local T_GREEN   = '#8c9a8c'
local T_BLUE    = '#708a99'
local T_MAGENTA = '#a6829c'
local T_CYAN    = '#70a09f'
local T_YELLOW  = '#ffe066'

local T_B_RED   = '#d97e7e'
local T_B_GREEN = '#afd7af'
local T_B_BLUE  = '#8ab0c6'
local T_B_MAG   = '#c59dc8'
local T_B_CYAN  = '#8cc8c7'

local term_colors = {
      BG,
      T_RED,
      T_GREEN,
      ACCENT,
      T_BLUE,
      T_MAGENTA,
      T_CYAN,
      MUTED,
      SBAR_BG,
      T_B_RED,
      T_B_GREEN,
      T_YELLOW,
      T_B_BLUE,
      T_B_MAG,
      T_B_CYAN,
      FG
}
for i, c in ipairs(term_colors) do
    vim.g['terminal_color_' .. (i - 1)] = c
end

-- FZF
vim.env.FZF_DEFAULT_OPTS =
  '--color=' ..
  'fg:#ffffff,' ..
  'bg:#0a0a0a,' ..
  'hl:#9d9d9d,' ..
  'fg+:#0a0a0a,' ..
  'bg+:#cccccc,' ..
  'hl+:#9d9d9d,' ..
  'border:#1a1a1a,' ..
  'header:#8a8a8a,' ..
  'gutter:#0a0a0a,' ..
  'spinner:#9d9d9d,' ..
  'info:#8a8a8a,' ..
  'pointer:#9d9d9d,' ..
  'marker:#9d9d9d,' ..
  'prompt:#9d9d9d,' ..
  'query:#ffffff,' ..
  'separator:#1a1a1a,' ..
  'scrollbar:#555555,' ..
  'label:#8a8a8a,' ..
  'disabled:#7d7d7d,' ..
  'preview-fg:#ffffff,' ..
  'preview-bg:#0f0f0f'
