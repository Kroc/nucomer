-- nücomer magazine (c) copyright Kroc Camen 2019. unless otherwise noted,
-- licenced under Creative Commons Attribution Non-Commercial Share-Alike 4.0
-- licence; you may reuse and modify this code how you please as long as you:
--
-- # retain the copyright notice
-- # use the same licence for your derived code
-- # do not use it for commercial purposes
--   (contact the author for a commercial licence)
--

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

    ["ç"]  = 0x7b,  -- as in "façade"
    ["è"]  = 0x7c,  -- as in "cafè"
    ["é"]  = 0x7d,  -- as in "née"
    ["ï"]  = 0x7e,  -- as in "naïve"
    ["ü"]  = 0x7f,  -- as in "nücomer"
}

-- convert ASCII string to the screen codes used by Nücomer
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
            s_out = s_out .. string.char(0x61, 0x62)
            -- skip the extra (utf-8) bytes
            i = i + 1

        -- "... I ...":
        ---------------------------------------------------------------------
        elseif self:match("^ I ", i) ~= nil then
            s_out = s_out .. string.char(0x70, 0x71)
            -- skip a couple of bytes
            i = i + 2

        -- "*'ll":
        ------------------------------------------------------------------------
        elseif self:match("^%w'll ?", i) ~= nil then
            -- we process this before the "I'*" contraction because there's
            -- a separate contractor character for "I'*" to avoid needing
            -- special characters for "I'm" and "I'd"
            --
            -- encode the character before the "'ll"
            s_out = s_out .. string.char(str2scr[self:sub(i, i)])
            -- add the specialised "'l" character and a normal "l"
            s_out = s_out .. string.char(0x73, 0x4c)
            -- move the index over the processed characters
            i = i + 3

        -- "I'*":
        ------------------------------------------------------------------------
        elseif self:match("^I'", i) ~= nil then
            -- encode using the special "I'*" character
            s_out = s_out .. string.char(0x72)
            -- skip a byte
            i = i + 1

        -- "o'":
        ------------------------------------------------------------------------
        elseif self:match("^o'", i) ~= nil then
            -- add the specialised "o'" character
            s_out = s_out .. string.char(0x74)
            -- skip a byte
            i = i + 1

        -- "*'r":
        ------------------------------------------------------------------------
        elseif self:match("^%w'r", i) ~= nil then
            -- encode the character before the "'r"
            s_out = s_out .. string.char(str2scr[self:sub(i, i)])
            -- add the specialised "'r" character
            s_out = s_out .. string.char(0x75)
            -- move the index over the processed characters
            i = i + 2

        -- "*'s":
        ------------------------------------------------------------------------
        elseif self:match("^%w's", i) ~= nil then
            -- encode the character before the "'s"
            s_out = s_out .. string.char(str2scr[self:sub(i, i)])
            -- add the specialised "'s" character
            s_out = s_out .. string.char(0x76)
            -- move the index over the processed characters
            i = i + 2

        -- "'t":
        ------------------------------------------------------------------------
        elseif self:match("^'t", i) ~= nil then
            -- add the specialised "'t" character
            s_out = s_out .. string.char(0x77)
            -- skip a byte
            i = i + 1

        -- "*'ve":
        ------------------------------------------------------------------------
        elseif self:match("^%w've", i) ~= nil then
            -- encode the character before the "'ve"
            s_out = s_out .. string.char(str2scr[self:sub(i, i)])
            -- add the specialised "'ve" characters
            s_out = s_out .. string.char(0x78, 0x79)
            -- move the index over the processed characters
            i = i + 3

        -- 1st ordinal
        ------------------------------------------------------------------------
        elseif self:match("^1st", i) ~= nil then
            -- replace the "st" with the special character
            s_out = s_out .. string.char(str2scr["1"], 0x6a)
            -- skip the extra bytes
            i = i + 2

        -- 2nd ordinal
        ------------------------------------------------------------------------
        elseif self:match("^2nd", i) ~= nil then
            -- replace the "nd" with the special character
            s_out = s_out .. string.char(str2scr["2"], 0x6b)
            -- skip the extra bytes
            i = i + 2

        -- 3rd ordinal
        ------------------------------------------------------------------------
        elseif self:match("^3rd", i) ~= nil then
            -- replace the "rd" with the special character
            s_out = s_out .. string.char(str2scr["3"], 0x6c)
            -- skip the extra bytes
            i = i + 2

        -- "?th" ordinal:
        ------------------------------------------------------------------------
        elseif self:match("^[0456789]th", i) ~= nil then
            -- encode the numeral before the "th"
            s_out = s_out .. string.char(str2scr[self:sub(i, i)])
            -- add the specialised "th" character
            s_out = s_out .. string.char(0x6d)
            -- skip the extra bytes
            i = i + 2

        -- utf-8 characters that map to one c64 screen-code:
        ------------------------------------------------------------------------
        elseif self:match("^"..utf8.charpattern, i) ~= nil then
            -- capture the character; will be 1-4 bytes
            local s_utf8 = self:match("^"..utf8.charpattern, i)
            -- look up the C64 screen-code
            local i_scr = str2scr[s_utf8]
            -- if there is no conversion display an error mark
            if i_scr == nil then i_scr = 0xff; end -- warning sign "<!>"
            -- add to the C64 string
            s_out = s_out .. string.char(i_scr)
            -- skip over the excess bytes
            i = i + (#s_utf8-1)
        else
            -- "�"
            --#s_out = s_out .. string.char(0xff)
        end

    until i >= #self

    return s_out
end

--------------------------------------------------------------------------------
Line = {
    indent      = 0,        -- pre-indent, number of spaces
    source      = "",       -- source line text, encoded on-demand to C64
    is_literal  = false,    -- is this a literal-text line?
    default     = 0,        -- default style class
    styles      = {},       -- table of style classes for each character
    -------------------------- no touchy!
    _dirty      = false,    -- changes made?
    _cache      = "",       -- cached encoded version of line
}

-- create a new instance of the Line class
--------------------------------------------------------------------------------
function Line:new()
    ----------------------------------------------------------------------------
    -- crate new, empty, instance
    local line = {
        indent      = 0,        -- pre-indent, number of spaces
        source      = "",       -- source line text, encoded on-demand to C64
        is_literal  = false,    -- is this a literal-text line?
        default     = 0,        -- default colour class
        styles      = {},       -- table of style classes for each char
        -------------------------- no touchy!
        _dirty      = false,    -- changes made?
        _cache      = "",       -- cached encoded version of line
    }
    setmetatable(line, self)    -- set new instance to inherit from prototype
    self.__index = self         -- bind "self"
    return line                 -- return the new instance
end

--------------------------------------------------------------------------------
function Line:_cacheLine()
    ----------------------------------------------------------------------------
    if self._dirty then
        if self.is_literal then
            self._cache = self.source
        else
            self._cache = self.source:toC64()
        end
        self._dirty = false
    end
end

-- encode a utf-8 string for the C64 and add it to the line
--------------------------------------------------------------------------------
function Line:addString(s_utf8, i_style)
    ----------------------------------------------------------------------------
    -- default style class?
    if i_style == nil then i_style = self.default; end
    -- get the length of the current line, when encoded,
    -- to determine where (on screen) our addition appears
    local i = self:getCharLen()
    -- if there's nothing on the line yet, then the style-class
    -- will begin on the first character
    if i == 0 then i = 1; end

    -- encode the combined line + string to get the end-point
    -- (combining the string with the line may change its encoded length!)
    self.source = self.source .. s_utf8
    self._dirty = true
    -- do we need to add colour data?
    --#if i_style ~= self.default then
        -- re-encode the line given the string we've added;
        self:_cacheLine()
        -- the length of this will determine the end-point
        local j = self:getCharLen()
        -- set the style class for those characters
        -- (this'll allow us to more easily combine spans)
        for n = i, j do self.styles[n] = i_style; end
    --#end
end

-- returns the length of the line in printable characters,
-- NOT the byte length, which may be very different
--------------------------------------------------------------------------------
function Line:getCharLen()
    ----------------------------------------------------------------------------
    -- does the line need re-encoding?
    self:_cacheLine()
    -- the cached line will provide the length
    return #self._cache
end

-- return the line encoded for the C64
--------------------------------------------------------------------------------
function Line:encode()
    ----------------------------------------------------------------------------
    -- TODO: not this way
    return self:getBin(), self:getBinLen()
end

-- returns the final binary form of the line
--------------------------------------------------------------------------------
function Line:getBin()
    ----------------------------------------------------------------------------
    -- binary string that will be returned
    local bin = self:getBinColour()
    -- does the line need re-encoding?
    self:_cacheLine()
    -- TODO: literal lines with RLE-compression
    bin = bin .. self._cache
    -- note that lines are written into the binary backwards!
    -- this is so that the line length can be used as a count-down
    -- index which is faster for 6502s to process
    return bin:reverse()
end

-- returns the binary colour data
--------------------------------------------------------------------------------
function Line:getBinColour()
    ----------------------------------------------------------------------------
    local s_bin = ""

    -- non-default style class?
    if self.default ~= 0 then
        -- indicate the default style-class for the whole line
        s_bin = string.char(0x80 + self.default)
    end
    -- is there *any* colour data?
    if #self.styles == 0 then return s_bin; end

    -- batch together the style-classes for each character into spans:
    ----------------------------------------------------------------------------
    local last_index    = 0
    local span_begin    = 0
    local span_style    = self.default
    local spans         = {}

    --#print(truncate(self.source))

    for char_index, char_style in pairs(self.styles) do
        ------------------------------------------------------------------------
        --#print("?", char_index, char_style)
        -- if the character style-class has changed or the index
        -- is non-contiguous then start a new span
        if char_style ~= span_style or char_index > (last_index+1) then
            -- we do not add spans for the default style,
            -- nor before the first span has been initialised
            if (span_begin > 0) and (span_style ~= self.default)
            then
                -- construct a span covering the contiguous
                -- characters of the same style-class
                table.insert(spans, {
                    first = span_begin, last = last_index,
                    style = span_style
                })
                --#print("+", span_begin, last_index)
            end
            -- begin a new span:
            span_begin  = char_index
            span_style  = char_style
        end
        -- where the character style remains
        -- contiguous, we inch forward
        last_index  = char_index
    end
    -- given that the line's text may continue past the last style change,
    -- we must check if there remains one un-finished span
    if (span_begin > 0) and (span_style ~= self.default) then
        table.insert(spans, {
            first = span_begin, last = last_index,
            style = span_style
        })
        --#print("+", span_begin, last_index)
    end

    -- convert spans into binary colour-data
    ----------------------------------------------------------------------------
    for _, span in pairs(spans) do
        --#print("=", span.first, span.last, self.source:sub(span.first, span.last+1))
    end

    return s_bin
end

-- length of the binary line, including colour-data (if present)
--------------------------------------------------------------------------------
function Line:getBinLen()
    ----------------------------------------------------------------------------
    -- get the true length in bytes
    local len = string.len(self:getBin())
    -- is this a literal-encoded line?
    -- if yes, set bit 6 which indicates a literal-encoded line
    if self.is_literal then len = len + 0x40; end
    -- is there colour data?
    -- if yes, set bit 7 which indicates the presence of colour-data
    if self.default ~= 0 then len = len + 0x80; end
    -- And Now You Know
    return len
end

