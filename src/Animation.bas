REM =====================================================================
REM  SCZ-Architecture - Animation module
REM  Bus paths, moving token, wire lighting and control-bus labels
REM =====================================================================
Option Explicit

Global gPR(700) As Long
Global gPC(700) As Long
Global gPN As Long
Global gCtlSave(200) As Long
Global gCtlStr(200) As String
Global gCtlA As Long
Global gCtlB As Long
Global gCtlOn As Boolean

Sub Flash(ByVal r As Long, ByVal c As Long, ByVal col As Long)
	If gDelay = 0 Then Exit Sub
	Dim o As Object, b As Long, k As Integer
	o = Cel(r, c)
	b = o.CellBackColor
	For k = 1 To 2
		o.CellBackColor = col
		Wait gDelay * 3
		o.CellBackColor = b
		Wait gDelay * 2
	Next k
End Sub

Sub PAdd(ByVal r As Long, ByVal c As Long)
	gPR(gPN) = r
	gPC(gPN) = c
	gPN = gPN + 1
End Sub

Sub BuildBusPath(ByVal bus As Long, ByVal cS As Long, ByVal sBelow As Boolean, ByVal cD As Long, ByVal dBelow As Boolean)
	Dim r As Long, c As Long, s As Integer
	gPN = 0
	If sBelow Then
		For r = R_BELOW1 To bus + 1 Step -1 : PAdd(r, cS) : Next r
	Else
		For r = R_STUB0 To bus - 1 : PAdd(r, cS) : Next r
	End If
	If cD >= cS Then
		s = 1
	Else
		s = -1
	End If
	For c = cS To cD Step s : PAdd(bus, c) : Next c
	If dBelow Then
		For r = bus + 1 To R_BELOW1 : PAdd(r, cD) : Next r
	Else
		For r = bus - 1 To R_STUB0 Step -1 : PAdd(r, cD) : Next r
	End If
End Sub

Sub BuildIntPath(ByVal src As String, ByVal dst As String)
	Dim rs As Long, rd As Long, r As Long, s As Integer
	gPN = 0
	rs = RRow(src) : rd = RRow(dst)
	If RLeft(src) Then
		PAdd(rs, C_LBUF) : PAdd(rs, C_LSTUB)
	Else
		PAdd(rs, C_RBUF) : PAdd(rs, C_RSTUB)
	End If
	If rd >= rs Then
		s = 1
	Else
		s = -1
	End If
	For r = rs To rd Step s : PAdd(r, C_IBUS) : Next r
	If RLeft(dst) Then
		PAdd(rd, C_LSTUB)
	Else
		PAdd(rd, C_RSTUB)
	End If
End Sub

Sub RunPath(ByVal txt As String, ByVal tokCol As Long, ByVal actCol As Long, ByVal mult As Integer)
	If gDelay = 0 Or gPN = 0 Then Exit Sub
	Dim i As Long, sv(700) As Long, ss(700) As String, o As Object, prev As Object
	Lk()
	For i = 0 To gPN - 1
		o = Cel(gPR(i), gPC(i))
		sv(i) = o.CellBackColor
		ss(i) = o.getString()
		o.CellBackColor = actCol
	Next i
	Ulk()
	Wait gDelay * 2
	For i = 0 To gPN - 1
		Lk()
		If i > 0 Then
			prev = Cel(gPR(i - 1), gPC(i - 1))
			prev.CellBackColor = actCol
			prev.setString(ss(i - 1))
		End If
		o = Cel(gPR(i), gPC(i))
		o.CellBackColor = tokCol
		o.setString(txt)
		Ulk()
		Wait gDelay * mult
	Next i
	Wait gDelay * 3
	Lk()
	o.setString(ss(gPN - 1))
	For i = 0 To gPN - 1
		Cel(gPR(i), gPC(i)).CellBackColor = sv(i)
	Next i
	Ulk()
End Sub

Sub AnimData(ByVal cS As Long, ByVal sB As Boolean, ByVal cD As Long, ByVal dB As Boolean, ByVal txt As String)
	If gDelay = 0 Then Exit Sub
	BuildBusPath(R_BDAT, cS, sB, cD, dB)
	RunPath(txt, COL_TOK_DATA, COL_DAT_ACT, 1)
End Sub

Sub AnimAddr(ByVal cS As Long, ByVal cD As Long, ByVal txt As String)
	If gDelay = 0 Then Exit Sub
	BuildBusPath(R_BADR, cS, False, cD, False)
	RunPath(txt, COL_TOK_ADR, COL_ADR_ACT, 1)
End Sub

Sub AnimInt(ByVal src As String, ByVal dst As String, ByVal txt As String)
	If gDelay = 0 Then Exit Sub
	BuildIntPath(src, dst)
	RunPath(txt, COL_TOK_DATA, COL_INT_ACT, 3)
End Sub

Sub CtlOn(ByVal c1 As Long, ByVal c2 As Long, ByVal lbl As String)
	If gDelay = 0 Then Exit Sub
	Dim c As Long
	If c1 < c2 Then
		gCtlA = c1 : gCtlB = c2
	Else
		gCtlA = c2 : gCtlB = c1
	End If
	For c = gCtlA To gCtlB
		gCtlSave(c - gCtlA) = Cel(R_BCTL, c).CellBackColor
		gCtlStr(c - gCtlA) = GetS(R_BCTL, c)
		Bg(R_BCTL, c, COL_CTL_ACT)
	Next c
	PutS(R_BCTL, gCtlA + 1, lbl)
	gCtlOn = True
End Sub

Sub CtlOff()
	If Not gCtlOn Then Exit Sub
	Dim c As Long
	For c = gCtlA To gCtlB
		Bg(R_BCTL, c, gCtlSave(c - gCtlA))
		PutS(R_BCTL, c, gCtlStr(c - gCtlA))
	Next c
	gCtlOn = False
End Sub
