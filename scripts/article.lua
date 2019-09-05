-- nücomer magazine (c) copyright Kroc Camen 2019. unless otherwise noted,
-- licenced under Creative Commons Attribution Non-Commercial Share-Alike 4.0
-- licence; you may reuse and modify this code how you please as long as you:
--
-- # retain the copyright notice
-- # use the same licence for your derived code
-- # do not use it for commercial purposes
--   (contact the author for a commercial licence)
--

-- article.lua : manages article text transformation

--------------------------------------------------------------------------------
-- this is the conversion table used to convert the source article characters
-- into screen-codes for the custom font used on the C64, which is not in any
-- guaranteed order, being instead a selection of only the necessary characters
-- and various pseudo-characters for typographic effects such as "smart quotes"
--
local str2scr = {
    -- we begin in ASCII order purely for easy comparison to the source ASCII
    -- text, and the need to replicate ASCII characters not within the C64 ROM,
    -- such as curly braces & back-slash
    --
    [" "]  = 0x00,  -- space
    ["!"]  = 0x01,
    ['"']  = 0x02,  -- straight quotes
    ["#"]  = 0x03,
    ["$"]  = 0x04,
    ["%"]  = 0x05,
    ["&"]  = 0x06,
    ["'"]  = 0x07,  -- straight apostrophe
    ["("]  = 0x08,
    [")"]  = 0x09,
    ["*"]  = 0x0a,
    ["+"]  = 0x0b,
    [","]  = 0x0c,
    ["-"]  = 0x0d,
    ["."]  = 0x0e,
    ["/"]  = 0x0f,

    ["0"]  = 0x10,
    ["1"]  = 0x11,
    ["2"]  = 0x12,
    ["3"]  = 0x13,
    ["4"]  = 0x14,
    ["5"]  = 0x15,
    ["6"]  = 0x16,
    ["7"]  = 0x17,
    ["8"]  = 0x18,
    ["9"]  = 0x19,

    [":"]  = 0x1a,
    [";"]  = 0x1b,
    ["<"]  = 0x1c,
    ["="]  = 0x1d,
    [">"]  = 0x1e,
    ["?"]  = 0x1f,
    ["@"]  = 0x20,

    ["A"]  = 0x21,
    ["B"]  = 0x22,
    ["C"]  = 0x23,
    ["D"]  = 0x24,
    ["E"]  = 0x25,
    ["F"]  = 0x26,
    ["G"]  = 0x27,
    ["H"]  = 0x28,
    ["I"]  = 0x29,
    ["J"]  = 0x2a,
    ["K"]  = 0x2b,
    ["L"]  = 0x2c,
    ["M"]  = 0x2d,
    ["N"]  = 0x2e,
    ["O"]  = 0x2f,
    ["P"]  = 0x30,
    ["Q"]  = 0x31,
    ["R"]  = 0x32,
    ["S"]  = 0x33,
    ["T"]  = 0x34,
    ["U"]  = 0x35,
    ["V"]  = 0x36,
    ["W"]  = 0x37,
    ["X"]  = 0x38,
    ["Y"]  = 0x39,
    ["Z"]  = 0x3a,

    ["["]  = 0x3b,
    ["\\"] = 0x3c,
    ["]"]  = 0x3d,
    ["^"]  = 0x3e,
    ["_"]  = 0x3f,
    ["`"]  = 0x40,

    ["a"]  = 0x41,
    ["b"]  = 0x42,
    ["c"]  = 0x43,
    ["d"]  = 0x44,
    ["e"]  = 0x45,
    ["f"]  = 0x46,
    ["g"]  = 0x47,
    ["h"]  = 0x48,
    ["i"]  = 0x49,
    ["j"]  = 0x4a,
    ["k"]  = 0x4b,
    ["l"]  = 0x4c,
    ["m"]  = 0x4d,
    ["n"]  = 0x4e,
    ["o"]  = 0x4f,
    ["p"]  = 0x50,
    ["q"]  = 0x51,
    ["r"]  = 0x52,
    ["s"]  = 0x53,
    ["t"]  = 0x54,
    ["u"]  = 0x55,
    ["v"]  = 0x56,
    ["w"]  = 0x57,
    ["x"]  = 0x58,
    ["y"]  = 0x59,
    ["z"]  = 0x5a,

    ["{"]  = 0x5b,
    ["|"]  = 0x5c,
    ["}"]  = 0x5d,
    ["~"]  = 0x5e,

    ["£"]  = 0x5f,  -- unicode, because Americans
    ["•"]  = 0x60,  -- bullet point
    ["–"]  = 0x61,  -- en-dash (hyphenation word-break / numerical-break)
                    -- em-dash is handled separately as it is two chars
    ["“"]  = 0x64,  -- left "smart-quotes"

    ["ç"]  = 0x7a,  -- as in façade
    ["è"]  = 0x7b,  -- as in "cafè"
    ["é"]  = 0x7c,  -- as in "née"
    ["ï"]  = 0x7d,  -- as in "naïve"
    ["ü"]  = 0x7e,  -- as in "nücomer"
}

-- convert ASCII string to the screen codes used by Nucomer
--------------------------------------------------------------------------------
function string:toC64 ()
    ----------------------------------------------------------------------------
    -- this happens
    if string.len(self) == 0 then return ""; end

    -- we need to do multi-character conversions (such as contractions),
    -- as well as the default character-to-screen-code conversion, so we
    -- walk through the string byte-by-byte, matching utf-8 characters
    -- forward
    --
    local s_out = ""
    local i = 0

    repeat
        ------------------------------------------------------------------------
        -- move to the next byte
        i = i + 1

        -- from the current position,
        -- try match a multi-byte sequence:
        --
        -- opening "smart" quote
        ------------------------------------------------------------------------
        if self:match("^\"%w", i) ~= nil then
            -- swap the quote for the other-way-around one
            s_out = s_out .. string.char(0x64)

        -- em-dash:
        ------------------------------------------------------------------------
        elseif self:match("^—", i) ~= nil then
            -- add as two C64 screen-codes!
            s_out = s_out .. string.char(0x62, 0x63)
            -- skip the extra byte
            i = i + 1

        -- "*'d" contractions:
        ------------------------------------------------------------------------
        elseif self:match("^%w'd ?", i) ~= nil then
            -- encode the character before the "'d"
            s_out = s_out .. string.char(str2scr[self:sub(i, i)])
            -- add the specialised "'d" character
            s_out = s_out .. string.char(0x70)
            -- move the index over the processed characters
            i = i + 2

        -- "I'm" contraction: (uses different character than "I'??")
        ------------------------------------------------------------------------
        elseif self:match("^I'm", i) ~= nil then
            -- encode using the special "I'*" character
            s_out = s_out .. string.char(0x71, 0x4d)
            -- move the index over the processed characters
            i = i + 2

        -- "*'ll'"
        ------------------------------------------------------------------------
        elseif self:match("^'ll ?", i) ~= nil then
            -- add the specialised "'l" character and a normal "l"
            s_out = s_out .. string.char(0x72, 0x4c)
            -- move the index over the processed characters
            i = i + 2

        -- "o'"
        ------------------------------------------------------------------------
        elseif self:match("^o'", i) ~= nil then
            -- add the specialised "o'" character
            s_out = s_out .. string.char(0x73)
            -- skip a byte
            i = i + 1

        -- "*'r" contractions:
        ------------------------------------------------------------------------
        elseif self:match("^%w'r", i) ~= nil then
            -- encode the character before the "'r"
            s_out = s_out .. string.char(str2scr[self:sub(i, i)])
            -- add the specialised "'r" character
            s_out = s_out .. string.char(0x74)
            -- move the index over the processed characters
            i = i + 2

        -- "*'s" contractions:
        ------------------------------------------------------------------------
        elseif self:match("^%w's", i) ~= nil then
            -- encode the character before the "'s"
            s_out = s_out .. string.char(str2scr[self:sub(i, i)])
            -- add the specialised "'s" character
            s_out = s_out .. string.char(0x75)
            -- move the index over the processed characters
            i = i + 2

        -- "'t*" contractions:
        ------------------------------------------------------------------------
        elseif self:match("'t%w", i) ~= nil then
            -- add the specialised "'t" character
            s_out = s_out .. string.char(0x76)
            -- skip a byte
            i = i + 1

        -- "*'ve" contractions:
        ------------------------------------------------------------------------
        elseif self:match("^%w've", i) ~= nil then
            -- encode the character before the "'ve"
            s_out = s_out .. string.char(str2scr[self:sub(i, i)])
            -- add the specialised "'ve" characters!
            s_out = s_out .. string.char(0x77, 0x78)
            -- move the index over the processed characters
            i = i + 3

        -- utf-8 characters that map to one c64 screen-code:
        ------------------------------------------------------------------------
        elseif self:match("^"..utf8.charpattern, i) ~= nil then
            -- capture the character; will be 1-4 bytes
            local s_utf8 = self:match("^"..utf8.charpattern, i)
            -- look up the C64 screen-code
            local i_scr = str2scr[s_utf8]
            -- if there is no conversion display an error mark
            if i_scr == nil then i_scr = 0xbf; end -- reverse "?"
            -- add to the C64 string
            s_out = s_out .. string.char(i_scr)
            -- skip over the excess bytes
            i = i + (#s_utf8-1)

        end

    until i >= #self

    return s_out
end

--------------------------------------------------------------------------------
local hyphenate = require "scripts.hyphenate"

for _, s_exception in pairs({
    -- where the hyphenation algorithm fails, I am referring to the
    -- "Collins Gem Dictionary Of English Spelling", 1994 reprint,
    -- ISBN: 0-00-458725-1
    "every-thing", "pri-vate"
}) do
    hyphenate:insertException("en-gb", s_exception)
end

-- do a mono-spaced word-break:
--
-- given a word and a remaining number of characters representing the space
-- within which to fit the word, hyphenate the word such that as much of it
-- as possible fits within the given space and return the remainder of the
-- word that will move to the next line of text
--------------------------------------------------------------------------------
function hyphenate:breakWord(s_locale, s_word, s_len)
    ----------------------------------------------------------------------------
    -- if the word already contains hyphens, then treat as multiple separate
    -- words for hyphenation; this allows us to resolve word-breaking for
    -- double-barreled words, such as... "double-barreled"... which must be
    -- hyphenated *and* retain their explicit hyphen, i.e. "dou-ble-bar-reled"
    --
    local words = s_word:split("-")

    local before = ""       -- the part of the word(s) before the line-break
    local after  = ""       -- the part of the word(s) after the line-break
    local broken = false    -- if word-break has occurred

    for i, word in ipairs(words) do
        -- once the word-break has occurred, all remaining words are added
        -- after the line-break with no further hyphenation required
        if broken then
            -- include the explicit hyphen between words;
            -- e.g. "cul-de-sac", which would not hyphenate as separate words
            after = after .. "-" .. word
        else
            -- split the word into hyphenation boundaries
            t_pieces = self:hyphenate(s_locale, word)

            -- with multiple words, we need to account for the explicit hyphen
            -- that must be preserved between words (e.g. "cul-de-sac"). when
            -- one word has already been added to the line and wrapping has
            -- not yet occurred we have to include the explicit hyphen
            if i > 1 then before = before .. "-"; end
            -- add word pieces until we can't fit any more on the line...
            for _, piece in ipairs(t_pieces) do
                -- if a word-piece could fit (including a trailing hyphen!)
                -- then add it (sans-hyphen) and try the next piece
                if broken == false and #before + #piece + 1 <= s_len then
                    before = before .. piece
                else
                    -- the word-piece does not fit!
                    -- add it after the line-break!
                    after = after .. piece
                    -- mark the line as broken so that all further pieces
                    -- will now be placed after the line-break
                    broken = true
                end
            end
        end
    end
    -- we use a hyphen-dash "-" (minus) to mark hyphens between words, but when
    -- a word is broken at a hyphenation point, an en-dash is used instead.
    -- in the instance of the line-break occuring on the explicit hyphen in
    -- double-barraled words, we must retain that style of hyphen and not
    -- add the en-dash as well!
    if #before > 0 and before:sub(-1) ~= "-" then
        before = before .. "–" -- this is a utf-8 en-dash, not a minus-dash!
    end

    return before, after
end

--------------------------------------------------------------------------------
Article = {
    infile      = "",
    outfile     = "",
    lines       = {}    -- table of converted lines in the article
}

-- create a new instance of the Article class
--------------------------------------------------------------------------------
function Article:new()
    ----------------------------------------------------------------------------
    -- crate new, empty, instance
    local article = {
        infile  = "",
        outfile = "",
        lines   = {}    -- table of converted lines in the article
    }
    setmetatable(article, self) -- set new instance to inherit from prototype
    self.__index = self         -- bind "self"
    return article              -- return the new instance
end

--------------------------------------------------------------------------------
function Article:read(s_infile)
    ----------------------------------------------------------------------------
    -- remember my name
    self.infile = s_infile
    -- get a line-reading iterator
    local f_lines,err = io.lines(self.infile)
    -- problem? exit
    if err then print ("! error: " .. err); os.exit(false); end

    -- TODO:
    -- due to the off-screen scrolling used on the C64, we need to add one
    -- blank line before the article and one-blank line after, though we
    -- strip excess leading / trailing lines first
    --
    -- add the leading line to account for the off-screen top row
    self:read_line("")

    -- walk each line and process
    for s_line in f_lines do
        self:read_line(s_line)
    end
    -- add the trailing line to account for the off-screen bottom row
    self:read_line("")
end

-- take an input line of ASCII text and create C64 line(s)
--------------------------------------------------------------------------------
function Article:read_line(s_text)
    ----------------------------------------------------------------------------
    -- create line-object to hold line meta-data
    local line      = Line:new()
    local index     = 0         -- current byte index in the line
    local ascii     = 0         -- current character
    local word_str  = ""        -- current word (for word-wrapping)
    local word_len  = 0         -- character length of word (not byte-length!)

    -- we do not want to leave trailing spaces on lines, so when a word begins,
    -- we hold on to the space until the word ends and decide where it goes
    -- based on the word-wrapping
    local word_spc  = 0         -- number of pending spaces once word ends

    -- (private) add character to the current word
    ----------------------------------------------------------------------------
    function add_char(i_char)
        ------------------------------------------------------------------------
        word_str = word_str .. string.char(i_char)
        word_len = word_len + 1
    end

    -- (private) append current word to the current line
    ----------------------------------------------------------------------------
    function add_word()
        ------------------------------------------------------------------------
        -- convert the word to C64 codes, as this may affect its length
        -- e.g. contractions using specialised single-characters
        local s_c64 = word_str:toC64()
        -- if the word will not fit on the line, hyphenate & word-wrap
        if line.length + #s_c64 + word_spc > 40 then
            -- hyphenate the word splitting into as much as can fit
            -- on the current line and the remainder for the next line
            local before, after = hyphenate:breakWord(
                -- split the word according to how much line space remains
                "en-gb", word_str, (40 - line.length) - word_spc
            )
            --#print(left, right)
            -- add the part of the word that fits (if any)
            if #before > 0 then
                -- add the pending spaces from before the word started
                if word_spc > 0 then
                    line:addString(string.rep(" ", word_spc))
                end
                -- add the hyphenated portion of the word
                line:addString(before)
                -- the pending spaces have been handled,
                -- don't add them again on the next line
                word_spc = 0
            end
            -- dispatch the current line
            add_line()
            -- begin the new line with the remainder of the word, if any.
            -- note that the unused pending space is carried forward
            if #after > 0 then line:addString(after); end
        else
            -- add the pending spaces from before the word started
            if word_spc > 0 then line:addString(string.rep(" ", word_spc)); end
            -- the word fits the line, add as is
            if word_len > 0 then line:addString(word_str); end
            -- the pending spaces have been handled,
            -- don't add them again on the next line
            word_spc = 0
        end
        -- reset the current word
        word_str = ""
        word_len = 0
    end

    -- (private) add the current line to the article and start another
    ----------------------------------------------------------------------------
    function add_line()
        ------------------------------------------------------------------------
        -- add line to the article line array
        table.insert(self.lines, line)
        -- start a new line
        line = Line:new()
    end

    -- look for special markup at the beginning of the line
    ----------------------------------------------------------------------------
    -- :: title
    --
    if s_text:match("^::") ~= nil then
        -- change the line's default style class
        line.default = 1
        -- move the index forward over the marker
        index = 3

    -- horizontal bar?
    -- ---------------
    elseif s_text:match("^%-%-%-%-") ~= nil then
        -- change the line's default style class
        line.default = 1
        -- build a horizontal bar directly out of screen-codes
        line:addC64(string.rep(string.char(0x7f), 40))
       -- no need to process any more of the source line
       -- just add the bar we've given and exit
       goto eol
    end

    -- convert em-dashes and consume optional spaces either side
    s_text = s_text:gsub(" ?%-%- ?", "—") -- note that this is an em-dash!

::next::
    ----------------------------------------------------------------------------
    -- move to the next character
    index = index + 1
    -- hit end of the line?
    if index > #s_text then goto eol; end

    -- read a single byte
    ascii = s_text:byte(index)

    -- space = word-break
    if ascii == 0x20 then
        ------------------------------------------------------------------------
        -- the current word is complete, add it to the line
        -- and handle the pending space according to word-wrap
        add_word()
        -- queue another space
        word_spc = 1

    --#-- punctuation that word-breaks after
    --#-- (we remove spaces after commas!)
    --#elseif s_text:match("^[%,] %l", index) then
    --#    ------------------------------------------------------------------------
    --#    add_char(ascii)     -- append the punctuation to the word
    --#    add_word()          -- append the word with punctuation attached
    --#    word_spc = 0        -- do not add a space before the next word
    --#    index = index + 1   -- skip the space!

    -- an em-dash is a word-break either side
    elseif s_text:match("^—", index) then
        ------------------------------------------------------------------------
        -- add current word, treating the em-dash as a word-break
        add_word()
        -- add the em-dash as its own word
        word_str = s_text:match("^—", index)
        word_len = utf8.len(word_str)
        add_word()
        -- skip the extra byte
        index = index + 1

    else
        ------------------------------------------------------------------------
        -- add to the current word
        -- (and handle word-wrap)
        add_char(ascii)
    end
    goto next

::eol::
    ----------------------------------------------------------------------------
    -- add the current word to the end of the line.
    -- this might cause an additional line-break!
    add_word()
    -- dispatch the final line
    add_line()
end

--------------------------------------------------------------------------------
function Article:write()
    ----------------------------------------------------------------------------
    -- (attempt) to open the output file
    local f_out,err = io.open(self.outfile, "wb")
    -- problem? exit
    if err then print ("! error: " .. err); os.exit(false); end

    -- write the PRG header
    f_out:write(string.pack("<I2", 0x3FFE))

    -- how long the line-lengths list is (2-bytes)
    f_out:write(string.pack("<I2", #self.lines+2))
    -- the list of line-lengths
    for _, line in ipairs(self.lines) do
        f_out:write(string.pack("B", line:getBinLen()))
    end
    -- the lines-length table is suffixed with $80
    -- to indicate when to stop scrolling downards
    f_out:write(string.pack("B", 0x80))

    -- and then the binary line-data
    for _, line in ipairs(self.lines) do
        -- do not output empty lines; on the C64, when a line-length of 0
        -- is encountered, the line-data pointer is not moved forward
        if line.length > 0 then f_out:write(line:getBin()); end
    end
end

--------------------------------------------------------------------------------
Line = {
    text        = "",       -- line text, encoded for the C64
    is_petscii  = false,    -- is this a PETSCII-only line?
    length      = 0,        -- length of line in characters, not bytes
    default     = 0,        -- default colour class
}

-- create a new instance of the Line class
--------------------------------------------------------------------------------
function Line:new()
    ----------------------------------------------------------------------------
    -- crate new, empty, instance
    local line = {
        text        = "",       -- line text, encoded for the C64
        is_petscii  = false,    -- is this a PETSCII-only line?
        length      = 0,        -- length of line in characters, not bytes
        default     = 0         -- default colour class
    }
    setmetatable(line, self)    -- set new instance to inherit from prototype
    self.__index = self         -- bind "self"
    return line                 -- return the new instance
end

-- add C64 screen-code(s) directly to the line, without conversion
--------------------------------------------------------------------------------
function Line:addC64(s_c64)
    ----------------------------------------------------------------------------
    self.text = self.text .. s_c64
    self.length = self.length + #s_c64
end

-- encode a utf-8 code-point for the C64 and add it to the line
--------------------------------------------------------------------------------
function Line:addChar(i_utf8)
    ----------------------------------------------------------------------------
    -- the conversion to C64 screen codes may yield
    -- more than 1 character, for example the em-dash
    self:addString(utf8.char(i_utf8))
end

-- encode a utf-8 string for the C64 and add it to the line
--------------------------------------------------------------------------------
function Line:addString(s_utf8)
    ----------------------------------------------------------------------------
    self:addC64(string.toC64(s_utf8))
end

-- returns the final binary form of the line
--------------------------------------------------------------------------------
function Line:getBin()
    -- binary string that will be returned
    local bin = ""
    -- non-default style class?
    if self.default ~= 0 then
        -- include the colour data
        bin = string.char(0x80 + self.default) .. bin
    end
    -- TODO: PETSCII-only lines with RLE-compression
    bin = bin .. self.text
    -- note that lines are written into the binary backwards!
    -- this is so that the line length can be used as a count-down
    -- index which is faster for 6502s to process
    return bin:reverse()
end

-- length of the binary line, including colour-data (if present)
--------------------------------------------------------------------------------
function Line:getBinLen()
    -- is there colour data?
    if self.default ~= 0 then
        -- mark line as having colour-data by setting the high-bit
        return string.len(self:getBin()) + 0x80
    else
        return string.len(self:getBin())
    end
end
