REM =====================================================================
REM  SCZ-Architecture - Isa module
REM  Instruction set: disassembler of the fixed 4-byte format
REM =====================================================================
Option Explicit

Function Disasm(b As Variant) As String
	Dim n1 As String, n2 As String, a As String, im As String
	n1 = RegName(b(1)) : n2 = RegName(b(2))
	a = H3((b(2) And 1) * 256 + b(3)) & "h" : im = H2(b(3)) & "h"
	Select Case b(0)
		Case 0 : Disasm = "NOP"
		Case 1 : Disasm = "MOV " & n1 & ", " & im
		Case 2 : Disasm = "MOV " & n1 & ", " & n2
		Case 3 : Disasm = "MOV " & n1 & ", [" & a & "]"
		Case 4 : Disasm = "MOV [" & a & "], " & n1
		Case 5 : Disasm = "ADD " & n1 & ", " & n2
		Case 6 : Disasm = "ADD " & n1 & ", " & im
		Case 7 : Disasm = "SUB " & n1 & ", " & n2
		Case 8 : Disasm = "SUB " & n1 & ", " & im
		Case 9 : Disasm = "INC " & n1
		Case 10 : Disasm = "DEC " & n1
		Case 11 : Disasm = "CMP " & n1 & ", " & n2
		Case 12 : Disasm = "CMP " & n1 & ", " & im
		Case 13 : Disasm = "JMP " & a
		Case 14 : Disasm = "JZ " & a
		Case 15 : Disasm = "JNZ " & a
		Case 16 : Disasm = "IN " & n1 & ", [KBD]"
		Case 17 : Disasm = "OUT [LCD], " & n1
		Case 18 : Disasm = "HLT"
		Case 19 : Disasm = "JC " & a
		Case Else : Disasm = "???"
	End Select
End Function
