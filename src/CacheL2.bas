REM =====================================================================
REM  SCZ-Architecture - CacheL2 module
REM  Unified direct-mapped L2 cache (4 x 8 B) and invalidation
REM =====================================================================
Option Explicit

Function L2Row(ByVal lb As Long) As Long
	L2Row = R_L2_0 + ((lb \ 8) Mod 4)
End Function

Sub InvalCaches(ByVal f As Integer)
	Dim r As Long, k As Integer, hit As Boolean
	hit = False
	If CacheLineOfFrame(R_L1I, f) Then
		ClearLine(R_L1I) : hit = True
	End If
	If CacheLineOfFrame(R_L1D, f) Then
		ClearLine(R_L1D) : hit = True
	End If
	For k = 0 To 3
		If CacheLineOfFrame(R_L2_0 + k, f) Then
			ClearLine(R_L2_0 + k) : hit = True
		End If
	Next k
	If hit Then Micro("Coherence: the cache lines of frame M" & f & " are INVALIDATED", "")
End Sub

Function CacheLineOfFrame(ByVal r As Long, ByVal f As Integer) As Boolean
	Dim t As Long
	CacheLineOfFrame = False
	If GetS(r, C_CV) = "1" Then
		t = HexVal(GetS(r, C_CTAG))
		If t >= 0 Then CacheLineOfFrame = ((t \ 32) = f)
	End If
End Function

Sub ClearLine(ByVal r As Long)
	Dim i As Integer
	For i = 0 To 7
		PutS(r, C_CB0 + i, "--")
		Bg(r, C_CB0 + i, COL_CEMPTY)
	Next i
	PutS(r, C_CTAG, "---")
	Bg(r, C_CTAG, COL_CEMPTY)
	PutS(r, C_CV, "0")
End Sub
