; build me twice with atasm
;
; atasm -r -DHACKADAY_1K=1 -DHACKADAY_2K5=0 copter.s -othin.bin
; atasm -r -DHACKADAY_1K=0 -DHACKADAY_2K5=1 copter.s -ofat.bin

; ------------------------------------------------------------------
; config
;
; CHEAP_SEA       = 1                   ; solid blue sea
; BLOCK_GFX       = 1                   ; no external graphics
; EMBED_FONT      = 1                   ; embed font in code
; EXTRA_HACKS     = 1                   ; various space-saving hacks
; EXPORT_DIGIT    = 1                   ; export digit drawing function
; RTS_ON_DIE      = 1                   ; return to caller on death
; ------------------------------------------------------------------

.if HACKADAY_1K
CHEAP_SEA       = 1
BLOCK_GFX       = 1
EMBED_FONT      = 1
EXTRA_HACKS     = 1
EXPORT_DIGIT    = 0
RTS_ON_DIE      = 0
.else
.if HACKADAY_2K5
CHEAP_SEA       = 0
BLOCK_GFX       = 0
EMBED_FONT      = 0
EXTRA_HACKS     = 0
EXPORT_DIGIT    = 0
RTS_ON_DIE      = 0
.else
CHEAP_SEA       = 0
BLOCK_GFX       = 0
EMBED_FONT      = 0
EXTRA_HACKS     = 0
EXPORT_DIGIT    = 1
RTS_ON_DIE      = 1
.endif
.endif

; ------------------------------------------------------------------
; sprite numbers
; ------------------------------------------------------------------

.if BLOCK_GFX
SPR_BIRD        = 0
SPR_COPTER      = 5
SPR_PLATFORM    = 10
SPR_COIN        = 14
SPR_CYAN        = 18
.else
SPR_COPTER      = 12
SPR_COIN        = 24
SPR_PLATFORM    = 28
SPR_SEA         = 34
SPR_CYAN        = 40
SPR_END         = 42
.endif

.if EMBED_FONT
DIGITS          = font
.else
DIGITS          = $1300+SPR_END*32
.endif

; ------------------------------------------------------------------
; plot operations, encoded as branch deltas from plot_end to kernel
; ------------------------------------------------------------------

OP_PAD          = pad-plot_end
OP_STORE        = store-plot_end
OP_BLEND        = blend-plot_end

; ------------------------------------------------------------------
; key scan codes
; ------------------------------------------------------------------

KEY_Z           = $61
KEY_X           = $42
KEY_SPACE       = $62
KEY_SHIFT       = $00

; ------------------------------------------------------------------
; zero page memory map
; ------------------------------------------------------------------

copter_fuel     = $50
copter_alive    = $51

bird_y          = $53
bird_x          = $58
bird_w          = $5d

platform_dx     = $62

.if BLOCK_GFX
digit_addr      = $63

lfsr            = $65
.else
copter_dx       = $63

digit_addr      = $64

.if EXPORT_DIGIT
digit_data      = $66
.endif

lfsr            = $66
.endif

work            = $68
work0           = work+0
work1           = work+1
work2           = work+2
work3           = work+3
work4           = work+4
work5           = work+5
work6           = work+6
work7           = work+7
work8           = work+8
work9           = work+9

collide         = $77
master_frame    = $78

.if .not BLOCK_GFX
sprite_frame    = $79
.endif

.if .not CHEAP_SEA
sea_frame       = $7a
.endif

score           = $7b
spacer          = $7e
bonus           = $7f

platform_bss    = $82
platform_x      = platform_bss

coin_bss        = $83
coin_x          = coin_bss+0
coin_y          = coin_bss+4

copter_bss      = $8b
copter_x_l      = copter_bss+0
copter_y_l      = copter_bss+1
copter_x_h      = copter_bss+2
copter_y_h      = copter_bss+3
copter_vx_l     = copter_bss+4
copter_vy_l     = copter_bss+5
copter_vx_h     = copter_bss+6
copter_vy_h     = copter_bss+7
copter_x_o      = copter_bss+8
copter_y_o      = copter_bss+9
copter_detect   = copter_bss+10

bird_bss        = $96
bird_ox         = bird_bss+0
bird_dx         = bird_bss+5

; ------------------------------------------------------------------
; main function
;
; starts half way through sound memory
; ------------------------------------------------------------------

*=$880   ; start at free RAM

main
    sei
        
    ; ------------------------------------------------------------------
    ; generate block graphics from table
    ; ------------------------------------------------------------------
.local    
    
.if BLOCK_GFX
    ldy     #0
?loop0    
?load
    lda     blocks
    ldx     #8
?loop1   
    sta     $700,y
    iny
    dex
    bne     ?loop1
    inc     ?load+1
    tya
    bne     ?loop0
.endif

restart

    ; ------------------------------------------------------------------
    ; initalize zero page $51-$9f from tables and trailing zeros
    ; ------------------------------------------------------------------
.local

    ldx     #$4f
?loop
    lda     zero_page,x
    sta     $50,x
    dex
    bpl     ?loop

    ; ------------------------------------------------------------------
    ; clear screen to cyan, relying on *$53 == $30
    ; ------------------------------------------------------------------
.local

    lda     #$3c
    ldy     #0

?loop
    sta     ($52),y
    iny
    bne     ?loop
    inc     $53
    bpl     ?loop

    ; *$53 has been incremented to $80 at this point

    ; ------------------------------------------------------------------
    ; clear cursor, remap magenta to yellow, prepare for keyboard scan
    ; ------------------------------------------------------------------
.local

?loop
    inx
    lda     hw_data,x
    ldy     hw_addr,x
    sta     $fe00,y
    bne     ?loop

    ; insert spacer into bonus/score

    sta     spacer                          ; value $aa comes from last hw data

main_loop
    ; ------------------------------------------------------------------
    ; wait for vblank
    ; ------------------------------------------------------------------
.local

    lda     #2
?loop
    bit     $fe4d
    beq     ?loop
    sta     $fe4d

    ; ------------------------------------------------------------------
    ; generate the looped sprite frame in (0, 4, 8, 4)
    ; ------------------------------------------------------------------
.local

.if .not BLOCK_GFX
    lda     master_frame    
    and     #$0c
    cmp     #$0c
    bne     ?skip
    lda     #$04
?skip
    sta     sprite_frame
.endif

    ; ------------------------------------------------------------------
    ; on even frames, update the platform direction and position
    ; ------------------------------------------------------------------
.local    

    lda     master_frame
    lsr
    bcs     ?skip1
    
    lda     platform_x
    cmp     #122
    lda     platform_dx
    bcc     ?skip0
    eor     #$ff
    adc     #0                              ; add 1, because carry known set
    sta     platform_dx
?skip0
;    clc                                    ; because either arrived via a bcc or via adc #0 to either 0 or 254
    adc     platform_x
    sta     platform_x
?skip1

    ; ------------------------------------------------------------------
    ; if the helicopter is in the top half of the screen, draw the sea
    ; and status bar now, to allow the raster time to get into the 
    ; bottom half of the screen
    ; ------------------------------------------------------------------
.local

    lda     copter_y_h
    php                                     ; push flags so we can make the opposite decision at the end of the game loop
    bmi     ?skip
    jsr     moveable
?skip

    ; ------------------------------------------------------------------
    ; run the helicopter
    ; ------------------------------------------------------------------
.local

    ; hit detection (both pixels)

    jsr     detect
    lsr     copter_detect
    jsr     detect

    ; check if we're at sea level

    lda     copter_y_h
    cmp     #232
    bne     ?skip1
    
    ; we're at sea level
    
    ; if we hit a bird, die
    
    lda     copter_alive
    bpl     ?die
    
    ; on even frames, move us with the platform
    
    lda     master_frame
    lsr
    
    lda     copter_x_h
    bcs     ?skip0
;   clc                                     ; because bcs just above
    adc     platform_dx
    sta     copter_x_h

?skip0

    ; check if we're on the platform

    sec
    sbc     platform_x
    cmp     #3
    bmi     ?die
    cmp     #29
    bmi     ?live
    
?die
.if RTS_ON_DIE
    plp
    rts
.else
.if .not EXTRA_HACKS
    plp
.endif    
?loop
    lda     #KEY_SPACE
    sta     $fe4f
    lda     $fe4f
    bpl     ?loop
.if EXTRA_HACKS    
    bmi     restart
.else
    jmp     restart
.endif    
.endif    

?live
    ; we're on the platform

    ; add the bonus to the score

    ldx     #254    
    jsr     add24                           ; add24 exits with 255 in y    
    
    ; fill fuel, clear bonus and horizontal velocity

    sty     copter_fuel
    
    iny
    sty     bonus+1
    sty     bonus+2
    sty     copter_vx_l
    sty     copter_vx_h

    beq     ?skip3                          ; zero flag known set
    
?skip1
    ; we're not at sea level
    
    ; read Z and X keys, find delta in {-1, 0, 1}, update last direction

    ldy     #0

    lda     #KEY_Z
    jsr     inkey
    bpl     ?skip2

    dey    

.if .not BLOCK_GFX    
    lda     #SPR_COPTER
    sta     copter_dx
.endif    
    
?skip2
    lda     #KEY_X
    jsr     inkey
    bpl     ?skip3

    iny

.if .not BLOCK_GFX    
    lda     #SPR_COPTER+2
    sta     copter_dx
.endif

?skip3
    ; run x-axis processing

    lda     #153                            ; max x
    ldx     #0
    jsr     axis

    ; read spacebar, find delta in {-1, 1}, decrement fuel

    ldy     #1

;    lda     #KEY_SHIFT
    txa                                     ; KEY_SHIFT is 0
    jsr     inkey
    bpl     ?skip4
    
    lda     copter_fuel
    beq     ?skip4
    dec     copter_fuel
    
    dey
    dey
    
?skip4
    ; run y-axis processing

    lda     #232                            ; max y
    inx                                     ; increment to 1
    jsr     axis
    
    ; ------------------------------------------------------------------
    ; erase the helicopter at its old position
    ; ------------------------------------------------------------------
.local
    
    ldy     copter_x_o
    lda     copter_y_o
    sta     work8
    lda     #SPR_CYAN
    jsr     plot_store

    ; ------------------------------------------------------------------
    ; run, and draw, the coins
    ; ------------------------------------------------------------------
.local    
    
    ldx     #3
?loop0
    stx     work9

    ; store coin y in work8, check if coin has been collected (msb == 0)
    
    lda     coin_y,x
    asl     a
    sta     work8
    bcc     ?skip0

    ; not collected, so compute animation frame, fetch coin x

.if BLOCK_GFX
    lda     #SPR_COIN
.else    
    lda     master_frame
    and     #$18
    lsr     a
    lsr     a
    lsr     a
;    clc                                    ; because lsr with known-zero lsb above
    adc     #SPR_COIN
.endif    
    
    ldy     coin_x,x

.if BLOCK_GFX
    bcs     ?skip1                          ; missing calculation above means carry still set
.else        
    bcc     ?skip1
.endif

?skip0
    ; collected, so need to generate a new random position

    ; find a random y in {8, 24, 40, ..., 232}
    ; the value computed is actually 0x80 | y >> 1

?loop1
    jsr     rand
    and     #120
    cmp     #120
    bpl     ?loop1
    ora     #$84    
                 
    ; check no other coins on this row 
                              
    ldy     #3
?loop2
    cmp     coin_y,y
    beq     ?loop1
    dey
    bpl     ?loop2
    sta     coin_y,x

    ; find a random x in (0, 2, 4, ..., 152}
    
?loop3
    jsr     rand
    asl
    cmp     #154
    bcs     ?loop3
    
    ldy     coin_x,x                   ; fetch old coin x
    sta     coin_x,x

    lda     #SPR_CYAN                           ; draw will erase coin
    
?skip1    
    ; draw or erase
    
    jsr     plot_store
    
    ldx     work9
    dex
    bpl     ?loop0

    ; ------------------------------------------------------------------
    ; run, and draw, the birds
    ; ------------------------------------------------------------------
.local    

    ldx     #4
?loop
    stx     work9

    ; update direction if at limit

    lda     bird_ox,x
    cmp     bird_w,x
    lda     bird_dx,x
    bcc     ?skip                           ; branch on unsigned <, so flip dx if x is -1 or max_x
    eor     #2
    sta     bird_dx,x
    clc
?skip
    ; compute bird x 

    adc     bird_ox,x
    clc
    adc     #$ff
    sta     bird_ox,x
    adc     bird_x,x
    tay
    
    ; store bird y in work8
    
    lda     bird_y,x
    sta     work8
    
    ; compute animation frame 

.if BLOCK_GFX
    lda     #SPR_BIRD
.else
    lda     bird_dx,x
;    clc                                    ; because previous add is known not to overflow
    adc     sprite_frame    
.endif
    
    ; draw with padding
             
    ldx     #OP_PAD
    jsr     plot
    
    ldx     work9
    dex
    bpl     ?loop

    ; ------------------------------------------------------------------
    ; draw helicopter in new position
    ; ------------------------------------------------------------------
.local    

    ; fetch helicopter x, store copy for future erase

    ldy     copter_x_h
    sty     copter_x_o

    ; fetch helicopter y, store copy for future erase
    ; helicopter y coordinates are offset by 8 pixels
    
    lda     copter_y_h
;    clc                                    ; because plot function clear carry
    adc     #8
    sta     copter_y_o
    sta     work8
    
    ; compute animation frame
    
.if BLOCK_GFX
    lda     #SPR_COPTER
.else    
    lda     copter_dx
;    clc                                    ; because previous add is known not to overflow
    adc     sprite_frame
.endif

    ; draw

    jsr     plot_blend
    
    ; store collision value for hit detection on next frame
    
    lda     collide
    sta     copter_detect

    ; ------------------------------------------------------------------
    ; if the helicopter is in the bottom half of the screen, draw the 
    ; sea and status bar now
    ; ------------------------------------------------------------------
.local

    plp
    bpl     ?skip
    jsr     moveable
?skip

    ; ------------------------------------------------------------------
    ; increment the master frame
    ; ------------------------------------------------------------------
    
    inc     master_frame

    jmp     main_loop

; ------------------------------------------------------------------
; this is the "moveable" work (the sea and status bar), that we can 
; do either at the start or end of the frame
;
; by moving this carefully, we can ensure that the raster doesn't 
; intersect the helicopter position while it is erased
; ------------------------------------------------------------------

moveable
.if CHEAP_SEA
.local
    ldy     #127
    lda     #$30

?loop
    sta     $7d80,y
    sta     $7e00,y
    sta     $7e80,y
    sta     $7f00,y
    sta     $7f80,y
    dey
    bpl     ?loop
.else
    ; ------------------------------------------------------------------
    ; generate the looped sea frame in (0, 64, 128)
    ; ------------------------------------------------------------------
.local
    
    lda     sea_frame
    clc
    adc     #8
    cmp     #$c0
    bcc     ?skip
    lda     #0
?skip
    sta     sea_frame
    and     #$c0

    ; ------------------------------------------------------------------
    ; draw ten copies of the current sea frame, five at a time
    ; ------------------------------------------------------------------
.local

    ldy     #127
?loop0
    sta     ?load+1                         ; self-modify
    ldx     #63
?loop1
?load
    lda     $1300+SPR_SEA*32-64,y
    sta     $7d80,y
    sta     $7e00,y
    sta     $7e80,y
    sta     $7f00,y
    sta     $7f80,y
    dey
    dex
    bpl     ?loop1
    
    lda     ?load+1
    clc
    adc     #64

    cpy     #0
    bpl     ?loop0
.endif    
    ; ------------------------------------------------------------------
    ; draw the platform, in three pieces
    ; ------------------------------------------------------------------
.local

    ; store platform y in work8

    lda     #248
    sta     work8
    
    ; x coordinate goes in y, with a copy on the stack
    
    lda     platform_x
    adc     #8                              ; add 9 (carry known set because of cpy above)
    tay
    pha

    ; animation frame doubles as loop counter
    
.if BLOCK_GFX
    lda     #3
.else
    lda     #SPR_PLATFORM/2
.endif
    sta     work9

?loop
    ; draw platform section

.if BLOCK_GFX
    lda     #SPR_PLATFORM
.else
    asl
.endif
    jsr     plot_blend

    ; compute next x coordinate

    pla
;    clc                                    ; because plot functions clear carry
    adc     #7
    tay
    pha

    ; compute next animation frame

.if BLOCK_GFX
    dec     work9
.else
    inc     work9
    lda     work9
    cmp     #SPR_PLATFORM/2+3
.endif    
    bne     ?loop
    
    pla

    ; ------------------------------------------------------------------
    ; draw the score
    ; ------------------------------------------------------------------
.local
    
    ; draw fourteen BCD digits (middle two digits are 0xaa, so blank)
    ; proceed right to left: calling digit decrements work0 by 16

    lda     #$f0
    sta     digit_addr
    
    ldx     #7
?loop
    stx     work4
    
    ; fetch digit pair

    lda     score-1,x
    
    ; draw ls digit, preserving value
    
    pha
    asl     a
    asl     a
    jsr     digit

    ; draw ms digit
    
    pla
    lsr     a
    lsr     a
    jsr     digit
    
    ldx     work4
    dex
    bne     ?loop
    
    ; ------------------------------------------------------------------
    ; draw the fuel bar
    ; ------------------------------------------------------------------
.local
    
    lda     copter_fuel
    lsr     a
    lsr     a
    tay

    clc

    ; assume x is zero (from previous loop)

?loop0
    ; compute value to store, based on whether we are in the bar, at
    ; the bar edge, or out of the bar
    
    lda     #$3c                            ; two cyan pixels
    dey
    dey
    beq     ?skip0
    bmi     ?skip1
    eor     #$15                            ; make right pixel red
?skip0
    eor     #$2a                            ; make left pixel red
?skip1    
    
    ; draw four red pixels
    
?loop1
    sta     $3123,x
    sta     $3124,x
    sta     $3125,x
    
    ; move to next column
    
    txa
;    clc                                    ; because of clc at top of loop, and bounded iterations
    adc     #8
    tax
    
    bne     ?loop0

    rts

; ------------------------------------------------------------------
; scan a key
;
; arguments:
;
;     a = key code
;
; return:
;
;     n flag set if key pressed and alive
; ------------------------------------------------------------------

inkey
    sta     $fe4f
    lda     $fe4f
    and     copter_alive
    rts

; ------------------------------------------------------------------
; hit detection
;
; examine bits {4, 2, 0) of copter_detect
; ------------------------------------------------------------------
.local

detect
    ; mask off bits and examine
    
    lda     copter_detect
    and     #$15
    
    ; cheapest test sequence is different in block and bitmap modes
    
.if BLOCK_GFX    
    cmp     #$11
    beq     ?coin                           ; magenta (recolored to yellow) -> coin
    cmp     #$01
    bne     ?none                           ; red -> bird
.else
    beq     ?none                           ; black or empty pixel -> no hit
    cmp     #$14
    beq     ?none                           ; cyan -> no hit
    cmp     #$11
    beq     ?coin                           ; magenta (recolored to yellow) -> coin
    cmp     #$15
    beq     ?coin                           ; white -> coin
.endif

    lsr     copter_alive                    ; must have been a bird, so clear msb of copter_alive

?none
    rts
    
?coin
    ; adjust helicopter y for comparison with coin y

    lda     copter_y_h
    ror                                     ; we got here as a result of an equality comparison, and C set means unsigned >=, so ror sucks in a carry
    clc
    adc     #4                              
    and     #$f8
    adc     #4

    ; loop over coins

    ldx     #3
?loop0
    cmp     coin_y,x
    bne     ?skip
    
    ; clear msb, marking coin as collected
    
    and     #$7f
    sta     coin_y,x

    ; special-case bonus == 0
    
    ldx     bonus+2
    beq     ?zero
    
    ; double bonus
    
    ldx     #2    
    
    ; ------------------------------------------------------------------
    ; this is a handy little snippet for adding two 3-byte BCD values
    ; so we parameterize it and call it from the main loop to add the 
    ; bonus to the score when we land
    ;
    ; arguments:
    ;
    ;     x = offset of ls byte from bonus
    ;         2 to double bonus (inline use)
    ;         254 to add bonus to score
    ; ------------------------------------------------------------------
        
add24    
    sed
    clc
    ldy     #2
?loop1    
    lda     bonus,x
    adc     bonus,y
    sta     bonus,x
    dex
    dey
    bpl     ?loop1     
    cld
    rts

?zero
    ; first coin of this flight, so set bonus to 1

    inx
    stx     bonus+2
    rts

?skip
    dex
    bpl     ?loop0
    rts

; ------------------------------------------------------------------
; helicopter physics for one axis
;
; arguments:
;
;     a = bounds in this axis
;     x = offset to values in helicopter data structure in {0, 1}
;     y = delta in {-1, 0, 1}
; ------------------------------------------------------------------
.local

axis
    sta     work2

    ; if delta == 0, skip velocity update

    tya
    beq     ?skip0

    ; convert delta to 16-bit velocity increment
    
    ; -1 -> $ffc0 (-64)
    ;  1 -> $0040 (64)

    ; ms byte
    
    cmp     #$80
    ror
    pha

    ; ls byte

    and     #$80
    clc
    adc     #$40
    
    ; update velocity
    
;    clc                                    ; because previous add is known not to overflow
    adc     copter_vx_l,x
    sta     copter_vx_l,x
    pla
    adc     copter_vx_h,x
    sta     copter_vx_h,x

?skip0
    ; add velocity to position

    clc
    lda     copter_x_l,x
    adc     copter_vx_l,x
    sta     copter_x_l,x
    lda     copter_x_h,x
    adc     copter_vx_h,x
    
    ; bounds check position
    
    cmp     work2
    bcc     ?skip1
    
    ; zero velocity and ls byte of position
    
    ldy     #0
    sty     copter_x_l,x
    sty     copter_vx_l,x
    sty     copter_vx_h,x

    ; clamp ms byte of position to 0 or bounds
    
    cmp     #248
    lda     work2
    bcc     ?skip1
    tya
?skip1

    sta     copter_x_h,x
    
    ; velocity = velocity * 3 / 4
    
    lda     copter_vx_l,x
    sta     work0
    lda     copter_vx_h,x
    cmp     #$80                            ; asr16 idiom
    ror     A
    ror     work0
    cmp     #$80
    ror     A
    ror     work0
    sta     work1

    lda     copter_vx_l,x
    sec
    sbc     work0
    sta     copter_vx_l,x
    lda     copter_vx_h,x
    sbc     work1
    sta     copter_vx_h,x
    
    rts

; ------------------------------------------------------------------
; LFSR pseudorandom number generator from 
;
; https://wiki.nesdev.com/w/index.php/Random_number_generator
;
; uses two bytes of workspace at lfsr, which must not be zero
;
; returns:
;
;     a = result
; ------------------------------------------------------------------
.local

rand
	ldy     #8
	lda     lfsr+0
?loop
	asl
	rol     lfsr+1
	bcc     ?skip
	eor     #$2d
?skip
	dey
	bne     ?loop
	sta     lfsr+0
    rts

; ------------------------------------------------------------------
; optional exported function to draw single digit from 4*8-pixel 
; font in cyan/black
;
; arguments:
;
;     digit_data              = ASCII 
;     digit_addr+1,digit_addr = screen address
;
; returns:
;
;     digit_addr+1,digit_addr = screen address-16
; ------------------------------------------------------------------
.local

.if EXPORT_DIGIT
digit_export
    lda     digit_data
    
    ; convert subset of ASCII to our font order
    ; ' ' -> 10
    ; '0' -> 0
    ; 'A' -> 11
    
    cmp     #48
    bcc     ?space
    cmp     #65
    bcc     ?number
    sbc     #7
?number
    sbc     #26
?space
    sbc     #21
    
    asl
    asl
    
    .byte   $2c                             ; 2-byte BIT hack
.endif

; ------------------------------------------------------------------
; internal function to draw single digit from 4*8-pixel font in 
; cyan/black
;
; arguments:
;
;     a                       = digit << 2
;     digit_addr+1,digit_addr = screen address
;
; returns:
;
;     digit_addr+1,digit_addr = screen address-16
;
; (note only digit_addr is updated if not exporting function)
; ------------------------------------------------------------------

digit
    and     #$3c    
    clc
    adc     #<DIGITS
    sta     ?load+1                         ; self-modify

    ldy     #15
?loop0
    ; each byte of font data encodes four pixels

    ldx     #3
?load
    lda     DIGITS
?loop1
    pha

    ; take 2 lsbs, multiply by 20 (cyan) and store
    
    and     #3
    asl
    asl
    sta     work3
    asl
    asl
    ora     work3
    sta     (digit_addr),y
    
    pla
    lsr
    lsr
    dey
    dex
    bpl     ?loop1
    inc     ?load+1                         ; self-modify
    tya
    bpl     ?loop0
    
    ; move to next character position
    
    lda     digit_addr
;    sec                                    ; we know carry is set by last lsr above
    sbc     #16                             
    sta     digit_addr

.if EXPORT_DIGIT
    ; exported version needs to traverse page boundaries

    lda     digit_addr+1
    sbc     #0
    sta     digit_addr+1
.endif    
    rts

; ------------------------------------------------------------------
; computed left-shift of 16-bit value
;
; arguments:
;
;     a           = ls byte
;     x           = offset from work0 of ls byte
;     y           = shift
;     work1+x     = ms byte
;
; returns:
;
;     work1,work0+x = shifted value
;     a             = ls byte of shifted value
;     x             = offset from work0 of ls byte + 2
;     y             = 0
; ------------------------------------------------------------------
.local

asl16
?loop
    asl
    rol     work1,x
    dey
    bne     ?loop
    sta     work0,x
    inx
    inx
asl16_out                                   ; handy rts near plot
    rts

; ------------------------------------------------------------------
; master plot function
;
; this blits an 8x8 pixel sprite into the BBC's wacky video memory
; layout
;
;  0   8  16  ..
;  1   9  17  ..
;  2  10  18  ..
;  3  11  19  ..
;  4  12  20  ..
;  5  13  21  ..
;  6  14  22  ..
;  7  15  23  ..
; 640 648
; 641 649
; 642 650
;  :   :
;
; each byte contains two pixels interleaved in bits (6,4,2,0) and
; (7,5,3,1)
;
; we use a pre-baked shifted copy of each sprite, stored in the next
; slot, to target odd x coordinates
;
; arguments:
;
;     a           = sprite number (32 byte increments)
;     x           = operation (OP_PAD, OP_STORE, OP_BLEND)
;     y           = x coordinate
;     work8       = y coordinate
;
; returns:
;
;     x           = 0
;     c           = 0
;
; we have two extra entry points, plot_store and plot_blend, which
; pre-set x to OP_STORE and OP_BLEND respectively
; ------------------------------------------------------------------
.local

plot_store
    ldx     #OP_STORE
    .byte   $2c                             ; 2-byte BIT hack

plot_blend
    ldx     #OP_BLEND

plot
    stx     ?jump+1                         ; self-modify

    ; zero ms bytes of 16-bit address components, collide flag

    ldx     #0
    stx     work5
    stx     work3
    stx     work1
    
    stx     collide

.if BLOCK_GFX
    ; work1,work0 = 0x700 + (sprite + (x & 1) ^ 1) * 8
    
    pha
    tya
    eor     #1
    lsr
    sta     work7
    pla

    adc     #$e0
    ldy     #3
.else
    ; work1,work0 = 0x1300 + (sprite + (x & 1)) * 32

    sty     work7
    lsr     work7

    adc     #$98
    ldy     #5
.endif
    jsr     asl16

    ; work6 = y & 7
    
    lda     work8
    and     #7
    sta     work6

    ; work3,work2 = (y >> 3) * 640
    ; normally we'd use the ROM lookup table to do this, but
    ; hand-cranking it here for the sake of hackaday

    lda     work8
    lsr
    lsr
    lsr
    sta     work2
    asl
    asl
    adc     work2

    ldy     #7
    jsr     asl16

    ; work5,work4 = (x >> 1) * 8

    lda     work7
    ldy     #3
    jsr     asl16

    ; accumulate components of destination address
    ;
    ; work3,work2 = 0x3000 + (x >> 1) * 8 + (y >> 3) * 640 + (y & 7)

;    clc                                    ; because rol with known-zero msb in asl16
    adc     work6
    adc     work2                           ; previous add is of 3-bit value to value with 3 zero lsbs
    sta     work2

    lda     work3
    adc     work5
    adc     #$30                            ; previous add can only generate values < 0x50
    sta     work3

    ; process 8 - (y&7) pixels in first stripe, skipping y&7 pixels each column

    lda     #9                              
    sbc     work6                           ; we know carry is clear (so borrow is set) so add one here
    clc
    jsr     ?stripe

    ; advance source address by number of pixels already processed
    ;
    ; because of sprite alignment, no carry can occur out of ls byte
    
    lda     work4                           
;    clc                                    ; because plot functions clear carry
    adc     work0
    sta     work0
    
    ; advance destination address to top of next stripe
    
    lda     work2
    and     #$f8
;    clc                                    ; because previous add is known not to overflow
    adc     #$80
    sta     work2
    lda     work3
    adc     #$02
    sta     work3
    
    ; process y&7 pixels in first stripe, skipping 8 - (y&7) pixels each column
    
    ldy     work4
    lda     work6                           
    sty     work6
    
    ; exit if all work done in first stripe 
   
    beq     asl16_out                       

?stripe
    ; store pixels to process

    sta     work4
    
    ; always process 4 columns
    
    lda     #4
    sta     work5
    
    ldy     #0
?jump
    bvc     pad                             ; will have been modified
plot_end
   
; ------------------------------------------------------------------
; plot kernels
;
; arguments:
;
;     y           = 0
;     c           = 0
;
;     work1,work0 = source address
;     work3,work2 = destination address
;     work4       = pixels to process
;     work5       = columns to process
;     work6       = pixels to skip (8-work4)
; ------------------------------------------------------------------
      
; ------------------------------------------------------------------
; pad kernel
;
; writes a column of cyan, then calls the store kernel, then writes
; another column of cyan
;
; we use this to draw birds, so they erase themselves as they move
; ------------------------------------------------------------------
.local    
    
pad
    jsr     ?column

    ; nudge destination address forward to next column and reset y

    lda     work2
;    clc                                    ; because plot clears carry
    adc     #8
    sta     work2
    txa
    tay
    adc     work3
    sta     work3
    
    jsr     store

?column    
    ldx     work4
    lda     #60
?loop
    sta     (work2),y
    iny
    dex
    bne     ?loop
    
    rts

; ------------------------------------------------------------------
; store and blend kernels
;
; store just copies the source data
;
; blend only writes pixels if the msb of the 4-bit color is zero,
; and records any non-cyan pixel overwritten in "collide"
;
; store is actually implemented by self-modifying the blend kernel
; to jump over the clever stuff straight to the write out
; ------------------------------------------------------------------
.local    

store
    lda     #?fast-?slow                    ; offset to fast path
    
    .byte   $24                             ; 1-byte BIT hack

blend
    tya                                     ; offset to slow path (zero)
    
    sta     ?jump+1                         ; self-modify

?loop0
    ldx     work4
    
?loop1
    lda     (work0),y                       
?jump    
    bpl     ?fast                           ; opportunity to jump to fast path (store data always has bits 7,6 == 00)
?slow

    ; time to determine pixel opacity

    asl     a                               ; put bit 7 in C, bit 6 in N
    bmi     ?bits_x1                        
    lda     (work2),y
    bcs     ?bits_10                        
    
?bits_00                                    ; bits 7 and 6 both 0, so fully opaque
    cmp     #$3c                            ; check cyan
    
?decide    
    beq     ?commit                         ; arrive here with Z set if pixels to be occluded are all cyan
    sta     collide
    
?commit                                     ; arrive here with pixels to be occluded in A
    eor     (work2),y                       
    ora     (work0),y                       
    and     #$3f                            ; don't write transparency flags to frame buffer (could use palette hack)
?fast
    sta     (work2),y
    
    ; fall through to loop tails
    
?bits_11                                    ; bits 7 and 6 both 1, so fully transparent
    iny
    dex
    bne     ?loop1
    tya
    clc
    adc     work6
    tay
    dec     work5
    bne     ?loop0
    rts

?bits_x1                                    ; bit 6 was 1
    bcs     ?bits_11
    lda     (work2),y
    
?bits_01                                    ; bit 7 is 0, bit 6 is 1, so ls pixel is transparent
    and     #$aa                            ; preserve bits 7,5,3,1
    cmp     #$28                            ; check they're cyan
    bvc     ?decide                         ; overflow known clear 
    
?bits_10                                    ; bit 7 is 1, bit 6 is 0, so ms pixel is transparent
    and     #$55                            ; preserve bits 6,4,2,0
    cmp     #$14                            ; check they're cyan
    bvc     ?decide                         ; overflow known clear 

; ------------------------------------------------------------------
; source data for block graphics
; ------------------------------------------------------------------

.if BLOCK_GFX
blocks
    .byte $29, $03, $03, $03, $16
    .byte $84, $0c, $0c, $0c, $48
    .byte $80, $00, $00, $00, $40
    .byte $3c, $33, $33, $3c
    .byte $3c, $3c, $3c, $3c
.endif

; ------------------------------------------------------------------
; embedded numeric font
; ------------------------------------------------------------------

.if EMBED_FONT
font
    .byte $57, $f5, $56, $e5
    .byte $fd, $ff, $a8, $e2
    .byte $fd, $f5, $94, $cf
    .byte $d7, $f5, $bc, $cf
    .byte $55, $d5, $bf, $d5
    .byte $d7, $df, $3c, $c5
    .byte $d7, $df, $16, $e5
    .byte $ff, $d5, $aa, $cf
    .byte $d7, $f5, $96, $e5
    .byte $55, $d5, $bf, $e5
    .byte $ff, $ff                          ; remove last two bytes as identical to next two bytes
.endif

; ------------------------------------------------------------------
; zero page initial values
; ------------------------------------------------------------------

zero_page
    .byte   $ff, $ff                        ; copter_fuel, copter_alive
    .byte   $00                             ; spare byte for screen clear hack
    .byte   $30, $b0, $40, $20, $d0         ; bird_y    
    .byte   $10, $22, $01, $57, $07         ; bird_x
    .byte   $66, $41, $49, $37, $61         ; bird_w
    .byte   $01                             ; platform_dx
.if .not BLOCK_GFX    
    .byte   $0c                             ; copter_dx
.endif
    .byte   $00, $30                        ; digit_addr

; ------------------------------------------------------------------
; hardware initialisation data and addresses get copied to zero page
; first (and abused to initialise LFSR)
; ------------------------------------------------------------------

hw_data_init
    .byte   $54                         ; palette setup
    .byte   $14                         ; clear cursor
    .byte   $7f                         ; setup keyboard
    .byte   $03            
    .byte   $02                         ; clear vblank interrupt
    .byte   $aa                         ; nonsense value written (safely) to CRTC address register, but left in A to be written to spacer

hw_addr_init
    .byte   $21                         ; palette setup
    .byte   $20                         ; clear cursor
    .byte   $43                         ; setup keyboard
    .byte   $40                         
    .byte   $4d                         ; clear vblank interrupt

hw_data=$50+(hw_data_init-zero_page)
hw_addr=$50+(hw_addr_init-zero_page)
