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

The last point is important, because it's where we get the term "leet" (((or "l33t"/"1337"))) from. Every cracker's group was an exclusive club[^1] and you had to be "elite" (((an access rank))) to get your grubby mitts on the good stuff.

[^1]: This was in the time before the World Wide Web, so communication was done via Bulletin Board Systems ((("BBSes"))), a half-way house between e-mail lists and the forums that we would recognise today. It's also important to note that BBSes were not part of the Internet and each BBS was a specific computer in somebody's home that users phoned into with their computers.

Back then, source code was never provided (((just transferring binaries could be an all-night job))) and you were expected to learn from disassembling other's work.

Old habits die hard, and even though you'll find a lot of C64 projects on GitHub, it's not where the Real Work^TM gets done in the community.

To someone like me, having experienced both the 20th and the 21st Centuries (((and the changes in the computing landscape they have wrought))), I've witnessed the widening of the generational gap between the way things worked in the '90s -- copy+paste, physical manuals, lots of forum silos -- versus how things are (((were!))) done in the 2010s -- open-source, distributed (((Git))) & all-encompassing social-media platforms.

:: Why nücomer?
--------------------------------------------------------------------------------
All of the code that both produces this magazine on the PC, and runs it on the C64, is open-source and available to examine;

* <github.com/Kroc/nucomer>

Whilst I have commented the code to an excessive degree, this article is about the decisions made for the initial approach and the issues encountered along the way.

To someone entirely new to 8-bit machines, it's perfectly natural (((if naïve))) to assume that one just writes a text file, "puts" it on the C64 and loads it up; job done, go home.

For the Commodore 64, despite being a keyboard-driven machine advertised for its productivity capabilities[^2], putting text on the screen is a surprisingly abstruse task, as we are about to learn!

[^2]: The North American video-game crash of 1983 meant that labelling any computer as a "game" was considered a death-wish. It was with no small amount of consternation that Nintendo's "Family Computer" (Famicom) was rebranded an "Entertainment System" in the West. So anathema was the mention of "video games" to retailers that marketing of home micro-computers was heavily biased toward education & productivity even if, especially in the case of the C64, it was used primarily as a games machine.

:: Introducing PETSCII:
--------------------------------------------------------------------------------
The C64 does not use ASCII, or at least  ASCII as you know it. To explain why, we need to set the way-back machine to 1977 when the first "turn key" (((you didn't have to assemble it yourself))) home microcomputers became available to buy with the Apple II, Commodore PET & the RadioShack TRS-80, collectively known as the Trinity.

Next to these three our modest C64 would be considered a super-computer. With just 4096 bytes of RAM, standard, graphics were out of the question[^3]. All three shipped without lower-case letters, opting instead to populate the character set with a series of "block graphics" akin to a symbol-font, like WingDings that you might recognise today. By arranging these blocks on screen, rather chunky and crude graphics could be produced, typically just 80 'pixels' wide.

[^3]: Excepting the Apple II which had a quirky space-saving graphics mode (((if you had at least 8K RAM))) that was difficult to use, but then that's the genius of Steve Wozniak for you.

Even though the ASCII used in computers today had already been standardised by 1968, Commodore opted to use the earlier 1963 standard -- lacking lower-case, underscore, and curly braces[^4] -- and extended it to their design, to be known as PETSCII.

[^4]: ASCII was based on earlier 5-bit (((32 character))) automated telegram codes, which had no use for case or punctuation. What's more, until the home microcomputer revolution, a byte was not guaranteed to be 8-bits wide; IBM often used 6-bit bytes (((64 characters))), another reason why early computers only ever used upper-case letters -- ASCII has 96 printable characters.

SHOUTING IN ALL-CAPS might be okay for 1977 but demand was growing for lower-case, given the exploding computer word-processing market in the early '80s. Given that the PETSCII character set was already set in stone and backwards compatibility was important to users, many of whom had been burned on the myriad of failed incompatible systems released during the boom, Commodore introduced lower-case on the C64 by means of a simple, but effective kludge.

The hardware, being 8-bit, could not index more than 256 characters, so it was not possible to simply 'append' more to the end. What they did was to have two character sets, and electrically flip between them by tricking the video hardware to see either the lower or upper 2K half of a 4K ROM containing the character graphics. In the lower-case set (((upper-half of ROM!))), many PETSCII graphic symbols were sacrificed to fit the lower-case characters.

The downside of this approach is that you only get one or the other. If you want to use lower-case letters with the card suit characters (((spade, club, diamond, heart))) then tough luck, you can't!

Naturally, there are ways around this, but we shall get to those in due time.

:: Introducing Screen Codes:

What's often overlooked about ASCII today is that is was designed primarily as a communications encoding, that is, a stream of commands being sent over the wire, and not necessarily as the storage format; after all, mainframes at the time natively used 36-bit 'words' and would typically bit-pack six, 6-bit characters per word.

Prior to the home computer revolution, there were no computers on desks, but there might have been a screen and keyboard: a dumb-terminal, connected to the real computer in the basement, receiving key-strokes and sending out text in response.

Have you ever noticed, or wondered why, ASCII has a code for "bell" (((0x7)))? This is a control code to make the terminal beep! For example, if the user entered an invalid date. It would not make sense to store a bell character in a database!

Likewise PETSCII is a really a method of *controlling* output on a C64; a string can contain characters for changing the text colour, moving the cursor around, and even switching the character set used for the whole screen.