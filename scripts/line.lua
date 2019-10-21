-- nücomer magazine (c) copyright Kroc Camen 2019. unless otherwise noted,
-- licenced under Creative Commons Attribution Non-Commercial Share-Alike 4.0
-- licence; you may reuse and modify this code how you please as long as you:
--
-- # retain the copyright notice
-- # use the same licence for your derived code
-- # do not use it for commercial purposes
--   (contact the author for a commercial licence)
--

require "scripts.string"

--------------------------------------------------------------------------------
Line = {
    indent      = 0,        -- pre-indent, number of spaces
    source      = "",       -- source line text, encoded on-demand to C64
    is_literal  = false,    -- is this a literal-text line?
    default     = 0,        -- default style class
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
        source      = "",       -- source line text, encoded on-demand to C64
        indent      = 0,        -- pre-indent, number of spaces
        is_literal  = false,    -- is this a literal-text line?
        default     = 0,        -- default colour class
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
    if self._dirty == false then return; end

    self._cache = self.source:toC64()
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

    self.source = self.source .. ("\x1b"..tostring(i_style)) .. s_utf8
    self._dirty = true
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

    local _, _styles = self.source:toC64()

    for char_index, char_style in ipairs(_styles) do
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

    --#print(self.source)
    --#print(view)

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

    --#print("#", #s_bin)
    return s_bin
end