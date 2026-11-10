REM =====================================================================
REM  SCZ-Architecture - Memory module
REM  Physical RAM (8 x 32 B) and disk / swap area (16 x 32 B)
REM =====================================================================
Option Explicit

Function RamRow(ByVal pa As Long) As Long
	RamRow = R_RAM0 + (pa \ 32) * 2 + ((pa Mod 32) \ 16)
End Function

Function RamCol(ByVal pa As Long) As Long
	RamCol = C_RAM0 + (pa Mod 16)
End Function

Function RamGet(ByVal pa As Long) As Long
	RamGet = ParseB(GetS(RamRow(pa), RamCol(pa)))
End Function

Sub RamSet(ByVal pa As Long, ByVal v As Long)
	v = v And 255
	If pa >= 224 And pa < 240 And v >= 33 And v < 127 Then
		PutS(RamRow(pa), RamCol(pa), Chr(v))
	Else
		PutS(RamRow(pa), RamCol(pa), H2(v))
	End If
End Sub

Function DskRow(ByVal va As Long) As Long
	DskRow = R_DSK0 + ((va \ 32) Mod 8) * 2 + ((va Mod 32) \ 16)
End Function

Function DskCol(ByVal va As Long) As Long
	If (va \ 32) < 8 Then
		DskCol = C_DSKA + (va Mod 16)
	Else
		DskCol = C_DSKB + (va Mod 16)
	End If
End Function

Function DskLblCol(ByVal p As Integer) As Long
	If p < 8 Then
		DskLblCol = C_DLBLA
	Else
		DskLblCol = C_DLBLB
	End If
End Function

Function FramePage(ByVal f As Integer) As Integer
	Dim s As String
	s = GetS(R_RAM0 + f * 2, C_RAMPG)
	If Left(s, 1) = "P" Then
		FramePage = CInt(Val(Mid(s, 2)))
	Else
		FramePage = -1
	End If
End Function

Sub FlashFrame(ByVal f As Integer, ByVal col As Long)
	If gDelay = 0 Then Exit Sub
	Dim i As Integer, k As Integer, sv(31) As Long
	For i = 0 To 31 : sv(i) = Cel(RamRow(f * 32 + i), RamCol(f * 32 + i)).CellBackColor : Next i
	For k = 1 To 2
		Lk()
		For i = 0 To 31 : Bg(RamRow(f * 32 + i), RamCol(f * 32 + i), col) : Next i
		Ulk()
		Wait gDelay * 4
		Lk()
		For i = 0 To 31 : Bg(RamRow(f * 32 + i), RamCol(f * 32 + i), sv(i)) : Next i
		Ulk()
		Wait gDelay * 3
	Next k
End Sub

Sub FlashDiskPage(ByVal p As Integer, ByVal col As Long)
	If gDelay = 0 Then Exit Sub
	Dim i As Integer, k As Integer, pc As Long
	pc = PageCol(p)
	For k = 1 To 2
		Lk()
		For i = 0 To 31 : Bg(DskRow(p * 32 + i), DskCol(p * 32 + i), col) : Next i
		Ulk()
		Wait gDelay * 4
		Lk()
		For i = 0 To 31 : Bg(DskRow(p * 32 + i), DskCol(p * 32 + i), pc) : Next i
		Ulk()
		Wait gDelay * 3
	Next k
End Sub

Sub FlashRamLine(ByVal lb As Long)
	If gDelay = 0 Then Exit Sub
	Dim i As Integer, sv(7) As Long
	Lk()
	For i = 0 To 7
		sv(i) = Cel(RamRow(lb + i), RamCol(lb + i)).CellBackColor
		Bg(RamRow(lb + i), RamCol(lb + i), COL_TOK_DATA)
	Next i
	Ulk()
	Wait gDelay * 6
	Lk()
	For i = 0 To 7 : Bg(RamRow(lb + i), RamCol(lb + i), sv(i)) : Next i
	Ulk()
End Sub

Sub DiskLabel(ByVal p As Integer, ByVal f As Integer)
	Dim r As Long, c As Long
	r = R_DSK0 + (p Mod 8) * 2 : c = DskLblCol(p)
	If f >= 0 Then
		PutS(r, c, "P" & p & " >M" & f)
		Bg(r, c, COL_RESID)
	Else
		PutS(r, c, "P" & p)
		Bg(r, c, PageCol(p))
	End If
	UpdFree()
End Sub

Sub UpdFree()
	Dim f As Integer, n As Integer
	For f = 0 To 6
		If FramePage(f) < 0 Then n = n + 1
	Next f
	PutS(R_RAMINFO, C_RAMINFO, "Free frames: " & n & " of 7   |   M7 pinned to I/O (not paged)")
End Sub
