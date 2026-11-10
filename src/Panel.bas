REM =====================================================================
REM  SCZ-Architecture - Panel module
REM  Control panel actions: Step, Run, Stop and Reset
REM =====================================================================
Option Explicit

Sub PanelStep()
	If PrepareRun() Then
		DoStep()
		If St(ST_HALT) = 1 Then Summary()
	End If
End Sub

Sub PanelRun()
	Dim k As Integer
	If PrepareRun() Then
		Do While St(ST_HALT) = 0 And k < 3000 And Not gStop
			DoStep()
			k = k + 1
		Loop
		If St(ST_HALT) = 1 Then
			Summary()
		ElseIf gStop Then
			Status("Execution PAUSED by the user. Press Step or Run to continue from here.", 2)
		End If
	End If
End Sub

Sub PanelReset()
	If St(ST_LOADED) = 1 Then
		LoadProg(St(ST_PROGCOL), oSt.getCellByPosition(2, ST_PROGCOL).getString())
	Else
		ThisComponent.lockControllers()
		ResetMachine()
		ThisComponent.unlockControllers()
		Status("Machine reset. Load a program.", 0)
	End If
End Sub

Function PrepareRun() As Boolean
	Dim txt As String
	PrepareRun = False
	If St(ST_LOADED) = 0 Then
		Status("Load a program first (buttons P1, P2 or P3).", 2)
		Exit Function
	End If
	If St(ST_HALT) = 1 Then
		LoadProg(St(ST_PROGCOL), oSt.getCellByPosition(2, ST_PROGCOL).getString())
		Status("The program had already finished: it was reloaded and runs again.", 0)
	End If
	If St(ST_INSTR) = 0 And St(ST_KCOUNT) = 0 And St(ST_USESIN) = 1 Then
		txt = KbdText()
		If Len(txt) > 0 Then
			Status("The program reads the keyboard: the text of the yellow box is typed automatically ('" & txt & "').", 0)
			TypeText(txt)
		End If
	End If
	PrepareRun = True
End Function

Sub Summary()
	Dim pre As String
	If St(ST_PROGCOL) = PG_COL_P1 Then pre = "RESULT " & GetS(R_P1RES, C_P1RES) & "  |  "
	Status(pre & "END. Instructions: " & St(ST_INSTR) & " | Page faults: " & St(ST_PF) & " | Swap-in: " & St(ST_SWIN) & " | Swap-out: " & St(ST_SWOUT) & " | Hits L1I/L1D/L2: " & St(ST_L1I_H) & "/" & St(ST_L1D_H) & "/" & St(ST_L2_H), 1)
End Sub
