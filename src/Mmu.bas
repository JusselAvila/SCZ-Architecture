REM =====================================================================
REM  SCZ-Architecture - Mmu module
REM  MMU: virtual to physical translation and page table
REM =====================================================================
Option Explicit

Global gTLFault As Boolean
Global gTLVictim As Integer

Sub PTPaint(ByVal v As Integer, ByVal col As Long)
	Dim c As Long
	Lk()
	For c = C_PT_P To C_PT_EST : Bg(R_PT0 + v, c, col) : Next c
	Ulk()
End Sub

Sub PTNormal(ByVal v As Integer)
	If GetS(R_PT0 + v, C_PT_P) = "1" Then
		PTPaint(v, COL_PT_RES)
	Else
		PTPaint(v, COL_PT_OUT)
	End If
	If GetS(R_PT0 + v, C_PT_D) = "1" Then Bg(R_PT0 + v, C_PT_D, COL_DIRTY)
End Sub

Function Translate(ByVal va As Long, ByVal isW As Boolean, ByVal isF As Boolean) As Long
	Dim vpn As Integer, off As Long, pfn As Long, pa As Long, r As Long, fault As Boolean
	vpn = va \ 32 : off = va Mod 32
	r = R_PT0 + vpn
	Lk()
	IncSt(ST_REF)
	PutS(R_MMU1, C_MMU, "VA 0x" & H3(va) & "  =  page " & vpn & "  +  offset 0x" & H2(off))
	PutS(R_MMU2, C_MMU, "Looking up page " & vpn & " in the page table...")
	PTPaint(vpn, COL_PT_LOOK)
	Ulk()
	Pause(gDelay * 6)
	gTLFault = False : gTLVictim = -1
	fault = (GetS(r, C_PT_P) <> "1")
	If fault Then PageFault(vpn)
	pfn = CLng(Val(GetS(r, C_PT_PFN)))
	pa = pfn * 32 + off
	Lk()
	PutS(r, C_PT_R, "1")
	Cel(r, C_PT_USO).setValue(St(ST_REF))
	If isW Then PutS(r, C_PT_D, "1")
	PutS(R_MMU2, C_MMU, "P=1 -> frame " & pfn & "  ->  PA = " & pfn & "x32 + " & off & " = 0x" & H3(pa))
	PTNormal(vpn)
	Ulk()
	Flash(r, C_PT_PFN, COL_FLASH)
	If (Not isF) Or fault Or vpn <> St(ST_LASTFP) Then TLRecord(vpn, isW, isF)
	If isF Then SetSt(ST_LASTFP, vpn)
	Translate = pa
End Function
