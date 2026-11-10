REM =====================================================================
REM  SCZ-Architecture - Assembler module
REM  Two-pass assembler, .DATA directive and syntax check
REM =====================================================================
Option Explicit

Sub CheckEditor()
	Dim img(511) As Long, n As Long, er As String
	If Assemble(PG_COL_ED, img, n, er) Then
		oPg.getCellByPosition(PG_COL_ED, PG_MSG_ROW).setString("Syntax OK: " & n & " bytes of code (" & (n \ 4) & " instructions).")
		oPg.getCellByPosition(PG_COL_ED, PG_MSG_ROW).CellBackColor = COL_HIT
	Else
		oPg.getCellByPosition(PG_COL_ED, PG_MSG_ROW).setString("ERRORS -> " & er)
		oPg.getCellByPosition(PG_COL_ED, PG_MSG_ROW).CellBackColor = COL_MISS
	End If
End Sub

Function Assemble(ByVal srcCol As Integer, img() As Long, nCode As Long, er As String) As Boolean
	Dim lines() As String, i As Integer, nL As Integer, pass As Integer, loc As Long
	Dim labN(80) As String, labA(80) As Long, nLab As Integer
	Dim s As String, lab As String, mn As String, ops As String, p As Integer, e As Variant, e1 As String
	Dim dataTxt As String, k As Integer, nInst As Integer, lblTxt As String
	nL = PG_NLINES
	ReDim lines(nL) As String
	er = ""
	For i = 0 To 511 : img(i) = 0 : Next i
	For i = 0 To PG_NLINES - 1
		lines(i) = oPg.getCellByPosition(srcCol, PG_R0 + i).getString()
	Next i
	nL = PG_NLINES
	REM clear the listing
	For i = 0 To PG_NLINES - 1
		For k = 0 To 3 : oPg.getCellByPosition(PG_LST + k, PG_R0 + i).setString("") : Next k
	Next i
	nLab = 0
	For pass = 1 To 2
		loc = 0 : nInst = 0 : dataTxt = ""
		For i = 0 To nL - 1
			s = lines(i)
			p = InStr(s, ";")
			If p > 0 Then s = Left(s, p - 1)
			s = Trim(s)
			If s = "" Then GoTo SigLinea
			lblTxt = ""
			p = InStr(s, ":")
			If p > 0 Then
				lab = UCase(Trim(Left(s, p - 1)))
				lblTxt = lab & ": "
				If pass = 1 Then
					labN(nLab) = lab : labA(nLab) = loc : nLab = nLab + 1
				End If
				s = Trim(Mid(s, p + 1))
				If s = "" Then GoTo SigLinea
			End If
			p = InStr(s, " ")
			If p > 0 Then
				mn = UCase(Left(s, p - 1)) : ops = Trim(Mid(s, p + 1))
			Else
				mn = UCase(s) : ops = ""
			End If
			If mn = ".DATA" Then
				If pass = 2 Then
					e1 = ""
					DataDir(ops, img, e1)
					If e1 <> "" Then er = er & "line " & (i + 1) & ": " & e1 & "; "
					dataTxt = dataTxt & ".DATA " & ops & "   "
				End If
				GoTo SigLinea
			End If
			If pass = 2 Then
				e1 = ""
				e = Encode(mn, ops, labN, labA, nLab, e1)
				If e1 <> "" Then
					er = er & "line " & (i + 1) & ": " & e1 & "; "
				ElseIf loc + 3 < 480 Then
					For k = 0 To 3 : img(loc + k) = e(k) : Next k
					If nInst < PG_NLINES Then
						oPg.getCellByPosition(PG_LST, PG_R0 + nInst).setString(H3(loc))
						oPg.getCellByPosition(PG_LST + 1, PG_R0 + nInst).setString(H2(e(0)) & " " & H2(e(1)) & " " & H2(e(2)) & " " & H2(e(3)))
						oPg.getCellByPosition(PG_LST + 2, PG_R0 + nInst).setString(lblTxt & mn & " " & ops)
						oPg.getCellByPosition(PG_LST + 3, PG_R0 + nInst).setString("P" & (loc \ 32))
					End If
				Else
					er = er & "program too long; "
				End If
			End If
			loc = loc + 4
			nInst = nInst + 1
SigLinea:
		Next i
	Next pass
	oPg.getCellByPosition(PG_LST + 2, PG_R0 + PG_NLINES - 1).setString(dataTxt)
	nCode = loc
	If loc = 0 And er = "" Then er = "the program has no instructions"
	Assemble = (er = "")
End Function

Sub DataDir(ByVal ops As String, img() As Long, er As String)
	Dim a As Variant, i As Integer, ok As Boolean, ad As Long, v As Long
	a = Split(ops, ",")
	ok = True
	ad = ParseNum(a(0), ok)
	If Not ok Or ad < 0 Or ad > 479 Then
		er = "invalid .DATA address"
		Exit Sub
	End If
	For i = 1 To UBound(a)
		ok = True
		v = ParseNum(a(i), ok)
		If Not ok Or ad + i - 1 > 479 Then
			er = "invalid .DATA value: " & a(i)
			Exit Sub
		End If
		img(ad + i - 1) = v And 255
	Next i
End Sub

Function ParseNum(ByVal t As String, ok As Boolean) As Long
	Dim u As String, i As Integer
	t = Trim(t) : u = UCase(t)
	ParseNum = 0
	If Len(t) >= 3 And Left(t, 1) = "'" Then
		ParseNum = Asc(Mid(t, 2, 1))
		Exit Function
	End If
	If Len(u) = 0 Then
		ok = False
		Exit Function
	End If
	If Left(u, 2) = "0X" Then
		ParseNum = HexVal(Mid(u, 3))
	ElseIf Right(u, 1) = "H" And Len(u) > 1 Then
		ParseNum = HexVal(Left(u, Len(u) - 1))
	Else
		For i = 1 To Len(u)
			If InStr("0123456789", Mid(u, i, 1)) = 0 Then
				ok = False
				Exit Function
			End If
		Next i
		ParseNum = CLng(u)
	End If
	If ParseNum < 0 Then ok = False
End Function

Function RegIdx(ByVal t As String) As Integer
	Select Case UCase(Trim(t))
		Case "AX" : RegIdx = 0
		Case "BX" : RegIdx = 1
		Case "CX" : RegIdx = 2
		Case "DX" : RegIdx = 3
		Case Else : RegIdx = -1
	End Select
End Function

Function OpType(ByVal t As String) As Integer
	Dim u As String, inner As String, ok As Boolean
	u = UCase(Trim(t))
	OpType = 0
	If u = "" Then Exit Function
	If RegIdx(u) >= 0 Then
		OpType = 1
		Exit Function
	End If
	If Left(u, 1) = "[" And Right(u, 1) = "]" Then
		inner = Trim(Mid(u, 2, Len(u) - 2))
		If inner = "KBD" Then
			OpType = 4
		ElseIf inner = "LCD" Then
			OpType = 5
		Else
			ok = True
			ParseNum(inner, ok)
			If ok Then OpType = 3
		End If
		Exit Function
	End If
	ok = True
	ParseNum(Trim(t), ok)
	If ok Then
		OpType = 2
	Else
		OpType = 6
	End If
End Function

Function MemAddr(ByVal t As String) As Long
	Dim u As String, ok As Boolean
	u = Trim(t)
	ok = True
	MemAddr = ParseNum(Trim(Mid(u, 2, Len(u) - 2)), ok)
End Function

Function Encode(ByVal mn As String, ByVal ops As String, labN() As String, labA() As Long, ByVal nLab As Integer, er As String) As Variant
	Dim e(3) As Long, a As Variant, n As Integer, o1 As String, o2 As String, t1 As Integer, t2 As Integer
	Dim ad As Long, im As Long, ok As Boolean, i As Integer, found As Boolean, baseOp As Integer
	If Trim(ops) = "" Then
		n = 0
	Else
		a = Split(ops, ",")
		n = UBound(a) + 1
		o1 = Trim(a(0))
		If n > 1 Then o2 = Trim(a(1))
	End If
	t1 = OpType(o1) : t2 = OpType(o2)
	Select Case mn
		Case "NOP"
			e(0) = 0
		Case "HLT"
			e(0) = 18
		Case "MOV", "LOAD", "STORE"
			If t1 = 1 And t2 = 2 Then
				ok = True : im = ParseNum(o2, ok)
				If im > 255 Then er = "immediate greater than 255"
				e(0) = 1 : e(1) = RegIdx(o1) : e(3) = im And 255
			ElseIf t1 = 1 And t2 = 1 Then
				e(0) = 2 : e(1) = RegIdx(o1) : e(2) = RegIdx(o2)
			ElseIf t1 = 1 And t2 = 3 Then
				ad = MemAddr(o2)
				If ad > 479 Then er = "address out of range (0-1DF)"
				e(0) = 3 : e(1) = RegIdx(o1) : e(2) = ad \ 256 : e(3) = ad Mod 256
			ElseIf t1 = 3 And t2 = 1 Then
				ad = MemAddr(o1)
				If ad > 479 Then er = "address out of range (0-1DF)"
				e(0) = 4 : e(1) = RegIdx(o2) : e(2) = ad \ 256 : e(3) = ad Mod 256
			Else
				er = "invalid operands for MOV"
			End If
		Case "ADD", "SUB", "CMP"
			If mn = "ADD" Then
				baseOp = 5
			ElseIf mn = "SUB" Then
				baseOp = 7
			Else
				baseOp = 11
			End If
			If t1 = 1 And t2 = 1 Then
				e(0) = baseOp : e(1) = RegIdx(o1) : e(2) = RegIdx(o2)
			ElseIf t1 = 1 And t2 = 2 Then
				ok = True : im = ParseNum(o2, ok)
				e(0) = baseOp + 1 : e(1) = RegIdx(o1) : e(3) = im And 255
			Else
				er = "invalid operands for " & mn
			End If
		Case "INC", "DEC"
			If t1 = 1 And n = 1 Then
				e(0) = IIf(mn = "INC", 9, 10) : e(1) = RegIdx(o1)
			Else
				er = mn & " requires a register"
			End If
		Case "JMP", "JZ", "JNZ", "JC"
			Select Case mn
				Case "JMP" : e(0) = 13
				Case "JZ" : e(0) = 14
				Case "JNZ" : e(0) = 15
				Case "JC" : e(0) = 19
			End Select
			If t1 = 2 Then
				ok = True : ad = ParseNum(o1, ok)
			ElseIf t1 = 6 Then
				found = False
				For i = 0 To nLab - 1
					If labN(i) = UCase(o1) Then
						ad = labA(i) : found = True
					End If
				Next i
				If Not found Then er = "undefined label: " & o1
			Else
				er = "invalid jump target"
			End If
			e(2) = ad \ 256 : e(3) = ad Mod 256
		Case "IN"
			If t1 = 1 And t2 = 4 Then
				e(0) = 16 : e(1) = RegIdx(o1)
			Else
				er = "usage: IN reg, [KBD]"
			End If
		Case "OUT"
			If t1 = 5 And t2 = 1 Then
				e(0) = 17 : e(1) = RegIdx(o2)
			Else
				er = "usage: OUT [LCD], reg"
			End If
		Case Else
			er = "unknown instruction '" & mn & "'"
	End Select
	Encode = e
End Function
