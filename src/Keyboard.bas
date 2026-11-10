REM =====================================================================
REM  SCZ-Architecture - Keyboard module
REM  Memory-mapped keyboard: 8 B queue in RAM M7 and the IN instruction
REM =====================================================================
Option Explicit

Sub KeyboardType()
	Dim txt As String
	txt = KbdText()
	If Len(txt) = 0 Then
		Status("Type a text in the yellow KEYBOARD box (e.g. HELLO) and press TYPE again.", 2)
	Else
		REM if the program already finished, reload it so the LCD shows the new text
		If St(ST_LOADED) = 1 And St(ST_HALT) = 1 Then
			LoadProg(St(ST_PROGCOL), oSt.getCellByPosition(2, ST_PROGCOL).getString())
		End If
		TypeText(txt)
	End If
End Sub

Sub TypeText(ByVal txt As String)
	Dim i As Integer, ch As String, head As Long, cnt As Long, tl As Long, pa As Long
	For i = 1 To Len(txt)
		ch = Mid(txt, i, 1)
		head = St(ST_KHEAD) : cnt = St(ST_KCOUNT)
		If cnt >= 8 Then
			Status("Keyboard queue FULL (8 bytes). The remaining keys are lost.", 3)
			Exit For
		End If
		tl = (head + cnt) Mod 8
		pa = 7 * 32 + tl
		PutS(R_KKEY, C_KKEY, ch)
		Flash(R_KKEY, C_KKEY, COL_TOK_DATA)
		Status("Key '" & ch & "' (ASCII 0x" & H2(Asc(ch)) & ") -> the keyboard controller puts it in the queue, RAM M7 byte " & tl, 0)
		Micro("KBD -> data bus (En_KBD=1) -> RAM M7[0" & tl & "]  (keyboard queue)", "En_KBD,IO,Mem_W")
		AnimData(C_KBD_STUB, True, C_RAM_DAT, False, ch)
		RamSet(pa, Asc(ch))
		Bg(RamRow(pa), RamCol(pa), COL_KBDQ)
		Flash(RamRow(pa), RamCol(pa), COL_TOK_DATA)
		SetSt(ST_KCOUNT, cnt + 1)
	Next i
	Micro("Keyboard idle: its tri-state buffer goes back to high impedance (High-Z)", "")
	Status("Keyboard queue holds " & St(ST_KCOUNT) & " characters ('" & txt & "'). Press Run or Step.", 1)
End Sub

Sub DoIn(ByVal r1 As Integer)
	Dim n1 As String, head As Long, cnt As Long, pa As Long, ch As Long
	n1 = RegName(r1)
	cnt = St(ST_KCOUNT) : head = St(ST_KHEAD)
	If cnt = 0 Then
		Micro("IN: the keyboard queue is EMPTY -> ZF=1", "IO,Mem_R")
		SetFlag(C_ZF, 1)
		Status("IN " & n1 & ",[KBD]: the keyboard queue is empty -> ZF = 1", 2)
		Exit Sub
	End If
	pa = 7 * 32 + head
	ch = RamGet(pa)
	Status("IN: character '" & Chr(ch) & "' leaves the keyboard queue (RAM M7, byte " & head & ") towards " & n1, 0)
	Flash(RamRow(pa), RamCol(pa), COL_TOK_DATA)
	Micro("IN: keyboard buffer enabled (En_KBD=1): queue M7[0" & head & "] -> data bus -> MDR", "IO,Mem_R,En_KBD,Ld_MDR")
	CtlOn(C_CPU_CTL, C_RAM_CTL, "IO_RD")
	AnimData(C_RAM_DAT, False, C_CPU_DAT, False, Chr(ch))
	CtlOff()
	PutS(R_MDR, C_RVAL, H2(ch))
	Flash(R_MDR, C_RVAL, COL_FLASH)
	REM the consumed byte is released in the queue
	PutS(RamRow(pa), RamCol(pa), "00")
	Bg(RamRow(pa), RamCol(pa), COL_KBDQ_E)
	SetSt(ST_KHEAD, (head + 1) Mod 8)
	SetSt(ST_KCOUNT, cnt - 1)
	Micro(n1 & " <- MDR ('" & Chr(ch) & "') over the internal bus", "En_MDR,Ld_" & n1)
	AnimInt("MDR", n1, Chr(ch))
	SetReg(n1, ch)
	SetFlag(C_ZF, 0)
End Sub
