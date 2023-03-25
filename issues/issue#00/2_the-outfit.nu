:: The Outfit:
--------------------------------------------------------------------------------
So you decide to write a disk-magazine for the Commodore 64; all of the existing ones look super impressive so you first search *GitHub* for any open-source disk-mag code;

Congratulations, you have discovered that there are none (((~nücomer~ is the first))), and learnt your first important truth about the C64 hacking scene;

Being born, as it was, in the 1980s, before PCs were common, before the World Wide Web -- when transferring data between two computers meant literally dialling up the other person's house on a phone and getting the machines to scream at each other down the line -- and being born of the desire to crack and pirate games, the scene had neither a concept of intellectual rights nor licences. Even to this day, the scene operates on an unwritten gentleman's agreement whose details have been shaped and refined by decades of flame wars:

* *You may take and reuse, so long as you haven't been told not to*

* *You must never claim as your own, something you did not write*

* *Don't just copy+paste. Learn the principle and make something new*

* *Respect the rules before breaking them* -- via <@conspiracyhu>

* *Don't be lame*

The scene was the ultimate teenager's "brag & slag" contest, with each cracking group trying to beat the others to the latest release. In this intensely competitive environment, people kept their cards close to their chest.

The last point is important, because it's where we get the term "leet" (((or "l33t"/"1337"))) from. Every cracker's group was an exclusive club[^a] and you had to be "elite" (((an access rank))) to get your grubby mitts on the good stuff.

[^a]: This was in the time before the World Wide Web, so communication was done via Bulletin Board Systems ((("BBSes"))), a half-way house between e-mail lists and the forums that we would recognise today. It's also important to note that BBSes were not part of the Internet and each BBS was a specific computer in somebody's home that users phoned into with their own computer.

Back then, source code was never provided (((just transferring binaries could be an all-night job))) and you were expected to learn from disassembling other's work.

Old habits die hard, and even though you'll find a lot of C64 projects on ~GitHub~, it's not where the Real Work^TM gets done in the community.

To someone like me, having experienced both the 20th and the 21st Centuries (((and the changes in the computing landscape they have wrought))), I've witnessed the widening of the generational gap between the way things worked in the '90s -- copy+paste, physical manuals, lots of forum silos -- versus how things are (((were!))) done in the 2010s -- open-source, distributed (((Git))) & all-encompassing social-media platforms.

:: Why nücomer?
---------------
To bridge a gap, although the analogy is closer to repairing a bridge that's constantly on fire and falling apart.

All of the code that both produces this magazine on the PC, and runs it on the C64, is open-source and available to examine;

* <github.com/Kroc/nucomer>

Whilst I have commented the code to an excessive degree, this article is about the decisions made for the initial approach and the issues encountered along the way.

The first decision was simply to produce the content on the PC rather than on the C64 itself. There are benefits on both sides, but since the goal was accessibility to modern-minded developers there was no other choice than to cross-develop.

PC-based development brings its own challenges in just getting text from one machine to another. To someone entirely new to 8-bit machines, it's perfectly natural (((if naïve))) to assume that one just writes a text file, "puts" it on the C64 and loads it up; job done, go home.

For the Commodore 64, despite being a keyboard-driven machine advertised for its productivity capabilities[^b], putting text on the screen is a surprisingly abstruse task, as we are about to learn!

[^b]: The North American video-game crash of 1983 meant that labelling any computer as a "game" was considered a death-wish. It was with no small amount of consternation that Nintendo's "Family Computer" (Famicom) was rebranded an "Entertainment System" in the West. So anathema was the mention of "video games" to retailers that marketing of home micro-computers was heavily biased toward education & productivity even if, especially in the case of the C64, it was used primarily as a games machine.

:: Introducing PETSCII:
-----------------------
The C64 does not use ASCII, or at least  ASCII as you know it. To explain why, we need to set the way-back machine to 1977 when the first "turn key" (((you didn't have to assemble it yourself))) home micro-computers became available to buy with the Apple II, Commodore PET & the RadioShack TRS-80, collectively known as the Trinity.

Next to these three our modest C64 would be considered a super-computer. With just 4096 bytes of RAM, standard, graphics were out of the question[^c]. All three of the Trinity shipped without lower-case letters, opting instead to populate the character set with a series of "block graphics" akin to a symbol-font, like WingDings that you might recognise today. By arranging these blocks on screen, rather chunky and crude graphics could be produced, typically just 80 'pixels' wide.

[^c]: Excepting the Apple II which had a quirky space-saving graphics mode (((if you had at least 8K RAM))) that was difficult to use, but then that's the genius of Steve Wozniak for you.

Even though the ASCII used in computers today had already been standardised by 1968, Commodore opted to use the earlier 1963 standard -- lacking lower-case, underscore, and curly braces[^d] -- and extended it to their design, to be known as PETSCII.

[^d]: ASCII was based on earlier 5-bit (((32 character))) automated telegram codes, which had no use for case or punctuation. What's more, until the home microcomputer revolution, a byte was not guaranteed to be 8-bits wide; IBM often used 6-bit bytes (((64 characters))), another reason why early computers only ever used upper-case letters -- ASCII has 96 printable characters.

SHOUTING IN ALL-CAPS might be okay for 1977 but demand was growing for lower-case, given the exploding computer word-processing market in the early '80s. Given that the PETSCII character set was already set in stone and backwards compatibility was important to users, many of whom had been burned on the myriad of failed incompatible systems released during the boom, Commodore introduced lower-case on the C64 by means of a simple, but effective kludge.

The hardware, being 8-bit, could not index more than 256 characters, so it was not possible to simply 'append' more to the end. What they did was to have two character sets, and electrically flip between them by tricking the video hardware to see either the lower or upper 2K half of a 4K ROM containing the character graphics. In the newer mixed upper & lower-case set, many PETSCII graphic symbols were sacrificed to fit the lower-case characters.

The downside of this approach is that you only get one or the other. If you want to use lower-case letters with the card suit characters (((spade, club, diamond, heart))) then tough luck, you can't!

Naturally, there are ways around this, but we shall get to those in due time.

What's often overlooked about ASCII today is that it was designed as a communications encoding: a stream of commands being sent over the wire, and not necessarily as the storage format -- have you ever noticed, or wondered why, ASCII has a code for "bell"? (((0x7))) This is a control code to make an audible beep! For example, if the user entered an invalid date. It would not make sense to store a bell character in a database!

Prior to the home computer revolution, there were no computers on desks, but there might have been a screen and keyboard: a dumb-terminal, connected to the real computer in the basement, receiving key-strokes and sending out text in response.

Likewise PETSCII is really a method of *controlling* output on a C64; a string can contain codes for changing the text colour, moving the cursor around, and even switching the character set used ((for the whole screen only))).

This makes it extremely easy (((from BASIC))) to build screens, as layout and colour for a whole screen can be packed into a single string rather than having to construct the display using lines & lines of layout code.

I considered writing this mag' in BASIC (((to get it out quickly))) but for two reasons:
s

1. *BASIC is incredibly slow:*

Scrolling would be impossible. The C64 is not fast enough, even in machine code, to change the whole screen in less than one frame; that I've managed it in ~n�comer~ is only by way of some clever trickery and having to race the beam -- making changes to the screen just behind the line currently being sent to the display (((there's no "screen tear" because the change isn't seen until the screen output loops back to the top again))).

As an interpreted language BASIC isn't fast to start with, and Commodore's BASIC[^e] is not even fast by BASIC standards (((see BBC BASIC for the gold-standard in fast, and powerful, BASICs))). The speed shouldn't matter as far as the content is concerned, but if the content is about how the C64 works, our second point invalidates that assumption;

[^e]: If making IBM pay for every copy of MS-DOS was the best deal Bill Gates ever negotiated, then his deal with Commodore's "business is war" exec Jack Tramiel must be the worst. Jack demanded from MicroSoft (((a maker of BASICs for small & hobbyist kit-computers))) a perpetual licence to BASIC for their up-coming business computer (((the "PET"))) for a once-off sum of $25'000, vs. $3 per computer that Bill Gates was asking for. Needless to say, Commodore sold a lot of PETs.

2.* PETSCII is not how the machine actually works:*

PETSCII is an abstraction, a layer between you and the machine, made to make the machine easier to use. PETSCII codes are interpreted by the built in 'operating system' called "KERNAL"[^f] and the changes made to the hardware in no way matches what PETSCII implies.

[^f]: The Commodore ~KERNAL~ is often described as an Operating System to make it easier to understand to users of modern PCs, but it would be more accurate to call ~KERNAL~ a BIOS. Real operating systems are distinguished by having a "Hardware Abstraction Layer" that provides the same interface to software, regardless of hardware, whereas ~KERNAL~ is a fixed system that is coded directly for the hardware.

Data and commands are not "sent" to the Commodore's VIC-II chip, as one might expect with PC graphics cards; instead, the VIC-II has a more symbiotic relationship with the C64, like a Xenomorph.

The VIC-II takes some of its data from the C64's RAM, but it's important to understand that there is NO framebuffer![^g] The VIC-II generates the TV picture in real-time, line-by-line at the instant the TV is shooting electrons at the tube.

## link to Greg Nacu here

[^g]: The pedants in the audience will be shouting "but what about the C64's bitmap mode, that's a frame-buffer!", and whilst it is closer to a frame-buffer than text-mode, it isn't a single, linear memory space holding a complete frame -- for starters, the sprites are not part of the bitmap screen and are generated "live" by the VIC-II and secondly, the bitmap screen is not a contiguous RGB image some colour data is stored separately.

An individual RAM chip of the time was not able to read a full scan-line's worth of pixel+colour data fast enough to get the line out before the TV had moved onto the next. The solution to this was to read from multiple chips at the same time and combine the two bits of separate information;[^h] in the case of the C64, text characters and their colours are stored in separate chips.

[^h]: Systems with more colour capability than the C64 would use bit-planes to work around RAM speed limits, whereby each bit in a colour would be split into separate lanes. The disadvantage of this approach is that a single pixel colour is now split across 4 different memory addresses! Working with bit-planes is generally harder and slower than "chunky" (((in-order))) layouts.

```diagram-23456789012345678901234567890

   +------+                  +-------+
   |      |    +--------+    |       |
   | MAIN |    |        |    | COLOR |
   | RAM  +--->| VIC-II |<---+  RAM  |
   | 64KB |    |        |    |  1KB* |
   |      |    +-+------+    |       |
   +------+      |           +-------+
                 +-> pixels
```

What you're seeing when you power on a C64 is not a bitmap image (((in memory))) of some text. Whilst the C64 in particular has lots of RAM and can fit a bitmap image into 9 KB, for purposes of saving precious memory, nearly all 8-bit micro-computers default to a text-mode that only stores the character-codes and the video hardware assembles the actual pixels the instant they are needed.

For the C64's 40x25 text screen 1'000 bytes of the main RAM are used for the characters and another 1'000 bytes are in a separate chip, connected directly to the VIC-II, which are used for the colour of each respective character (((0-15))). Therefore, when a PETSCII code that changes the text colour is "printed", the colour is being written to a different chip than the characters are.

:: Introducing Screen Codes:
----------------------------------------------
With one byte for each character in a 40x25 grid it's apparent that the C64 can only display 1 of 256 possible characters in each cell; i.e. the C64 has only one, monospace, 8x8px "font"! This is where PETSCII falls apart, because PETSCII does not contain 256 characters! Some are control codes that change colour & move the cursor, and some do nothing at all! ((as with ASCII))).

To add insult to injury, the byte values for the printable characters in PETSCII, don't align with the screen-codes! 


Screen RAM does not contain ASCII/PETSCII character codes!

Now we can understand the relationship between each byte in "screen RAM" and the character ROM: the character ROM contains 256, 8x8 pixel character graphics. 





:: Compression
----------------------------------------------
Modern PC-based tools allow us to spend some fast computer time to save space in ways that could not be done developing on the machine itself; what might take seconds even on a 10 year old PC might take hours on an 8-bit microcomputer.

Compression is an art form best left to the experts and you'll save yourself a lot of time and effort (((that would be spent in much more productive areas))) by using an existing packer; the hard truth is that no custom compression scheme is going to outperform modern LZ-based packers.

~Exomizer~ is the packer most would recommend for ease of use; it can take single or multiple C64 programs and compress them into a combined, self-extracting program.

There is one reason, however, that ~nucomer~ uses a custom text-compression scheme and why the effort was justified (((even though I really should have waited until after the first issue was out the door))), and that is to simply fit more lines of text in RAM at runtime.

Unlike a general data packer however, we will need to be able to jump to any individual line in the data to print it. In fact, we'll need to do this anyway regardless of compression, so let's begin with looking at structuring the text data:

If we imagine lines of text in RAM, one immediately following another, then this is naturally easy to print a screen full of text, but what happens if we want to scroll UP, to the previous line of text that's NOT on screen? We can simply walk backwards through the wall of text until we find the beginning of the previous line line, right?

