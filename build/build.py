#!/usr/bin/env python3
"""
SCZ-Architecture - workbook generator.

Builds dist/Simulator_SIS131.ods (LibreOffice Calc + Basic macros):
  * creates the sheets SIMULATOR, PROGRAMS, ISA, GUIDE and STATE,
  * draws the simulator layout (CPU, caches, RAM, disk, buses, I/O, page table, timeline, log),
  * creates the form controls (buttons, text boxes, drop-down lists) and binds each button to its macro,
  * generates the Basic module `Config` with every layout coordinate, color and state row as a constant,
  * injects every src/*.bas file as a Basic module (one module per file),
  * loads optional content when it exists: catalog programs (src/programs/*.asm),
    ISA sheet (src/data/isa.txt), guide (src/data/guide.txt), team name (src/data/team.txt)
    and logo (assets/logo.png). Feature issues add these files without editing this script.

Requirements: LibreOffice 7.x or newer with the Python UNO bridge (python3-uno / libreoffice-pyuno).
Usage (from the repository root):
    python3 build/build.py                # writes dist/Simulator_SIS131.ods
    python3 build/build.py out/file.ods   # custom output path
"""
import os, sys, time, glob, subprocess
import uno
from com.sun.star.beans import PropertyValue
from com.sun.star.awt import Size, Point
from com.sun.star.table import BorderLine2, TableBorder2
from com.sun.star.script import ScriptEventDescriptor
from com.sun.star.lang import Locale

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
OUT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, "dist", "Simulator_SIS131.ods")
PORT = int(os.environ.get("SOFFICE_PORT", "2002"))


def rgb(r, g, b):
    return (r << 16) | (g << 8) | b


# ============================================================== colors
COL = dict(
    COL_ON=rgb(102,187,106), COL_OFF=rgb(224,224,224), COL_HIZ=rgb(207,216,220),
    COL_HIT=rgb(67,160,71), COL_MISS=rgb(229,57,53), COL_FAULT=rgb(239,83,80),
    COL_VICTIM=rgb(255,167,38), COL_FREE=rgb(245,245,245), COL_CEMPTY=rgb(250,250,250),
    COL_FLASH=rgb(255,238,88), COL_TOK_DATA=rgb(255,235,59), COL_TOK_ADR=rgb(255,255,255),
    COL_DAT_ACT=rgb(30,136,229), COL_ADR_ACT=rgb(216,27,96), COL_CTL_ACT=rgb(245,124,0),
    COL_INT_ACT=rgb(84,110,122),
    COL_ST_INFO=rgb(21,101,192), COL_ST_OK=rgb(46,125,50), COL_ST_WARN=rgb(239,108,0), COL_ST_ERR=rgb(198,40,40),
    COL_KBDQ=rgb(206,147,216), COL_KBDQ_E=rgb(243,229,245), COL_LCDB=rgb(178,223,219), COL_IORES=rgb(215,204,200),
    COL_PT_RES=rgb(200,230,201), COL_PT_OUT=rgb(255,255,255), COL_DIRTY=rgb(255,138,128),
    COL_PT_LOOK=rgb(255,241,118), COL_RESID=rgb(129,199,132), COL_TL_BG=rgb(255,255,255),
    COL_CODE_BG=rgb(255,253,231), COL_WHITE=rgb(255,255,255),
)
# one color per virtual page (reused in disk, RAM, caches and timeline)
PAGECOLS = [rgb(255,205,210), rgb(248,187,208), rgb(225,190,231), rgb(209,196,233),
            rgb(197,202,233), rgb(187,222,251), rgb(179,229,252), rgb(178,235,242),
            rgb(178,223,219), rgb(200,230,201), rgb(220,237,200), rgb(240,244,195),
            rgb(255,249,196), rgb(255,236,179), rgb(255,224,178), rgb(215,204,200)]
BUS_CTL, BUS_ADR, BUS_DAT, BUS_INT = rgb(255,204,128), rgb(244,143,177), rgb(144,202,249), rgb(176,190,197)
# control word: 21 signals, in display order
SIGNALS = ("En_PC,Ld_PC,Ld_MAR,Mem_R,Mem_W,IO,Ld_MDR,En_MDR,Ld_IR,En_IR,En_ALU,"
           "Ld_AX,En_AX,Ld_BX,En_BX,Ld_CX,En_CX,Ld_DX,En_DX,En_KBD,Ld_LCD")

# ============================================================== layout (row, column are 0-based)
L = dict(
    # header / settings / status bar
    R_STATUS=5, R_SET=4, C_SPEED=82, C_ANIMF=89, C_ALG=97,
    R_PROGNM=0, C_PROGNM=89, R_P1RES=2, C_P1RES=95,
    # CPU registers (left = data registers, right = control registers)
    R_AX=9, R_BX=11, R_CX=13, R_DX=15, R_PC=9, R_IR=11, R_IRM=12, R_MAR=13, R_MDR=15,
    C_LVAL=4, C_LDEC=6, C_LCHR=8, C_LBUF=10, C_LSTUB=11, C_IBUS=12, C_RSTUB=13, C_RBUF=14,
    C_RLBL=15, C_RVAL=17,
    R_ALU_A=18, R_ALU_B=19, R_ALU_R=20, R_ALU_IO=19, C_ALU_V=4, C_ALU_OP=8,
    R_FLAGS=23, C_ZF=4, C_CF=7, C_SF=10,
    R_UC_PH=18, R_UC_MI=19, R_UC_CLK=21, R_UC_INS=22, C_UC_V=17, C_UC_MI=14,
    R_MMU1=25, R_MMU2=26, C_MMU=14, R_HALT=25, C_HALT=2,
    C_CPU_CTL=18, C_CPU_ADR=19, C_CPU_DAT=20,
    # caches
    R_L1I=9, R_L1D=11, R_L2_0=14, C_CV=26, C_CB0=27, C_CTAG=36, C_CIND=40,
    C_L1_STUB=30, C_L2_STUB=41,
    # RAM
    R_RAM0=9, C_RAM0=50, C_RAMPG=49, R_RAMINFO=25, C_RAMINFO=47,
    C_RAM_CTL=53, C_RAM_ADR=55, C_RAM_DAT=58,
    # disk (virtual memory / swap)
    R_DSK0=9, C_DSKA=70, C_DSKB=89, C_DLBLA=68, C_DLBLB=87, C_DSK_CTL=80, C_DSK_DAT=86,
    # buses
    R_STUB0=28, R_BCTL=30, R_BADR=32, R_BDAT=34, R_BELOW1=36,
    # I/O
    R_KIN=39, C_KIN=4, R_KKEY=41, C_KKEY=4, R_KBUF=41, C_KBUF=13, C_KBD_STUB=10,
    R_LCD=39, C_LCD0=24, C_LCD_STUB=31, R_LCDLD=43, C_LCDLD=30,
    # control word
    R_CWV=41, C_CW0=46, R_CWVEC=39, C_CWVEC=89, R_CWM=42, C_CWM=50, R_EMI=43, C_EMI=56,
    # page table
    R_PT0=49, C_PT_P=3, C_PT_PFN=4, C_PT_D=6, C_PT_R=7, C_PT_CAR=8, C_PT_USO=10, C_PT_EST=12,
    # swap timeline
    R_TL_T=49, R_TL_REF=50, R_TL_M0=51, R_TL_F=58, R_TL_V=59, C_TL0=24, TL_MAX=82,
    # event log (one merged cell)
    R_LOG0=63, R_LOG1=76, C_LOG=20, LOG_LINES=15,
    # program window
    R_CODE0=71, CODE_MAX=24, C_CODE0=1, C_CODE1=18, C_CODE_A=1, C_CODE_B=3, C_CODE_S=8,
    # PROGRAMS sheet
    PG_COL_P1=1, PG_COL_P2=3, PG_COL_P3=5, PG_COL_ED=7, PG_LST=9, PG_R0=4, PG_NLINES=40, PG_MSG_ROW=3,
)

# STATE sheet: one row per internal counter (column B holds the value)
STATE = [("CLK", "Clock cycles (micro-steps)"), ("REF", "Memory reference counter"),
         ("TLN", "Next timeline column"), ("LASTFP", "Last code page fetched"),
         ("HALT", "CPU halted (1 = HLT)"), ("INSTR", "Instructions executed"),
         ("KHEAD", "Keyboard queue: head"), ("KCOUNT", "Keyboard queue: count"),
         ("LCDCUR", "LCD: cursor"), ("L1I_H", "L1I hits"), ("L1I_M", "L1I misses"),
         ("L1D_H", "L1D hits"), ("L1D_M", "L1D misses"), ("L2_H", "L2 hits"), ("L2_M", "L2 misses"),
         ("PF", "Page faults"), ("SWOUT", "Swap-out (writes to disk)"), ("SWIN", "Swap-in (reads from disk)"),
         ("LOADED", "Program loaded"), ("PROGCOL", "Program column"), ("NCODE", "Code bytes"),
         ("CODEHI", "Highlighted code line"), ("A", "Input A (P1)"), ("B", "Input B (P1)"),
         ("USESIN", "Program uses IN"), ("P1ORIG", "P1 is the original code")]
for i, (n, _) in enumerate(STATE):
    L["ST_" + n] = i
L["ST_LAST"] = len(STATE) - 1
STATE_DEFAULTS = {"LASTFP": -1, "CODEHI": -1}

# ============================================================== optional content
# Catalog programs: src/programs/p1.asm, p2.asm, p3.asm, editor.asm (added by the programs issue).
def read_program(name):
    path = os.path.join(SRC, "programs", name + ".asm")
    return open(path, encoding="utf-8").read().splitlines() if os.path.exists(path) else []

PROGRAMS = {L["PG_COL_P1"]: read_program("p1"), L["PG_COL_P2"]: read_program("p2"),
            L["PG_COL_P3"]: read_program("p3"), L["PG_COL_ED"]: read_program("editor")}
def read_data(name):
    path = os.path.join(SRC, "data", name)
    return open(path, encoding="utf-8").read().splitlines() if os.path.exists(path) else []

# src/data/isa.txt: "# title" = section, "|!a|b|.." = table header, "|a|b|.." = table row, other = text
ISA_LINES = read_data("isa.txt")
# src/data/guide.txt: "# title" = heading, other non-empty line = paragraph
GUIDE_EXTRA = [("H", l[1:].strip()) if l.startswith("#") else ("", l.strip()) for l in read_data("guide.txt") if l.strip()]
# src/data/team.txt: line 1 = team name, line 2 = members
TEAM = read_data("team.txt")
LOGO = os.path.join(ROOT, "assets", "logo.png")


def norm_code(lines):
    """Normalized code text (no comments, no .DATA, single spaces, upper case)."""
    out = ""
    for t in lines:
        t = " ".join(t.split(";")[0].replace("\t", " ").split()).upper()
        if t and not t.startswith(".DATA"):
            out += t + "|"
    return out


# ============================================================== Basic modules
def config_module():
    lines = ["REM Generated by build/build.py - do not edit by hand.",
             "REM Layout coordinates, colors and STATE rows of the simulator.", "Option Explicit", ""]
    lines += ["Public Const %s = %d" % (k, v) for k, v in L.items()]
    lines += ["Public Const %s = %d" % (k, v) for k, v in COL.items()]
    lines.append('Public Const SIGNALS = "%s"' % SIGNALS)
    lines.append('Public Const PAGECOLS = "%s"' % ",".join(str(c) for c in PAGECOLS))
    lines.append('Public Const P1_SIG = "%s"' % norm_code(PROGRAMS[L["PG_COL_P1"]]))
    return "\n".join(lines) + "\n"


def basic_modules():
    mods = [("Config", config_module())]
    for path in sorted(glob.glob(os.path.join(SRC, "*.bas"))):
        name = os.path.splitext(os.path.basename(path))[0]
        mods.append((name, open(path, encoding="utf-8").read()))
    return mods


# ============================================================== LibreOffice connection
def pv(n, v):
    p = PropertyValue(); p.Name = n; p.Value = v; return p


def connect():
    local = uno.getComponentContext()
    resolver = local.ServiceManager.createInstanceWithContext("com.sun.star.bridge.UnoUrlResolver", local)
    url = "uno:socket,host=localhost,port=%d;urp;StarOffice.ComponentContext" % PORT
    try:
        return resolver.resolve(url), None
    except Exception:
        proc = subprocess.Popen(["soffice", "--headless", "--invisible", "--norestore",
                                 "--accept=socket,host=localhost,port=%d;urp;" % PORT],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(80):
            try:
                return resolver.resolve(url), proc
            except Exception:
                time.sleep(0.5)
    raise RuntimeError("Could not start or reach LibreOffice (soffice).")


ctx, own_proc = connect()
desktop = ctx.ServiceManager.createInstanceWithContext("com.sun.star.frame.Desktop", ctx)
doc = desktop.loadComponentFromURL("private:factory/scalc", "_blank", 0, (pv("Hidden", True),))
sheets = doc.Sheets
sheets.getByIndex(0).Name = "SIMULATOR"
for i, n in enumerate(["PROGRAMS", "ISA", "GUIDE", "STATE"]):
    sheets.insertNewByName(n, i + 1)
sh = sheets.getByName("SIMULATOR")

CENTER = uno.Enum("com.sun.star.table.CellHoriJustify", "CENTER")
LEFT = uno.Enum("com.sun.star.table.CellHoriJustify", "LEFT")


def C(s, r, c): return s.getCellByPosition(c, r)
def R(s, r1, c1, r2, c2): return s.getCellRangeByPosition(c1, r1, c2, r2)


def fmt(s, r1, c1, r2, c2, bg=None, fg=None, size=None, bold=False, center=True, merge=False,
        text=None, font=None, wrap=False, rot=None, italic=False):
    rg = R(s, r1, c1, r2, c2)
    if merge and (r1 != r2 or c1 != c2): rg.merge(True)
    if bg is not None: rg.CellBackColor = bg
    if fg is not None: rg.CharColor = fg
    if size: rg.CharHeight = size
    if bold: rg.CharWeight = 150
    if italic: rg.CharPosture = uno.Enum("com.sun.star.awt.FontSlant", "ITALIC")
    if font: rg.CharFontName = font
    rg.HoriJustify = CENTER if center else LEFT
    rg.VertJustify = 2
    if wrap: rg.IsTextWrapped = True
    if rot is not None: rg.RotateAngle = rot
    if text is not None: C(s, r1, c1).setString(text)
    return rg


def line(color, w=35):
    b = BorderLine2(); b.Color = color; b.OuterLineWidth = w; b.LineWidth = w; return b


def outline(s, r1, c1, r2, c2, color=rgb(96,96,96), w=35):
    tb = TableBorder2()
    for side in ("Top", "Bottom", "Left", "Right"):
        setattr(tb, side + "Line", line(color, w)); setattr(tb, "Is%sLineValid" % side, True)
    R(s, r1, c1, r2, c2).TableBorder2 = tb


def grid(s, r1, c1, r2, c2, color=rgb(189,189,189)):
    tb = TableBorder2()
    for side in ("Top", "Bottom", "Left", "Right"):
        setattr(tb, side + "Line", line(color, 9)); setattr(tb, "Is%sLineValid" % side, True)
    tb.HorizontalLine = line(color, 9); tb.IsHorizontalLineValid = True
    tb.VerticalLine = line(color, 9); tb.IsVerticalLineValid = True
    R(s, r1, c1, r2, c2).TableBorder2 = tb


def box(s, r1, c1, r2, c2, title, hdr, body):
    fmt(s, r1, c1, r2, c2, bg=body)
    fmt(s, r1, c1, r1, c2, bg=hdr, fg=COL["COL_WHITE"], size=9, bold=True, merge=True, text=title)
    outline(s, r1, c1, r2, c2, hdr, 50)


WHITE = COL["COL_WHITE"]
GRAY_TXT = rgb(96,96,96)

# ============================================================== SIMULATOR sheet
NC, NR = 107, 100
allr = R(sh, 0, 0, NR, NC)
allr.CharFontName = "Arial"; allr.CharHeight = 7
for c in range(NC + 1): sh.Columns.getByIndex(c).Width = 460
sh.Columns.getByIndex(0).Width = 250
for r in range(NR + 1): sh.Rows.getByIndex(r).Height = 420
for r, h in ((0, 520), (1, 480), (2, 600), (3, 480), (4, 560), (5, 750), (6, 200),
             (35, 300), (36, 300), (45, 250), (46, 250)):
    sh.Rows.getByIndex(r).Height = h
fmt(sh, 0, 0, NR, NC, bg=rgb(250,250,252))

# --- header: logo, team, title
fmt(sh, 0, 1, 2, 4, bg=rgb(13,71,161), fg=rgb(255,213,79), size=16, bold=True, merge=True, text="◆")
outline(sh, 0, 1, 2, 4, rgb(255,213,79), 70)
fmt(sh, 0, 5, 1, 28, bg=rgb(13,71,161), fg=WHITE, size=13, bold=True, merge=True,
    text="TEAM: " + (TEAM[0].strip() if TEAM else "[WRITE THE TEAM NAME HERE]"))
fmt(sh, 2, 5, 2, 28, bg=rgb(21,101,192), fg=rgb(227,242,253), size=7, merge=True,
    text=("Members: " + TEAM[1].strip()) if len(TEAM) > 1 else "Replace the diamond with the team logo (Insert > Image)")
fmt(sh, 0, 29, 1, 80, bg=rgb(13,71,161), fg=WHITE, size=11, bold=True, merge=True,
    text="COMPUTER ARCHITECTURE SIMULATOR · Tri-state buses · L1/L2 cache · Virtual memory · I/O")
fmt(sh, 2, 29, 2, 80, bg=rgb(21,101,192), fg=rgb(227,242,253), size=7, merge=True,
    text="UCB San Pablo · Software Engineering · SIS-131 Computer Architecture · Second Partial 2/2026 · single-core CPU, 1 process, 1 thread")
# program name + P1 inputs
fmt(sh, 0, 81, 0, 88, bg=rgb(38,50,56), fg=WHITE, size=7, bold=True, merge=True, text="PROGRAM:")
fmt(sh, 0, 89, 0, 105, bg=rgb(55,71,79), fg=rgb(255,238,88), size=8, bold=True, merge=True, text="(none)")
fmt(sh, 1, 81, 1, 105, bg=rgb(21,101,192), fg=WHITE, size=7, bold=True, merge=True,
    text="PROGRAM 1 INPUTS  (A and B from 0 to 255 · result in DX)")
fmt(sh, 2, 81, 2, 105, bg=rgb(227,242,253))
fmt(sh, 2, 81, 2, 82, size=9, bold=True, merge=True, text="A =")
fmt(sh, 2, 88, 2, 89, size=9, bold=True, merge=True, text="B =")
fmt(sh, 2, 95, 2, 105, bg=WHITE, fg=rgb(13,71,161), size=8, bold=True, merge=True, text="A x B = ?")
outline(sh, 1, 81, 2, 105, rgb(21,101,192), 35)
# settings labels (the values are drop-down lists created below)
fmt(sh, 3, 82, 3, 87, bg=rgb(236,239,241), size=7, bold=True, merge=True, text="Speed 1-5")
fmt(sh, 3, 89, 3, 95, bg=rgb(236,239,241), size=7, bold=True, merge=True, text="Animate fetch")
fmt(sh, 3, 97, 3, 103, bg=rgb(236,239,241), size=7, bold=True, merge=True, text="Page replacement")
# status bar
fmt(sh, 5, 1, 5, 105, bg=COL["COL_ST_INFO"], fg=WHITE, size=10, bold=True, merge=True, wrap=True,
    text="Welcome. Load a program (P1, P2 or P3) and press ▶ Step or ▶▶ Run.")

# --- CPU
box(sh, 7, 1, 27, 22, "SINGLE-CORE CPU  (8-bit registers · internal bus)", rgb(21,101,192), rgb(232,240,254))
fmt(sh, 8, 2, 8, 3, size=6, bold=True, merge=True, text="Reg")
fmt(sh, 8, 4, 8, 5, size=6, bold=True, merge=True, text="Hex")
fmt(sh, 8, 6, 8, 7, size=6, bold=True, merge=True, text="Dec")
fmt(sh, 8, 8, 8, 8, size=6, bold=True, text="Chr")
fmt(sh, 8, 10, 8, 10, size=5, bold=True, text="Buf")
fmt(sh, 8, 11, 8, 13, size=5, bold=True, merge=True, text="INT. BUS")
fmt(sh, 8, 14, 8, 14, size=5, bold=True, text="Buf")
for name, r in (("AX", 9), ("BX", 11), ("CX", 13), ("DX", 15)):
    fmt(sh, r, 2, r, 3, bg=rgb(21,101,192), fg=WHITE, size=9, bold=True, merge=True, text=name)
    fmt(sh, r, 4, r, 5, bg=WHITE, size=10, bold=True, merge=True, font="Courier New", text="00")
    fmt(sh, r, 6, r, 7, bg=WHITE, size=8, merge=True, text="0")
    fmt(sh, r, 8, r, 8, bg=WHITE, size=8, text="-")
    outline(sh, r, 2, r, 8, rgb(21,101,192), 25)
    fmt(sh, r, 10, r, 10, bg=COL["COL_HIZ"], size=6, bold=True, text="Z")
    fmt(sh, r, 11, r, 11, bg=BUS_INT)
for name, r in (("PC", 9), ("IR", 11), ("MAR", 13), ("MDR", 15)):
    fmt(sh, r, 15, r, 16, bg=rgb(55,71,79), fg=WHITE, size=9, bold=True, merge=True, text=name)
    fmt(sh, r, 17, r, 21, bg=WHITE, size=9, bold=True, merge=True, font="Courier New", text="000")
    outline(sh, r, 15, r, 21, rgb(55,71,79), 25)
    fmt(sh, r, 13, r, 13, bg=BUS_INT)
    fmt(sh, r, 14, r, 14, bg=COL["COL_HIZ"] if name != "MAR" else rgb(248,187,208), size=6, bold=True,
        text="Z" if name != "MAR" else "→A")
fmt(sh, 12, 15, 12, 21, size=7, bold=True, fg=rgb(13,71,161), merge=True, italic=True)
fmt(sh, 10, 15, 10, 21, size=5, merge=True, fg=GRAY_TXT, text="PC: 9 bits (virtual address)")
fmt(sh, 14, 15, 14, 21, size=5, merge=True, fg=GRAY_TXT, text="MAR → MMU → address bus")
fmt(sh, 16, 15, 16, 21, size=5, merge=True, fg=GRAY_TXT, text="MDR ↔ data bus")
fmt(sh, 9, 12, 21, 12, bg=BUS_INT)
fmt(sh, 22, 12, 22, 12, bg=BUS_INT, size=5, text="▼")
# ALU
fmt(sh, 17, 2, 17, 9, bg=rgb(0,121,107), fg=WHITE, size=8, bold=True, merge=True, text="ALU")
for r, t in ((18, "A"), (19, "B"), (20, "RES")):
    fmt(sh, r, 2, r, 3, bg=rgb(178,223,219), size=7, bold=True, merge=True, text=t)
    fmt(sh, r, 4, r, 7, bg=WHITE, size=7, merge=True, font="Courier New")
fmt(sh, 18, 8, 19, 9, bg=rgb(255,249,196), size=8, bold=True, merge=True)
fmt(sh, 20, 8, 20, 9, bg=rgb(178,223,219), size=5, merge=True, text="op")
outline(sh, 17, 2, 20, 9, rgb(0,121,107), 35)
fmt(sh, 19, 10, 19, 10, bg=COL["COL_HIZ"], size=6, bold=True, text="Z")
fmt(sh, 19, 11, 19, 11, bg=BUS_INT)
# flags
fmt(sh, 22, 2, 22, 10, size=6, bold=True, merge=True, text="FLAGS")
for c, t in ((2, "ZF"), (5, "CF"), (8, "SF")):
    fmt(sh, 23, c, 23, c + 1, bg=rgb(55,71,79), fg=WHITE, size=7, bold=True, merge=True, text=t)
    fmt(sh, 23, c + 2, 23, c + 2, bg=COL["COL_OFF"], size=8, bold=True, text="0")
fmt(sh, 25, 2, 26, 10, bg=COL["COL_ST_OK"], fg=WHITE, size=8, bold=True, merge=True, text="CPU READY")
# control unit
fmt(sh, 17, 14, 17, 21, bg=rgb(94,53,177), fg=WHITE, size=7, bold=True, merge=True, text="CONTROL UNIT")
fmt(sh, 18, 14, 18, 16, size=6, bold=True, merge=True, text="Phase:")
fmt(sh, 18, 17, 18, 21, bg=WHITE, size=6, bold=True, merge=True, wrap=True)
fmt(sh, 19, 14, 20, 21, bg=WHITE, size=6, merge=True, wrap=True, center=False)
fmt(sh, 21, 14, 21, 16, size=6, bold=True, merge=True, text="Cycles:")
fmt(sh, 21, 17, 21, 21, bg=WHITE, size=8, bold=True, merge=True, text="0")
fmt(sh, 22, 14, 22, 16, size=6, bold=True, merge=True, text="Instr.:")
fmt(sh, 22, 17, 22, 21, bg=WHITE, size=8, bold=True, merge=True, text="0")
outline(sh, 17, 14, 22, 21, rgb(94,53,177), 35)
fmt(sh, 24, 14, 24, 21, bg=rgb(230,81,0), fg=WHITE, size=7, bold=True, merge=True, text="MMU (translation)")
fmt(sh, 25, 14, 25, 21, bg=WHITE, size=6, merge=True, wrap=True)
fmt(sh, 26, 14, 26, 21, bg=WHITE, size=6, merge=True, wrap=True, bold=True)
outline(sh, 24, 14, 26, 21, rgb(230,81,0), 35)

# --- CACHES
box(sh, 7, 24, 27, 45, "CACHE HIERARCHY  (L1I 8 B · L1D 8 B · L2 32 B)", rgb(94,53,177), rgb(237,231,246))
fmt(sh, 8, 26, 8, 26, size=6, bold=True, text="V")
for i in range(8): fmt(sh, 8, 27 + i, 8, 27 + i, size=6, bold=True, text=str(i))
fmt(sh, 8, 36, 8, 38, size=6, bold=True, merge=True, text="TAG (PA)")
fmt(sh, 8, 40, 8, 44, size=6, bold=True, merge=True, text="Result")


def cache_row(r, label, lblbg):
    fmt(sh, r, 24, r, 25, bg=lblbg, fg=WHITE, size=8, bold=True, merge=True, text=label)
    fmt(sh, r, 26, r, 26, bg=WHITE, size=7, bold=True, text="0")
    fmt(sh, r, 27, r, 34, bg=COL["COL_CEMPTY"], size=7, font="Courier New")
    for i in range(8): C(sh, r, 27 + i).setString("--")
    fmt(sh, r, 36, r, 38, bg=COL["COL_CEMPTY"], size=7, bold=True, merge=True, font="Courier New", text="---")
    grid(sh, r, 26, r, 34, rgb(149,117,205))


cache_row(9, "L1I", rgb(69,39,160)); fmt(sh, 9, 40, 9, 44, bg=COL["COL_CEMPTY"], size=8, bold=True, merge=True, fg=WHITE)
fmt(sh, 10, 26, 10, 38, size=5, merge=True, fg=GRAY_TXT, text="instructions only (PC stream) · 1 line of 8 B")
cache_row(11, "L1D", rgb(69,39,160)); fmt(sh, 11, 40, 11, 44, bg=COL["COL_CEMPTY"], size=8, bold=True, merge=True, fg=WHITE)
fmt(sh, 12, 26, 12, 38, size=5, merge=True, fg=GRAY_TXT, text="data only (operands) · 1 line of 8 B")
fmt(sh, 13, 24, 13, 44, bg=rgb(179,157,219), size=6, bold=True, merge=True,
    text="UNIFIED L2 32 B = 4 lines × 8 B · direct mapped: line = (PA ÷ 8) mod 4")
for k in range(4): cache_row(14 + k, "L2·%d" % k, rgb(94,53,177))
fmt(sh, 14, 40, 17, 44, bg=COL["COL_CEMPTY"], size=9, bold=True, merge=True, fg=WHITE)
for r in (9, 11): outline(sh, r, 40, r, 44, rgb(94,53,177), 25)
outline(sh, 14, 40, 17, 44, rgb(94,53,177), 25)
# statistics
fmt(sh, 19, 24, 19, 27, bg=rgb(69,39,160), fg=WHITE, size=7, bold=True, merge=True, text="Level")
fmt(sh, 19, 28, 19, 31, bg=rgb(46,125,50), fg=WHITE, size=7, bold=True, merge=True, text="Hits")
fmt(sh, 19, 32, 19, 35, bg=rgb(198,40,40), fg=WHITE, size=7, bold=True, merge=True, text="Misses")
fmt(sh, 19, 36, 19, 40, bg=rgb(69,39,160), fg=WHITE, size=7, bold=True, merge=True, text="Hit rate")
nf = doc.NumberFormats
loc = Locale()
pct = nf.queryKey("0.0%", loc, False)
if pct == -1: pct = nf.addNew("0.0%", loc)
for i, (nm, h, m) in enumerate((("L1I", L["ST_L1I_H"], L["ST_L1I_M"]), ("L1D", L["ST_L1D_H"], L["ST_L1D_M"]),
                                 ("L2", L["ST_L2_H"], L["ST_L2_M"]))):
    r = 20 + i
    fmt(sh, r, 24, r, 27, bg=WHITE, size=8, bold=True, merge=True, text=nm)
    fmt(sh, r, 28, r, 31, bg=WHITE, size=9, bold=True, merge=True); C(sh, r, 28).setFormula("=$STATE.B%d" % (h + 1))
    fmt(sh, r, 32, r, 35, bg=WHITE, size=9, bold=True, merge=True); C(sh, r, 32).setFormula("=$STATE.B%d" % (m + 1))
    fmt(sh, r, 36, r, 40, bg=WHITE, size=9, bold=True, merge=True)
    C(sh, r, 36).setFormula('=IF($STATE.B%d+$STATE.B%d=0;"—";$STATE.B%d/($STATE.B%d+$STATE.B%d))' % (h+1, m+1, h+1, h+1, m+1))
    C(sh, r, 36).NumberFormat = pct
grid(sh, 19, 24, 22, 40, rgb(149,117,205))
fmt(sh, 24, 24, 26, 44, size=6, merge=True, wrap=True, center=False, fg=rgb(69,39,160),
    text="Policies: WRITE-THROUGH (RAM is always up to date), no write-allocate. "
         "Physical cache: TAG = physical base address of the line. When a frame is evicted by SWAP its lines are "
         "INVALIDATED. Line color = color of the page it came from.")

# --- RAM
box(sh, 7, 47, 27, 66, "MAIN MEMORY (RAM) 256 B = 8 frames × 32 B", rgb(46,125,50), rgb(232,245,233))
fmt(sh, 8, 47, 8, 48, size=6, bold=True, merge=True, text="Frame")
fmt(sh, 8, 49, 8, 49, size=6, bold=True, text="Page")
for i in range(16): fmt(sh, 8, 50 + i, 8, 50 + i, size=6, bold=True, text="%X" % i)
for f in range(8):
    r = 9 + 2 * f
    fmt(sh, r, 47, r + 1, 48, bg=rgb(46,125,50) if f < 7 else rgb(121,85,72), fg=WHITE, size=8, bold=True,
        merge=True, text="M%d" % f if f < 7 else "M7\nI/O", wrap=True)
    fmt(sh, r, 49, r + 1, 49, bg=COL["COL_FREE"], size=6, bold=True, merge=True, text="-")
    fmt(sh, r, 50, r + 1, 65, bg=COL["COL_FREE"], size=7, font="Courier New")
    for i in range(32): C(sh, r + i // 16, 50 + i % 16).setString("00")
    grid(sh, r, 50, r + 1, 65)
    outline(sh, r, 47, r + 1, 65, rgb(46,125,50), 30)
fmt(sh, 25, 47, 25, 66, size=6, bold=True, merge=True, text="Free frames: 7 of 7")
fmt(sh, 26, 47, 26, 50, bg=COL["COL_KBDQ"], size=5, merge=True, text="M7 00-07 KBD queue")
fmt(sh, 26, 51, 26, 55, bg=COL["COL_LCDB"], size=5, merge=True, text="M7 08-0F LCD video")
fmt(sh, 26, 56, 26, 66, size=5, merge=True, text="colors = virtual page held by the frame")

# --- DISK
box(sh, 7, 68, 27, 105, "DISK — VIRTUAL MEMORY / SWAP AREA  (512 B = 16 pages × 32 B)", rgb(230,81,0), rgb(255,243,224))
for base, lc in ((70, 68), (89, 87)):
    fmt(sh, 8, lc, 8, lc + 1, size=6, bold=True, merge=True, text="Page")
    for i in range(16): fmt(sh, 8, base + i, 8, base + i, size=6, bold=True, text="%X" % i)
for p in range(16):
    r = 9 + 2 * (p % 8); base = 70 if p < 8 else 89; lc = 68 if p < 8 else 87
    fmt(sh, r, lc, r + 1, lc + 1, bg=PAGECOLS[p], size=7, bold=True, merge=True, text="P%d" % p, wrap=True)
    fmt(sh, r, base, r + 1, base + 15, bg=PAGECOLS[p], size=7, font="Courier New")
    for i in range(32): C(sh, r + i // 16, base + i % 16).setString("00")
    grid(sh, r, base, r + 1, base + 15)
    outline(sh, r, lc, r + 1, base + 15, rgb(230,81,0), 25)
fmt(sh, 25, 68, 26, 105, size=6, merge=True, wrap=True, center=False, fg=rgb(191,54,12),
    text="The program is assembled and stored HERE (virtual memory). A page reaches RAM only when the CPU asks for it (demand paging). "
         "Green label 'P2 >M3' = page resident in frame M3. Every page keeps its color in disk, RAM, caches and timeline.")


# --- BUSES
def bus(r, color, label):
    fmt(sh, r, 1, r, 105, bg=color)
    C(sh, r, 1).setString(label); C(sh, r, 1).HoriJustify = LEFT; C(sh, r, 1).CharWeight = 150; C(sh, r, 1).CharHeight = 6


bus(30, BUS_CTL, "CONTROL BUS (Read · Write · Clock · IO)")
bus(32, BUS_ADR, "ADDRESS BUS (PA)")
bus(34, BUS_DAT, "DATA BUS (8 bits, bidirectional)")


def stub(col, r1, r2, color):
    for r in range(r1, r2 + 1):
        if r not in (30, 32, 34):
            C(sh, r, col).CellBackColor = color


for col, bc, last in ((18, BUS_CTL, 29), (19, BUS_ADR, 31), (20, BUS_DAT, 33),
                      (30, BUS_DAT, 33), (41, BUS_DAT, 33),
                      (53, BUS_CTL, 29), (55, BUS_ADR, 31), (58, BUS_DAT, 33),
                      (80, BUS_CTL, 29), (86, BUS_DAT, 33)):
    stub(col, 28, last, bc)
for col in (10, 31): stub(col, 35, 36, BUS_DAT)
fmt(sh, 28, 21, 28, 22, size=5, merge=True, text="CPU", bold=True)
fmt(sh, 28, 31, 28, 33, size=5, merge=True, text="L1", bold=True)
fmt(sh, 28, 42, 28, 43, size=5, merge=True, text="L2", bold=True)
fmt(sh, 28, 59, 28, 61, size=5, merge=True, text="RAM", bold=True)
fmt(sh, 28, 87, 28, 89, size=5, merge=True, text="DMA", bold=True)

# --- KEYBOARD
box(sh, 37, 1, 44, 18, "KEYBOARD  (input · 8 B queue in RAM M7)", rgb(123,31,162), rgb(243,229,245))
fmt(sh, 38, 1, 38, 18, size=6, merge=True, italic=True, text="Type in the box (max. 8) · ⌨ TYPE or just ▶▶ Run")
fmt(sh, 39, 1, 39, 3, size=7, bold=True, merge=True, text="Text:")
fmt(sh, 39, 4, 40, 11, bg=rgb(255,249,196), size=14, bold=True, merge=True, font="Courier New")
outline(sh, 39, 4, 40, 11, rgb(249,168,37), 50)
fmt(sh, 41, 1, 42, 3, size=7, bold=True, merge=True, text="Key:")
fmt(sh, 41, 4, 42, 5, bg=WHITE, size=14, bold=True, merge=True, font="Courier New")
outline(sh, 41, 4, 42, 5, rgb(123,31,162), 35)
fmt(sh, 41, 7, 42, 12, size=6, bold=True, merge=True, wrap=True, text="Keyboard tri-state buffer (En_KBD):")
fmt(sh, 41, 13, 42, 14, bg=COL["COL_HIZ"], size=8, bold=True, merge=True, text="Z")
fmt(sh, 43, 1, 43, 3, size=6, bold=True, merge=True, text="Head:")
fmt(sh, 43, 4, 43, 4, bg=WHITE, size=8, bold=True); C(sh, 43, 4).setFormula("=$STATE.B%d" % (L["ST_KHEAD"] + 1))
fmt(sh, 43, 6, 43, 8, size=6, bold=True, merge=True, text="Queued:")
fmt(sh, 43, 9, 43, 9, bg=WHITE, size=8, bold=True); C(sh, 43, 9).setFormula("=$STATE.B%d" % (L["ST_KCOUNT"] + 1))
fmt(sh, 43, 11, 43, 13, size=6, bold=True, merge=True, text="Free:")
fmt(sh, 43, 14, 43, 14, bg=WHITE, size=8, bold=True); C(sh, 43, 14).setFormula("=8-$STATE.B%d" % (L["ST_KCOUNT"] + 1))
fmt(sh, 44, 1, 44, 18, size=5, merge=True, fg=GRAY_TXT, text="I/O address: queue = PA 0xE0-0xE7 (M7)")

# --- LCD
box(sh, 37, 20, 44, 43, "8×1 LCD SCREEN  (output · 8 B video buffer in RAM M7)", rgb(0,105,92), rgb(224,242,241))
fmt(sh, 38, 21, 42, 42, bg=rgb(38,50,56))
fmt(sh, 39, 23, 41, 40, bg=rgb(156,204,101))
for i in range(8):
    fmt(sh, 39, 24 + 2 * i, 41, 25 + 2 * i, bg=rgb(156,204,101), fg=rgb(27,38,15), size=24, bold=True, merge=True, font="Courier New")
    outline(sh, 39, 24 + 2 * i, 41, 25 + 2 * i, rgb(139,186,85), 9)
for i in range(8): fmt(sh, 42, 24 + 2 * i, 42, 25 + 2 * i, fg=rgb(176,190,197), size=5, merge=True, text=str(i))
fmt(sh, 43, 21, 43, 23, size=6, bold=True, merge=True, text="Cursor:")
fmt(sh, 43, 24, 43, 24, bg=WHITE, size=8, bold=True); C(sh, 43, 24).setFormula("=$STATE.B%d" % (L["ST_LCDCUR"] + 1))
fmt(sh, 43, 26, 43, 29, size=6, bold=True, merge=True, text="Ld_LCD:")
fmt(sh, 43, 30, 43, 30, bg=COL["COL_OFF"], size=8, bold=True, text="0")
fmt(sh, 43, 32, 43, 42, size=5, merge=True, fg=GRAY_TXT, text="video buffer = PA 0xE8-0xEF (M7)")

# --- CONTROL WORD
box(sh, 37, 45, 44, 105, "CONTROL WORD  (vector emitted by the Control Unit on every micro-step)", rgb(55,71,79), rgb(236,239,241))
sigs = SIGNALS.split(",")
for i, s in enumerate(sigs):
    c = 46 + 2 * i
    fmt(sh, 38, c, 40, c + 1, bg=rgb(255,224,178) if s.startswith("En_") else rgb(207,216,220), size=7, bold=True, merge=True, text=s, rot=9000)
    fmt(sh, 41, c, 41, c + 1, bg=COL["COL_OFF"], size=9, bold=True, merge=True, text="0")
grid(sh, 38, 46, 41, 46 + 2 * len(sigs) - 1, rgb(144,164,174))
fmt(sh, 38, 89, 38, 105, size=6, bold=True, merge=True, text="Binary vector (signal order)")
fmt(sh, 39, 89, 40, 105, bg=rgb(38,50,56), fg=rgb(105,240,174), size=11, bold=True, merge=True, font="Courier New", text="0" * len(sigs))
fmt(sh, 41, 89, 41, 105, size=5, merge=True, fg=GRAY_TXT, text="orange = En_ (drives the bus) · gray = Ld_/control")
fmt(sh, 42, 45, 42, 49, size=6, bold=True, merge=True, text="Micro-step:")
fmt(sh, 42, 50, 42, 105, bg=WHITE, size=7, bold=True, merge=True, center=False, text="-")
fmt(sh, 43, 45, 43, 55, size=6, bold=True, merge=True, text="Buffer with output enabled:")
fmt(sh, 43, 56, 43, 105, bg=WHITE, size=7, bold=True, merge=True, center=False, fg=rgb(183,28,28),
    text="NONE -> everything in high impedance (High-Z)")
fmt(sh, 44, 45, 44, 105, size=6, merge=True, italic=True,
    text="Physical bus rule: at any instant only ONE tri-state buffer has Enable=1; the others stay in High-Z (Z). The 'ON/Z' buffers sit next to each register.")

# --- PAGE TABLE
box(sh, 47, 1, 68, 18, "PAGE TABLE (16 entries)", rgb(249,168,37), rgb(255,248,225))
for c1, c2, t in ((1, 2, "VPN"), (3, 3, "P"), (4, 5, "Frame"), (6, 6, "D"), (7, 7, "R"),
                  (8, 9, "Load"), (10, 11, "Use"), (12, 18, "Status")):
    fmt(sh, 48, c1, 48, c2, bg=rgb(255,224,130), size=7, bold=True, merge=True, text=t)
for v in range(16):
    r = 49 + v
    fmt(sh, r, 1, r, 2, bg=PAGECOLS[v], size=7, bold=True, merge=True, text="P%d" % v)
    for c1, c2 in ((3, 3), (4, 5), (6, 6), (7, 7), (8, 9), (10, 11), (12, 18)):
        fmt(sh, r, c1, r, c2, bg=WHITE, size=7, merge=True)
    C(sh, r, 3).setString("0"); C(sh, r, 4).setString("-"); C(sh, r, 6).setString("0"); C(sh, r, 7).setString("0")
    C(sh, r, 12).setString("on disk")
grid(sh, 48, 1, 64, 18, rgb(249,168,37))
fmt(sh, 65, 1, 65, 5, size=6, bold=True, merge=True, text="Page faults:")
fmt(sh, 65, 6, 65, 7, bg=WHITE, size=9, bold=True, merge=True, fg=rgb(198,40,40)); C(sh, 65, 6).setFormula("=$STATE.B%d" % (L["ST_PF"] + 1))
fmt(sh, 65, 8, 65, 10, size=6, bold=True, merge=True, text="Swap-in:")
fmt(sh, 65, 11, 65, 12, bg=WHITE, size=9, bold=True, merge=True); C(sh, 65, 11).setFormula("=$STATE.B%d" % (L["ST_SWIN"] + 1))
fmt(sh, 65, 13, 65, 15, size=6, bold=True, merge=True, text="Swap-out:")
fmt(sh, 65, 16, 65, 17, bg=WHITE, size=9, bold=True, merge=True); C(sh, 65, 16).setFormula("=$STATE.B%d" % (L["ST_SWOUT"] + 1))
fmt(sh, 66, 1, 68, 18, size=6, merge=True, wrap=True, center=False,
    text="P = present in RAM · D = dirty (modified) · R = referenced · Load = arrival time (FIFO) · Use = last access (LRU). "
         "VA (9 bits) = page (4 bits) | offset (5 bits).  PA = frame × 32 + offset.")

# --- SWAP TIMELINE
box(sh, 47, 20, 60, 105, "SWAP TIMELINE — reference string and frame contents after every access", rgb(85,139,47), rgb(241,248,233))
fmt(sh, 48, 20, 48, 105, size=6, merge=True, italic=True, center=False,
    text="Each column = one memory reference (i = instruction, r = read, w = write). F = page fault. 'Out' = victim page sent to disk. Bold = referenced page.")
for r, t in ((49, "t"), (50, "Ref."), (58, "Fault"), (59, "Out")):
    fmt(sh, r, 20, r, 23, bg=rgb(197,225,165), size=7, bold=True, merge=True, text=t)
for f in range(7):
    fmt(sh, 51 + f, 20, 51 + f, 23, bg=rgb(46,125,50), fg=WHITE, size=7, bold=True, merge=True, text="Frame M%d" % f)
fmt(sh, 49, 24, 59, 105, bg=WHITE, size=6)
grid(sh, 49, 24, 59, 105, rgb(197,225,165))

# --- EVENT LOG
box(sh, 62, 20, 77, 105, "MICRO-OPERATION LOG (most recent first)", rgb(66,66,66), rgb(250,250,250))
fmt(sh, 63, 20, 76, 105, size=7, merge=True, center=False, font="Courier New", bg=WHITE, wrap=True)
C(sh, 63, 20).VertJustify = 1

# --- PROGRAM WINDOW
box(sh, 70, 1, 95, 18, "RUNNING PROGRAM (yellow line = PC)", rgb(130,119,23), COL["COL_CODE_BG"])
for k in range(L["CODE_MAX"]):
    r = L["R_CODE0"] + k
    fmt(sh, r, 1, r, 2, size=7, bold=True, merge=True, font="Courier New", bg=COL["COL_CODE_BG"])
    fmt(sh, r, 3, r, 7, size=6, merge=True, font="Courier New", bg=COL["COL_CODE_BG"])
    fmt(sh, r, 8, r, 18, size=7, merge=True, center=False, font="Courier New", bg=COL["COL_CODE_BG"])

# ============================================================== PROGRAMS sheet
pg = sheets.getByName("PROGRAMS")
R(pg, 0, 0, 60, 14).CharFontName = "Arial"
for c, w in ((0, 700), (1, 8800), (2, 300), (3, 8800), (4, 300), (5, 8800), (6, 300), (7, 8800), (8, 300),
             (9, 1200), (10, 2600), (11, 6500), (12, 1100)):
    pg.Columns.getByIndex(c).Width = w
pg.Rows.getByIndex(0).Height = 800; pg.Rows.getByIndex(1).Height = 1000; pg.Rows.getByIndex(3).Height = 700
fmt(pg, 0, 0, 0, 12, bg=rgb(13,71,161), fg=WHITE, size=13, bold=True, merge=True,
    text="PROGRAM DIRECTORY (catalog on disk) · EDITOR · ASSEMBLER · LOADER")
for c, t, colr in ((1, "PROGRAM 1 — Sequential multiplication (AX, BX, CX, DX + loop)", rgb(21,101,192)),
                   (3, "PROGRAM 2 — Keyboard → 8×1 LCD (interactive echo)", rgb(123,31,162)),
                   (5, "PROGRAM 3 — Memory fill and SWAP (page faults)", rgb(230,81,0)),
                   (7, "EDITOR — free code (check and load)", rgb(46,125,50))):
    fmt(pg, 2, c, 2, c, bg=colr, fg=WHITE, size=9, bold=True, text=t, wrap=True)
fmt(pg, 2, 9, 2, 12, bg=rgb(55,71,79), fg=WHITE, size=9, bold=True, merge=True, text="LAST ASSEMBLY LISTING")
for c, t in ((9, "Addr"), (10, "Machine code"), (11, "Instruction"), (12, "Page")):
    fmt(pg, 3, c, 3, c, bg=rgb(207,216,220), size=8, bold=True, text=t)
fmt(pg, 3, 1, 3, 5, size=7, merge=True, italic=True, wrap=True,
    text="One line = one cell (press Enter after editing). ';' comments · 'LABEL:' jumps · '.DATA addr, v1, v2…' data. In P1 the .DATA line is rewritten by the INPUTS panel.")
fmt(pg, 3, 7, 3, 7, bg=rgb(245,245,245), size=8, bold=True, wrap=True, text="(syntax checker messages)")
for col, prog in PROGRAMS.items():
    rg = R(pg, L["PG_R0"], col, L["PG_R0"] + L["PG_NLINES"] - 1, col)
    rg.CharFontName = "Courier New"; rg.CharHeight = 9
    rg.CellBackColor = rgb(255,253,240) if col != L["PG_COL_ED"] else rgb(232,245,233)
    for i, ln in enumerate(prog[:L["PG_NLINES"]]): C(pg, L["PG_R0"] + i, col).setString(ln)
    grid(pg, L["PG_R0"], col, L["PG_R0"] + L["PG_NLINES"] - 1, col, rgb(224,224,224))
rl = R(pg, L["PG_R0"], 9, L["PG_R0"] + L["PG_NLINES"] - 1, 12)
rl.CharFontName = "Courier New"; rl.CharHeight = 8
grid(pg, L["PG_R0"], 9, L["PG_R0"] + L["PG_NLINES"] - 1, 12, rgb(224,224,224))
for i in range(L["PG_NLINES"]): C(pg, L["PG_R0"] + i, 0).setValue(i + 1)
R(pg, L["PG_R0"], 0, L["PG_R0"] + L["PG_NLINES"] - 1, 0).CharColor = rgb(158,158,158)
R(pg, L["PG_R0"], 0, L["PG_R0"] + L["PG_NLINES"] - 1, 0).CharHeight = 7

# ============================================================== ISA sheet
isa = sheets.getByName("ISA")
for c, w in ((0, 1500), (1, 4800), (2, 6000), (3, 9000), (4, 5200)): isa.Columns.getByIndex(c).Width = w
fmt(isa, 0, 0, 0, 4, bg=rgb(13,71,161), fg=WHITE, size=13, bold=True, merge=True,
    text="INSTRUCTION SET ARCHITECTURE (ISA) — fixed 4-byte format")
r = 2
if not ISA_LINES:
    fmt(isa, 2, 0, 2, 4, size=9, merge=True, italic=True, fg=GRAY_TXT,
        text="The instruction table, fetch cycle and memory map are added by the ISA issue (src/data/isa.txt).")
for ln in ISA_LINES:
    if not ln.strip():
        r += 1; continue
    if ln.startswith("#"):
        r += 1
        fmt(isa, r, 0, r, 4, bg=rgb(230,81,0), fg=WHITE, size=11, bold=True, merge=True, text=ln[1:].strip())
    elif ln.startswith("|"):
        head = ln.startswith("|!")
        cells = [c.strip() for c in ln[2 if head else 1:].split("|")]
        for j, t in enumerate(cells[:5]):
            cl = C(isa, r, j); cl.setString(t); cl.CharHeight = 9
            if head:
                cl.CellBackColor = rgb(55,71,79); cl.CharColor = WHITE; cl.CharWeight = 150
            elif j < 3:
                cl.CharFontName = "Courier New"
        grid(isa, r, 0, r, 4)
    else:
        fmt(isa, r, 0, r, 4, size=9, merge=True, center=False, wrap=True, text=ln.strip())
        if len(ln) > 120: isa.Rows.getByIndex(r).Height = 900
    r += 1

# ============================================================== GUIDE sheet
gu = sheets.getByName("GUIDE")
gu.Columns.getByIndex(0).Width = 600; gu.Columns.getByIndex(1).Width = 26000
fmt(gu, 0, 0, 0, 1, bg=rgb(13,71,161), fg=WHITE, size=13, bold=True, merge=True, text="QUICK USER GUIDE")
guide = [
    ("H", "0. Enable macros (only once)"),
    ("", "Tools > Options > LibreOffice > Security > Macro Security > MEDIUM. Close and reopen the file and choose 'Enable Macros'."),
    ("", "If the buttons do not respond: Form menu (or View > Toolbars > Form Design) and turn off 'Design Mode'."),
    ("", "If you edit a CELL (code in PROGRAMS or a memory byte), press Enter before using a button: while a cell is being edited LibreOffice does not pass the click to the macros."),
    ("H", "1. Sheets"),
    ("", "SIMULATOR = the machine.  PROGRAMS = catalog, editor and assembly listing.  ISA = instruction set and micro-operations.  STATE = internal counters (do not edit)."),
] + GUIDE_EXTRA
for i, (k, t) in enumerate(guide):
    cl = C(gu, 2 + i, 1); cl.setString(t); cl.IsTextWrapped = True; cl.VertJustify = 2
    if k == "H":
        R(gu, 2 + i, 0, 2 + i, 1).CellBackColor = rgb(227,242,253); cl.CharWeight = 150; cl.CharHeight = 11
        gu.Rows.getByIndex(2 + i).Height = 650
    else:
        cl.CharHeight = 10; gu.Rows.getByIndex(2 + i).Height = 950 if len(t) > 180 else 600

# ============================================================== STATE sheet
es = sheets.getByName("STATE")
es.Columns.getByIndex(0).Width = 7000; es.Columns.getByIndex(1).Width = 2000; es.Columns.getByIndex(2).Width = 6000
for i, (n, d) in enumerate(STATE):
    C(es, i, 0).setString("%s — %s" % (n, d)); C(es, i, 1).setValue(STATE_DEFAULTS.get(n, 0))
C(es, len(STATE) + 1, 0).setString("Internal simulator sheet: do not edit.")

# ============================================================== Basic modules
lib = doc.BasicLibraries
if not lib.hasByName("Standard"): lib.createLibrary("Standard")
std = lib.getByName("Standard")
for name, code in basic_modules():
    if std.hasByName(name): std.removeByName(name)
    std.insertByName(name, code)


# ============================================================== form controls
def macro(n):
    return "vnd.sun.star.script:Standard.Core.%s?language=Basic&location=document" % n


def place(s, model, r, c, wcols, hrows, pad=30):
    shape = doc.createInstance("com.sun.star.drawing.ControlShape")
    cell = C(s, r, c); pos = cell.Position
    w = sum(s.Columns.getByIndex(c + i).Width for i in range(wcols)) - 2 * pad
    h = sum(s.Rows.getByIndex(r + i).Height for i in range(hrows)) - 2 * pad
    shape.Size = Size(w, h); shape.Position = Point(pos.X + pad, pos.Y + pad)
    shape.Control = model
    s.DrawPage.add(shape)
    shape.Anchor = cell


def button(s, label, r, c, wcols, hrows, mac, bg, size=9):
    model = doc.createInstance("com.sun.star.form.component.CommandButton")
    model.Label = label; model.Name = "btn_" + mac
    model.BackgroundColor = bg; model.TextColor = WHITE; model.FontHeight = size; model.FontWeight = 150
    place(s, model, r, c, wcols, hrows, pad=20)


def control(s, kind, name, r, c, wcols, hrows, **props):
    model = doc.createInstance("com.sun.star.form.component." + kind)
    model.Name = name
    for k, v in props.items():
        if isinstance(v, uno.Any): uno.invoke(model, "setPropertyValue", (k, v))
        else: setattr(model, k, v)
    place(s, model, r, c, wcols, hrows)


button(sh, "P1 · Multiplication", 3, 1, 12, 2, "BtnLoadP1", rgb(21,101,192))
button(sh, "P2 · Keyboard → LCD", 3, 13, 12, 2, "BtnLoadP2", rgb(123,31,162))
button(sh, "P3 · Memory fill + SWAP", 3, 25, 12, 2, "BtnLoadP3", rgb(230,81,0))
button(sh, "▶  Step", 3, 38, 8, 2, "BtnStep", rgb(46,125,50), size=11)
button(sh, "▶▶  Run", 3, 46, 9, 2, "BtnRun", rgb(27,94,32), size=11)
button(sh, "■  Stop", 3, 55, 7, 2, "BtnStop", rgb(183,28,28), size=10)
button(sh, "⟲  Reset", 3, 62, 8, 2, "BtnReset", rgb(84,110,122), size=10)
button(sh, "Load EDITOR", 3, 71, 9, 2, "BtnLoadEditor", rgb(130,119,23))
button(sh, "⌨ TYPE", 39, 12, 6, 2, "BtnType", rgb(123,31,162))
button(pg, "✔ Check EDITOR syntax", 1, 7, 1, 1, "BtnCheckEditor", rgb(46,125,50))
button(pg, "Assemble and load EDITOR → simulator", 1, 9, 3, 1, "BtnLoadEditor", rgb(130,119,23))
button(pg, "Load P1", 1, 1, 1, 1, "BtnLoadP1", rgb(21,101,192))
button(pg, "Load P2", 1, 3, 1, 1, "BtnLoadP2", rgb(123,31,162))
button(pg, "Load P3", 1, 5, 1, 1, "BtnLoadP3", rgb(230,81,0))

YEL = rgb(255,249,196)
control(sh, "TextField", "txtKeyboard", 39, 4, 8, 2, Text="HELLO", DefaultText="HELLO", MaxTextLen=8,
        FontHeight=16, FontWeight=150, FontName="Courier New", BackgroundColor=YEL, Align=1, Border=0)
for name, col, val in (("numA", 83, "7"), ("numB", 90, "5")):
    control(sh, "TextField", name, 2, col, 5, 1, Text=val, DefaultText=val, MaxTextLen=3, Align=1,
            FontHeight=10, FontWeight=150, BackgroundColor=YEL, Border=1)


def dropdown(name, c, w, items, sel):
    control(sh, "ListBox", name, 4, c, w, 1, Dropdown=True, LineCount=len(items), FontHeight=10, FontWeight=150,
            BackgroundColor=YEL, Border=1,
            StringItemList=uno.Any("[]string", tuple(items)),
            DefaultSelection=uno.Any("[]short", (sel,)), SelectedItems=uno.Any("[]short", (sel,)))


dropdown("lstSpeed", 82, 6, ["1", "2", "3", "4", "5"], 2)
dropdown("lstAnim", 89, 7, ["YES", "NO"], 0)
dropdown("lstAlg", 97, 7, ["LRU", "FIFO"], 0)

# Bind each button to ITS macro. Done at the end because adding shapes can shift the
# index of the controls inside the form, and events are attached by index.
for s_ in (sh, pg):
    forms = s_.DrawPage.Forms
    for fi in range(forms.Count):
        form = forms.getByIndex(fi)
        for i in range(form.Count):
            m = form.getByIndex(i)
            form.revokeScriptEvents(i)
            if m.Name.startswith("btn_"):
                ev = ScriptEventDescriptor()
                ev.ListenerType = "XActionListener"; ev.EventMethod = "actionPerformed"
                ev.ScriptType = "Script"; ev.ScriptCode = macro(m.Name[4:])
                form.registerScriptEvent(i, ev)

# no spell checking (avoids red underlines on hex values and code)
nolang = Locale("zxx", "", "")
for n in ("SIMULATOR", "PROGRAMS", "ISA", "GUIDE", "STATE"):
    R(sheets.getByName(n), 0, 0, 120, 110).CharLocale = nolang
try:
    doc.ApplyFormDesignMode = False
except Exception:
    pass

# print setup: SIMULATOR on one A3 landscape page
ps = doc.StyleFamilies.getByName("PageStyles").getByName(sh.PageStyle)
ps.IsLandscape = True; ps.Width = 42000; ps.Height = 29700
ps.LeftMargin = ps.RightMargin = ps.TopMargin = ps.BottomMargin = 600
ps.HeaderIsOn = False; ps.FooterIsOn = False
ps.ScaleToPagesX = 1; ps.ScaleToPagesY = 1
sh.setPrintAreas((R(sh, 0, 0, 96, 106).RangeAddress,))
ctrl = doc.CurrentController
ctrl.setActiveSheet(sh)
try:
    ctrl.ZoomType = 3; ctrl.ZoomValue = 80; ctrl.ShowGrid = False
except Exception:
    pass

# team logo (added by the logo issue)
if os.path.exists(LOGO):
    gp = ctx.ServiceManager.createInstanceWithContext("com.sun.star.graphic.GraphicProvider", ctx)
    graphic = gp.queryGraphic((pv("URL", uno.systemPathToFileUrl(LOGO)),))
    logo = doc.createInstance("com.sun.star.drawing.GraphicObjectShape")
    logo.Graphic = graphic
    cell = C(sh, 0, 1); pos = cell.Position
    side = sum(sh.Rows.getByIndex(i).Height for i in range(3)) - 60
    logo.Size = Size(side, side)
    w4 = sum(sh.Columns.getByIndex(c).Width for c in range(1, 5))
    logo.Position = Point(pos.X + (w4 - side) // 2, pos.Y + 30)
    sh.DrawPage.add(logo)
    logo.Anchor = cell
    C(sh, 0, 1).setString("")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
doc.storeToURL(uno.systemPathToFileUrl(OUT), (pv("FilterName", "calc8"),))
doc.close(True)
if own_proc is not None:
    try: desktop.terminate()
    except Exception: pass
print("Saved", OUT)
