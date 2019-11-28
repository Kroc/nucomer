-- nücomer magazine (c) copyright Kroc Camen 2019. unless otherwise noted,
-- licenced under Creative Commons Attribution Non-Commercial Share-Alike 4.0
-- licence; you may reuse and modify this code how you please as long as you:
--
-- # retain the copyright notice
-- # use the same licence for your derived code
-- # do not use it for commercial purposes
--   (contact the author for a commercial licence)
--

-- string.lua : conversion of ASCII to C64 screen & colour codes
--------------------------------------------------------------------------------
-- nücomer provides 8 text styles (0 being the default)
--
STYLE_DEFAULT   = 0             -- default body text
STYLE_TITLE     = 1             -- structural; titles / lines
STYLE_BOLD      = 2             -- *bold*
STYLE_NOUN      = 3             -- ~noun~
STYLE_NAME      = 4             -- _name_
STYLE_SOFT      = 5             -- ((soft))
STYLE_URL       = 6             -- <url>
STYLE_WARN      = 7             -- !

-- escape codes are used in the source ASCII string to indicate
-- where style changes will occur in the ouput C64 string
ESC             = "\x1B"
ESC_DEFAULT     = ESC..tostring(STYLE_DEFAULT)
ESC_TITLE       = ESC..tostring(STYLE_TITLE)
ESC_BOLD        = ESC..tostring(STYLE_BOLD)
ESC_NOUN        = ESC..tostring(STYLE_NOUN)
ESC_NAME        = ESC..tostring(STYLE_NAME)
ESC_SOFT        = ESC..tostring(STYLE_SOFT)
ESC_URL         = ESC..tostring(STYLE_URL)
ESC_WARN        = ESC..tostring(STYLE_WARN)

-- this is the conversion table used to convert the source article characters
-- into screen-codes for the custom font used on the C64, which is not in any
-- guaranteed order, being instead a selection of only the necessary characters
-- and various pseudo-characters for typographic effects such as "smart quotes"
--
str2scr = {
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

    ["ç"]  = 0x7b,  -- as in "façade"
    ["è"]  = 0x7c,  -- as in "cafè"
    ["é"]  = 0x7d,  -- as in "née"
    ["ï"]  = 0x7e,  -- as in "naïve"
    ["ü"]  = 0x7f,  -- as in "nücomer"
}

-- convert ASCII string to the screen / colour codes used by nücomer
--------------------------------------------------------------------------------
function string:toC64 ()
    ----------------------------------------------------------------------------
    -- this happens
    if string.len(self) == 0 then return "", {}; end

    -- for each character, a style class is stored
    --
    local style  = STYLE_DEFAULT -- current style class
    local styles = {}            -- an array 0..n

    -- we need to do multi-character conversions (such as contractions),
    -- as well as the default character-to-screen-code conversion, so we
    -- walk through the string byte-by-byte, matching utf-8 characters
    -- forward
    --
    local out_str = ""
    local i = 0

    repeat
        ------------------------------------------------------------------------
        -- move to the next byte
        i = i + 1

        -- from the current position,
        -- try match a multi-byte sequence:
        --
        -- escape codes, for setting the style-class
        ------------------------------------------------------------------------
        if self:match("^\x1B%S", i) then
            -- skip over the escape code
            i = i + 1
            -- read the style class:
            if self:match("^[0-7]", i) then
                -- convert ASCII number to literal number 0-7
                style = self:byte(i)-0x30
            else
                -- literal character (not a valid escape)
                out_str = out_str .. self:sub(i, i)
                -- add style class for the added character(s)
                table.insert(styles, style)
            end

        -- opening "smart" quote
        ------------------------------------------------------------------------
        elseif self:match("^\"%w", i) then
            -- swap the quote for the other-way-around one
            out_str = out_str .. string.char(0x64)
            -- add style class for the added character(s)
            table.insert(styles, style)

        -- em-dash: "--"
        ------------------------------------------------------------------------
        elseif self:match("^%-%-", i) then
            -- how many bytes is that?
            local em = self:match("^%-%-", i)
            -- add as two C64 screen-codes!
            out_str = out_str .. string.char(0x61, 0x62)
            -- add style class for the added character(s)
            table.insert(styles, style)
            table.insert(styles, style)
            -- skip the extra bytes
            i = i + #em-1

        -- em-dash: (unicode)
        ------------------------------------------------------------------------
        elseif self:match("^—", i) then
            -- how many bytes is that?
            local em = self:match("^—", i)
            -- add as two C64 screen-codes!
            out_str = out_str .. string.char(0x61, 0x62)
            -- add style class for the added character(s)
            table.insert(styles, style)
            table.insert(styles, style)
            -- skip the extra (utf-8) bytes
            i = i + #em-1

        -- full-stop (further left than dot between characters)
        ------------------------------------------------------------------------
        elseif self:match("^%.%s", i)
            or self:match("^%.$", i) then
            -- add the special full-stop char
            out_str = out_str ..string.char(0x63)
            -- add style class for the added character(s)
            table.insert(styles, style)

        -- "... I ...":
        ------------------------------------------------------------------------
        elseif self:match("^ I ", i) then
            out_str = out_str .. string.char(0x70, 0x71)
            -- add style class for the added character(s)
            table.insert(styles, style)
            table.insert(styles, style)
            -- skip a couple of bytes
            i = i + 2

        -- "*'ll":
        ------------------------------------------------------------------------
        elseif self:match("^%w'll ?", i) then
            -- we process this before the "I'*" contraction because there's
            -- a separate contractor character for "I'*" to avoid needing
            -- special characters for "I'm" and "I'd"
            --
            -- encode the character before the "'ll"
            out_str = out_str .. string.char(str2scr[self:sub(i, i)])
            -- add the specialised "'l" character and a normal "l"
            out_str = out_str .. string.char(0x73, 0x4c)
            -- add style class for the added character(s)
            table.insert(styles, style)
            table.insert(styles, style)
            table.insert(styles, style)
            -- move the index over the processed characters
            i = i + 3

        -- "I'*":
        ------------------------------------------------------------------------
        elseif self:match("^I'%w", i) then
            -- encode using the special "I'*" character
            out_str = out_str .. string.char(0x72)
            -- add style class for the added character(s)
            table.insert(styles, style)
            -- skip a byte
            i = i + 1

        -- "o'":
        ------------------------------------------------------------------------
        elseif self:match("^o'", i) then
            -- add the specialised "o'" character
            out_str = out_str .. string.char(0x74)
            -- add style class for the added character(s)
            table.insert(styles, style)
            -- skip a byte
            i = i + 1

        -- "*'r":
        ------------------------------------------------------------------------
        elseif self:match("^%w'r", i) then
            -- encode the character before the "'r"
            out_str = out_str .. string.char(str2scr[self:sub(i, i)])
            -- add the specialised "'r" character
            out_str = out_str .. string.char(0x75)
            -- add style class for the added character(s)
            table.insert(styles, style)
            table.insert(styles, style)
            -- move the index over the processed characters
            i = i + 2

        -- "*'s":
        ------------------------------------------------------------------------
        elseif self:match("^%w's", i) then
            -- encode the character before the "'s"
            out_str = out_str .. string.char(str2scr[self:sub(i, i)])
            -- add the specialised "'s" character
            out_str = out_str .. string.char(0x76)
            -- add style class for the added character(s)
            table.insert(styles, style)
            table.insert(styles, style)
            -- move the index over the processed characters
            i = i + 2

        -- "'t":
        ------------------------------------------------------------------------
        elseif self:match("^'t", i) then
            -- add the specialised "'t" character
            out_str = out_str .. string.char(0x77)
            -- add style class for the added character(s)
            table.insert(styles, style)
            -- skip a byte
            i = i + 1

        -- "*'ve":
        ------------------------------------------------------------------------
        elseif self:match("^%w've", i) then
            -- encode the character before the "'ve"
            out_str = out_str .. string.char(str2scr[self:sub(i, i)])
            -- add the specialised "'ve" characters
            out_str = out_str .. string.char(0x78, 0x79)
            -- add style class for the added character(s)
            table.insert(styles, style)
            table.insert(styles, style)
            table.insert(styles, style)
            -- move the index over the processed characters
            i = i + 3

        -- 1st ordinal
        ------------------------------------------------------------------------
        elseif self:match("^1st[%s%p]", i) then
            -- replace the "st" with the special character
            out_str = out_str .. string.char(str2scr["1"], 0x6a)
            -- add style class for the added character(s)
            table.insert(styles, style)
            -- skip the extra bytes
            i = i + 2

        -- 2nd ordinal
        ------------------------------------------------------------------------
        elseif self:match("^2nd[%s%p]", i) then
            -- replace the "nd" with the special character
            out_str = out_str .. string.char(str2scr["2"], 0x6b)
            -- add style class for the added character(s)
            table.insert(styles, style)
            -- skip the extra bytes
            i = i + 2

        -- 3rd ordinal
        ------------------------------------------------------------------------
        elseif self:match("^3rd[%s%p]", i) then
            -- replace the "rd" with the special character
            out_str = out_str .. string.char(str2scr["3"], 0x6c)
            -- add style class for the added character(s)
            table.insert(styles, style)
            -- skip the extra bytes
            i = i + 2

        -- "?th" ordinal:
        ------------------------------------------------------------------------
        elseif self:match("^%dth[%s%p]", i) then
            -- encode the character before the "th"
            out_str = out_str .. string.char(str2scr[self:sub(i, i)])
            -- add the specialised "th" character
            out_str = out_str .. string.char(0x6d)
            -- add style class for the added character(s)
            table.insert(styles, style)
            table.insert(styles, style)
            -- skip the extra bytes
            i = i + 2

        -- utf-8 characters that map to one c64 screen-code:
        ------------------------------------------------------------------------
        elseif self:match("^"..utf8.charpattern, i) then
            -- capture the character; will be 1-4 bytes
            local s_utf8 = self:match("^"..utf8.charpattern, i)
            -- look up the C64 screen-code
            local i_scr = str2scr[s_utf8]
            -- if there is no conversion display an error mark
            if i_scr == nil then
                -- use warning symbol "<!>"
                i_scr = 0xff
                -- set the warning style class
                table.insert(styles, STYLE_WARN)
            else
                -- set the normal style class
                table.insert(styles, style)
            end
            -- add to the C64 string
            out_str = out_str .. string.char(i_scr)
            -- skip over the excess bytes
            i = i + (#s_utf8-1)

        ------------------------------------------------------------------------
        else
            -- "�"
            out_str = out_str .. string.char(0xff)
            -- set the warning style class
            table.insert(styles, STYLE_WARN)
        end

    until i >= #self

    return out_str, styles
end

--------------------------------------------------------------------------------
scr2str = {
    ["\x00"]        = " ",
    ["\x01"]        = "!",
    ["\x02"]        = '"',      -- right curly-quote
    ["\x03"]        = "#",
    ["\x04"]        = "$",
    ["\x05"]        = "%",
    ["\x06"]        = "&",
    ["\x07"]        = "'",
    ["\x08"]        = "(",
    ["\x09"]        = ")",
    ["\x0a"]        = "*",
    ["\x0b"]        = "+",
    ["\x0c"]        = ",",
    ["\x0d"]        = "-",
    ["\x0e"]        = ".",
    ["\x0f"]        = "/",

    ["\x10"]        = "0",
    ["\x11"]        = "1",
    ["\x12"]        = "2",
    ["\x13"]        = "3",
    ["\x14"]        = "4",
    ["\x15"]        = "5",
    ["\x16"]        = "6",
    ["\x17"]        = "7",
    ["\x18"]        = "8",
    ["\x19"]        = "9",

    ["\x1a"]        = ":",
    ["\x1b"]        = ";",
    ["\x1c"]        = "<",
    ["\x1d"]        = "=",
    ["\x1e"]        = ">",
    ["\x1f"]        = "?",
    ["\x20"]        = "@",

    ["\x21"]        = "A",
    ["\x22"]        = "B",
    ["\x23"]        = "C",
    ["\x24"]        = "D",
    ["\x25"]        = "E",
    ["\x26"]        = "F",
    ["\x27"]        = "G",
    ["\x28"]        = "H",
    ["\x29"]        = "I",
    ["\x2a"]        = "J",
    ["\x2b"]        = "K",
    ["\x2c"]        = "L",
    ["\x2d"]        = "M",
    ["\x2e"]        = "N",
    ["\x2f"]        = "O",
    ["\x30"]        = "P",
    ["\x31"]        = "Q",
    ["\x32"]        = "R",
    ["\x33"]        = "S",
    ["\x34"]        = "T",
    ["\x35"]        = "U",
    ["\x36"]        = "V",
    ["\x37"]        = "W",
    ["\x38"]        = "X",
    ["\x39"]        = "Y",
    ["\x3a"]        = "Z",

    ["\x3b"]        = "[",
    ["\x3c"]        = "\\",
    ["\x3d"]        = "]",
    ["\x3e"]        = "^",
    ["\x3f"]        = "_",
    ["\x40"]        = "`",

    ["\x41"]        = "a",
    ["\x42"]        = "b",
    ["\x43"]        = "c",
    ["\x44"]        = "d",
    ["\x45"]        = "e",
    ["\x46"]        = "f",
    ["\x47"]        = "g",
    ["\x48"]        = "h",
    ["\x49"]        = "i",
    ["\x4a"]        = "j",
    ["\x4b"]        = "k",
    ["\x4c"]        = "l",
    ["\x4d"]        = "m",
    ["\x4e"]        = "n",
    ["\x4f"]        = "o",
    ["\x50"]        = "p",
    ["\x51"]        = "q",
    ["\x52"]        = "r",
    ["\x53"]        = "s",
    ["\x54"]        = "t",
    ["\x55"]        = "u",
    ["\x56"]        = "v",
    ["\x57"]        = "w",
    ["\x58"]        = "x",
    ["\x59"]        = "y",
    ["\x5a"]        = "z",

    ["\x5b"]        = "{",
    ["\x5c"]        = "|",
    ["\x5d"]        = "}",
    ["\x5e"]        = "~",
    ["\x5f"]        = "£",
    ["\x60"]        = "*",
    ["\x61"]        = "-",
    ["\x62"]        = "-",
    ["\x63"]        = ".",
    ["\x64"]        = '"',      -- left curly-quote
    ["\x65"]        = "...",
    ["\x66"]        = "\xF3",   -- code page 850 for "¾"
    ["\x67"]        = "\xAB",   -- code page 850 for "½"
    ["\x68"]        = '"',
    ["\x69"]        = "'",
    ["\x6a"]        = "^st",
    ["\x6b"]        = "^nd",
    ["\x6c"]        = "^rd",
    ["\x6d"]        = "^th",
    ["\x6e"]        = "^tm",
    ["\x6f"]        = "\xB8",   -- code page 850 for "©"

    ["\x70"]        = " I",
    ["\x71"]        = "I ",
    ["\x72"]        = "I'",
    ["\x73"]        = "'l",
    ["\x74"]        = "o'",
    ["\x75"]        = "'r",
    ["\x76"]        = "'s",
    ["\x77"]        = "'t",
    ["\x78"]        = "'v",
    ["\x79"]        = "['v]e",

    ["\x7b"]        = "\x87", -- code page 850 for "ç",
    ["\x7c"]        = "\x8A", -- code page 850 for "è",
    ["\x7d"]        = "\x82", -- code page 850 for "é",
    ["\x7e"]        = "\x8B", -- code page 850 for "ï",
    ["\x7f"]        = "\x81", -- code page 850 for "ü",
}

-- for compression, convert C64 screen-codes to lower-case
--------------------------------------------------------------------------------
function string:scr2lower()
    ----------------------------------------------------------------------------
    -- screen codes 0x21 to 0x3a are upper-case letters
    local out = ""
    for i = 1, #self do
        local scr = self:byte(i)
        if scr >= 0x21 and scr <= 0x3a then
            out = out .. string.char(scr + 0x20)
        else
            out = out .. string.char(scr)
        end
    end
    return out
end

-- for debug purposes, covert C64 screen codes back to ASCII
--------------------------------------------------------------------------------
function string:fromC64()
    ----------------------------------------------------------------------------
    local out = ""
    local i = 0

    repeat
        -- move to the next byte
        i = i + 1

        -- from the current position,
        -- try match a multi-byte sequence:
        --
        -- "... I  ..."
        ------------------------------------------------------------------------
        if self:match("^\x70\x71", i) then
            -- these two bytes expand to three, so should be matched together,
            -- if possible. separately they expand to " I" & "I "
            out = out .. " I "
            -- skip the additional byte
            i = i + 1

        ------------------------------------------------------------------------
        else
            local ascii = scr2str[self:sub(i, i)]
            if ascii == nil then
                ascii = string.format("\\x%02X", self:byte(i))
            end
            out = out .. ascii
        end

    until i >= #self

    return out
end