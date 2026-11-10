; ===== EDITOR: write or change code here =====
; Press 'Check EDITOR syntax' and then 'Assemble and load'.
; Example: write HOLA directly on the LCD
        MOV  DX, 'H'
        OUT  [LCD], DX
        MOV  DX, 'O'
        OUT  [LCD], DX
        MOV  DX, 'L'
        OUT  [LCD], DX
        MOV  DX, 'A'
        OUT  [LCD], DX
        HLT
