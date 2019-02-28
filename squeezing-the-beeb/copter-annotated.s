S_COPL = 12                 ; constants, zero-page map
S_COPR = 14
S_COIN = 24
S_LAND = 28
S_CYAN = 40

L = S_LAND/2
M = L+3

WATR = $1700
DIGS = $1840

O_PAD = p-p
O_STR = s-p
O_BLN = b-p

KEY_Z  = $61
KEY_X  = $42
KEY_SP = $62
KEY_UP = $00

p_fuel = $50
p_live = $51
b_y = $53
b_x = $58
b_w = $5d
l_dx = $62
p_dx = $63
da = $64
lfsr = $66

w0 = $68
w1 = $69
w2 = $6a
w3 = $6b
w4 = $6c
w5 = $6d
w6 = $6e
w7 = $6f
w8 = $70
w9 = $71

hit = $77
mframe = $78
sframe = $79
wframe = $7a
scr = $7b
spacer = $7e
bonus  = $7f

l_x = $82
c_x = $83
c_y = $87
p_xl = $8b
p_yl = $8c
p_xh = $8d
p_yh = $8e
p_vxl = $8f
p_vyl = $90
p_vxh = $91
p_vyh = $92
p_xo = $93
p_yo = $94
p_hit = $95
b_ox = $96
b_dx = $9b

hwdat = $66
hwadr = $6c

*=$880
;--------------------------------------------------------------------------------
 sei                        ; initialise zero-page, hardware; clear screen
  
top
 ldx #$4f
l00
 lda zpage,x
 sta $50,x
 dex
 bpl l00
 
 lda #$3c
 ldy #0
l01
 sta ($52),y
 iny
 bne l01
 inc $53
 bpl l01

l02
 inx
 lda hwdat,x
 ldy hwadr,x
 sta $fe00,y
 bne l02
 
 sta spacer

;--------------------------------------------------------------------------------
loop                        ; top of main loop: wait for vblank
 lda #2
l03
 bit $fe4d
 beq l03
 sta $fe4d
;--------------------------------------------------------------------------------
 lda mframe                 ; update animation frame and platform position
 and #$0c
 cmp #$0c
 bne s00
 lda #$04
s00
 sta sframe

 lda mframe
 lsr
 bcs s02 
 lda l_x
 cmp #122
 lda l_dx
 bcc s01
 eor #$ff
 adc #0
 sta l_dx
s01
 adc l_x
 sta l_x
s02
;--------------------------------------------------------------------------------
 lda p_yh                   ; possibly do moveable work
 php
 bmi s03
 jsr canmove
s03
;--------------------------------------------------------------------------------
 jsr detect                 ; check if player has died
 lsr p_hit
 jsr detect

 lda p_yh
 cmp #232
 bne s05 
 lda p_live
 bpl die
 lda mframe
 lsr 
 lda p_xh
 bcs s04
 adc l_dx
 sta p_xh
s04
 sec
 sbc l_x
 cmp #3
 bmi die
 cmp #29
 bmi live
die
 plp
l04
 lda #KEY_SP
 sta $fe4f
 lda $fe4f
 bpl l04
 jmp top
live
 ldx #254 
 jsr add24
 sty p_fuel
 iny
 sty bonus+1
 sty bonus+2
 sty p_vxl
 sty p_vxh
 beq s07
s05
;-------------------------------------------------------------------------------- 
 ldy #0                     ; run player physics
 lda #KEY_Z
 jsr inkey
 bpl s06
 dey 
 lda #S_COPL
 sta p_dx
s06
 lda #KEY_X
 jsr inkey
 bpl s07
 iny
 lda #S_COPR
 sta p_dx
s07
 lda #153
 ldx #0
 jsr axis

 ldy #1
 txa     
 jsr inkey
 bpl s08
 lda p_fuel
 beq s08
 dec p_fuel
 dey
 dey
s08
 lda #232
 inx     
 jsr axis
;--------------------------------------------------------------------------------  
 ldy p_xo                   ; erase player
 lda p_yo
 sta w8
 lda #S_CYAN
 jsr plot_s
;--------------------------------------------------------------------------------  
 ldx #3                     ; run coins
l05
 stx w9
 lda c_y,x
 asl a
 sta w8
 bcc s09
 lda mframe
 and #$18
 lsr a
 lsr a
 lsr a
 adc #S_COIN
 ldy c_x,x
 bcc s10
s09
l06
 jsr rand
 and #120
 cmp #120
 bpl l06
 ora #$84    
 ldy #3
l07
 cmp c_y,y
 beq l06
 dey
 bpl l07
 sta c_y,x
l08
 jsr rand
 asl
 cmp #154
 bcs l08
 ldy c_x,x
 sta c_x,x
 lda #S_CYAN 
s10  
 jsr plot_s
 ldx w9
 dex
 bpl l05
;--------------------------------------------------------------------------------  
 ldx #4                     ; run birds
l09
 stx w9
 lda b_ox,x
 cmp b_w,x
 lda b_dx,x
 bcc s11
 eor #2
 sta b_dx,x
 clc
s11
 adc b_ox,x
 clc
 adc #$ff
 sta b_ox,x
 adc b_x,x
 tay
 lda b_y,x
 sta w8
 lda b_dx,x
 adc sframe 
 ldx #O_PAD
 jsr plot
 ldx w9
 dex
 bpl l09
;--------------------------------------------------------------------------------  
 ldy p_xh                   ; draw player
 sty p_xo 
 lda p_yh
 adc #8
 sta p_yo
 sta w8 
 lda p_dx
 adc sframe
 jsr plot_b
 lda hit
 sta p_hit
;--------------------------------------------------------------------------------
 plp                        ; do moveable work if not done
 bpl s12
 jsr canmove
s12
;--------------------------------------------------------------------------------
 inc mframe                 ; end of main loop
 jmp loop
;--------------------------------------------------------------------------------
canmove                     ; moveable work: first draw water and platform
 lda wframe                 
 clc
 adc #8
 cmp #$c0
 bcc s13
 lda #0
s13
 sta wframe
 and #$c0

 ldy #127
l10
 sta m00+1
 ldx #63
l11
m00
 lda WATR,y
 sta $7d80,y
 sta $7e00,y
 sta $7e80,y
 sta $7f00,y
 sta $7f80,y
 dey
 dex
 bpl l11
 lda m00+1
 clc
 adc #64
 cpy #0
 bpl l10
 
 lda #248
 sta w8
 lda l_x
 adc #8   
 tay
 pha
 lda #L
 sta w9
l12
 asl
 jsr plot_b
 pla
 adc #7
 tay
 pha
 inc w9
 lda w9
 cmp #M
 bne l12
 pla
;--------------------------------------------------------------------------------
 lda #$f0                   ; draw score and bonus
 sta da 
 ldx #7
l13
 stx w4
 lda scr-1,x
 pha
 asl a
 asl a
 jsr digit
 pla
 lsr a
 lsr a
 jsr digit
 ldx w4
 dex
 bne l13
;-------------------------------------------------------------------------------- 
 lda p_fuel                 ; draw fuel bar
 lsr a
 lsr a
 tay
 clc
l14
 lda #$3c
 dey
 dey
 beq s14
 bmi s15
 eor #$15
s14
 eor #$2a
s15
 sta $3123,x
 sta $3124,x
 sta $3125,x
 txa
 adc #8
 tax
 bne l14
 rts
;-------------------------------------------------------------------------------- 
inkey                       ; read key
 sta $fe4f
 lda $fe4f
 and p_live
 rts
;-------------------------------------------------------------------------------- 
detect                      ; collision detection
 lda p_hit
 and #$15
 beq none
 cmp #$14
 beq none
 cmp #$11
 beq coin
 cmp #$15
 beq coin 
 lsr p_live
none
 rts
 
coin
 lda p_yh
 ror     
 clc
 adc #4     
 and #$f8
 adc #4
 ldx #3
l15
 cmp c_y,x
 bne s16 
 and #$7f
 sta c_y,x
 ldx bonus+2
 beq zero
 ldx #2  
add24 
 sed
 clc
 ldy #2
l16
 lda bonus,x
 adc bonus,y
 sta bonus,x
 dex
 dey
 bpl l16 
 cld
 rts
zero
 inx
 stx bonus+2
 rts
s16
 dex
 bpl l15
 rts
;-------------------------------------------------------------------------------- 
axis                        ; do player physics for one axis
 sta w2

 tya
 beq s17
 cmp #$80
 ror
 pha
 and #$80
 clc
 adc #$40
 adc p_vxl,x
 sta p_vxl,x
 pla
 adc p_vxh,x
 sta p_vxh,x
s17

 clc
 lda p_xl,x
 adc p_vxl,x
 sta p_xl,x
 lda p_xh,x
 adc p_vxh,x 
 cmp w2
 bcc s18
 ldy #0
 sty p_xl,x
 sty p_vxl,x
 sty p_vxh,x
 cmp #248
 lda w2
 bcc s18
 tya
s18
 sta p_xh,x
 
 lda p_vxl,x
 sta w0
 lda p_vxh,x
 cmp #$80
 ror A
 ror w0
 cmp #$80
 ror A
 ror w0
 sta w1
 lda p_vxl,x
 sec
 sbc w0
 sta p_vxl,x
 lda p_vxh,x
 sbc w1
 sta p_vxh,x
 rts
;-------------------------------------------------------------------------------- 
rand                        ; Galois LFSR random number generator
 ldy #8
 lda lfsr+0
l17
 asl
 rol lfsr+1
 bcc s19
 eor #$2d
s19
 dey
 bne l17
 sta lfsr+0
 rts
;-------------------------------------------------------------------------------- 
digit                       ; draw 4*8 pixel digit
 and #$3c 
 clc
 adc #<DIGS
 sta m01+1

 ldy #15
l18
 ldx #3
m01
 lda DIGS
l19
 pha 
 and #3
 asl
 asl
 sta w3
 asl
 asl
 ora w3
 sta (da),y 
 pla
 lsr
 lsr
 dey
 dex
 bpl l19
 inc m01+1
 tya
 bpl l18
 
 lda da
 sbc #16    
 sta da
 rts
;-------------------------------------------------------------------------------- 
asl16                       ; 16-bit variable shift left
 asl
 rol w1,x
 dey
 bne asl16
 sta w0,x
 inx
 inx
out
 rts
;-------------------------------------------------------------------------------- 
plot_s                      ; plot function with entry points
 ldx #O_STR
 .byte $2c 

plot_b
 ldx #O_BLN

plot
 stx m02+1

 ldx #0
 stx w5
 stx w3
 stx w1 
 stx hit

 sty w7
 lsr w7
 adc #$98
 ldy #5 
 jsr asl16

 lda w8
 and #7
 sta w6

 lda w8
 lsr
 lsr
 lsr
 sta w2
 asl
 asl
 adc w2
 ldy #7
 jsr asl16
 lda w7
 ldy #3
 jsr asl16
 adc w6
 adc w2    
 sta w2
 lda w3
 adc w5
 adc #$30  
 sta w3

 lda #9     
 sbc w6    
 clc
 jsr stripe

 lda w4     
 adc w0
 sta w0 
 lda w2
 and #$f8
 adc #$80
 sta w2
 lda w3
 adc #$02
 sta w3 
 ldy w4
 lda w6     
 sty w6 
 beq out    

stripe
 sta w4
 lda #4
 sta w5
 ldy #0
m02
 bvc pad
;--------------------------------------------------------------------------------   
pad                         ; kernels
p
 jsr col

 lda w2
 adc #8
 sta w2
 txa
 tay
 adc w3
 sta w3
 
 jsr store

col 
 ldx w4
 lda #60
l21
 sta (w2),y
 iny
 dex
 bne l21 
 rts

store
s
 lda #f-slow  
 .byte  $24

blend
b
 tya
 
 sta m03+1 

l22
 ldx w4
l23
 lda (w0),y    
m03 
 bpl fast  
slow
 asl a   
 bmi bits_x1   
 lda (w2),y
 bcs bits_10   
bits_00
 cmp #$3c
decide 
 beq commit
 sta hit
commit   
 eor (w2),y    
 ora (w0),y    
 and #$3f
fast
f
 sta (w2),y 
bits_11
 iny
 dex
 bne l23
 tya
 clc
 adc w6
 tay
 dec w5
 bne l22
 rts
bits_x1    
 bcs bits_11
 lda (w2),y
bits_01    
 and #$aa  
 cmp #$28  
 bvc decide 
bits_10    
 and #$55  
 cmp #$14  
 bvc decide
;-------------------------------------------------------------------------------- 
zpage                       ; zero-page and hardware initialisation data
 .word $ffff
 .word $3000
 .word $40b0
 .word $d020 
 .word $2210
 .word $5701
 .word $6607
 .word $4941
 .word $6137
 .word $0c01
 .word $3000

 .word $1454
 .word $037f
 .word $aa02

 .word $2021
 .word $4043
 .byte $4d
