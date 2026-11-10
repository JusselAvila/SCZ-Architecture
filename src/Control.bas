REM =====================================================================
REM  SCZ-Architecture - Control module
REM  Hard-wired control unit: fetch T1-T4, decode/execute and jumps
REM =====================================================================
Option Explicit

Sub Phase(ByVal s As String)
	PutS(R_UC_PH, C_UC_V, s)
End Sub

Sub DoStep()
	Dim pc As Long, pa As Long, b As Variant, keep As Long
	If St(ST_LOADED) = 0 Then
		Status("Load a program first (buttons P1, P2 or P3).", 2)
		Exit Sub
	End If
	If St(ST_HALT) = 1 Then
		Status("The CPU is halted (HLT). Press Reset or load another program.", 2)
		Exit Sub
	End If
	pc = GetReg("PC")
	If pc >= 480 Or pc \ 4 >= St(ST_NCODE) \ 4 Then
		Status("ERROR: PC (0x" & H3(pc) & ") left the program code. CPU halted.", 3)
		Halt()
		Exit Sub
	End If
	HiCode(pc \ 4)
	Phase("FETCH  PC=0x" & H3(pc))
	keep = gDelay
	If Not gAnimF Then gDelay = 0
	Micro("T1: MAR <- PC (0x" & H3(pc) & ") over the internal bus", "En_PC,Ld_MAR")
	AnimInt("PC", "MAR", H3(pc))
	gDelay = keep
	PutS(R_MAR, C_RVAL, H3(pc))
	pa = Translate(pc, False, True)
	b = ReadInstr(pa)
	If Not gAnimF Then gDelay = 0
	Micro("T3: IR <- MDR   (" & Disasm(b) & ")", "En_MDR,Ld_IR")
	AnimInt("MDR", "IR", "ins")
	gDelay = keep
	PutS(R_IR, C_RVAL, H2(b(0)) & " " & H2(b(1)) & " " & H2(b(2)) & " " & H2(b(3)))
	PutS(R_IRM, C_RLBL, Disasm(b))
	Flash(R_IR, C_RVAL, COL_FLASH)
	Micro("T4: PC <- PC + 4", "Ld_PC")
	PutS(R_PC, C_RVAL, H3(pc + 4))
	Phase("EXECUTE: " & Disasm(b))
	Execute(b)
	IncSt(ST_INSTR)
	PutS(R_UC_INS, C_UC_V, CStr(St(ST_INSTR)))
End Sub

Sub Halt()
	SetSt(ST_HALT, 1)
	ShowP1Result()
	PutS(R_HALT, C_HALT, "CPU HALTED (HLT)")
	Bg(R_HALT, C_HALT, COL_ST_ERR)
	Phase("HALTED")
End Sub

Sub Execute(b As Variant)
	Dim op As Long, r1 As Integer, r2 As Integer, addr As Long, imm As Long, n1 As String, n2 As String, v As Long, tk As Boolean
	op = b(0) : r1 = b(1) And 3 : r2 = b(2) And 3 : imm = b(3)
	addr = (b(2) And 1) * 256 + b(3)
	n1 = RegName(r1) : n2 = RegName(r2)
	Select Case op
		Case 0
			Micro("NOP: does nothing", "")
		Case 1
			Micro(n1 & " <- 0x" & H2(imm) & " (immediate value from IR)", "En_IR,Ld_" & n1)
			AnimInt("IR", n1, H2(imm))
			SetReg(n1, imm)
		Case 2
			v = GetReg(n2)
			Micro(n1 & " <- " & n2 & " (0x" & H2(v) & ") over the internal bus", "En_" & n2 & ",Ld_" & n1)
			AnimInt(n2, n1, H2(v))
			SetReg(n1, v)
		Case 3
			Micro("MAR <- operand address 0x" & H3(addr), "En_IR,Ld_MAR")
			AnimInt("IR", "MAR", H3(addr))
			PutS(R_MAR, C_RVAL, H3(addr))
			v = ReadByte(addr)
			Micro(n1 & " <- MDR (0x" & H2(v) & ")", "En_MDR,Ld_" & n1)
			AnimInt("MDR", n1, H2(v))
			SetReg(n1, v)
		Case 4
			v = GetReg(n1)
			Micro("MAR <- destination address 0x" & H3(addr), "En_IR,Ld_MAR")
			AnimInt("IR", "MAR", H3(addr))
			PutS(R_MAR, C_RVAL, H3(addr))
			Micro("MDR <- " & n1 & " (0x" & H2(v) & ")", "En_" & n1 & ",Ld_MDR")
			AnimInt(n1, "MDR", H2(v))
			PutS(R_MDR, C_RVAL, H2(v))
			WriteByte(addr, v)
		Case 5 : AluOp("ADD", r1, n2, GetReg(n2), True)
		Case 6 : AluOp("ADD", r1, "IR", imm, True)
		Case 7 : AluOp("SUB", r1, n2, GetReg(n2), True)
		Case 8 : AluOp("SUB", r1, "IR", imm, True)
		Case 9 : AluOp("INC", r1, "", 1, True)
		Case 10 : AluOp("DEC", r1, "", 1, True)
		Case 11 : AluOp("CMP", r1, n2, GetReg(n2), False)
		Case 12 : AluOp("CMP", r1, "IR", imm, False)
		Case 13, 14, 15, 19
			Select Case op
				Case 13 : tk = True
				Case 14 : tk = (Flag(C_ZF) = 1)
				Case 15 : tk = (Flag(C_ZF) = 0)
				Case 19 : tk = (Flag(C_CF) = 1)
			End Select
			If tk Then
				Micro("Jump TAKEN: PC <- 0x" & H3(addr), "En_IR,Ld_PC")
				AnimInt("IR", "PC", H3(addr))
				SetPC(addr)
			Else
				Micro("Jump NOT taken (condition false): PC stays at 0x" & GetS(R_PC, C_RVAL), "")
			End If
		Case 16 : DoIn(r1)
		Case 17 : DoOut(r1)
		Case 18
			Micro("HLT: the CPU stops", "")
			Halt()
			Status("HLT: end of program.", 1)
		Case Else
			Status("Invalid opcode 0x" & H2(op) & ". CPU halted.", 3)
			Halt()
	End Select
End Sub
