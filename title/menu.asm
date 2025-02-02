.export SettablesLevel
SettablesCount = $4

.pushseg
.segment "MENUWRAM"
Settables:
SettablePUP: .byte $00
SettablesHero:  .byte $00
SettablesLevel: .byte $00
Settable2:   .byte $00
.popseg

MenuTitles:
.byte "P-UP"
.byte "HERO"
.byte "WRLD"
.byte "RNG "

.define MenuTitleLocations \
    $20CA + ($40 * 0), \
    $20CA + ($40 * 1), \
    $20CA + ($40 * 2), \
    $20CA + ($40 * 3)

.define MenuValueLocations \
    $20D3 + ($40 * 0) - 3, \
    $20D3 + ($40 * 1) - 4, \
    $20D3 + ($40 * 2) - 2, \
    $20D3 + ($40 * 3) - 4

UpdateMenuValueJE:
    tya
    jsr JumpEngine
    .word UpdateValuePUps        ; p-up
	.word UpdateValueToggle		 ; hero
	.word UpdateValueToggle		 ; level
    .word UpdateValueFramerule   ; frame

DrawMenuValueJE:
    tya
    jsr JumpEngine
    .word DrawValueString_PUp    ; p-up
    .word DrawValueString_Hero   ; hero
    .word DrawValueString_Level   ; level
    .word DrawValueFramerule 	 ; frame

DrawMenuTitle:
    clc
    lda VRAM_Buffer1_Offset
    tax
    adc #3 + 4
    sta VRAM_Buffer1_Offset
    lda MenuTitleLocationsHi, y
    sta VRAM_Buffer1+0, x
    lda MenuTitleLocationsLo, y
    sta VRAM_Buffer1+1, x
    lda #4
    sta VRAM_Buffer1+2, x
    tya
    rol a
    rol a
    tay
    lda MenuTitles,y
    sta VRAM_Buffer1+3, x
    lda MenuTitles+1,y
    sta VRAM_Buffer1+4, x
    lda MenuTitles+2,y
    sta VRAM_Buffer1+5, x
    lda MenuTitles+3,y
    sta VRAM_Buffer1+6, x
    lda #0
    sta VRAM_Buffer1+7, x
    rts


MenuReset:
    jsr DrawMenu
    rts

; ===========================================================================
;  Redraw menu
; ---------------------------------------------------------------------------
DrawMenu:
    ldy #(SettablesCount-1)
    sty $10
@KeepDrawing:
    jsr DrawMenuTitle
    ldy $10
    jsr DrawMenuValueJE
    ldy $10
    dey
    sty $10
    bpl @KeepDrawing
    rts
	
; ===========================================================================

; ===========================================================================
;  Menu main loop
; ---------------------------------------------------------------------------
MenuNMI:
    jsr DrawSelectionMarkers
    lda PressedButtons
    clc
    cmp #0
    bne @READINPUT
    rts
@READINPUT:
    and #%00001111
    beq @SELECT
    ldy MenuSelectedItem
    jsr UpdateMenuValueJE
    jmp RenderMenu
@SELECT:
    lda PressedButtons
    cmp #%00100000
    bne @START
    ldx #0
    stx MenuSelectedSubitem
    inc MenuSelectedItem
    lda MenuSelectedItem
    cmp #SettablesCount
    bne @SELECT2
    stx MenuSelectedItem
@SELECT2:
    jmp RenderMenu
@START:
    cmp #%00010000
    bne @DONE
    ldx HeldButtons
    cpx #%10000000
    lda #0
    bcc @START2
    lda #1
@START2:
    sta PrimaryHardMode
    jmp TStartGame
@DONE:
    rts
RenderMenu:
    ldy MenuSelectedItem
    jsr DrawMenu
    rts
; ===========================================================================


; ===========================================================================
;  Position the "cursors" of the menu at the correct location
; ---------------------------------------------------------------------------
DrawSelectionMarkers:
    lda #$00                                 ; set palette attributes for sprites
    sta Sprite_Attributes + (1 * SpriteLen)  ;
    lda #$21                                 ;
    sta Sprite_Attributes + (2 * SpriteLen)  ;
    lda #$5B                                 ; mushroom elevator for sprite 1
    sta Sprite_Tilenumber + (1 * SpriteLen)  ;
    lda #$27                                 ; set solid background for sprite 2
    sta Sprite_Tilenumber + (2 * SpriteLen)  ;
    lda #$1E                                 ; get initial Y position
    ldy MenuSelectedItem                     ; get current menu item
:   clc                                      ;
    adc #$10                                 ; add 16px per menu item
    dey                                      ; decrement loop value
    bpl :-                                   ; and loop until done
    sta Sprite_Y_Position + (1 * SpriteLen)  ; reposition sprite 1 (floating coin)
    sta Sprite_Y_Position + (2 * SpriteLen)  ; reposition sprite 2 (background color)
    lda #$A9                                 ; get initial X position
    sta Sprite_X_Position + (1 * SpriteLen)  ; reposition sprite 1 (floating coin)
    sbc #$8                                  ; offset by 8px for the background color
    ldy MenuSelectedSubitem                  ; get which subitem is selected
:   sec                                      ; then offset by another 8px per subitem
    sbc #$8                                  ;
    dey                                      ; decrement loop value
    bpl :-                                   ; and loop until done
    sta Sprite_X_Position + (2 * SpriteLen)  ; reposition sprite 2 (background color)
    rts                                      ; done
; ===========================================================================

UpdateValueITC:
    ldx #$FF
    lda HeldButtons
    and #%10000000
    bne @Skip
    ldx #3
    @Skip:
    stx $0
    jmp UpdateValueShared

; update selected powerup value
UpdateValuePUps:
    ldx #3                 ; there are 3 total states
    jmp UpdateValueShared  ; update selected menu item

; update toggleable option
UpdateValueToggle:
    ldx #2                 ; toggle between two options
    jmp UpdateValueShared  ; update selected menu item
	
; ===========================================================================
; Update a single byte menu item
; ---------------------------------------------------------------------------
; Input:  Y   = menu item index
;         X   = maximum allowed value
; ---------------------------------------------------------------------------
UpdateValueShared:
    @Max = $0
    stx @Max                          ; temp store max value
    clc                               ;
    lda PressedButtons                ; get current inputs
    and #Down_Dir|Left_Dir            ; check if we're pressing decrementing direction
    bne @Decrement                    ; yes - skip ahead to decrement
@Increment:                           ; no - we are incrementing
    lda Settables,y                   ; get current value of the menu item
    adc #1                            ; increment it
    cmp @Max                          ; check if we're beyond the maximum value
    bcc @Store                        ; no - skip ahead to store
    lda #0                            ; yes - set to 0
    beq @Store                        ; and store
@Decrement:                           ;
    lda Settables,y                   ; get current value of the menu item
    beq @Wrap                         ; if it's 0, wrap around
    sec                               ;
    sbc #1                            ; otherwise, decrement it
    bvc @Store                        ; skip ahead to store
@Wrap:                                ;
    lda @Max                          ; wrap around to the maximum value + 1
    sec                               ; and decrement it by 1
    sbc #1                            ;
@Store:                               ;
    sta Settables,y                   ; store the new value
    rts                               ;
; ===========================================================================

DrawValueNormal:
    clc
    lda VRAM_Buffer1_Offset
    tax
    adc #4
    sta VRAM_Buffer1_Offset
    lda MenuValueLocationsHi, y
    sta VRAM_Buffer1+0, x
    lda MenuValueLocationsLo, y
    sta VRAM_Buffer1+1, x
    lda #1
    sta VRAM_Buffer1+2, x
    lda Settables, y
    adc #1
    sta VRAM_Buffer1+3, x
    lda #0
    sta VRAM_Buffer1+4, x
    rts

DrawValueString_PUp:
    lda Settables,y
    asl a
    tax
    lda PUpStrings,x
    sta MenuTextPtr
    lda PUpStrings+1,x
    sta MenuTextPtr+1
    lda #5
    sta MenuTextLen
    jmp DrawValueString

; ===========================================================================
; Draws player name to the screen
; ---------------------------------------------------------------------------
DrawValueString_Hero:
    lda Settables,y                   ; get the selected player
    asl a                             ; get offset into pointer table
    tax                               ;
    lda @Strings,x                    ; copy string pointer to menu text pointer
    sta MenuTextPtr                   ;
    lda @Strings+1,x                  ;
    sta MenuTextPtr+1                 ;
    lda #5                            ; set fixed string length
    sta MenuTextLen                   ;
    jmp DrawValueString               ; and draw the string

@Strings:
.word @Str0
.word @Str1

@Str0: .byte "MARIO"
@Str1: .byte "LUIGI"
; ===========================================================================	

; ===========================================================================
; Draws player name to the screen
; ---------------------------------------------------------------------------
DrawValueString_Level:
    lda Settables,y                   ; get the selected player
    asl a                             ; get offset into pointer table
    tax                               ;
    lda @Strings,x                    ; copy string pointer to menu text pointer
    sta MenuTextPtr                   ;
    lda @Strings+1,x                  ;
    sta MenuTextPtr+1                 ;
    lda #3                            ; set fixed string length
    sta MenuTextLen                   ;
    jmp DrawValueString               ; and draw the string

@Strings:
.word @Str0
.word @Str1

@Str0: .byte "8-4"
@Str1: .byte "D-4"
; ===========================================================================	

MenuTextPtr = $C3
MenuTextLen = $C2
DrawValueString:
    clc
    lda VRAM_Buffer1_Offset
    tax
    adc MenuTextLen
    adc #3
    sta VRAM_Buffer1_Offset
    lda MenuValueLocationsHi, y
    sta VRAM_Buffer1+0, x
    lda MenuValueLocationsLo, y
    sta VRAM_Buffer1+1, x
    lda MenuTextLen
    sta VRAM_Buffer1+2, x
    ldy #0
@CopyNext:
    lda (MenuTextPtr),y
    sta VRAM_Buffer1+3, x
    inx
    iny
    cpy MenuTextLen
    bcc @CopyNext
    lda #0
    sta VRAM_Buffer1+4, x
    rts

UpdateValueFramerule:
    clc
    ldx MenuSelectedSubitem
    lda PressedButtons
    and #%00000011
    beq @update_value

    lda PressedButtons
    cmp #%00000001 ; right
    bne @check_left
    dex
@check_left:
    cmp #%00000010 ; left
    bne @store_selected
    inx
@store_selected:
    txa
    bpl @not_under
    lda #4
@not_under:
    cmp #5
    bcc @not_over
    lda #0
@not_over:
    sta MenuSelectedSubitem
    rts
@update_value:
    lda MathFrameruleDigitStart, x
    tay
    lda PressedButtons
    cmp #%00001000
    beq @increase
    dey
    bpl @store_value
    ldy #$E
@increase:
    iny
    cpy #$10
    bne @store_value
    ldy #0
@store_value:
    tya
    sta MathFrameruleDigitStart, x
    rts

DrawValueFramerule:
    clc
    lda VRAM_Buffer1_Offset
    tax
    adc #8
    sta VRAM_Buffer1_Offset
    lda MenuValueLocationsHi, y
    sta VRAM_Buffer1+0, x
    lda MenuValueLocationsLo, y
    sta VRAM_Buffer1+1, x
    lda #5
    sta VRAM_Buffer1+2, x
    lda MathFrameruleDigitStart+0
    sta VRAM_Buffer1+3+4, x
    lda MathFrameruleDigitStart+1
    sta VRAM_Buffer1+3+3, x
    lda MathFrameruleDigitStart+2
    sta VRAM_Buffer1+3+2, x
    lda MathFrameruleDigitStart+3
    sta VRAM_Buffer1+3+1, x
    lda MathFrameruleDigitStart+4
    sta VRAM_Buffer1+3+0, x
    lda #0
    sta VRAM_Buffer1+3+5, x
    rts

MenuValueLocationsLo: .lobytes MenuValueLocations
MenuValueLocationsHi: .hibytes MenuValueLocations

MenuTitleLocationsLo: .lobytes MenuTitleLocations
MenuTitleLocationsHi: .hibytes MenuTitleLocations

PUpStrings:
.word PUpStrings_Non
.word PUpStrings_Fir
.word PUpStrings_SFir
PUpStrings_Non:
.byte "NONE "
PUpStrings_Fir:
.byte "FIRE "
PUpStrings_SFir:
.byte "FIRE!"

.pushseg
.segment "MENUWRAM"
MenuSelectedItem: .byte $00
MenuSelectedSubitem: .byte $00
RNGExtraCycle: .byte $00
MathDigits:
MathFrameruleDigitStart:
  .byte $00, $00, $00, $00, $00 ; selected framerule
MathFrameruleDigitEnd:
MathInGameFrameruleDigitStart:
  .byte $00, $00, $00, $00, $00 ; ingame framerule
MathInGameFrameruleDigitEnd:
.popseg
