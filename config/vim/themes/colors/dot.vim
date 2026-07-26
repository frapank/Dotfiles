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
const MUTED       = '#a8a8a8'
const NOISE       = '#737373'
const DIM         = '#7d7d7d'
const SPLIT       = '#1a1a1a'
const PMENU_BG    = '#0f0f0f'
const PMENU_FG    = '#e6e6e6'
const PMENU_SE    = '#cccccc'
const WILD_BG     = '#303030'
const SBAR_BG     = '#555555'
const THUMB_BG    = '#aaaaaa'
const CURSOR_BG   = '#141414'
const STATUS_BG   = '#1a1a1a'
const DIFF_ADD_BG = '#1a231a'
const DIFF_CHG_BG = '#1a1a23'
const DIFF_DEL_BG = '#231a1a'

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
Hi('Underlined', FG, BG, 'underline')
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

Hi('StatusLine',       FG,     STATUS_BG, 'bold')
Hi('StatusLineNC',     BG,     MUTED,     'bold')
Hi('StatusLineTerm',   FG,     STATUS_BG, 'bold')
Hi('StatusLineTermNC', BG,     MUTED,     'bold')

Hi('CursorLine',     'NONE',   CURSOR_BG)
Hi('CursorLineNr',   ACCENT,     BG)
Hi('CursorLineFold', NOISE,    CURSOR_BG, 'italic')
Hi('CursorLineSign', DIM,      CURSOR_BG)
Hi('CursorColumn',   'NONE',   CURSOR_BG)
Hi('MatchParen',     ACCENT,     BG)

Hi('Cursor',         BG,       ACCENT)
Hi('lCursor',        BG,       ACCENT)
Hi('CursorIM',       BG,       ACCENT)

Hi('Visual',         BG,       ACCENT)
Hi('VisualNOS',      BG,       PMENU_SE)
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
HiSp('SpellBad',    ACCENT)
HiSp('SpellCap',    MUTED)
HiSp('SpellLocal',  DIM)
HiSp('SpellRare',   NOISE)

# Terminal colors
const T_RED     = '#cc6666'
const T_GREEN   = '#8c9a8c'
const T_BLUE    = '#708a99'
const T_MAGENTA = '#a6829c'
const T_CYAN    = '#70a09f'
const T_YELLOW  = '#ffe066'

const T_B_RED   = '#d97e7e'
const T_B_GREEN = '#afd7af'
const T_B_BLUE  = '#8ab0c6'
const T_B_MAG   = '#c59dc8'
const T_B_CYAN  = '#8cc8c7'

g:terminal_ansi_colors = [
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
]

# FZF
$FZF_DEFAULT_OPTS =
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
