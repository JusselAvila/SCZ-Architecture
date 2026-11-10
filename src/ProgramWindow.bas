REM =====================================================================
REM  SCZ-Architecture - ProgramWindow module
REM  Program window (PC highlight) and swap timeline (reference string)
REM =====================================================================
Option Explicit

Sub HiCode(ByVal idx As Long)
	Dim old As Long, c As Integer
	Lk()
	old = St(ST_CODEHI)
	If old >= 0 And old < CODE_MAX Then
		For c = C_CODE0 To C_CODE1 : Bg(R_CODE0 + old, c, COL_CODE_BG) : Next c
	End If
	If idx >= 0 And idx < CODE_MAX And idx < St(ST_NCODE) \ 4 Then
		For c = C_CODE0 To C_CODE1 : Bg(R_CODE0 + idx, c, COL_FLASH) : Next c
		SetSt(ST_CODEHI, idx)
	Else
		SetSt(ST_CODEHI, -1)
	End If
	Ulk()
End Sub

Sub TLRecord(ByVal vpn As Integer, ByVal isW As Boolean, ByVal isF As Boolean)
	Dim n As Long, c As Long, f As Integer, p As Integer, s As String, o As Object
	n = St(ST_TLN)
	If n >= TL_MAX Then Exit Sub
	Lk()
	c = C_TL0 + n
	Cel(R_TL_T, c).setValue(n + 1)
	If isF Then
		s = "i"
	ElseIf isW Then
		s = "w"
	Else
		s = "r"
	End If
	PutS(R_TL_REF, c, "P" & vpn & s)
	Bg(R_TL_REF, c, PageCol(vpn))
	For f = 0 To 6
		p = FramePage(f)
		o = Cel(R_TL_M0 + f, c)
		If p >= 0 Then
			o.setString("P" & p)
			o.CellBackColor = PageCol(p)
			If p = vpn Then
				o.CharWeight = 150
			Else
				o.CharWeight = 100
			End If
		Else
			o.setString("")
			o.CellBackColor = COL_FREE
		End If
	Next f
	If gTLFault Then
		PutS(R_TL_F, c, "F")
		Bg(R_TL_F, c, COL_FAULT)
	End If
	If gTLVictim >= 0 Then
		PutS(R_TL_V, c, "P" & gTLVictim)
		Bg(R_TL_V, c, COL_VICTIM)
	End If
	SetSt(ST_TLN, n + 1)
	Ulk()
End Sub
