# resource building python script
# really terrible code, but no time to fix

import random, pygame, sys
from pygame.locals import *

#             R    G    B
BLACK     = (  0,   0,   0, 255)
RED       = (255,   0,   0, 255)
GREEN     = (  0, 255,   0, 255)
YELLOW     =(255, 255,   0, 255)
BLUE      = (  0,   0, 255, 255)
MAGENTA   = (255,   0, 255, 255)
CYAN      = (  0, 255, 255, 255)
WHITE     = (255, 255, 255, 255)

COLORS = {BLACK : 0, RED : 1, GREEN : 4, YELLOW : 5, BLUE : 16, MAGENTA : 17, CYAN : 20, WHITE : 21}

FILES = [
    ("bird-1.png",0,1,CYAN),
    ("bird-1.png",0,0,CYAN),
    ("bird-1.png",1,1,CYAN),
    ("bird-1.png",1,0,CYAN),
    ("bird-2.png",0,1,CYAN),		
    ("bird-2.png",0,0,CYAN),		
    ("bird-2.png",1,1,CYAN),		
    ("bird-2.png",1,0,CYAN),		
    
    ("bird-3.png",0,1,CYAN),
    ("bird-3.png",0,0,CYAN),
    ("bird-3.png",1,1,CYAN),
    ("bird-3.png",1,0,CYAN),
    ("helicopter-1.png",0,1),
    ("helicopter-1.png",0,0),
    ("helicopter-1.png",1,1),
    ("helicopter-1.png",1,0),
    
    ("helicopter-2.png",0,1),
    ("helicopter-2.png",0,0),
    ("helicopter-2.png",1,1),
    ("helicopter-2.png",1,0),
    ("helicopter-3.png",0,1),
    ("helicopter-3.png",0,0),
    ("helicopter-3.png",1,1),
    ("helicopter-3.png",1,0),
    
    ("coin-1.png",0,0),
    ("coin-2.png",0,0),    
    ("coin-3.png",0,0),
    ("coin-4.png",0,0),
    ("platform-edge.png",0,1),
    ("platform-edge.png",0,0),
    ("platform-center.png",0,1),
    ("platform-center.png",0,0),
    
    ("platform-edge.png",1,1),
    ("platform-edge.png",1,0),
    ("sea-1.png",0,0),
    ("sea-1.png",0,8),
    ("sea-2.png",0,0),
    ("sea-2.png",0,8),
    ("sea-3.png",0,0),
    ("sea-3.png",0,8),
    
    ("cyan.png",0,0),
    ("cyan.png",0,0)
]

def get_at(image, p, d):
    try:
        return image.get_at(p)
    except:
        return d
       
def tileToWords(name, flip, off, d):
    image = pygame.image.load(name)    
    
    w = [0 for i in range(8)]

    for y in range(8):
        for x in range(8):
            rgba = get_at(image, ((8-(x+off) if flip else x+off)*2,y), d)
            
            w[(y>>2)+(x>>1)*2] |= (COLORS[(rgba[0], rgba[1], rgba[2], rgba[3])] if rgba[3] else 64) << (1-(x&1)+(y&3)*8)
            
    return w

def numberToBytes(image, off):
    b = [0 for i in range(4)]

    for y in range(8):
        for x in range(4):
            b[3-(x&2)-(y>>2)] |= (0 if get_at(image, (off+x*2, y), (0, 0, 0, 0))[0] == 0 else 1) << (1-(x&1)) + ((3-(y&3))<<1)
            
    return b

image = pygame.image.load("font.png")

print "\n".join(["; build me with atasm", ";", "; atasm -r gfx.s", "", "*=$1300"]+["\n".join([("        .word $%04x, $%04x" % (i&0xffff, i>>16)) for i in tileToWords(f[0], f[1], f[2], f[3] if len(f) == 4 else (0, 0, 0, 0))]) for f in FILES]+["\n".join([("        .byte $%02x" % i) for i in numberToBytes(image, i*8)]) for i in range(37)])

