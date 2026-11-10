#!/usr/bin/env python3
"""
SCZ-Architecture - headless regression tests.

Opens dist/Simulator_SIS131.ods in LibreOffice (no window), loads each catalog program,
runs it at speed 5 with LRU and with FIFO, and compares registers, LCD, page faults and
counters with tests/expected.json.

Usage (from the repository root, needs LibreOffice + python3-uno):
    python3 tests/run_tests.py                 # uses dist/Simulator_SIS131.ods
    python3 tests/run_tests.py path/file.ods
Exit code 0 = all tests passed.
"""
import json, os, subprocess, sys, time
import uno
from com.sun.star.beans import PropertyValue

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ODS = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, "dist", "Simulator_SIS131.ods")
EXPECTED = json.load(open(os.path.join(ROOT, "tests", "expected.json"), encoding="utf-8"))
PORT = int(os.environ.get("SOFFICE_PORT", "2002"))

# cell positions (row, column), same as the layout table in build/build.py
POS = {"AX": (9, 4), "BX": (11, 4), "CX": (13, 4), "DX": (15, 4), "STATUS": (5, 1), "P1RES": (2, 95)}
LCD_ROW, LCD_COL0 = 39, 24
STATE_ROWS = {"PF": 15, "SWOUT": 16, "SWIN": 17, "INSTR": 5, "HALT": 4}
TIMELINE_OUT_ROW, TIMELINE_COL0 = 59, 24


def pv(n, v):
    p = PropertyValue(); p.Name = n; p.Value = v; return p


def connect():
    local = uno.getComponentContext()
    res = local.ServiceManager.createInstanceWithContext("com.sun.star.bridge.UnoUrlResolver", local)
    url = "uno:socket,host=localhost,port=%d;urp;StarOffice.ComponentContext" % PORT
    try:
        return res.resolve(url)
    except Exception:
        subprocess.Popen(["soffice", "--headless", "--invisible", "--norestore",
                          "--accept=socket,host=localhost,port=%d;urp;" % PORT],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(80):
            try:
                return res.resolve(url)
            except Exception:
                time.sleep(0.5)
    raise RuntimeError("LibreOffice is not reachable")


def run_case(desktop, case, policy):
    doc = desktop.loadComponentFromURL(uno.systemPathToFileUrl(ODS), "_blank", 0,
                                       (pv("Hidden", True), pv("MacroExecutionMode", 4)))
    try:
        sh = doc.Sheets.getByName("SIMULATOR"); st = doc.Sheets.getByName("STATE")
        form = sh.DrawPage.Forms.getByIndex(0)
        sel = lambda name, idx: uno.invoke(form.getByName(name), "setPropertyValue",
                                           ("SelectedItems", uno.Any("[]short", (idx,))))
        sel("lstSpeed", 4)                                   # speed 5 = no animation
        sel("lstAlg", 0 if policy == "LRU" else 1)
        if "A" in case: form.getByName("numA").Text = str(case["A"])
        if "B" in case: form.getByName("numB").Text = str(case["B"])
        if "text" in case: form.getByName("txtKeyboard").Text = case["text"]
        sp = doc.getScriptProvider()
        for macro in (case["load"], "BtnRun"):
            sp.getScript("vnd.sun.star.script:Standard.Core.%s?language=Basic&location=document" % macro).invoke((), (), ())
        g = lambda rc: sh.getCellByPosition(rc[1], rc[0]).getString()
        got = {k: g(POS[k]) for k in ("AX", "BX", "CX", "DX", "P1RES")}
        got["LCD"] = "".join(sh.getCellByPosition(LCD_COL0 + 2 * i, LCD_ROW).getString() or " " for i in range(8)).rstrip()
        for k, r in STATE_ROWS.items():
            got[k] = int(st.getCellByPosition(1, r).getValue())
        got["VICTIMS"] = [v for v in (sh.getCellByPosition(TIMELINE_COL0 + i, TIMELINE_OUT_ROW).getString() for i in range(82)) if v]
        got["STATUS"] = g(POS["STATUS"])
        return got
    finally:
        doc.close(True)


def main():
    if not os.path.exists(ODS):
        print("File not found:", ODS); return 2
    ctx = connect()
    desktop = ctx.ServiceManager.createInstanceWithContext("com.sun.star.frame.Desktop", ctx)
    total = failed = 0
    for case in EXPECTED["cases"]:
        for policy in case.get("policies", ["LRU", "FIFO"]):
            exp = dict(case["expect"]); exp.update(case.get("expect_" + policy, {}))
            got = run_case(desktop, case, policy)
            diffs = ["%s: expected %r, got %r" % (k, v, got.get(k)) for k, v in exp.items() if got.get(k) != v]
            total += 1
            if diffs:
                failed += 1
                print("FAIL  %-30s %-4s  %s" % (case["name"], policy, "; ".join(diffs)))
                print("      status:", got["STATUS"])
            else:
                print("PASS  %-30s %-4s" % (case["name"], policy))
    print("\n%d/%d passed" % (total - failed, total))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
