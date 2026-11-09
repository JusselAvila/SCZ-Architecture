REM =====================================================================
REM  SCZ-Architecture - Cpu module
REM  Registers, ALU and flags (ZF, CF, SF)
REM =====================================================================
Option Explicit

Function RegName(ByVal i As Integer) As String
	RegName = Mid("AXBXCXDX", (i And 3) * 2 + 1, 2)
End Function

Function RRow(ByVal n As String) As Long
	Select Case n
		Case "AX" : RRow = R_AX
		Case "BX" : RRow = R_BX
		Case "CX" : RRow = R_CX
		Case "DX" : RRow = R_DX
		Case "PC" : RRow = R_PC
		Case "IR" : RRow = R_IR
		Case "MAR" : RRow = R_MAR
		Case "MDR" : RRow = R_MDR
		Case "ALU" : RRow = R_ALU_IO
		Case Else : RRow = R_AX
	End Select
End Function

Function RLeft(ByVal n As String) As Boolean
	RLeft = (n = "AX" Or n = "BX" Or n = "CX" Or n = "DX" Or n = "ALU")
End Function

Function GetReg(ByVal n As String) As Long
	If n = "PC" Or n = "MAR" Then
		GetReg = HexVal(GetS(RRow(n), C_RVAL))
		If GetReg < 0 Then GetReg = 0
	Else
		GetReg = ParseB(GetS(RRow(n), C_LVAL))
	End If
End Function

Sub SetReg(ByVal n As String, ByVal v As Long)
	Dim r As Long
	r = RRow(n)
	v = v And 255
	Lk()
	PutS(r, C_LVAL, H2(v))
	PutS(r, C_LDEC, CStr(v))
	If v >= 32 And v < 127 Then
		PutS(r, C_LCHR, Chr(v))
	Else
		PutS(r, C_LCHR, "-")
	End If
	Ulk()
	Flash(r, C_LVAL, COL_FLASH)
End Sub

Sub SetPC(ByVal v As Long)
	PutS(R_PC, C_RVAL, H3(v))
	Flash(R_PC, C_RVAL, COL_FLASH)
	HiCode(v \ 4)
End Sub

Sub SetFlags(ByVal res As Long, ByVal cf As Integer)
	SetFlag(C_ZF, IIf(res = 0, 1, 0))
	SetFlag(C_SF, IIf((res And 128) <> 0, 1, 0))
	If cf >= 0 Then SetFlag(C_CF, cf)
End Sub

Sub SetFlag(ByVal c As Long, ByVal v As Integer)
	PutS(R_FLAGS, c, CStr(v))
	If v = 1 Then
		Bg(R_FLAGS, c, COL_ON)
	Else
		Bg(R_FLAGS, c, COL_OFF)
	End If
End Sub

Function Flag(ByVal c As Long) As Integer
	If GetS(R_FLAGS, c) = "1" Then
		Flag = 1
	Else
		Flag = 0
	End If
End Function

Sub AluOp(ByVal opn As String, ByVal r1 As Integer, ByVal bSrc As String, ByVal bVal As Long, ByVal wb As Boolean)
	Dim a As Long, res As Long, cf As Integer, n1 As String
	n1 = RegName(r1)
	a = GetReg(n1)
	cf = -1
	Micro("ALU.A <- " & n1 & " (0x" & H2(a) & ")", "En_" & n1)
	AnimInt(n1, "ALU", H2(a))
	PutS(R_ALU_A, C_ALU_V, H2(a) & "h = " & a)
	If bSrc = "IR" Then
		Micro("ALU.B <- immediate from IR (0x" & H2(bVal) & ")", "En_IR")
		AnimInt("IR", "ALU", H2(bVal))
	ElseIf bSrc <> "" Then
		Micro("ALU.B <- " & bSrc & " (0x" & H2(bVal) & ")", "En_" & bSrc)
		AnimInt(bSrc, "ALU", H2(bVal))
	End If
	PutS(R_ALU_B, C_ALU_V, H2(bVal) & "h = " & bVal)
	Select Case opn
		Case "ADD"
			res = a + bVal
			cf = IIf(res > 255, 1, 0)
		Case "SUB", "CMP"
			res = a - bVal
			cf = IIf(a < bVal, 1, 0)
		Case "INC"
			res = a + 1
		Case "DEC"
			res = a - 1
	End Select
	res = (res + 256) And 255
	PutS(R_ALU_A, C_ALU_OP, opn)
	PutS(R_ALU_R, C_ALU_V, H2(res) & "h = " & res)
	Flash(R_ALU_R, C_ALU_V, COL_FLASH)
	SetFlags(res, cf)
	If wb Then
		Micro(n1 & " <- ALU result (0x" & H2(res) & ")", "En_ALU,Ld_" & n1)
		AnimInt("ALU", n1, H2(res))
		SetReg(n1, res)
	Else
		Micro("CMP: only the flags are updated (ZF=" & Flag(C_ZF) & ", CF=" & Flag(C_CF) & ")", "")
	End If
End Sub
