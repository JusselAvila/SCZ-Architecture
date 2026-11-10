REM =====================================================================
REM  SCZ-Architecture - Swap module
REM  Page fault handling, FIFO/LRU replacement, swap-out and swap-in
REM =====================================================================
Option Explicit

Function FindFreeFrame() As Integer
	Dim f As Integer
	FindFreeFrame = -1
	For f = 0 To 6
		If FramePage(f) < 0 Then
			FindFreeFrame = f
			Exit Function
		End If
	Next f
End Function

Function ChooseVictim() As Integer
	Dim v As Integer, best As Integer, bv As Double, x As Double, useLRU As Boolean, col As Long
	useLRU = (ListSel("lstAlg", "LRU") <> "FIFO")
	If useLRU Then
		col = C_PT_USO
	Else
		col = C_PT_CAR
	End If
	best = -1 : bv = 1E9
	For v = 0 To 14
		If GetS(R_PT0 + v, C_PT_P) = "1" Then
			x = Cel(R_PT0 + v, col).getValue()
			If x < bv Then
				bv = x : best = v
			End If
		End If
	Next v
	ChooseVictim = best
End Function

Sub PageFault(ByVal vpn As Integer)
	Dim f As Integer, victim As Integer, alg As String, r As Long, i As Integer
	r = R_PT0 + vpn
	IncSt(ST_PF)
	gTLFault = True
	PTPaint(vpn, COL_FAULT)
	PutS(r, C_PT_EST, "PAGE FAULT")
	PutS(R_MMU2, C_MMU, "PAGE FAULT: page " & vpn & " has P=0 (not in RAM)")
	Status("PAGE FAULT: page P" & vpn & " is NOT in RAM (bit P=0). The instruction is suspended and the OS takes control.", 3)
	Micro("Page fault trap -> the OS handles the fault of page " & vpn, "")
	f = FindFreeFrame()
	victim = -1
	If f < 0 Then
		alg = ListSel("lstAlg", "LRU")
		If alg <> "FIFO" Then alg = "LRU"
		victim = ChooseVictim()
		f = CInt(Val(GetS(R_PT0 + victim, C_PT_PFN)))
		gTLVictim = victim
		PTPaint(victim, COL_VICTIM)
		PutS(R_PT0 + victim, C_PT_EST, "VICTIM (" & alg & ")")
		Status("RAM FULL (7 user frames in use). " & alg & " picks as VICTIM page P" & victim & " in frame M" & f & ".", 2)
		FlashFrame(f, COL_VICTIM)
		If GetS(R_PT0 + victim, C_PT_D) = "1" Then
			Status("Victim P" & victim & " is DIRTY (D=1): SWAP-OUT -> frame M" & f & " is copied to disk so its data is not lost.", 2)
			SwapOut(victim, f)
		Else
			Status("Victim P" & victim & " is CLEAN (D=0): discarded without writing (the disk already has an identical copy).", 0)
			For i = 0 To 31 : Bg(RamRow(f * 32 + i), RamCol(f * 32 + i), COL_FREE) : Next i
		End If
		InvalCaches(f)
		Lk()
		PutS(R_PT0 + victim, C_PT_P, "0")
		PutS(R_PT0 + victim, C_PT_PFN, "-")
		PutS(R_PT0 + victim, C_PT_D, "0")
		PutS(R_PT0 + victim, C_PT_R, "0")
		PutS(R_PT0 + victim, C_PT_EST, "on disk (swap)")
		PTNormal(victim)
		PutS(R_RAM0 + f * 2, C_RAMPG, "-")
		Bg(R_RAM0 + f * 2, C_RAMPG, COL_FREE)
		DiskLabel(victim, -1)
		Ulk()
	End If
	Status("SWAP-IN: page P" & vpn & " (32 bytes) is brought from disk to frame M" & f & ".", 0)
	SwapIn(vpn, f)
	Lk()
	PutS(r, C_PT_P, "1")
	PutS(r, C_PT_PFN, CStr(f))
	PutS(r, C_PT_D, "0")
	PutS(r, C_PT_R, "1")
	Cel(r, C_PT_CAR).setValue(St(ST_REF))
	PutS(r, C_PT_EST, "in RAM (M" & f & ")")
	PTNormal(vpn)
	Ulk()
	Micro("Page table: P" & vpn & " -> P=1, frame=" & f & ". The instruction RESUMES.", "")
	Status("Page P" & vpn & " loaded in M" & f & " (P=1). The faulting instruction resumes.", 1)
End Sub

Sub SwapOut(ByVal v As Integer, ByVal f As Integer)
	Dim i As Integer, pc As Long, va As Long
	Micro("SWAP-OUT (DMA): frame M" & f & " -> data bus -> disk, page P" & v, "Mem_R,IO")
	CtlOn(C_RAM_CTL, C_DSK_CTL, "DMA")
	AnimData(C_RAM_DAT, False, C_DSK_DAT, False, "P" & v)
	pc = PageCol(v)
	For i = 0 To 31
		va = v * 32 + i
		Lk()
		If i > 0 Then Bg(DskRow(va - 1), DskCol(va - 1), pc)
		PutS(DskRow(va), DskCol(va), H2(RamGet(f * 32 + i)))
		Bg(DskRow(va), DskCol(va), COL_TOK_DATA)
		Bg(RamRow(f * 32 + i), RamCol(f * 32 + i), COL_FREE)
		If gDelay = 0 Or i = 31 Then Bg(DskRow(va), DskCol(va), pc)
		Ulk()
		Pause(gDelay \ 2)
	Next i
	CtlOff()
	IncSt(ST_SWOUT)
End Sub

Sub SwapIn(ByVal v As Integer, ByVal f As Integer)
	Dim i As Integer, pc As Long, va As Long
	FlashDiskPage(v, COL_TOK_DATA)
	Micro("SWAP-IN (DMA): disk, page P" & v & " -> data bus -> frame M" & f & " of RAM", "Mem_W,IO")
	CtlOn(C_RAM_CTL, C_DSK_CTL, "DMA")
	AnimData(C_DSK_DAT, False, C_RAM_DAT, False, "P" & v)
	pc = PageCol(v)
	For i = 0 To 31
		va = v * 32 + i
		Lk()
		If i > 0 Then Bg(RamRow(f * 32 + i - 1), RamCol(f * 32 + i - 1), pc)
		PutS(RamRow(f * 32 + i), RamCol(f * 32 + i), GetS(DskRow(va), DskCol(va)))
		Bg(RamRow(f * 32 + i), RamCol(f * 32 + i), COL_TOK_DATA)
		If gDelay = 0 Or i = 31 Then Bg(RamRow(f * 32 + i), RamCol(f * 32 + i), pc)
		Ulk()
		Pause(gDelay \ 2)
	Next i
	CtlOff()
	PutS(R_RAM0 + f * 2, C_RAMPG, "P" & v)
	Bg(R_RAM0 + f * 2, C_RAMPG, pc)
	Bg(RamRow(f * 32 + 31), RamCol(f * 32 + 31), pc)
	DiskLabel(v, f)
	IncSt(ST_SWIN)
	UpdFree()
End Sub
