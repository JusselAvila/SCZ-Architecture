REM =====================================================================
REM  SCZ-Architecture - Lcd module
REM  Memory-mapped 8x1 LCD: video buffer in RAM M7 and the OUT instruction
REM =====================================================================
Option Explicit

Sub DoOut(ByVal r1 As Integer)
	Dim n1 As String, v As Long, cur As Long, pa As Long, ch As String
	n1 = RegName(r1)
	v = GetReg(n1)
	cur = St(ST_LCDCUR)
	If v >= 32 And v < 127 Then
		ch = Chr(v)
	Else
		ch = "?"
	End If
	Status("OUT: character '" & ch & "' travels from " & n1 & " to the video buffer (RAM M7, byte 0" & Hex(8 + cur) & ") and then to the LCD", 0)
	Micro("MDR <- " & n1 & " ('" & ch & "') over the internal bus", "En_" & n1 & ",Ld_MDR")
	AnimInt(n1, "MDR", ch)
	PutS(R_MDR, C_RVAL, H2(v))
	Micro("MDR -> data bus -> LCD video buffer in RAM M7[0" & Hex(8 + cur) & "]", "En_MDR,IO,Mem_W")
	CtlOn(C_CPU_CTL, C_RAM_CTL, "IO_WR")
	AnimData(C_CPU_DAT, False, C_RAM_DAT, False, ch)
	CtlOff()
	pa = 7 * 32 + 8 + cur
	RamSet(pa, v)
	Flash(RamRow(pa), RamCol(pa), COL_TOK_DATA)
	Micro("LCD controller: video buffer -> data bus -> screen (Ld_LCD=1)", "IO,Mem_R,Ld_LCD")
	AnimData(C_RAM_DAT, False, C_LCD_STUB, True, ch)
	PutS(R_LCD, C_LCD0 + 2 * cur, ch)
	Flash(R_LCD, C_LCD0 + 2 * cur, COL_TOK_DATA)
	SetSt(ST_LCDCUR, (cur + 1) Mod 8)
End Sub
