REM =====================================================================
REM  SCZ-Architecture - CacheL1 module
REM  L1I and L1D caches (one 8 B line each) and memory access through the hierarchy
REM =====================================================================
Option Explicit

Function L1Row(ByVal isI As Boolean) As Long
	If isI Then
		L1Row = R_L1I
	Else
		L1Row = R_L1D
	End If
End Function

Function LineHas(ByVal r As Long, ByVal lb As Long) As Boolean
	LineHas = (GetS(r, C_CV) = "1" And GetS(r, C_CTAG) = H3(lb))
End Function

Sub CacheInd(ByVal r As Long, ByVal hit As Boolean, ByVal lvl As String)
	If hit Then
		PutS(r, C_CIND, lvl & " HIT")
		Bg(r, C_CIND, COL_HIT)
	Else
		PutS(r, C_CIND, lvl & " MISS")
		Bg(r, C_CIND, COL_MISS)
	End If
	Pause(gDelay * 6)
End Sub

Sub CopyLine(ByVal rDst As Long, ByVal lb As Long, ByVal fromL2 As Boolean)
	Dim i As Integer, col As Long, s As String
	col = PageCol(FramePage(lb \ 32))
	For i = 0 To 7
		If fromL2 Then
			s = GetS(L2Row(lb), C_CB0 + i)
		Else
			s = H2(RamGet(lb + i))
		End If
		Lk()
		If i > 0 Then Bg(rDst, C_CB0 + i - 1, col)
		PutS(rDst, C_CB0 + i, s)
		Bg(rDst, C_CB0 + i, COL_TOK_DATA)
		Ulk()
		Pause(gDelay)
	Next i
	Bg(rDst, C_CB0 + 7, col)
	PutS(rDst, C_CTAG, H3(lb))
	Bg(rDst, C_CTAG, col)
	PutS(rDst, C_CV, "1")
End Sub

Sub EnsureLine(ByVal isI As Boolean, ByVal pa As Long, ByVal anim As Boolean)
	Dim lb As Long, lvl As String, r1 As Long, keep As Long
	lb = (pa \ 8) * 8
	r1 = L1Row(isI)
	If isI Then
		lvl = "L1I"
	Else
		lvl = "L1D"
	End If
	keep = gDelay
	If Not anim Then gDelay = 0
	If LineHas(r1, lb) Then
		gDelay = keep
		CacheInd(r1, True, lvl)
		If isI Then
			IncSt(ST_L1I_H)
		Else
			IncSt(ST_L1D_H)
		End If
		Exit Sub
	End If
	gDelay = keep
	CacheInd(r1, False, lvl)
	If isI Then
		IncSt(ST_L1I_M)
	Else
		IncSt(ST_L1D_M)
	End If
	If LineHas(L2Row(lb), lb) Then
		CacheInd(R_L2_0, True, "L2")
		IncSt(ST_L2_H)
		If Not anim Then gDelay = 0
		Micro("L2 HIT: line 0x" & H3(lb) & " goes up from L2 to " & lvl, "")
		AnimData(C_L2_STUB, False, C_L1_STUB, False, "8B")
		CopyLine(r1, lb, True)
		gDelay = keep
		Exit Sub
	End If
	CacheInd(R_L2_0, False, "L2")
	IncSt(ST_L2_M)
	If Not anim Then gDelay = 0
	Micro("MISS in " & lvl & " and in L2 -> RAM access: address bus <- PA 0x" & H3(lb) & ", Mem_R=1", "Mem_R")
	CtlOn(C_CPU_CTL, C_RAM_CTL, "MEM_R")
	AnimAddr(C_CPU_ADR, C_RAM_ADR, H3(lb))
	FlashRamLine(lb)
	Micro("RAM -> data bus -> L2: the 8 B line is copied (0x" & H3(lb) & "-0x" & H3(lb + 7) & ")", "Mem_R")
	AnimData(C_RAM_DAT, False, C_L2_STUB, False, "8B")
	CopyLine(L2Row(lb), lb, False)
	CtlOff()
	Micro("L2 -> " & lvl & ": the same line is copied to level 1", "")
	AnimData(C_L2_STUB, False, C_L1_STUB, False, "8B")
	CopyLine(r1, lb, True)
	gDelay = keep
End Sub

Function ReadInstr(ByVal pa As Long) As Variant
	Dim b(3) As Long, i As Integer, off As Integer, lb As Long, s As String, keep As Long
	EnsureLine(True, pa, gAnimF)
	lb = (pa \ 8) * 8 : off = pa - lb
	s = ""
	For i = 0 To 3
		b(i) = ParseB(GetS(R_L1I, C_CB0 + off + i))
		s = s & H2(b(i)) & " "
	Next i
	keep = gDelay
	If Not gAnimF Then gDelay = 0
	Micro("MDR <- instruction (4 bytes from L1I over the data bus): " & Trim(s), "Ld_MDR")
	AnimData(C_L1_STUB, False, C_CPU_DAT, False, "ins")
	gDelay = keep
	PutS(R_MDR, C_RVAL, Trim(s))
	ReadInstr = b
End Function

Function ReadByte(ByVal va As Long) As Long
	Dim pa As Long, lb As Long, v As Long, off As Integer
	pa = Translate(va, False, False)
	EnsureLine(False, pa, True)
	lb = (pa \ 8) * 8 : off = pa - lb
	v = ParseB(GetS(R_L1D, C_CB0 + off))
	Flash(R_L1D, C_CB0 + off, COL_TOK_DATA)
	Micro("MDR <- byte 0x" & H2(v) & " read from L1D (data bus)", "Ld_MDR")
	AnimData(C_L1_STUB, False, C_CPU_DAT, False, H2(v))
	PutS(R_MDR, C_RVAL, H2(v))
	Flash(R_MDR, C_RVAL, COL_FLASH)
	ReadByte = v
End Function

Sub WriteByte(ByVal va As Long, ByVal v As Long)
	Dim pa As Long, lb As Long, off As Integer, r2 As Long
	pa = Translate(va, True, False)
	lb = (pa \ 8) * 8 : off = pa - lb
	Micro("Write: address bus <- PA 0x" & H3(pa) & ", data bus <- MDR (0x" & H2(v) & "), Mem_W=1", "En_MDR,Mem_W")
	CtlOn(C_CPU_CTL, C_RAM_CTL, "MEM_W")
	AnimAddr(C_CPU_ADR, C_RAM_ADR, H3(pa))
	If LineHas(R_L1D, lb) Then
		CacheInd(R_L1D, True, "L1D")
		IncSt(ST_L1D_H)
		AnimData(C_CPU_DAT, False, C_L1_STUB, False, H2(v))
		PutS(R_L1D, C_CB0 + off, H2(v))
		Flash(R_L1D, C_CB0 + off, COL_TOK_DATA)
	Else
		CacheInd(R_L1D, False, "L1D")
		IncSt(ST_L1D_M)
	End If
	r2 = L2Row(lb)
	If LineHas(r2, lb) Then
		CacheInd(R_L2_0, True, "L2")
		IncSt(ST_L2_H)
		PutS(r2, C_CB0 + off, H2(v))
		Flash(r2, C_CB0 + off, COL_TOK_DATA)
	Else
		CacheInd(R_L2_0, False, "L2")
		IncSt(ST_L2_M)
	End If
	Micro("Write-through: value 0x" & H2(v) & " travels over the data bus to RAM (PA 0x" & H3(pa) & ")", "En_MDR,Mem_W")
	AnimData(C_CPU_DAT, False, C_RAM_DAT, False, H2(v))
	RamSet(pa, v)
	Flash(RamRow(pa), RamCol(pa), COL_TOK_DATA)
	Flash(RamRow(pa), RamCol(pa), COL_TOK_DATA)
	CtlOff()
End Sub
