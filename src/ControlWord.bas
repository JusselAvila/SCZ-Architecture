REM =====================================================================
REM  SCZ-Architecture - ControlWord module
REM  21-signal control word and tri-state buffers
REM =====================================================================
Option Explicit

Global gPrevSig As String

Sub Micro(ByVal desc As String, ByVal sigs As String)
	Dim i As Integer, nm As String, s2 As String, vec As String, emi As String
	s2 = "," & sigs & ","
	vec = "" : emi = ""
	Lk()
	IncSt(ST_CLK)
	For i = 0 To UBound(gSigs)
		nm = gSigs(i)
		If InStr(s2, "," & nm & ",") > 0 Then
			vec = vec & "1"
			If Left(nm, 3) = "En_" Then emi = emi & Mid(nm, 4) & " "
		Else
			vec = vec & "0"
		End If
		If Len(gPrevSig) <> UBound(gSigs) + 1 Or Mid(gPrevSig, i + 1, 1) <> Mid(vec, i + 1, 1) Then
			If Mid(vec, i + 1, 1) = "1" Then
				PutS(R_CWV, C_CW0 + 2 * i, "1")
				Bg(R_CWV, C_CW0 + 2 * i, COL_ON)
			Else
				PutS(R_CWV, C_CW0 + 2 * i, "0")
				Bg(R_CWV, C_CW0 + 2 * i, COL_OFF)
			End If
		End If
	Next i
	gPrevSig = vec
	PutS(R_CWVEC, C_CWVEC, vec)
	PutS(R_CWM, C_CWM, desc)
	PutS(R_UC_MI, C_UC_MI, desc)
	PutS(R_UC_CLK, C_UC_V, CStr(St(ST_CLK)))
	TriBuf(R_AX, C_LBUF, InStr(s2, ",En_AX,") > 0)
	TriBuf(R_BX, C_LBUF, InStr(s2, ",En_BX,") > 0)
	TriBuf(R_CX, C_LBUF, InStr(s2, ",En_CX,") > 0)
	TriBuf(R_DX, C_LBUF, InStr(s2, ",En_DX,") > 0)
	TriBuf(R_ALU_IO, C_LBUF, InStr(s2, ",En_ALU,") > 0)
	TriBuf(R_PC, C_RBUF, InStr(s2, ",En_PC,") > 0)
	TriBuf(R_IR, C_RBUF, InStr(s2, ",En_IR,") > 0)
	TriBuf(R_MDR, C_RBUF, InStr(s2, ",En_MDR,") > 0)
	TriBuf(R_KBUF, C_KBUF, InStr(s2, ",En_KBD,") > 0)
	If InStr(s2, ",Ld_LCD,") > 0 Then
		PutS(R_LCDLD, C_LCDLD, "1") : Bg(R_LCDLD, C_LCDLD, COL_ON)
	Else
		PutS(R_LCDLD, C_LCDLD, "0") : Bg(R_LCDLD, C_LCDLD, COL_OFF)
	End If
	If emi = "" Then
		If InStr(s2, ",Mem_R,") > 0 Then
			emi = "MEMORY / CACHE (Mem_R=1)  ->  every register in High-Z"
		Else
			emi = "NONE  ->  every buffer in high impedance (High-Z)"
		End If
	Else
		emi = Trim(emi) & "  (Enable=1)  ->  the other buffers in High-Z"
	End If
	PutS(R_EMI, C_EMI, emi)
	LogLine(desc & "   [" & sigs & "]")
	Ulk()
	Pause(gDelay * 7)
End Sub

Sub TriBuf(ByVal r As Long, ByVal c As Long, ByVal onn As Boolean)
	If onn = (GetS(r, c) = "ON") Then Exit Sub
	If onn Then
		PutS(r, c, "ON")
		Bg(r, c, COL_ON)
	Else
		PutS(r, c, "Z")
		Bg(r, c, COL_HIZ)
	End If
End Sub
