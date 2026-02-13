; ===========================================================================
;  Start the game!
; ---------------------------------------------------------------------------
TStartGame:
    @RNGDigits = (MathInGameRNGIterationCountEnd-MathInGameRNGIterationCountStart-1)
    jsr InitBankSwitchingCode                    ; copy utility code to WRAM
    ldx #@RNGDigits                              ; reset rng iteraton count digits
    lda #0                                       ;
:   sta MathInGameRNGIterationCountStart, x      ;
    dex                                          ;
    bpl :-                                       ;
    lda RNGDigitStart+1                          ; copy each rng digit from the menu
    sta InGameRNGDigitStart+1                    ;
    lda RNGDigitStart                            ;
    sta InGameRNGDigitStart                      ;
    clc                                          ;
    lda #2                                       ; set starting opermode to "gamemode"
    sta OperMode                                 ;
    lsr a                                        ; set flag indicating we are entering from the menu
    sta EnteringFromMenu                         ;
    sta IsPlaying                                ; mark that we are in game mode
    lsr a                                        ; clear A
    sta OperMode_Task                            ; clear opermode task value
    sta GameEngineSubroutine                     ; clear game engine task
    sta TimerControl                             ; mark the game as running
    sta PendingScoreDrawPosition                 ; clear pending status bar draw flag
    sta PPU_CTRL_REG1                            ; diable rendering
    sta Mirror_PPU_CTRL_REG1                     ;
    sta PPU_CTRL_REG2                            ;
    sta $4015                                    ; silence music
    sta EventMusicQueue                          ; stop music queue
    ldx SettablesWorld                           ; copy menu world number
    stx WorldNumber                              ;
    ldx SettablesLevel                           ; copy menu level number
    stx LevelNumber                              ;
    ldx SettablesPUP                             ; get menu powerup state
    lda @StatusSizes,x                           ; get player size based on menu state
    sta PlayerSize                               ; and update player size
    lda @StatusPowers,x                          ; get player power state based on menu state
    sta PlayerStatus                             ; and update player status
    lda SettablesTimer                           ; update timer setting
    eor #%1                                      ;
    sta $6603                                    ;
    lda #$2                                      ; give player 3 lives
    sta NumberofLives                            ;
    inc FetchNewGameTimerFlag                    ; tell the game to reload the game timer
    jmp BANK_AdvanceToLevel                      ; transition to the wram code to start the game
@StatusSizes:
.byte $1, $0, $0, $0, $1, $1
@StatusPowers:
.byte $0, $1, $2, $0, $1, $2
; ===========================================================================

; ===========================================================================
;  Practise routine per frame routine
; ---------------------------------------------------------------------------
PractiseNMI:
    lda EnteringFromMenu                         ; are we currently entering from the menu?
    beq @ClearPractisePrintScore                 ; no - then we can run our routine
    rts                                          ; otherwise, we're loading, so just return
@ClearPractisePrintScore:                        ;
    lda VRAM_Buffer1_Offset                      ; check if we have pending ppu draws
    bne @IncrementIterationCounter               ; yes - skip ahead
    sta PendingScoreDrawPosition                 ; no - clear pending vram address for drawing
@IncrementIterationCounter:                      ;
    jsr IncrementIterationCounter                ; increment the base10 RNG iteration counter
    jsr CheckForLevelEnd                         ; run level transition handler
    jsr CheckJumpingState                        ; run jump handler
    jsr CheckAreaTimer                           ; run area transition timing handler
@CheckUpdateStatusbarValues:                     ;
    lda FrameCounter                             ; get current frame counter
    and #3                                       ; and just make sure we're in a specific 4 frame spot
    cmp #2                                       ;
    bne @CheckInput                              ; if not, skip ahead
    jsr RedrawHighFreqStatusbar                  ; otherwise update status bar
@CheckInput:                                     ;
    lda JoypadBitMask                            ; get current joypad state
    and #(Select_Button | Start_Button)          ; mask out all but select and start
    beq @Done                                    ; neither are held - nothing more to do here
    jsr ReadJoypads                              ; re-read joypad state, to avoid filtering from the game
@CheckForRestartLevel:                           ;
    cmp #(Up_Dir | Select_Button)                ; check if select + up are held
    bne @CheckForReset                           ; no - skip ahead
    lda #0                                       ; yes - we are restarting the level
    sta PPU_CTRL_REG1                            ; disable screen rendering
    sta PPU_CTRL_REG2                            ;
    jsr InitializeMemory                         ; clear memory
    dex                                          ; decrement X to $FF (was $00 from InitializeMemory)
    txs                                          ; reset stack pointer
    jmp TStartGame                               ; and start the game
@CheckForReset:                                  ;
    cmp #(Down_Dir | Select_Button)              ; check if select + down are held
    bne @Done                                    ; no - skip ahead
    lda #0                                       ; yes - we are returning to the title screen
    sta PPU_CTRL_REG1                            ; disable screen rendering
    sta PPU_CTRL_REG2                            ;
    jmp HotReset                                 ; and reset the game
@Done:                                           ;
    rts                                          ;
; ===========================================================================

; ===========================================================================
;  Handle new area loading loading
; ---------------------------------------------------------------------------
PractiseEnterStage:
    @RNGDigitCount = MathInGameRNGIterationCountEnd - MathInGameRNGIterationCountStart - 1
    lda #3                                       ; set life counter so we can't lose the game
    sta NumberofLives                            ;
    lda #$14                                     ; reset first byte of LFSR like normal
    sta PseudoRandomBitReg                       ;
    ldx #@RNGDigitCount                          ; save rng iteration count to copy for display
:   lda MathInGameRNGIterationCountStart,x       ; and reset rng iteration count since rng was reseeded
    sta MathRNGIterationCountStart,x             ;
    lda #0                                       ;
    sta MathInGameRNGIterationCountStart,x       ;
    dex                                          ;
    bpl :-                                       ;
    lda EnteringFromMenu                         ; check if we're entering from the menu
    beq @SaveToMenu                              ; no, the player beat a level, update the menu state
    jsr RNGQuickResume                           ; yes, the player is starting a new game, load the rng state
    dec EnteringFromMenu                         ; then mark that we've entered from the menu, so this doesn't happen again
    beq @Shared                                  ; and skip ahead to avoid saving the state for no reason
@SaveToMenu:                                     ;
    jsr UpdateRNGValue                           ; copy the rng to stored digits
    lda LevelEnding                              ; check if we are transitioning to a new level
    beq @Shared                                  ; no - skip ahead and enter the game
    lda InGameRNGDigitStart+1                    ; yes - copy the rng to the menu
    sta RNGDigitStart+1                          ;
    lda InGameRNGDigitStart                      ;
    sta RNGDigitStart                            ;
    lda WorldNumber                              ; copy current world and level to the menu
    sta SettablesWorld                           ;
    lda LevelNumber                              ;
    sta SettablesLevel                           ;
    lda PlayerSize                               ; get player powerup state
    asl a                                        ; shift up a couple of bits to make room for powerup state
    asl a                                        ;
    ora PlayerStatus                             ; combine with powerup state
    tax                                          ; copy to X
    lda @PUpStates,x                             ; and get the menu selection values from the players current state
    sta SettablesPUP                             ; and write to menu powerup state
@Shared:                                         ;
    lda #0                                       ; clear out some starting state
    sta CachedChangeAreaTimer                    ;
    sta LevelEnding                              ;
    sta $00                                      ; needed for GetAreaDataAddrs
    jmp RedrawLowFreqStatusbar                   ; and update the status line
@PUpStates:
.byte $3                                         ; size = 0, status = 0. big vuln. mario
.byte $1                                         ; size = 0, status = 1. big super mario
.byte $2                                         ; size = 0, status = 2. big fire mario
.byte $0                                         ; pad
.byte $0                                         ; size = 1, status = 0. small vuln. mario
.byte $5                                         ; size = 1, status = 1. small super mario
.byte $6                                         ; size = 1, status = 2. small fire mario
; ===========================================================================

; ===========================================================================
;  Handle level transitions
; ---------------------------------------------------------------------------
CheckForLevelEnd:
    lda LevelEnding                              ; have we already detected the level end?
    bne @Done                                    ; if so - exit
    lda WorldEndTimer                            ; check the end of world timer
    bne @ChangeTopStatusTimeToRemains            ; if set, branch ahead
    lda StarFlagTaskControl                      ; check the current starflag state
    cmp #4                                       ; are we in the final starflag task?
    bne @Done                                    ; no - exit
@ChangeTopStatusTimeToRemains:
    jsr ChangeTopStatusTimeToRemains             ; change the 'TIME' in the title to remains
    jsr RedrawLowFreqStatusbar                   ; and redraw the status bar
@LevelEnding:
    inc LevelEnding                              ; yes - mark the level end as ended
@Done:                                           ;
    rts                                          ;
; ===========================================================================

; ===========================================================================
;  Handle area transitions (pipes, etc)
; ---------------------------------------------------------------------------
CheckAreaTimer:
    lda CachedChangeAreaTimer                    ; have we already handled the area change?
    bne @Done                                    ; yes - exit
    lda ChangeAreaTimer                          ; no - check if we should handle it
    beq @Done                                    ; no - exit
    sta CachedChangeAreaTimer                    ; yes - cache the timer value
    jsr ChangeTopStatusTimeToRemains             ; change the 'TIME' in the title to remains
    jsr RedrawLowFreqStatusbar                   ; and redraw the status bar
@Done:                                           ;
    rts                                          ;
; ===========================================================================

; ===========================================================================
;  Handle player jumping
; ---------------------------------------------------------------------------
CheckJumpingState:
    lda JumpSwimTimer                            ; check jump timer
    cmp #$20                                     ; is it the max value (player just jumped)
    bne @Done                                    ; no - exit
    jsr RedrawLowFreqStatusbar                   ; yes - redraw the status bar
@Done:                                           ;
    rts                                          ; done!
; ===========================================================================

; ===========================================================================
;  Update rng value digits
; ---------------------------------------------------------------------------
UpdateRNGValue:
    @RNGTemp = $0
    lda PseudoRandomBitReg+1                     ; load second byte of LFSR
    sta @RNGTemp                                 ;
    lsr a                                        ; move high nybble to low
    lsr a                                        ;
    lsr a                                        ;
    lsr a                                        ;
    sta InGameRNGDigitStart+1                    ; and store high digit
    lda @RNGTemp                                 ; mask out low nybble
    and #%1111                                   ;
    sta InGameRNGDigitStart                      ; and store low digit
    rts                                          ;
; ===========================================================================

; ===========================================================================
;  Advance to the next base 10 RNG iteration count
; ---------------------------------------------------------------------------
IncrementIterationCounter:
    @DigitOffset = (MathInGameRNGIterationCountStart-MathDigits)
    clc                                          ;
    lda #1                                       ; we want to add 1 to the digits
    ldx #@DigitOffset                            ; get the offset to the digit we are incrementing
    jmp B10Add                                   ; and run base 10 addition
; ===========================================================================

; ===========================================================================
;  Handle when the game wants to redraw the MARIO / TIME text at the top
; ---------------------------------------------------------------------------
PractiseWriteTopStatusLine:
    clc                                          ;
    ldy VRAM_Buffer1_Offset                      ; get current vram offset
    lda #(@TopStatusTextEnd-@TopStatusText+1)    ; get text length
    adc VRAM_Buffer1_Offset                      ; add to vram offset
    sta VRAM_Buffer1_Offset                      ; and store new offset
    ldx #0                                       ;
@CopyData:                                       ;
    lda @TopStatusText,x                         ; copy bytes of the status bar text to vram
    sta VRAM_Buffer1,y                           ;
    iny                                          ; advance vram offset
    inx                                          ; advance text offset
    cpx #(@TopStatusTextEnd-@TopStatusText)      ; check if we're at the end
    bne @CopyData                                ; if not, loop
    lda #0                                       ; then set null terminator at the end
    sta VRAM_Buffer1,y                           ;
    inc ScreenRoutineTask                        ; and advance the screen routine task
    rts                                          ; done
@TopStatusText:                                  ;
  .byte $20, $43,  3, "RNG"                      ;
  .byte $20, $4a,  19, "SOCKS TO FRAME TIME"     ;
  .byte $20, $73,   2, $2e, $29                  ; coin that shows next to the coin counter
  .byte $23, $c0, $7f, $aa                       ; tile attributes for the top row, sets palette
  .byte $23, $c4, $01, %11100000                 ; set palette for the flashing coin
@TopStatusTextEnd:
   .byte $00
; ===========================================================================

; ===========================================================================
;  Handle the game requesting redrawing the bottom status bar
; ---------------------------------------------------------------------------
PractiseWriteBottomStatusLine:
    jsr RedrawLowFreqStatusbar                   ; redraw the status bar
    jsr PrintRNGSeed                             ; display the current rng seed
    inc ScreenRoutineTask                        ; and advance to the next smb screen routine
    rts                                          ;
; ===========================================================================

; ===========================================================================
;  Place the remains instead of "TIME" during level transitions
; ---------------------------------------------------------------------------
ChangeTopStatusTimeToRemains:
    clc                                          ;
    lda VRAM_Buffer1_Offset                      ; get current vram offset
    tay                                          ;
    adc #7                                       ; and advance it by 7
    sta VRAM_Buffer1_Offset                      ; store the new offset
    lda #$20                                     ; write the ppu address to update
    sta VRAM_Buffer1+0, y                        ;
    lda #$59                                     ;
    sta VRAM_Buffer1+1, y                        ;
    lda #4                                       ; we are writing four bytes
    sta VRAM_Buffer1+2, y                        ;
    lda #'R'                                     ; "R" to indicate remains
    sta VRAM_Buffer1+3, y                        ;
    lda #'x'                                     ; "x" between "R" and remains
    sta VRAM_Buffer1+4, y                        ;
    lda IntervalTimerControl                     ; remains value in base10
    jsr B10DivBy10                               ;
    sta VRAM_Buffer1+6, y                        ;
    txa                                          ;
    sta VRAM_Buffer1+5, y                        ;
    lda #0                                       ; set the null terminator
    sta VRAM_Buffer1+7, y                        ;
    rts                                          ; and finish
; ===========================================================================

; ===========================================================================
;  Place the rng seed in the title screen during level transitions
; ---------------------------------------------------------------------------
PrintRNGSeed:
    clc                                          ;
    lda VRAM_Buffer1_Offset                      ; get current vram offset
    tay                                          ;
    adc #5                                       ; and advance it by 5
    sta VRAM_Buffer1_Offset                      ; store the new offset
    lda #$20                                     ; write the ppu address to update
    sta VRAM_Buffer1+0, y                        ;
    lda #$47                                     ;
    sta VRAM_Buffer1+1, y                        ;
    lda #2                                       ; we are writing two bytes
    sta VRAM_Buffer1+2, y                        ;
    lda InGameRNGDigitStart+1                    ; high nybble of RNG
    sta VRAM_Buffer1+3, y                        ;
    lda InGameRNGDigitStart                      ; then low nybble of RNG
    sta VRAM_Buffer1+4, y                        ;
    lda #0                                       ; set the null terminator
    sta VRAM_Buffer1+7, y                        ;
    rts                                          ; and finish
; ===========================================================================

; ===========================================================================
;  Redraw the status bar portion that updates less often
; ---------------------------------------------------------------------------
RedrawLowFreqStatusbar:
    clc                                          ;
    ldy PendingScoreDrawPosition                 ; check if we have a pending draw that hasn't been sent to the ppu
    bne @RefreshBufferX                          ; yes - skip ahead and refresh the buffer to avoid overloading the ppu
    ldy VRAM_Buffer1_Offset                      ; no - get the current buffer offset
    iny                                          ; increment past the ppu location
    iny                                          ;
    iny                                          ;
    sty PendingScoreDrawPosition                 ; and store it as our pending position
    jsr @PrintIterationCount                     ; draw the current rng iteration count
    jsr @PrintFramecounter                       ; draw the current framecounter value
    ldx ObjectOffset                             ; load object offset, our caller might expect it to be unchanged
    rts                                          ; and exit
@RefreshBufferX:                                 ;
    jsr @PrintIterationDataAtY                   ; refresh pending rng iteration count
    tya                                          ; get the buffer offset we're drawing to
    adc #7                                       ; and shift over to the framecounter position
    tay                                          ;
    jsr @PrintFramecounterDataAtY                ; and then refresh the pending frame ounter value
    ldx ObjectOffset                             ; load object offset, our caller might expect it to be unchanged
    rts                                          ; and exit
; ---------------------------------------------------------------------------
;  Copy current rng iteration count to VRAM
; ---------------------------------------------------------------------------
@PrintIterationCount:
    lda VRAM_Buffer1_Offset                      ; get the current buffer offset
    tay                                          ;
    adc #(3+4)                                   ; shift over based on length of the iteration text
    sta VRAM_Buffer1_Offset                      ; store the ppu location of the iteration count
    lda #$20                                     ;
    sta VRAM_Buffer1,y                           ;
    lda #$65                                     ;
    sta VRAM_Buffer1+1,y                         ;
    lda #$04                                     ; store the number of digits to draw
    sta VRAM_Buffer1+2,y                         ;
    iny                                          ; increment past the ppu location
    iny                                          ;
    iny                                          ;
    lda #0                                       ; place our null terminator
    sta VRAM_Buffer1+4,y                         ;
@PrintIterationDataAtY:
    lda MathRNGIterationCountStart+3             ; then copy the iteration numbers into the buffer
    sta VRAM_Buffer1+0,y                         ;
    lda MathRNGIterationCountStart+2             ;
    sta VRAM_Buffer1+1,y                         ;
    lda MathRNGIterationCountStart+1             ;
    sta VRAM_Buffer1+2,y                         ;
    lda MathRNGIterationCountStart+0             ;
    sta VRAM_Buffer1+3,y                         ;
    rts                                          ;
; ---------------------------------------------------------------------------
;  Copy current frame number to VRAM
; ---------------------------------------------------------------------------
@PrintFramecounter:
    lda VRAM_Buffer1_Offset                      ; get current vram offset
    tay                                          ;
    adc #(3+3)                                   ; add 3 for vram offset, 3 for values to draw
    sta VRAM_Buffer1_Offset                      ; save new vram offset
    lda #$20                                     ; store the ppu location of the frame number
    sta VRAM_Buffer1,y                           ;
    lda #$75                                     ;
    sta VRAM_Buffer1+1,y                         ;
    lda #$03                                     ; store the number of digits to draw
    sta VRAM_Buffer1+2,y                         ;
    iny                                          ; advance y to the end of the buffer to write
    iny                                          ;
    iny                                          ;
    lda #0                                       ; place our null terminator
    sta VRAM_Buffer1+3,y                         ;
@PrintFramecounterDataAtY:                       ;
    lda FrameCounter                             ; get the current frame number
    jsr B10DivBy10                               ; divide by 10
    sta VRAM_Buffer1+2,y                         ; store remainder in vram buffer
    txa                                          ; get the result of the divide
    jsr B10DivBy10                               ; divide by 10
    sta VRAM_Buffer1+1,y                         ; store remainder in vram buffer
    txa                                          ; get the result of the divide
    sta VRAM_Buffer1+0,y                         ; and store it in vram
    rts                                          ;
; ===========================================================================

; ===========================================================================
;  Update and draw status bar values
; ---------------------------------------------------------------------------
RedrawHighFreqStatusbar:
    @SockSubX = $2                               ; memory locations that sockfolder is stored in
    @SockX    = $3                               ;
    lda VRAM_Buffer1_Offset                      ; check if there are pending ppu updates
    beq :+                                       ; no - skip ahead to update status bar
    rts                                          ; yes - don't overload the ppu
:   jsr RecalculateSockfolder                    ; calculate new sockfolder value

    ldx #0                                       ; clear X
    lda #$20                                     ; write ppu location of status bar to vram buffer
    sta VRAM_Buffer1+0,x                         ;
    lda #$6A                                     ;
    sta VRAM_Buffer1+1,x                         ;
    lda #8                                       ; write number of bytes to draw
    sta VRAM_Buffer1+2,x                         ;
    lda #(8+3)                                   ; and update vram buffer offset to new location
    sta VRAM_Buffer1_Offset                      ;
    lda #$24                                     ; write spaces to a couple of locations
    sta VRAM_Buffer1+3+2,x                       ;
    sta VRAM_Buffer1+3+5,x                       ;
    lda #0                                       ; write null terminator
    sta VRAM_Buffer1+3+8,x                       ;

    lda @SockX                                   ; get sockfolder x position
    and #$0F                                     ; mask off the high nibble
    sta VRAM_Buffer1+3+0,x                       ; and write that byte to the vram buffer
    lda @SockSubX                                ; get sockfolder subpixel x position
    lsr                                          ; and shift down to the low nibble
    lsr                                          ;
    lsr                                          ;
    lsr                                          ;
    sta VRAM_Buffer1+3+1,x                       ; and write that byte to the vram buffer
    lda Player_X_MoveForce                       ; get the current player subpixel
    tay                                          ; copy to Y
    and #$0F                                     ; mask off the high nibble
    sta VRAM_Buffer1+3+4,x ; Y                   ; and write that byte to the vram buffer
    tya                                          ; restore full value from Y
    lsr                                          ; and shift down to the low nibble
    lsr                                          ;
    lsr                                          ;
    lsr                                          ;
    sta VRAM_Buffer1+3+3,x ; Y                   ; and write that byte to the vram buffer
    lda AreaPointer                              ; get the pointer to where warp pipes direct player
    tay                                          ; copy to Y
    and #$0F                                     ; mask off the high nibble
    sta VRAM_Buffer1+3+7,x ; X                   ; and write that byte to the vram buffer
    tya                                          ; restore full value from Y
    lsr                                          ; and shift down to the low nibble
    lsr                                          ;
    lsr                                          ;
    lsr                                          ;
    sta VRAM_Buffer1+3+6,x ; X                   ; and write that byte to the vram buffer
@skip:                                           ;
    rts                                          ;
; ===========================================================================


; ===========================================================================
;  Calculate the current sockfolder value
; ---------------------------------------------------------------------------
; Sockfolder is effectively calculated by the following formula:
;  Player_X_Position + ((0xFF - Player_Y_Position) / MaximumYSpeed) * MaximumXSpeed
;
; So that will give you the position that mario would be when he reaches the
; bottom of the screen assuming the player is falling at full speed.
;
; Here's a little javascript snippet that creates a 16 bit lookup table of sockfolder values:
;
;; // NTSC:
;; let max_x_speed = 0x0280; // maximum x speed in subpixels
;; let max_y_speed = 0x04;   // maximum y speed in pixels
;; // PAL:
;; //let max_x_speed = 0x0300; // maximum x speed in subpixels
;; //let max_y_speed = 0x05;   // maximum y speed in pixels
;;
;; let values = [];
;; for (let i=0xFF; i>=0x00; --i) {
;;     let value = Math.floor(i/max_y_speed)*max_x_speed;
;;     let format = Math.round(value).toString(16).padStart(4,'0');
;;     values.push('$' + format);
;; };
;;
;; let items_per_row = 0x8;
;; for (let i=0; i<(values.length/items_per_row); ++i) {
;;     let start = i * items_per_row;
;;     let end = (i * items_per_row) + items_per_row;
;;     let line = values.slice(start, end).join(',')
;;     console.log('.byte ' + line + ' ; range ' +  start.toString(16) + ' to ' + (end-1).toString(16));
;; }
;
; ---------------------------------------------------------------------------
RecalculateSockfolder:
    @DataTemp = $4                               ; temp value used for some maths
    @DataSubX = $2                               ; sockfolder subpixel x value
    @DataX    = $3                               ; sockfolder pixel x value
    lda SprObject_X_MoveForce                    ; get subpixel x position
    sta @DataSubX                                ; and store it in our temp data
    lda Player_X_Position                        ; get x position
    sta @DataX                                   ; and store it in our temp data
    lda Player_Y_Position                        ; get y position
    eor #$FF                                     ; invert the bits, now $FF is the top of the screen
    lsr a                                        ; divide pixel position by 8
    lsr a                                        ;
    lsr a                                        ;
    bcc @sock1                                   ; if we're on the top half of tile 'tile', we will land 2.5 pixels later.
    pha                                          ; so store the current value
    clc                                          ;
    lda @DataSubX                                ; get subpixel x position
    adc #$80                                     ; and increase it by half
    sta @DataSubX                                ; and store it back
    lda @DataX                                   ; get x position
    adc #$02                                     ; and add 2 + carry value
    sta @DataX                                   ; and store it back
    pla                                          ; then restore our original value
@sock1:                                          ;
    sta @DataTemp                                ; store this in our temp value
    asl a                                        ; multiply by 4
    asl a                                        ;
    adc @DataTemp                                ; and add the temp value
    adc @DataX                                   ; then add our x position
    sta @DataX                                   ; and store it back
    rts                                          ;
; ===========================================================================
