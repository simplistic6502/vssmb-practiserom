; ================================================================
;  Setup RNG
; ----------------------------------------------------------------
RNGQuickResume:
    lda MathRNGDigitStart+1              ; move high digit to high nybble
    asl a                                ;
    asl a                                ;
    asl a                                ;
    asl a                                ;
    ora MathRNGDigitStart+0              ; move low digit to low nybble
    sta PseudoRandomBitReg+1             ; and write to second byte of LFSR
    rts                                  ;
; ================================================================
