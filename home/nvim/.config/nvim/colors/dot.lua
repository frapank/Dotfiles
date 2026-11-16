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
local MUTED       = '#b1b1b1'
local NOISE       = '#7d7d7d'
local DIM         = '#8a8a8a'
local SPLIT       = '#191919'
local PMENU_BG    = '#121212'
local PMENU_FG    = '#e9e9e9'
local PMENU_SE    = '#b1b1b1'
local WILD_BG     = '#333333'
local SBAR_BG     = '#555555'
local THUMB_BG    = '#b1b1b1'
local CURSOR_BG   = '#191919'
local STATUS_BG   = '#191919'
local DIFF_ADD_BG = '#1a231a'
local DIFF_CHG_BG = '#1a1a23'
local DIFF_DEL_BG = '#231a1a'
local AMBER       = '#e0a86a'
local SEARCH_BG   = '#3a2d1e'
local SEL_BG      = '#333333'
local RED         = '#d8625e'
local GREEN       = '#93c2a0'
local LINK        = '#88bcdb'

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

local TERM = vim.env.TERM or ''
local USE_256 = not (TERM == ''
    or TERM == 'ansi'
    or TERM == 'xterm-color'
    or TERM:find('linux', 1, true)
    or TERM:find('dumb', 1, true)
    or TERM:find('^vt%d'))
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
local function Hi(group, fg, bg, attr, sp)
    attr = attr or 'NONE'
    vim.cmd(string.format("hi %s guifg=%s guibg=%s guisp=%s gui=%s cterm=%s ctermfg=%s ctermbg=%s",
        group, fg, bg, sp or 'NONE', attr, attr, to_cterm(fg), to_cterm(bg)))
end

-- Base groups
local groups = {
      'Constant', 'Character', 'Number', 'Boolean', 'Float',
      'Identifier', 'Function',
      'Statement', 'Conditional', 'Repeat', 'Label', 'Operator', 'Keyword', 'Exception',
      'PreProc', 'Include', 'Define', 'Macro', 'PreCondit',
      'Type', 'StorageClass', 'Structure', 'Typedef',
      'Special', 'SpecialChar', 'Tag', 'Delimiter', 'Debug',
      'Ignore',
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
Hi('Folded',         DIM,      SPLIT,   'italic')
Hi('FoldColumn',     DIM,      BG)
Hi('ColorColumn',    'NONE',   SPLIT)
Hi('Conceal',        NOISE,    BG)
Hi('QuickFixLine',   'NONE',   SEL_BG,   'bold')
Hi('Substitute',     BG,       AMBER)

Hi('Whitespace',     SPLIT,    BG)

Hi('PmenuKind',      NOISE,    PMENU_BG)
Hi('PmenuKindSel',   FG,       SEL_BG)
Hi('PmenuExtra',     NOISE,    PMENU_BG)
Hi('PmenuMatch',     AMBER,    PMENU_BG)
Hi('PmenuMatchSel',  AMBER,    SEL_BG,   'bold')
Hi('PmenuExtraSel',  DIM,      SEL_BG)

Hi('NormalFloat',    PMENU_FG, PMENU_BG)
Hi('FloatBorder',    NOISE,    PMENU_BG)
Hi('FloatTitle',     ACCENT,     PMENU_BG, 'bold')

Hi('LineNrAbove',    NOISE,    BG)
Hi('LineNrBelow',    NOISE,    BG)

Hi('StatusLine',     FG,       STATUS_BG, 'bold')
Hi('StatusLineNC',   DIM,      SPLIT)
Hi('StatusLineTerm',   FG,     STATUS_BG, 'bold')
Hi('StatusLineTermNC', DIM,    SPLIT)

-- the statusline of init.lua: the mode and the dot of a modified file
Hi('StlMode',        AMBER,    STATUS_BG, 'bold')
Hi('StlMod',         AMBER,    STATUS_BG, 'bold')

Hi('CursorLine',     'NONE',   CURSOR_BG)
Hi('CursorLineNr',   AMBER,    BG)
Hi('MatchParen',     AMBER,    BG,       'bold')

Hi('Cursor',         BG,       AMBER)
Hi('lCursor',        BG,       AMBER)
Hi('CursorIM',       BG,       AMBER)

Hi('Visual',         'NONE',   SEL_BG)
Hi('Search',         FG,       SEARCH_BG)
Hi('CurSearch',      BG,       AMBER,    'bold')
Hi('IncSearch',      BG,       AMBER)

Hi('Pmenu',          PMENU_FG, PMENU_BG)
Hi('PmenuSel',       FG,       SEL_BG,   'bold')
Hi('PmenuSbar',      PMENU_FG, SBAR_BG)
Hi('PmenuThumb',     PMENU_FG, THUMB_BG)
Hi('WildMenu',       PMENU_FG, WILD_BG)

Hi('TabLine',        MUTED,    SPLIT)
Hi('TabLineFill',    MUTED,    SPLIT)
Hi('TabLineSel',     BG,       FG,       'bold')

Hi('DiffAdd',        'NONE',   DIFF_ADD_BG)
Hi('DiffChange',     'NONE',   DIFF_CHG_BG)
Hi('DiffDelete',     RED,      DIFF_DEL_BG)
Hi('DiffText',       BG,       AMBER,    'bold')

Hi('Directory',      LINK,     BG,       'bold')
Hi('Title',          ACCENT,     BG,       'bold')
Hi('ModeMsg',        FG,       BG,       'bold')
Hi('MoreMsg',        DIM,      BG)
Hi('Question',       ACCENT,     BG)
Hi('WarningMsg',     AMBER,    BG)

Hi('String',         MUTED,    BG)
Hi('Comment',        NOISE,    BG,      'italic')
Hi('Todo',           AMBER,    BG,       'bold')
Hi('SpecialComment', AMBER,    BG)

Hi('Error',          RED,      BG,       'bold')
Hi('ErrorMsg',       RED,      BG,       'bold')

-- Spelling: undercurl, as vim
Hi('SpellBad',       'NONE',   'NONE',   'undercurl', RED)
Hi('SpellCap',       'NONE',   'NONE',   'undercurl', AMBER)
Hi('SpellLocal',     'NONE',   'NONE',   'undercurl', DIM)
Hi('SpellRare',      'NONE',   'NONE',   'undercurl', NOISE)

-- Diagnostics (LSP): red errors, amber warnings as the notifications of the desktop
Hi('DiagnosticError',          RED,    BG)
Hi('DiagnosticWarn',           AMBER,  BG)
Hi('DiagnosticInfo',           LINK,   BG)
Hi('DiagnosticHint',           NOISE,  BG)
Hi('DiagnosticOk',             GREEN,  BG)
Hi('DiagnosticUnderlineError', 'NONE', 'NONE', 'undercurl', RED)
Hi('DiagnosticUnderlineWarn',  'NONE', 'NONE', 'undercurl', AMBER)
Hi('DiagnosticUnderlineInfo',  'NONE', 'NONE', 'underline', LINK)
Hi('DiagnosticUnderlineHint',  'NONE', 'NONE', 'underline', NOISE)

Hi('Underlined',     LINK,     BG,       'underline')

-- the diff and patch syntax (git commit --verbose, .patch files), as delta
Hi('diffAdded',      GREEN,    BG)
Hi('diffRemoved',    RED,      BG)
Hi('diffChanged',    AMBER,    BG)
Hi('diffFile',       LINK,     BG,       'bold')
Hi('diffLine',       DIM,      BG)
Hi('diffSubname',    DIM,      BG)

-- treesitter's diff
vim.cmd('hi link @diff.plus diffAdded | hi link @diff.minus diffRemoved | hi link @diff.delta diffChanged')

-- Terminal colors: foot's, written by script/g0wm-theme.py
local term_colors = {
    '#0a0a0a', '#d8625e', '#83b290', '#c29d75',
    '#79accb', '#be95ba', '#6eb3b2', '#9d9d9d',
    '#7d7d7d', '#fb9795', '#a8d8b5', '#eac39a',
    '#9ed3f2', '#e5bbe1', '#93d9d9', '#ffffff',
}
for i, c in ipairs(term_colors) do
    vim.g['terminal_color_' .. (i - 1)] = c
end

-- FZF
vim.env.FZF_DEFAULT_OPTS =
  '--color=' ..
  'fg:#e9e9e9,' ..
  'bg:#0a0a0a,' ..
  'hl:#e0a86a,' ..
  'fg+:#e9e9e9,' ..
  'bg+:#222222,' ..
  'hl+:#e0a86a,' ..
  'border:#191919,' ..
  'header:#8a8a8a,' ..
  'gutter:#0a0a0a,' ..
  'spinner:#8a8a8a,' ..
  'info:#8a8a8a,' ..
  'pointer:#e0a86a,' ..
  'marker:#e0a86a,' ..
  'prompt:#8a8a8a,' ..
  'query:#e9e9e9,' ..
  'separator:#191919,' ..
  'scrollbar:#555555,' ..
  'label:#8a8a8a,' ..
  'disabled:#555555,' ..
  'preview-fg:#e9e9e9,' ..
  'preview-bg:#121212'
