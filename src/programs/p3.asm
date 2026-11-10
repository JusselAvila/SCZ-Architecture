; ===== PROGRAM 3: MEMORY FILL AND SWAP =====
; RAM = 7 user frames (M7 is pinned to I/O).
; Scattered pages are touched until RAM is FULL and then
; every new access forces a page REPLACEMENT (LRU/FIFO).
        MOV  AX, 0xAA      ; mark to be written
        MOV  [0x040], AX   ; P2 -> page fault, free frame (DIRTY)
        MOV  [0x060], AX   ; P3 -> page fault (DIRTY)
        MOV  [0x080], AX   ; P4 -> page fault (DIRTY)
        MOV  BX, [0x0A0]   ; P5 -> page fault (read only: CLEAN)
        MOV  BX, [0x0C0]   ; P6 -> page fault (CLEAN)
        MOV  [0x0E0], AX   ; P7 -> page fault: RAM FULL
        MOV  BX, [0x100]   ; P8 -> REPLACEMENT: swap-out of a dirty victim
        MOV  CX, [0x040]   ; P2 comes back from disk: CX = AA (the data survived)
        MOV  DX, [0x120]   ; P9 -> clean victim: discarded without writing
        HLT
