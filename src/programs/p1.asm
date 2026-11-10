; ===== PROGRAM 1: SEQUENTIAL MULTIPLICATION (repeated addition) =====
; RESULT = A x B   using AX, BX, CX and DX
; A and B are typed in the PROGRAM 1 INPUTS panel (top right)
; and the loader places them in virtual page 2 (0x040 and 0x041)
.DATA 0x040, 7, 5        ; A = 7 , B = 5
        MOV  AX, [0x040]  ; AX <- A (multiplicand)
        MOV  BX, [0x041]  ; BX <- B (multiplier)
        MOV  CX, BX       ; CX = loop counter
        MOV  DX, 0        ; DX = accumulator (partial result)
        CMP  CX, 0        ; if B = 0 there is nothing to add
        JZ   END
LOOP:   ADD  DX, AX       ; DX = DX + A   (repeated addition)
        DEC  CX           ; CX = CX - 1  (updates ZF)
        JNZ  LOOP         ; repeat while CX <> 0
END:    MOV  [0x042], DX  ; store A x B in memory (0x042)
        HLT               ; end: DX = A x B
