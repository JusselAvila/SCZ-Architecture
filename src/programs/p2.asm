; ===== PROGRAM 2: KEYBOARD ECHO -> 8x1 LCD SCREEN =====
; 1) Type a text (e.g. HELLO) in the KEYBOARD box
; 2) Press TYPE (or just Run): the letters enter the queue (RAM M7 00-07)
; 3) Run: each letter travels queue -> bus -> DX -> bus
;    -> video buffer (RAM M7 08-0F) -> LCD screen
NEXT:   IN   DX, [KBD]    ; DX <- next letter (ZF=1 if the queue is empty)
        JZ   DONE         ; empty queue -> finish
        OUT  [LCD], DX    ; send the letter to the LCD
        JMP  NEXT         ; repeat with the next letter
DONE:   HLT
