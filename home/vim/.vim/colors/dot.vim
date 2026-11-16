vim9script

# dot.vim
#
# Minimal black & grey colorscheme for Vim
#
# Supports:
#  - GVim / MacVim
#  - truecolor terminals
#  - 256-color terminals
#  - basic 16-color terminals
#
# Requires Vim 9.x (vim9script)
# Doesn't work in Neovim

hi clear
if exists('syntax_on')
  syntax reset
endif
set background=dark

g:colors_name = 'dot'

# Palette
const BG          = '#0a0a0a'
const FG          = '#e9e9e9'
const ACCENT      = '#9d9d9d'
const MUTED       = '#b1b1b1'
const NOISE       = '#7d7d7d'
const DIM         = '#8a8a8a'
const SPLIT       = '#191919'
const PMENU_BG    = '#121212'
const PMENU_FG    = '#e9e9e9'
const PMENU_SE    = '#b1b1b1'
const WILD_BG     = '#333333'
const SBAR_BG     = '#555555'
const THUMB_BG    = '#b1b1b1'
const CURSOR_BG   = '#191919'
const STATUS_BG   = '#191919'
const DIFF_ADD_BG = '#1a231a'
const DIFF_CHG_BG = '#1a1a23'
const DIFF_DEL_BG = '#231a1a'
const AMBER       = '#e0a86a'
const SEARCH_BG   = '#3a2d1e'
const SEL_BG      = '#333333'
const RED         = '#d8625e'
const GREEN       = '#93c2a0'
const LINK        = '#88bcdb'

def HexToRgb(hex: string): list<number>
  return [str2nr(hex[1 : 2], 16), str2nr(hex[3 : 4], 16), str2nr(hex[5 : 6], 16)]
enddef

def RgbToXterm256(r: number, g: number, b: number): number
  if r == g && g == b
    if r < 8
      return 16
    endif
    if r > 248
      return 231
    endif
    return float2nr(round(((r - 8) / 247.0) * 24)) + 232
  endif
  var ir = float2nr(round(r / 255.0 * 5))
  var ig = float2nr(round(g / 255.0 * 5))
  var ib = float2nr(round(b / 255.0 * 5))
  return 16 + (36 * ir) + (6 * ig) + ib
enddef

# Standard xterm default RGB values for the 16 basic ANSI colors
const ANSI16_RGB: list<list<number>> = [
  [0x00, 0x00, 0x00], [0xcd, 0x00, 0x00], [0x00, 0xcd, 0x00], [0xcd, 0xcd, 0x00],
  [0x00, 0x00, 0xee], [0xcd, 0x00, 0xcd], [0x00, 0xcd, 0xcd], [0xe5, 0xe5, 0xe5],
  [0x7f, 0x7f, 0x7f], [0xff, 0x00, 0x00], [0x00, 0xff, 0x00], [0xff, 0xff, 0x00],
  [0x5c, 0x5c, 0xff], [0xff, 0x00, 0xff], [0x00, 0xff, 0xff], [0xff, 0xff, 0xff],
]

def RgbToAnsi16(r: number, g: number, b: number): number
  var best = 0
  var bestDist = 999999999
  for i in range(16)
    var dr = r - ANSI16_RGB[i][0]
    var dg = g - ANSI16_RGB[i][1]
    var db = b - ANSI16_RGB[i][2]
    var dist = dr * dr + dg * dg + db * db
    if dist < bestDist
      bestDist = dist
      best = i
    endif
  endfor
  return best
enddef

const USE_256 = str2nr(&t_Co) >= 256
var ctermCache: dict<string> = {}

def ToCterm(hex: string): string
  if hex[0] !=# '#'
    return 'NONE'
  endif
  if has_key(ctermCache, hex)
    return ctermCache[hex]
  endif
  var result: string
  if USE_256
    const rgb = HexToRgb(hex)
    result = string(RgbToXterm256(rgb[0], rgb[1], rgb[2]))
  else
    const rgb = HexToRgb(hex)
    result = string(RgbToAnsi16(rgb[0], rgb[1], rgb[2]))
  endif
  ctermCache[hex] = result
  return result
enddef

# Highlight helpers
def Hi(group: string, fg: string, bg: string, attr: string = 'NONE')
  const cfg = ToCterm(fg)
  const cbg = ToCterm(bg)
  execute $"hi {group} guifg={fg} guibg={bg} gui={attr} cterm={attr} ctermfg={cfg} ctermbg={cbg}"
enddef

# Spell-style groups. Only sets the undercurl ("special") color.
def HiSp(group: string, sp: string)
  const csp = ToCterm(sp)
  execute $"hi {group} guisp={sp} gui=undercurl cterm=undercurl ctermul={csp}"
enddef

# Base syntax groups, deliberately monochrome.
# Below are the only ones that break from plain FG on BG
const groups = [
  'Constant', 'Character', 'Number', 'Boolean', 'Float',
  'Identifier', 'Function',
  'Statement', 'Conditional', 'Repeat', 'Label', 'Operator', 'Keyword', 'Exception',
  'PreProc', 'Include', 'Define', 'Macro', 'PreCondit',
  'Type', 'StorageClass', 'Structure', 'Typedef',
  'Special', 'SpecialChar', 'Tag', 'Delimiter', 'Debug',
]
for g in groups
  Hi(g, FG, BG)
endfor
Hi('Underlined', LINK, BG, 'underline')
Hi('Ignore',      BG, BG)

# Custom groups
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

Hi('StatusLine',       FG,     STATUS_BG, 'bold')
Hi('StatusLineNC',   DIM,      SPLIT)
Hi('StatusLineTerm',   FG,     STATUS_BG, 'bold')
Hi('StatusLineTermNC', DIM,     SPLIT)

# the statusline of the vimrc: the mode and the dot of a modified file
Hi('StlMode',        AMBER,    STATUS_BG, 'bold')
Hi('StlMod',         AMBER,    STATUS_BG, 'bold')

Hi('CursorLine',     'NONE',   CURSOR_BG)
Hi('CursorLineNr',   AMBER,    BG)
Hi('CursorLineFold', NOISE,    CURSOR_BG, 'italic')
Hi('CursorLineSign', DIM,      CURSOR_BG)
Hi('CursorColumn',   'NONE',   CURSOR_BG)
Hi('MatchParen',     AMBER,    BG,       'bold')

Hi('Cursor',         BG,       AMBER)
Hi('lCursor',        BG,       AMBER)
Hi('CursorIM',       BG,       AMBER)

Hi('Visual',         'NONE',   SEL_BG)
Hi('VisualNOS',      'NONE',   SEL_BG)
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

# the diff and patch syntax (git commit --verbose, .patch files), as delta
Hi('diffAdded',      GREEN,    BG)
Hi('diffRemoved',    RED,      BG)
Hi('diffChanged',    AMBER,    BG)
Hi('diffFile',       LINK,     BG,       'bold')
Hi('diffLine',       DIM,      BG)
Hi('diffSubname',    DIM,      BG)

# GUI chrome
Hi('Menu',           PMENU_FG, PMENU_BG)
Hi('Tooltip',        PMENU_FG, PMENU_BG)
Hi('Scrollbar',      THUMB_BG, SBAR_BG)
Hi('ToolbarLine',    MUTED,    SPLIT)
Hi('ToolbarButton',  FG,       SPLIT,    'bold')

# :terminal buffers
Hi('Terminal',        FG,      BG)

# Termdebug plugin
Hi('debugPC',          BG,     ACCENT)
Hi('debugBreakpoint',  ACCENT,   SPLIT)

# Spelling
HiSp('SpellBad',    RED)
HiSp('SpellCap',    AMBER)
HiSp('SpellLocal',  DIM)
HiSp('SpellRare',   NOISE)

# Terminal colors: foot's, written by script/g0wm-theme.py
g:terminal_ansi_colors = [
    '#0a0a0a', '#d8625e', '#83b290', '#c29d75',
    '#79accb', '#be95ba', '#6eb3b2', '#9d9d9d',
    '#7d7d7d', '#fb9795', '#a8d8b5', '#eac39a',
    '#9ed3f2', '#e5bbe1', '#93d9d9', '#ffffff',
]

# FZF
$FZF_DEFAULT_OPTS =
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
