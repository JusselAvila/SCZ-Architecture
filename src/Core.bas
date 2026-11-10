REM =====================================================================
REM  SCZ-Architecture - Core module
REM  Shared state, cell helpers, hexadecimal helpers, status bar, event log,
REM  repaint locking, form-control readers and the button entry points.
REM  Layout coordinates, colors and STATE rows come from the generated
REM  module `Config` (see build/build.py). LibreOffice Basic.
REM =====================================================================
Option Explicit

Global oSh As Object
Global oSt As Object
Global oPg As Object
Global gDelay As Long
Global gAnimF As Boolean
Global gBusy As Boolean
Global gStop As Boolean
Global gLk As Integer
Global gSigs As Variant
Global gPgCols As Variant

REM ====================== BUTTONS =======================================
REM Every button blocks overlapping runs (gBusy), calls the procedure of its
REM feature module and reports errors. While a feature module is not merged yet,
REM Basic raises error 35 (procedure not defined) and the button says it is pending.
Sub BtnLoadP1(Optional oEv As Object)
	If Not Enter() Then Exit Sub
	On Error GoTo Fail
	LoadProg(PG_COL_P1, "P1 Multiplication")
	Leave()
	Exit Sub
Fail:
	HandleErr("Load P1", Err, Erl, Error$)
End Sub
Sub BtnLoadP2(Optional oEv As Object)
	If Not Enter() Then Exit Sub
	On Error GoTo Fail
	LoadProg(PG_COL_P2, "P2 Keyboard -> LCD")
	Leave()
	Exit Sub
Fail:
	HandleErr("Load P2", Err, Erl, Error$)
End Sub
Sub BtnLoadP3(Optional oEv As Object)
	If Not Enter() Then Exit Sub
	On Error GoTo Fail
	LoadProg(PG_COL_P3, "P3 Memory fill and SWAP")
	Leave()
	Exit Sub
Fail:
	HandleErr("Load P3", Err, Erl, Error$)
End Sub
Sub BtnLoadEditor(Optional oEv As Object)
	If Not Enter() Then Exit Sub
	On Error GoTo Fail
	ThisComponent.CurrentController.setActiveSheet(oSh)
	LoadProg(PG_COL_ED, "EDITOR")
	Leave()
	Exit Sub
Fail:
	HandleErr("Load EDITOR", Err, Erl, Error$)
End Sub
Sub BtnCheckEditor(Optional oEv As Object)
	If Not Enter() Then Exit Sub
	On Error GoTo Fail
	CheckEditor()
	Leave()
	Exit Sub
Fail:
	HandleErr("Check EDITOR syntax", Err, Erl, Error$)
End Sub
Sub BtnStep(Optional oEv As Object)
	If Not Enter() Then Exit Sub
	On Error GoTo Fail
	PanelStep()
	Leave()
	Exit Sub
Fail:
	HandleErr("Step", Err, Erl, Error$)
End Sub
Sub BtnRun(Optional oEv As Object)
	If Not Enter() Then Exit Sub
	On Error GoTo Fail
	PanelRun()
	Leave()
	Exit Sub
Fail:
	HandleErr("Run", Err, Erl, Error$)
End Sub
Sub BtnStop(Optional oEv As Object)
	gStop = True
End Sub
Sub BtnReset(Optional oEv As Object)
	If Not Enter() Then Exit Sub
	On Error GoTo Fail
	PanelReset()
	Leave()
	Exit Sub
Fail:
	HandleErr("Reset", Err, Erl, Error$)
End Sub
Sub BtnType(Optional oEv As Object)
	If Not Enter() Then Exit Sub
	On Error GoTo Fail
	KeyboardType()
	Leave()
	Exit Sub
Fail:
	HandleErr("TYPE", Err, Erl, Error$)
End Sub

REM error 35 (procedure not defined) or 12 (name not defined, for a call without
REM arguments): the feature module that provides it is not merged yet
Sub HandleErr(ByVal action As String, ByVal num As Long, ByVal ln As Long, ByVal msg As String)
	Dim missing As String, p As Integer
	If num = 35 Or num = 12 Then
		missing = msg
		p = InStr(missing, "information:")
		If p > 0 Then missing = Trim(Mid(missing, p + 12))
		p = InStr(missing, Chr(10))
		If p > 0 Then missing = Trim(Mid(missing, p + 1))
		gBusy = False
		gLk = 0
		On Error Resume Next
		Do While ThisComponent.hasControllersLocked()
			ThisComponent.unlockControllers()
		Loop
		InitSh()
		Status(action & ": not implemented yet (pending module with '" & missing & "').", 2)
	Else
		ShowErr(action, num, ln, msg)
	End If
End Sub

Function Enter() As Boolean
	InitSh()
	If gBusy Then
		Enter = False
	Else
		gBusy = True
		gStop = False
		Enter = True
	End If
End Function
Sub Leave()
	gBusy = False
End Sub
Sub ShowErr(ByVal where As String, ByVal num As Long, ByVal ln As Long, ByVal msg As String)
	gBusy = False
	gLk = 0
	On Error Resume Next
	Do While ThisComponent.hasControllersLocked()
		ThisComponent.unlockControllers()
	Loop
	InitSh()
	Status("ERROR in " & where & " (line " & ln & ", code " & num & "): " & msg & ". Press Reset.", 3)
End Sub

REM ====================== INITIALIZATION ================================
Sub InitSh()
	oSh = ThisComponent.Sheets.getByName("SIMULATOR")
	oSt = ThisComponent.Sheets.getByName("STATE")
	oPg = ThisComponent.Sheets.getByName("PROGRAMS")
	gSigs = Split(SIGNALS, ",")
	gPgCols = Split(PAGECOLS, ",")
	Select Case Int(Val(ListSel("lstSpeed", "3")))
		Case 1 : gDelay = 90
		Case 2 : gDelay = 45
		Case 3 : gDelay = 18
		Case 4 : gDelay = 5
		Case 5 : gDelay = 0
		Case Else : gDelay = 18
	End Select
	gAnimF = (UCase(Left(ListSel("lstAnim", "YES"), 1)) = "Y")
End Sub

REM ====================== REPAINT LOCK ==================================
REM Nested lock: many cell writes -> a single repaint.
Sub Lk()
	If gLk = 0 Then ThisComponent.lockControllers()
	gLk = gLk + 1
End Sub
Sub Ulk()
	gLk = gLk - 1
	If gLk <= 0 Then
		gLk = 0
		ThisComponent.unlockControllers()
	End If
End Sub

REM ====================== CELL HELPERS ==================================
Function Cel(ByVal r As Long, ByVal c As Long) As Object
	Cel = oSh.getCellByPosition(c, r)
End Function
Sub PutS(ByVal r As Long, ByVal c As Long, ByVal s As String)
	oSh.getCellByPosition(c, r).setString(s)
End Sub
Function GetS(ByVal r As Long, ByVal c As Long) As String
	GetS = oSh.getCellByPosition(c, r).getString()
End Function
Sub Bg(ByVal r As Long, ByVal c As Long, ByVal col As Long)
	oSh.getCellByPosition(c, r).CellBackColor = col
End Sub
REM STATE sheet: value of row i (column B)
Function St(ByVal i As Integer) As Long
	St = oSt.getCellByPosition(1, i).getValue()
End Function
Sub SetSt(ByVal i As Integer, ByVal v As Long)
	oSt.getCellByPosition(1, i).setValue(v)
End Sub
Sub IncSt(ByVal i As Integer)
	SetSt(i, St(i) + 1)
End Sub
Sub Pause(ByVal ms As Long)
	If gDelay > 0 And ms > 0 Then Wait ms
End Sub
Function PageCol(ByVal p As Integer) As Long
	If p < 0 Or p > 15 Then
		PageCol = COL_FREE
	Else
		PageCol = CLng(gPgCols(p))
	End If
End Function

REM ====================== HEXADECIMAL ===================================
Function H2(ByVal v As Long) As String
	H2 = Right("00" & Hex(v And 255), 2)
End Function
Function H3(ByVal v As Long) As String
	H3 = Right("000" & Hex(v), 3)
End Function
REM "1F", "0x1F" -> 31 ; returns -1 when the text is not hexadecimal
Function HexVal(ByVal s As String) As Long
	Dim i As Integer, d As Integer, r As Long
	s = UCase(Trim(s))
	If Left(s, 2) = "0X" Then s = Mid(s, 3)
	If Len(s) = 0 Then
		HexVal = -1
		Exit Function
	End If
	r = 0
	For i = 1 To Len(s)
		d = InStr("0123456789ABCDEF", Mid(s, i, 1)) - 1
		If d < 0 Then
			HexVal = -1
			Exit Function
		End If
		r = r * 16 + d
	Next i
	HexVal = r
End Function
REM byte cell: 1 character = its ASCII code, otherwise 2 hex digits
Function ParseB(ByVal s As String) As Long
	Dim t As String
	t = Trim(s)
	If Len(t) = 0 Then
		ParseB = 0
	ElseIf Len(t) = 1 Then
		ParseB = Asc(t) And 255
	Else
		ParseB = HexVal(t) And 255
	End If
End Function

REM ====================== STATUS BAR AND EVENT LOG ======================
REM kind: 0 = info (blue), 1 = ok (green), 2 = warning (orange), 3 = error (red)
Sub Status(ByVal msg As String, ByVal kind As Integer)
	Dim c As Object
	Lk()
	c = Cel(R_STATUS, 1)
	c.setString(msg)
	Select Case kind
		Case 1 : c.CellBackColor = COL_ST_OK
		Case 2 : c.CellBackColor = COL_ST_WARN
		Case 3 : c.CellBackColor = COL_ST_ERR
		Case Else : c.CellBackColor = COL_ST_INFO
	End Select
	LogLine(">> " & msg)
	Ulk()
	Pause(gDelay * 10)
End Sub
REM the log is a single merged cell: newest line first, LOG_LINES lines kept
Sub LogLine(ByVal s As String)
	Dim t As String, p As Long, k As Integer, i As Long
	t = "[cycle " & Format(St(ST_CLK), "000") & "]  " & s & Chr(10) & Cel(R_LOG0, C_LOG).getString()
	p = 0
	For k = 1 To LOG_LINES
		i = InStr(p + 1, t, Chr(10))
		If i = 0 Then Exit For
		p = i
	Next k
	If k > LOG_LINES And p > 0 Then t = Left(t, p - 1)
	Cel(R_LOG0, C_LOG).setString(t)
End Sub

REM ====================== FORM CONTROLS =================================
REM Text boxes and lists are form controls (not cells), so their current value
REM is read even if the user did not press Enter before clicking a button.
Function FormModel(ByVal nm As String) As Object
	Dim oForms As Object, f As Object, i As Integer
	oForms = oSh.DrawPage.Forms
	For i = 0 To oForms.Count - 1
		f = oForms.getByIndex(i)
		If f.hasByName(nm) Then
			FormModel = f.getByName(nm)
			Exit Function
		End If
	Next i
End Function
Function CtlText(ByVal nm As String) As String
	Dim m As Object, v As Object, t As String
	m = FormModel(nm)
	If IsNull(m) Then Exit Function
	t = m.Text
	On Error Resume Next
	v = ThisComponent.CurrentController.getControl(m)
	If Not IsNull(v) Then t = v.getText()
	CtlText = t
End Function
Function KbdText() As String
	KbdText = Trim(CtlText("txtKeyboard"))
End Function
REM number 0..255 from a text box; defv when empty or not numeric
Function NumInput(ByVal nm As String, ByVal defv As Long) As Long
	Dim t As String, x As Double, m As Object
	t = Trim(CtlText(nm))
	If t = "" Or Not IsNumeric(t) Then
		x = defv
	Else
		x = Val(t)
	End If
	If x < 0 Then x = 0
	If x > 255 Then x = 255
	NumInput = CLng(Int(x))
	m = FormModel(nm)
	If Not IsNull(m) Then m.Text = CStr(NumInput)
End Function
Function ListSel(ByVal nm As String, ByVal defv As String) As String
	Dim m As Object, a As Variant
	ListSel = defv
	m = FormModel(nm)
	If IsNull(m) Then Exit Function
	a = m.SelectedItems
	If UBound(a) >= 0 Then ListSel = m.StringItemList(a(0))
End Function
