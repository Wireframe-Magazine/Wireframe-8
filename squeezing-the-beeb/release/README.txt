A few notes.

How to build
------------

Building the resources requires python 2.7 with pygame. Type:

python gfx.py > gfx.s

Building the binary files requires atasm or equivalent:

http://atari.miribilist.com/atasm/

Type:

atasm -r gfx.s
atasm -r -DHACKADAY_1K=1 -DHACKADAY_2K5=0 copter.s -othin.bin
atasm -r -DHACKADAY_1K=0 -DHACKADAY_2K5=1 copter.s -ofat.bin

How to start
------------

Load the disk image "copter.ssd" into your hardware or emulator (we
recommend BeebEm for this).

If using real hardware, set up the keyboard links to boot into graphics
mode 2 (see below).

If using an emulator which doesn't support the keyboard links, change 
to mode 2 on startup by typing:

MODE 2

To run the "fat" version, type:

*LOAD GFX
*RUN FAT

To run the "thin" version, type:

*RUN THIN

BASIC scripts "GOFAT" and "GOTHIN" are provided to automate these 
steps. At startup, type:

CHAIN "GOFAT"

or:

CHAIN "GOTHIN"

How to play
-----------

Use Z and X to move the helicopter (green block in the thin version) 
left and right, and "shift" to thrust upward. Avoid the birds (red 
blocks) and collect coins (yellow blocks). Each coin you collect on a
single trip doubles your bonus:

    coins           bonus
        1               1
        2               2
        3               4
        4               8
        5              16
        6              32
        :               :
        
when you hand on the platform, the bonus is added to your score and
zeroed, and you receive a new load of fuel. The aim of the game is
simply to get the highest possible score.

If you run out of fuel (indicated by the red bar), you lose the ability
to thrust upward, though you can still land if you're nimble enough. If
you collide with a bird or miss the platform, you die. Press space to 
start a new game.

Accessing hardware
------------------

On top of writing data to the display, we need to interact with the
hardware in a couple of ways. The OS ROM is off limits, so we have to
do this the old-fashioned way.

We poll for vblank by reading bit 1 of the system 6522 VIA interrupt 
status register at $fe4d. The vblank status is cleared by writing to 
the same register. We clear the vblank status immediately before the 
main loop to ensure we're in sync from the very first frame, as 
otherwise we see some flicker early on.

We scan the keyboard by disabling keyboard auto-scan at start of day,
and then writing to and reading from the slow databus at address $fe4f. 
The (completely insane) annotated disassembly for Exile here:

http://www.level7.org.uk/miscellany/exile-disassembly.txt

was very helpful in figuring out how to do this.

Drawing sprites
---------------

The BBC Micro lacks hardware sprite support, so all our moving objects 
(birds, coins, the helicopter, the platform) need to be drawn to the
framebuffer in software. This is made more exciting by the BBC's odd
screen memory layout. Each byte contains two pixels interleaved in bits 
(6,4,2,0) and (7,5,3,1), and pixel-pair byte addresses look like this:

  0   8  16  ..
  1   9  17  ..
  2  10  18  ..
  3  11  19  ..
  4  12  20  ..
  5  13  21  ..
  6  14  22  ..
  7  15  23  ..
 640 648
 641 649
 642 650
  :   :

Our sprites are all 7*8 pixels in size (allowing us to support odd x
coordinates using pre-shifted copies). The function "plot" does the 
necessary setup and uses one of three kernels ("pad", "store" and 
"blend") to do the actual writing.

Blend is the most interesting kernel. It uses a per-pixel mask stored
in the "spare" senior bit of each pixel (the BBC Micro only supports
8 colors, so only three bits are required for the full palette) to do
pixel-accurate masking and hit detection.

Chasing the raster
------------------

The game runs in graphics mode 2, whose framebuffer consumes 20K of the
32K of available RAM. Double buffering is out of the question, so to
get flicker-free graphics we must carefully manage the position of the
raster. In summary:

- The game runs "in a frame" at 50Hz.
- Frame processing starts immediately at the start of vblank.
- Coins and birds never overlap, and are designed to be self-erasing;
  the bird in particular is drawn padded with a pair of trailing cyan
  pixels to obscure its trail. This minimizes any artefacts that occur
  if the raster intersects the object while it is being drawn.
- The order of operations is
    - Optional status bar and sea update (see below)
    - Do helicopter control model
    - Erase helicopter
    - Draw coins
    - Draw birds
    - Draw helicopter
    - Optional status bar and sea update (see below)
- The status bar and sea can be drawn either first or last:
    - If the helicopter is in the top half of the screen, they are
      drawn first, to allow the raster time to reach the bottom half.
    - If the helicopter is in the bottom half of the screen, they are
      draw last, so the helicopter has been redrawn before the raster
      reaches it.

6502 miscellany
---------------

We use only the base, official NMOS 6502 instructions: no 65C02 
extensions or unofficial opcodes (though I would dearly have loved to
resort to STZ on occasion). There's a fair bit of self-modifying code
to:

- update address fields of load instructions to avoid zero-page setup
- implement cheap computed branches
- dynamically specialize the blend kernel to a store kernel

We use the 1- and 2-byte BIT hacks in a couple of places to provide
multiple entry points to functions.

A lot of effort went into flag propagation analysis to allow us to 
remove clc and sec instructions and substitute known-taken branches
(in particular bvc) for jumps.

Eligibility
-----------

The baseline "fat" version of the game is 1010 bytes in length, and
loads to address $880. It requires a 1492-byte sprite and font file to
be loaded at address $1300. You could stick your neck out and argue
that this meets the spirit of the rules: the user can substitute any
graphics of their choosing at this location (a script, gfx.py, is
provided for this purpose) to customize the game, and so the graphics
constitute "input".

On the other hand, you could argue this is bulls^H^H^H^H^Htendentious,
and that graphics constitute "initialized data tables", and so count
against the 1024-byte limit. To hedge against this, we've provided
a "thin" version. This is exactly 1024 bytes in length, and includes
both a numeric font and compressed "pong-o-vision" set of block
graphics.

One last point: the BBC Micro must already be in graphics mode 2 when
the program is started. Why is this permissible, when OS code must
have been executed to configure the graphics hardware? Well, handily
it is possible to configure the startup video mode using three links at
the front of the PCB circuit board (see page 489 of the Advanced User
Guide here: http://tinyurl.com/zjlwjk6). Video mode setup therefore
occurs during an "unavoidable hardcoded bootloader".

Credits
-------

Code by Eben Upton. Graphics by Sam Alder and Alex Carter, based on
resources developed for an event at the Centre for Computing History
in Cambridge.
