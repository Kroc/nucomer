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
    -------------------------- no touchy!
    _styles     = {},       -- table of style classes for each character
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
        -------------------------- no touchy!
        _styles     = {},       -- table of style classes for each char
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
    if self._dirty == false then return; end

    if self.is_literal then
        self._cache = self.source
    else
        self._cache = self.source:toC64()
    end
    self._dirty = false
end

-- encode a utf-8 string for the C64 and add it to the line
--------------------------------------------------------------------------------
function Line:addString(s_utf8, i_style)
    ----------------------------------------------------------------------------
    -- sanity check
    if s_utf8 == "" then return; end

    -- default style class?
    if i_style == nil then i_style = self.default; end
    -- get the length of the current line, when encoded,
    -- to determine where (on screen) our addition appears
    local i = self:getCharLen()+1

    -- encode the combined line + string to get the end-point
    -- (combining the string with the line may change its encoded length!)
    self.source = self.source .. s_utf8
    self._dirty = true
    -- the length of this will determine the end-point
    local j = self:getCharLen()

    -- set the style class for those character columns
    -- (this'll allow us to more easily combine spans)
    for n = i, j do self._styles[n] = i_style; end

    -- try and combine / minimise styles:
    --
    -- the more separate colour spans we have the more bytes we use,
    -- so we try minimise the number of spans by extending styles
    -- across spaces, i.e. taking a line that may look like this:
    --
    --      text  : the quick brown fox jumps over the lazy dog
    --      style : 1110111110111110111011111011110111011110111
    --
    -- and changing the style of the spaces to extend the nearest span:
    --
    --      text  : the quick brown fox jumps over the lazy dog
    --      style : 1111111111111111111111111111111111111111111
    --
    -- walk to the left of the string added...
    for n = i-1, 1, -1 do
        -- as long as spaces continue...
        if self.source:byte(n) == 0x20 then
            -- change their style class to match the added
            -- (right-most) style
            self._styles[n] = i_style
        else
            -- as soon as we hit any non-space, stop
            break
        end
    end
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

-- returns the source line, converted to C64 screen-codes
--------------------------------------------------------------------------------
function Line:getBinText()
    ----------------------------------------------------------------------------
    self:_cacheLine()   -- encode the line, if not already done
    return self._cache
end

-- returns the binary colour data
--------------------------------------------------------------------------------
function Line:getBinColour()
    ----------------------------------------------------------------------------
    if self.source == "" then return ""; end

    --#if true then return ""; end

    -- reverse the columns!
    --
    -- most lines are going to have some trailing space before the end of the
    -- screen; if we construct our colour-spans from the right to the left
    -- (rather than the natural left-to-right, to suit the text), then we will
    -- have a first span that will represent the largest amount of skippable
    -- [for colour] space, in most instances. given that the first byte of
    -- colour-data is an initial offset to skip, working from right to left
    -- will give us the best use of the byte -- if working left-to-right,
    -- a bullet point at the start of the line would be a waste of skipping
    --
    -- the string, at this stage, may not fill all 40 columns
    -- and we will need all in place in order to reverse them
    -- (lua stops iterating a table when it hits a null!)
    --
    local styles = {}
    for i = 1, 40 do; styles[i] = self.default; end

    for char_index, char_style in ipairs(self._styles) do
        -- reverse the column indicies
        styles[41-char_index] = char_style
    end

    local view = ""
    for i = 1, 40 do; view = tostring(styles[i]) .. view; end

    -- batch together the style-classes
    -- for each character into spans:
    --
    local last_index    = 1
    local span_begin    = 1
    local span_style    = styles[1]
    local spans         = {}

    --#print(truncate(self.source))

    for char_index, char_style in pairs(styles) do
        ------------------------------------------------------------------------
        -- if the character style-class has changed then start a new span
        if char_style ~= span_style then
            -- construct a span covering the contiguous
            -- characters of the same style-class
            table.insert(spans, {
                first = span_begin, last = last_index,
                style = span_style
            })
            -- begin a new span:
            span_begin  = char_index
            span_style  = char_style
        end
        -- where the character style remains
        -- contiguous, we inch forward
        last_index = char_index
    end
    -- given that the line's text may continue past the last style change,
    -- we must check if there remains one un-finished span
    table.insert(spans, {
        -- the whole line must always be coloured to avoid colour-garbage
        -- from other lines appearing when scrolling on the C64, so the last
        -- span is extended to the end of the screen
        first = span_begin, last = 40,
        style = span_style
    })

    -- is the whole line a single colour?
    if #spans == 1 then
        -- default line colour?
        if span_style > 0 then
            -- indicate the style-class for the whole line,
            -- by setting the high-bit. the lower 3 bits
            -- will be taken as the style-class to use
            return string.char(0x80 + span_style)
        else
            -- a default style-class for the whole line
            -- does not need any colour data,
            -- a critical space saver!
            return ""
        end
    end

    -- convert spans into binary colour-data
    ----------------------------------------------------------------------------
    local s_bin = ""

    print(truncate(self.source))
    print(view)

    for i, span in ipairs(spans) do
        -- the first byte of the colour-data must be an initial offset
        -- to the first non-default colour-span:
        --
        -- if the first colour-span is the default style,
        -- then replace it with the initial offset
        if i == 1 and span.style == self.default then
            -- note that this has to be 1-based to allow for "0" to
            -- be used for a non-default colour span occuring at the
            -- beginning of a line, leading to no initial offset
            s_bin = string.char((span.last-span.first)+1)
            --#print(">", (span.last-span.first)+1)
        else
            -- if the first colour span is not the default style,
            -- we have to conceed the first byte
            if i == 1 then s_bin = string.char(0); end
            -- move the style-class into the upper three bits
            local span_class = span.style * (2 ^ 5)
            -- the length of the span occupies the low five bits
            local span_width = span.last-span.first
            -- colour spans are limited to 32 chars!
            -- (0-to-31 represents 1-to-32 on the C64)
            if span_width > 31 then
                -- split the span into two;
                -- first write a maximum span of 32
                s_bin = s_bin .. string.char(31 + span_class)
                --#print("=", 32, span.style)
                -- leave the remainder
                span_width = span_width - 31
            end
            -- combine the span style-class and length
            s_bin = s_bin .. string.char(span_width + span_class)
            --#print("=", span_width+1, span.style)
        end
    end

    print("#", #s_bin)
    return s_bin
end