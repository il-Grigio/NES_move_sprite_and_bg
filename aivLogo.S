.db "NES", $1A, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0

.org $8000

.define PPUCTRL $2000
.define PPUMASK $2001
.define OAMADDR $2003
.define OAMDATA $2004
.define PPUSCROLL $2005
.define PPUADDR $2006
.define PPUDATA $2007
.define JOYPAD1 $4016

.define scrollx $01
.define buttons $02
.define currentlinefirstbyte $03
.define currentlinelastbyte $04
.define spriteposY $05
; PPUCTRL:
;     7  bit  0
;     ---- ----
;     VPHB SINN
;     |||| ||||
;     |||| ||++- Base nametable address
;     |||| ||    (0 = $2000; 1 = $2400; 2 = $2800; 3 = $2C00)
;     |||| |+--- VRAM address increment per CPU read/write of PPUDATA
;     |||| |     (0: add 1, going across; 1: add 32, going down)
;     |||| +---- Sprite pattern table address for 8x8 sprites
;     ||||       (0: $0000; 1: $1000; ignored in 8x16 mode)
;     |||+------ Background pattern table address (0: $0000; 1: $1000)
;     ||+------- Sprite size (0: 8x8 pixels; 1: 8x16 pixels – see PPU OAM#Byte 1)
;     |+-------- PPU master/slave select
;     |          (0: read backdrop from EXT pins; 1: output color on EXT pins)
;     +--------- Generate an NMI at the start of the
;                vertical blanking interval (0: off; 1: on)

; PPUMASK
;     7  bit  0
;     ---- ----
;     BGRs bMmG
;     |||| ||||
;     |||| |||+- Greyscale (0: normal color, 1: produce a greyscale display)
;     |||| ||+-- 1: Show background in leftmost 8 pixels of screen, 0: Hide
;     |||| |+--- 1: Show sprites in leftmost 8 pixels of screen, 0: Hide
;     |||| +---- 1: Show background
;     |||+------ 1: Show sprites
;     ||+------- Emphasize red (green on PAL/Dendy)
;     |+-------- Emphasize green (red on PAL/Dendy)
;     +--------- Emphasize blue


start:
    LDA #%10000000
    STA PPUCTRL

    LDA #%00011110
    STA PPUMASK

    LDA #$3F 
    STA PPUADDR
    LDA #0
    STA PPUADDR

    ; color pallette
    LDA #$0F
    STA PPUDATA
    LDA #$0
    STA PPUDATA
    LDA #$28
    STA PPUDATA
    LDA #$20
    STA PPUDATA
    


    ; sprite color pallette
        LDA #$3F 
        STA PPUADDR
        LDA #$14
        STA PPUADDR

        LDA #$21
        STA PPUDATA
        LDA #$22
        STA PPUDATA
        LDA #$23
        STA PPUDATA
        LDA #$24
        STA PPUDATA

    LDA #$20
    STA PPUADDR
    LDA #$00
    STA PPUADDR

    LDX #1
    ; set current line at 0
    LDA #$00
    STA currentlinelastbyte
    LDA #$20
    STA currentlinefirstbyte
    JSR draw_image


    LDX #1
    LDA #$00
    STA currentlinelastbyte
    LDA #$24
    STA currentlinefirstbyte
    JSR draw_image

    LDA #0
    STA OAMADDR
    LDA #$22        ;posy
    STA OAMDATA
    LDA #$66        ;tile index
    STA OAMDATA
    LDA #%00000001  ;attributes
    STA OAMDATA
    LDA #$22        ;posx
    STA OAMDATA

    LDA #77
    STA spriteposY

loop:
  JMP loop

draw_image:
    DEX
    STX PPUDATA
    INX
    TXA
        ; 00000110
    AND #%00001111 ; == #$0F
    BEQ new_line
    continue:
    INX
    BNE draw_image
    RTS


new_line:
    ; 2110
    LDA currentlinelastbyte
    CLC
    ADC #$20
    STA currentlinelastbyte

    BEQ incfirstbyte
    afterincfirstbyte:

    LDA currentlinefirstbyte
    STA PPUADDR

    LDA currentlinelastbyte
    STA PPUADDR
    JMP continue


incfirstbyte:
    LDY currentlinefirstbyte
    INY
    STY currentlinefirstbyte
    JMP afterincfirstbyte

; At the same time that we strobe bit 0, we initialize the ring counter
; so we're hitting two birds with one stone here
readjoy:
    lda #$01
    ; While the strobe bit is set, buttons will be continuously reloaded.
    ; This means that reading from JOYPAD1 will only return the state of the
    ; first button: button A.
    sta JOYPAD1
    sta buttons
    lsr a        ; now A is 0
    ; By storing 0 into JOYPAD1, the strobe bit is cleared and the reloading stops.
    ; This allows all 8 buttons (newly reloaded) to be read from JOYPAD1.
    sta JOYPAD1
joyloop:
    lda JOYPAD1
    lsr a           ; bit 0 -> Carry
    rol buttons  ; Carry -> bit 0; bit 7 -> Carry
    bcc joyloop
    rts

nmi:

    PHA
    JSR readjoy
    PLA
    JSR readxinput
    

  RTI
readxinput:
    LDA buttons
    AND #%00001111
    BEQ skipscroll

    LDA buttons
    AND #%00001101
    BEQ decresescrollx

    LDA buttons
    AND #%00001110
    BEQ incresescrollx
    
    LDA buttons
    AND #%00000111
    BEQ movespriteUP

    LDA buttons
    AND #%00001011
    BEQ movespriteDown


    
    skipscroll: 
    JSR movesprite

    LDA scrollx
    STA PPUSCROLL
    LDA #$00
    STA PPUSCROLL
    RTS
incresescrollx:
    LDA scrollx
    CMP #$FF
    BEQ skipscroll

    INC scrollx
    JMP skipscroll
decresescrollx:
    LDA scrollx
    AND #$FF
    BEQ skipscroll
    DEC scrollx
    JMP skipscroll
movesprite:
    LDA #0
    STA OAMADDR
    LDA spriteposY      ;posy
    STA OAMDATA
    LDA #$66        ;tile index
    STA OAMDATA
    LDA #%00000001  ;attributes
    STA OAMDATA
    LDA scrollx       ;posx
    STA OAMDATA
    RTS

movespriteUP:
    LDA spriteposY
    CMP #$00
    BEQ skipscroll
    DEC spriteposY
    JMP skipscroll

movespriteDown:
    LDA spriteposY
    CMP #$FF
    BEQ skipscroll
    INC spriteposY
    JMP skipscroll

irq:
  RTI

.goto $FFFA

.dw nmi
.dw start
.dw irq

.incbin "aiv256.chr"