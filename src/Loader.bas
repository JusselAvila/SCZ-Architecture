REM =====================================================================
REM  SCZ-Architecture - Loader module
REM  Loader (image to virtual memory), machine reset and Program 1 result
REM =====================================================================
Option Explicit

Sub LoadProg(ByVal colSrc As Integer, ByVal nm As String)
	InitSh()
	Dim img(511) As Long, nCode As Long, er As String, i As Integer, p As Integer, va As Long, k As Integer
	Dim a As Long, b As Long, usesIn As Integer, ln As String
	If colSrc = PG_COL_P1 Then
		a = NumInput("numA", 7) : b = NumInput("numB", 5)
		For i = 0 To PG_NLINES - 1
			ln = oPg.getCellByPosition(colSrc, PG_R0 + i).getString()
			If InStr(UCase(ln), ".DATA") > 0 And InStr(UCase(ln), "0X040") > 0 Then
				oPg.getCellByPosition(colSrc, PG_R0 + i).setString(".DATA 0x040, " & a & ", " & b & "      ; A = " & a & " , B = " & b & "  (from the P1 INPUTS panel)")
			End If
		Next i
	End If
	If Not Assemble(colSrc, img, nCode, er) Then
		Status("Assembly error in " & nm & ": " & er, 3)
		Exit Sub
	End If
	ThisComponent.lockControllers()
	ResetMachine()
	For va = 0 To 479
		PutS(DskRow(va), DskCol(va), H2(img(va)))
	Next va
	REM program window
	For k = 0 To CODE_MAX - 1
		PutS(R_CODE0 + k, C_CODE_A, oPg.getCellByPosition(PG_LST, PG_R0 + k).getString())
		PutS(R_CODE0 + k, C_CODE_B, oPg.getCellByPosition(PG_LST + 1, PG_R0 + k).getString())
		PutS(R_CODE0 + k, C_CODE_S, oPg.getCellByPosition(PG_LST + 2, PG_R0 + k).getString())
	Next k
	SetSt(ST_LOADED, 1)
	SetSt(ST_PROGCOL, colSrc)
	oSt.getCellByPosition(2, ST_PROGCOL).setString(nm)
	SetSt(ST_NCODE, nCode)
	SetSt(ST_A, a) : SetSt(ST_B, b)
	If colSrc = PG_COL_P1 Then
		If NormCode(colSrc) = P1_SIG Then SetSt(ST_P1ORIG, 1)
	End If
	For k = 0 To CODE_MAX - 1
		If Left(UCase(Trim(Mid(oPg.getCellByPosition(PG_LST + 2, PG_R0 + k).getString(), InStr(oPg.getCellByPosition(PG_LST + 2, PG_R0 + k).getString(), ":") + 1))), 3) = "IN " Then usesIn = 1
	Next k
	SetSt(ST_USESIN, usesIn)
	PutS(R_PROGNM, C_PROGNM, nm)
	If colSrc = PG_COL_P1 Then
		If St(ST_P1ORIG) = 1 Then
			PutS(R_P1RES, C_P1RES, a & " x " & b & " = ?")
		Else
			PutS(R_P1RES, C_P1RES, "A=" & a & ", B=" & b & "  (modified code)")
		End If
	Else
		PutS(R_P1RES, C_P1RES, "(P1 only)")
	End If
	ThisComponent.unlockControllers()
	HiCode(0)
	For p = 0 To (nCode - 1) \ 32
		FlashDiskPage(p, COL_TOK_DATA)
	Next p
	If colSrc = PG_COL_P1 Then Status("P1 inputs: A = " & a & " and B = " & b & " are written to virtual memory (0x040 and 0x041, page 2).", 0)
	Status("'" & nm & "' assembled (" & nCode & " bytes = " & (nCode \ 4) & " instructions) and loaded into VIRTUAL MEMORY (disk). RAM is empty: every page will arrive through a page fault.", 1)
End Sub

Sub ResetMachine()
	Dim i As Integer, f As Integer, c As Long, r As Long, v As Integer
	REM registers
	For i = 0 To 3
		r = RRow(RegName(i))
		PutS(r, C_LVAL, "00") : PutS(r, C_LDEC, "0") : PutS(r, C_LCHR, "-")
	Next i
	PutS(R_PC, C_RVAL, "000") : PutS(R_MAR, C_RVAL, "000") : PutS(R_MDR, C_RVAL, "00")
	PutS(R_IR, C_RVAL, "-- -- -- --") : PutS(R_IRM, C_RLBL, "")
	PutS(R_ALU_A, C_ALU_V, "") : PutS(R_ALU_B, C_ALU_V, "") : PutS(R_ALU_R, C_ALU_V, "") : PutS(R_ALU_A, C_ALU_OP, "")
	SetFlag(C_ZF, 0) : SetFlag(C_CF, 0) : SetFlag(C_SF, 0)
	PutS(R_HALT, C_HALT, "CPU READY")
	Bg(R_HALT, C_HALT, COL_ST_OK)
	PutS(R_MMU1, C_MMU, "VA -> (page, offset)")
	PutS(R_MMU2, C_MMU, "page -> frame  =>  PA")
	PutS(R_UC_PH, C_UC_V, "-") : PutS(R_UC_MI, C_UC_MI, "-") : PutS(R_UC_CLK, C_UC_V, "0") : PutS(R_UC_INS, C_UC_V, "0")
	REM RAM: frames 0-6 free, frame 7 = I/O
	For f = 0 To 6
		For i = 0 To 31
			PutS(RamRow(f * 32 + i), RamCol(f * 32 + i), "00")
			Bg(RamRow(f * 32 + i), RamCol(f * 32 + i), COL_FREE)
		Next i
		PutS(R_RAM0 + f * 2, C_RAMPG, "-")
		Bg(R_RAM0 + f * 2, C_RAMPG, COL_FREE)
	Next f
	For i = 0 To 31
		PutS(RamRow(224 + i), RamCol(224 + i), "00")
		If i < 8 Then
			Bg(RamRow(224 + i), RamCol(224 + i), COL_KBDQ_E)
		ElseIf i < 16 Then
			Bg(RamRow(224 + i), RamCol(224 + i), COL_LCDB)
		Else
			Bg(RamRow(224 + i), RamCol(224 + i), COL_IORES)
		End If
	Next i
	PutS(R_RAM0 + 14, C_RAMPG, "P15")
	Bg(R_RAM0 + 14, C_RAMPG, PageCol(15))
	REM disk
	For v = 0 To 15
		For i = 0 To 31
			PutS(DskRow(v * 32 + i), DskCol(v * 32 + i), "00")
			Bg(DskRow(v * 32 + i), DskCol(v * 32 + i), PageCol(v))
		Next i
		DiskLabel(v, -1)
	Next v
	PutS(R_DSK0 + 14, C_DLBLB, "P15 E/S")
	REM page table
	For v = 0 To 15
		r = R_PT0 + v
		PutS(r, C_PT_P, "0") : PutS(r, C_PT_PFN, "-") : PutS(r, C_PT_D, "0") : PutS(r, C_PT_R, "0")
		PutS(r, C_PT_CAR, "") : PutS(r, C_PT_USO, "")
		PutS(r, C_PT_EST, "on disk")
		PTNormal(v)
	Next v
	r = R_PT0 + 15
	PutS(r, C_PT_P, "1") : PutS(r, C_PT_PFN, "7") : PutS(r, C_PT_EST, "I/O pinned to M7")
	Cel(r, C_PT_CAR).setValue(0) : Cel(r, C_PT_USO).setValue(0)
	PTPaint(15, COL_IORES)
	REM caches
	ClearLine(R_L1I) : ClearLine(R_L1D)
	For i = 0 To 3 : ClearLine(R_L2_0 + i) : Next i
	PutS(R_L1I, C_CIND, "") : Bg(R_L1I, C_CIND, COL_CEMPTY)
	PutS(R_L1D, C_CIND, "") : Bg(R_L1D, C_CIND, COL_CEMPTY)
	PutS(R_L2_0, C_CIND, "") : Bg(R_L2_0, C_CIND, COL_CEMPTY)
	REM timeline
	For c = C_TL0 To C_TL0 + TL_MAX - 1
		For r = R_TL_T To R_TL_V
			Cel(r, c).setString("")
			Cel(r, c).CellBackColor = COL_TL_BG
			Cel(r, c).CharWeight = 100
		Next r
	Next c
	REM log, LCD, control word
	PutS(R_LOG0, C_LOG, "")
	gPrevSig = ""
	For i = 0 To 7 : PutS(R_LCD, C_LCD0 + 2 * i, "") : Next i
	For i = 0 To UBound(gSigs)
		PutS(R_CWV, C_CW0 + 2 * i, "0") : Bg(R_CWV, C_CW0 + 2 * i, COL_OFF)
	Next i
	PutS(R_CWVEC, C_CWVEC, String(UBound(gSigs) + 1, "0"))
	PutS(R_CWM, C_CWM, "-") : PutS(R_EMI, C_EMI, "NONE -> everything in high impedance (High-Z)")
	TriBuf(R_AX, C_LBUF, False) : TriBuf(R_BX, C_LBUF, False) : TriBuf(R_CX, C_LBUF, False) : TriBuf(R_DX, C_LBUF, False)
	TriBuf(R_ALU_IO, C_LBUF, False) : TriBuf(R_PC, C_RBUF, False) : TriBuf(R_IR, C_RBUF, False) : TriBuf(R_MDR, C_RBUF, False)
	TriBuf(R_KBUF, C_KBUF, False)
	PutS(R_KKEY, C_KKEY, "")
	REM program window
	For r = 0 To CODE_MAX - 1
		For c = C_CODE0 To C_CODE1
			Bg(R_CODE0 + r, c, COL_CODE_BG)
		Next c
		PutS(R_CODE0 + r, C_CODE_A, "") : PutS(R_CODE0 + r, C_CODE_B, "") : PutS(R_CODE0 + r, C_CODE_S, "")
	Next r
	REM state
	For i = 0 To ST_LAST : SetSt(i, 0) : Next i
	SetSt(ST_LASTFP, -1)
	SetSt(ST_CODEHI, -1)
	UpdFree()
End Sub

Function NormCode(ByVal col As Integer) As String
	Dim i As Integer, t As String, p As Integer, r As String
	r = ""
	For i = 0 To PG_NLINES - 1
		t = oPg.getCellByPosition(col, PG_R0 + i).getString()
		p = InStr(t, ";")
		If p > 0 Then t = Left(t, p - 1)
		t = UCase(Trim(Replace(t, Chr(9), " ")))
		Do While InStr(t, "  ") > 0
			t = Replace(t, "  ", " ")
		Loop
		If t <> "" And Left(t, 5) <> ".DATA" Then r = r & t & "|"
	Next i
	NormCode = r
End Function

Sub ShowP1Result()
	Dim a As Long, b As Long, dx As Long, txt As String
	If St(ST_PROGCOL) <> PG_COL_P1 Then Exit Sub
	a = St(ST_A) : b = St(ST_B) : dx = GetReg("DX")
	If St(ST_P1ORIG) = 1 Then
		REM original multiplication code
		txt = a & " x " & b & " = " & dx
		If a * b > 255 Then txt = txt & "  (8-bit overflow: real " & (a * b) & ")"
	Else
		REM the code was modified: do not assume which operation it performs
		txt = "A=" & a & ", B=" & b & "  ->  DX = " & dx
	End If
	PutS(R_P1RES, C_P1RES, txt)
	Flash(R_P1RES, C_P1RES, COL_FLASH)
End Sub
