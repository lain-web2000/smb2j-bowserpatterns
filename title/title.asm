.p02
.linecont +
.include "ascii.asm"
.include "../defines.inc"
.import GL_ENTER
.import GetAreaDataAddrs
.import LoadAreaPointer
.import EndWorld1Thru7
.import NMIHandler
.import IRQHandler
.import InitializeBG_CHR
.import InitializeSPR_CHR

;; WRAM SPACE
.segment "TEMPWRAM"
WRAMSaveHeader: .byte $00, $00, $00, $00, $00
HeldButtons: .byte $00
ReleasedButtons: .byte $00
LastReadButtons: .byte $00
PressedButtons: .byte $00
CachedChangeAreaTimer: .byte $00
LevelEnding: .byte $00
IsPlaying: .byte $00
EnteringFromMenu: .byte $00
PendingScoreDrawPosition: .byte $00
CachedITC: .byte $00
PREVIOUS_BANK: .byte $00

;; $7E00-$7FFF -- relocated bank switching code (starts at 7FA4) 
RelocatedCodeLocation = $7E00

.segment "PRACTISE_PRG0"
TitleReset3:
    ldx #$00
    stx PPU_CTRL_REG1
    stx PPU_CTRL_REG2
    jsr InitializeMemory
    jsr ForceClearWRAM
:   lda PPU_STATUS
    bpl :-
HotReset2:                             ;
    ldx #$00                           ; disable ppu again (this is called when resetting to the menu)
    stx PPU_CTRL_REG1                  ;
    stx PPU_CTRL_REG2                  ;
    ldx #$FF                           ; clear stack
    txs                                ;
:   lda PPU_STATUS                     ; wait for vblank
    bpl :-                             ;
    jsr InitBankSwitchingCode          ; copy bankswitching code to wram
    jsr ReadJoypads                    ; read controller to prevent a held button at startup from registering
    jsr PrepareScreen                  ; load in palette and background
    jsr MenuReset                      ; reset main menu
    lda #0                             ; disable playing state
    sta IsPlaying                      ;
    sta PPU_SCROLL_REG                 ; clear scroll registers
    sta PPU_SCROLL_REG                 ;
    lda #%10001000                     ; enable ppu
    sta Mirror_PPU_CTRL_REG1           ;
    sta PPU_CTRL_REG1                  ;
:   jmp :-                             ; infinite loop until NMI
; ================================================================

; ================================================================
;  Hot reset back to the title screen
; ----------------------------------------------------------------
HotReset:
    lda #0                             ; kill any playing sounds
    sta SND_MASTERCTRL_REG             ;
    jsr InitializeMemory               ; clear memory
    jmp HotReset2                      ; then jump to the shared reset code
; ================================================================

; ================================================================
;  Handle NMI interrupts while in the title screen
; ----------------------------------------------------------------
TitleNMI:
    lda Mirror_PPU_CTRL_REG1           ; disable nmi
    and #%01111111                     ;
    sta Mirror_PPU_CTRL_REG1           ; and update ppu state
    sta PPU_CTRL_REG1                  ;
    bit PPU_STATUS                     ; flip ppu status
    jsr WriteVRAMBufferToScreen        ; write any pending vram updates
    lda #0                             ; clear scroll registers
    sta PPU_SCROLL_REG                 ;
    sta PPU_SCROLL_REG                 ;
    lda #$02                           ; copy sprites
    sta SPR_DMA                        ;
    jsr ReadJoypads                    ; read controller state
    jsr MenuNMI                        ; and run menu code
    lda #%00011010                     ; set ppu mask state for menu
    sta PPU_CTRL_REG2                  ;
    lda Mirror_PPU_CTRL_REG1           ; get ppu mirror state
    ora #%10000000                     ; and reactivate nmi
    sta Mirror_PPU_CTRL_REG1           ; update ppu state
    sta PPU_CTRL_REG1                  ;
    rti                                ; and we are done for the frame

PrepareScreen:
    lda #$3F                           ; move ppu to palette memory
    sta PPU_ADDRESS                    ;
    lda #$00                           ;
    sta PPU_ADDRESS                    ;
    ldx #0                             ;
:   lda MenuPalette,x                  ; and copy the menu palette
    sta PPU_DATA                       ;
    inx                                ;
    cpx #(MenuPaletteEnd-MenuPalette)  ;
    bne :-                             ;
    lda #$20                           ; move ppu to nametable 0
    sta PPU_ADDRESS                    ;
    ldx #0                             ;
    stx PPU_ADDRESS                    ;
:   lda BGDATA+$000,x                  ; and copy every page of menu data
    sta PPU_DATA                       ;
    inx                                ;
    bne :-                             ;
:   lda BGDATA+$100,x                  ;
    sta PPU_DATA                       ;
    inx                                ;
    bne :-                             ;
:   lda BGDATA+$200,x                  ;
    sta PPU_DATA                       ;
    inx                                ;
    bne :-                             ;
:   lda BGDATA+$300,x                  ;
    sta PPU_DATA                       ;
    inx                                ;
    bne :-                             ;
    rts                                ;

InitializeMemory:
    ldx #0
    lda #0
@clear:
    sta $0000, x
    sta $0200, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    sta $6000, x
    inx
    bne @clear
    rts

InitializeWRAM:
    ldx #ROMSaveHeaderLen
@Verify:
    lda ROMSaveHeader, x
    cmp WRAMSaveHeader, x
    bne ForceClearWRAM
    dex
    bpl @Verify
    rts

ForceClearWRAM:
    lda #$60
    sta $1
    ldy #0
    sty $0
    ldx #$80
    lda #$00
@keep_copying:
    sta ($0),y
    iny
    bne @keep_copying
    ldy #0
    inc $1
    cpx $1
    bne @keep_copying
    ldx #ROMSaveHeaderLen
@Sign:
    lda ROMSaveHeader, x
    sta WRAMSaveHeader, x
    dex
    bpl @Sign
    rts

.include "practise.asm"
.include "menu.asm"
.include "utils.asm"
.include "background.asm"
.include "bankswitching.asm"
.include "rng.asm"

ROMSaveHeader:
.byte $03, $20, $07, $21, $03
ROMSaveHeaderLen = * - ROMSaveHeader - 1
