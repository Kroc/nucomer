:: Editorial: Why 8-Bit?
--------------------------------------------------------------------------------
by Kroc Camen / Camen Design

Welcome, Newcomer.

Why would anybody want to spend any time using, let alone programming, 30 or 40 year old computers thousands, even millions, of times more limited than their own PC or phone if they've never seen or heard of them before -- if nostalgia played no part?

Those who grew up with 8-bit computers in their youth have a fond connection with these systems, based on a measure that exceeds technical capability alone -- memories! But the scene faces a cliff-edge into a void of forgotten human memory. As each of us falls into this void, who will there be left to remember the C64, to keep bearing the torch?

From the day I received a Commodore 64, rather late in the game in 1991, I have been an outsider looking in. There was no scene for me; the days of the Commodore 64 being the hottest tech in town had long past and either way I never had any connections. There were no kids to swap cracked games with, there was no BBSes to dial in to -- this was the UK, where there was neither the infrastructure nor the affordability; disk drives had been expensive and uncommon, and modems even less so.

For me, the Commodore 64 was my own private world. With just games and manuals I could pick up cheap from local car-boot sales (think giant open-air thrift markets), I set about learning everything I could about this machine. And that's what sets 8-bit systems apart today. It is entirely possible to know and understand literally everything there is to know about the C64, right down to the electrical level. With total knowledge of a single machine, the possibilities are endless. But without a scene, without feedback, without encouragement, without direction, I could never achieve anything concrete; always full of ideas, but lacking the disciplined coding skills to take my ideas through to fruition.

Mentorship is the critical difference between a consumer and a creator.

30 years after I began my C64 journey, I'm aware of my adeptness at learning whatever tool is necessary for the job and to retain detailed technical information. I have no doubt that had I had access to the scene at the time, and a mentor to guide me, I could be just as good a demo-coder as any other.

For every skill I've learned and every community I've discovered I have always appraised myself as the outsider looking in, bringing with myself the experience of a newcomer, but critically, determined to build up the path behind me so that others do not have as hard a time as I had finding the way.

This publication exists to implore, educate and demonstrate the satisfaction that comes from 8-bit systems and software, particularly the Commodore 64 (we'll get to why in a moment). It is my sincere hope that you, the reader, have had to expend the least amount of effort in getting to this point. Maybe you're reading this in an emulator, in a web browser, and that is fine with me.

Elitist arguments about "original hardware" must be pushed back. Those with a nostalgic connection to the C64 must be willing to give their knowledge to a future world in which there is no original hardware, only de-facto standards.

In reality, modern hardware and the Internet are where people are productive today and Nücomer will never communicate in ignorance of this fact. There are plenty of tutorials and resources out there on setting up a PC development environment and writing your first lines of code for an 8-bit system, I cannot do that within the confines of the C64's RAM & storage! Instead, Nücomer explores the "why"; why you should solve a programming problem in a certain way; why 8-bit systems are the way they are; why you should care.

:: Why The Commodore 64?
--------------------------------------------------------------------------------
So why the Commodore 64, of all 8-bit systems?

Unlike today's "flavours of x86" PC market, the 8-bit generation of home-microcomputers ran on a variety of wildly different processor architectures.

The Zilog Z80 CPU -- an independently enhanced Intel 8080, and therefore a "cousin" to x86 -- featured in the ZX Spectrum (Timex Sinclair in the USA), Amstrad CPC, Tandy / RadioShack TRS 80, innumerable CP/M business systems, the MSX standard popular in Japan and later in consoles such as the SEGA Master System and, in a stripped down form, as the Nintendo Game Boy.

Programming the Z80 is fairly easy given its very large number of registers for an 8-bit system (over 20!) and how easily it handles 16-bit operations; the index registers are 16-bit as is the stack. A 16-bit add instruction means that you don't have to 

:: In This Issue:
--------------------------------------------------------------------------------
In this, the 0th issue -- zero because it can't be a true magazine until it's had feedback and outside input -- we look at the code & design of the magazine outfit itself; the challenges of even getting some text on the screen.

In "Help! My Interrupt Crashed!" I explain how an incremental approach to implementing custom interrupts will only lead to nightmarish bugs and provide a breakdown of the C64's interrupt "gotcha's".

"BSOD64: BRK Dancing" introduces our C64 debugger designed for users writing their first software for the platform, and explains how debugging works on the C64.