-- nücomer magazine (c) copyright Kroc Camen 2019. unless otherwise noted,
-- licenced under Creative Commons Attribution Non-Commercial Share-Alike 4.0
-- licence; you may reuse and modify this code how you please as long as you:
--
-- # retain the copyright notice
-- # use the same licence for your derived code
-- # do not use it for commercial purposes
--   (contact the author for a commercial licence)
--

-- compress.lua : text analysis and compression
--------------------------------------------------------------------------------
local Compress = {
    -- the table of lines (in screen codes) being compressed
    lines = {},
    -- table of byte-pair quantities;
    -- the key is the byte-pair (string), and the value
    -- is the number of times it has occurred
    pairs = {},
    -- table of single-character quantities;
    -- the key is the character (string), and the value
    -- is the number of times it has occurred
    chars = {},
    -- tokens are newly assigned bytes to represent pairs of bytes;
    -- this is the 'dictionary' used for decompressing the data
    tokens = {},
}

-- clear the current compression stats
--------------------------------------------------------------------------------
function Compress:clear()
    ----------------------------------------------------------------------------
    self.lines  = {}
    self.pairs  = {}
    self.chars  = {}
    self.tokens = {}
end

-- add a line of text to the compressor
--------------------------------------------------------------------------------
function Compress:addLine(src_line)
    ----------------------------------------------------------------------------
    -- convert the line to C64 screen codes and a list of style classes
    local src_screen, src_styles = src_line:toC64()

    -- we compress the colour data right away as this requires
    -- the original screen codes, before they get compressed
    local out_colour = compress:compressColour(src_screen, src_styles)
    local out_screen = src_screen

    -- add the binary data to our internal table
    --
    table.insert(self.lines, {
        source = src_line,
        colour = out_colour,
        screen = out_screen,
        -- where spaces will be extracted to be bit-packed
        spaces = {},
        -- unused initially, but will hold the tokenised
        -- version of the line when we begin compressing
        tokens = "",
    })
end

-- compress the list of style classes into binary colour data
--------------------------------------------------------------------------------
function Compress:compressColour(src_screen, src_styles)
    ----------------------------------------------------------------------------
    -- optimise blank lines
    if src_screen == "" then return ""; end

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
    -- this variable will hold the last known style
    -- before a space, and 'bleed' it across the spaces
    --
    local bleed = src_styles[1]
    local nuspc = str2scr[" "]

    for i = #src_screen, 1, -1 do
        -- as long as spaces continue...
        if src_screen:byte(i) == nuspc then
            -- change the style class to match
            -- the last used style class
            src_styles[i] = bleed
        else
            -- not a space? update the style class to bleed
            bleed = src_styles[i]
        end
    end

    -- in order to detect lines that are all one style, we want to bleed
    -- the last character's style class to the end of the line; e.g.
    --
    --      text  : a short line.
    --      style : 1111111111111000000000000000000000000000
    --
    -- is converted to:
    --
    --      text  : a short line.
    --      style : 1111111111111111111111111111111111111111
    --
    -- get the last character's style class:
    local default = src_styles[#src_styles]

    -- the line might not fill all 40 columns, and we will need
    -- all in place in order to reverse them (lua stops iterating
    -- a table when it hits a null!)
    --
    local out_styles = {}
    for i = 1, 40 do; out_styles[i] = default; end

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
    for src_index, src_style in ipairs(src_styles) do
        -- reverse the column indicies
        out_styles[41-src_index] = src_style
    end

    local view = ""
    for i = 1, 40 do; view = tostring(out_styles[i]) .. view; end

    -- batch together the style-classes
    -- for each character into spans:
    --
    local last_index    = 1
    local span_begin    = 1
    local span_style    = out_styles[1]
    local spans         = {}

    --#print(truncate(line))

    for char_index, char_style in pairs(out_styles) do
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
    ----------------------------------------------------------------------------
    if #spans == 1 then
        -- default line colour?
        if span_style > STYLE_DEFAULT then
            -- indicate the style-class for the whole line,
            -- by setting the high-bit. the lower 3 bits
            -- will be taken as the style-class to use
            return string.char(0x80 + span_style), src_screen
        else
            -- a default style-class for the whole line
            -- does not need any colour data,
            -- a critical space saver!
            return "", src_screen
        end
    end

    -- convert spans into binary colour-data
    ----------------------------------------------------------------------------
    local out_colour = ""

    --#print('"'..line..'"')
    --#print(view)
    --#print(#out_styles, inspect(out_styles))

    for i, span in ipairs(spans) do
        -- the first byte of the colour-data must be an initial offset
        -- to the first non-default colour-span:
        --
        -- if the first colour-span is the default style,
        -- then replace it with the initial offset
        if i == 1 and span.style == STYLE_DEFAULT then
            -- note that this has to be 1-based to allow for "0" to
            -- be used for a non-default colour span occuring at the
            -- beginning of a line, leading to no initial offset
            out_colour = string.char((span.last-span.first)+1)
            --#print(">", (span.last-span.first)+1)
        else
            -- if the first colour span is not the default style,
            -- we have to conceed the first byte
            -- TODO: we can use the sixth bit of the first byte to
            --       indicate an initial non-default style and use
            --       the first byte to indicate the style class
            --       and the second byte for the length
            if i == 1 then out_colour = string.char(0); end
            -- move the style-class into the upper three bits
            local span_class = span.style * (2 ^ 5)
            -- the length of the span occupies the low five bits
            local span_width = span.last-span.first
            -- colour spans are limited to 32 chars!
            -- (0-to-31 represents 1-to-32 on the C64)
            -- TODO: allow a trailing class to the end of the line
            --       using lengths 40-47?
            if span_width > 31 then
                -- split the span into two;
                -- first write a maximum span of 32
                out_colour = out_colour .. string.char(31 + span_class)
                --#print("=", 32, span.style)
                -- leave the remainder
                span_width = span_width - 32
            end
            -- combine the span style-class and length
            out_colour = out_colour .. string.char(span_width + span_class)
            --#print("=", span_width+1, span.style)
        end
    end
    --#print("#", #s_bin)

    return out_colour
end

-- iteratively compress the lines until no more tokens are free
--------------------------------------------------------------------------------
function Compress:compressLines()
    ----------------------------------------------------------------------------
    -- before compression, the lines are stored as direct screen codes.
    -- after compression, all bytes will be some form of token, so the first
    -- task is find all unqiue characters in the lines and assign these to the
    -- first "literal" tokens. i.e. instead of a scatter of screen-codes,
    -- $00-$FF, the lines will be recoded to the minimum number of unqiue
    -- tokens in packed order. if there were 56 unique characters in the
    -- article, then only tokens 1 to 56 would be used. this leaves all
    -- remaining tokens to be used for byte-pair compression
    --
    -- note that calling this routine will clear the current token table,
    -- and will re-encode all lines. the next avaiable token will be returned
    --
    local token = self:tokeniseChars()

    io.stdout:write("> compressing...              ")

    -- iteratively pair tokens:
    --
    while token <= 0xFF do
        ------------------------------------------------------------------------
        -- find the most common token pair
        -- (this might include existing compressed token-pairs!)
        local old_pair, old_count = self:analysePairs()

        if old_count ~= 0 then
            --#io.stdout:write(string.format(
            --#    "  ? $%02X = $%02X,$%02X ",
            --#    token,
            --#    old_pair:byte(1),
            --#    old_pair:byte(2)
            --#))
        else
            break
        end

        -- define the new token
        -- as a pair of old tokens:
        --
        self.tokens[token] = {
            pair = old_pair,
            -- combine the sizes of the two tokens. we need to know
            -- how many chars a token expands to for bit-packing spaces
            size = (
                self.tokens[old_pair:byte(1)].size +
                self.tokens[old_pair:byte(2)].size
            )
        }

        local old_size = 0
        local new_size = 0

        -- replace all instances of the pair,
        -- with the new token
        --
        for i = 1, #self.lines do
            --------------------------------------------------------------------
            local old_line = self.lines[i].tokens
            -- we'll build the replacement line byte-by-byte
            -- as it'll be shorter than the original
            local new_line = ""
            -- walk through the token-pairs
            local j = 1
            while j <= #old_line do
                -- is this the pair?
                if old_line:sub(j, j+1) == old_pair then
                    -- yes! use the new token in the output
                    new_line = new_line .. string.char(token)
                    -- skip the old pair
                    j = j + 2
                else
                    -- include as-is in the output
                    new_line = new_line .. old_line:sub(j, j)
                    -- move to the next byte
                    -- (i.e. allow overlapping pairs)
                    j = j + 1
                end
            end
            -- add the counts (to work out space-saved)
            old_size = old_size + #old_line
            new_size = new_size + #new_line
            -- save the compressed line
            self.lines[i].tokens = new_line
        end

        --#print(string.format(
        --#    " %3s %5d %10s",
        --#    self.tokens[token].size,
        --#    new_size-old_size,
        --#    filesize(new_size)
        --#))

        -- move to the next token number
        token = token + 1
    end

    -- bit pack spaces!
    ----------------------------------------------------------------------------
    -- since we've removed the spaces, we need to put them back in
    --
    for i = 1, #self.lines do
        ------------------------------------------------------------------------
        -- there are no spaces on a blank line
        -- (well, none that need printing anyway)
        if #self.lines[i].tokens > 0 then
            -- we will intersperse the space bytes with the tokens
            local out_line = ""
            local len = 0

            -- walk each token in the line...
            for j = 1, #self.lines[i].tokens do
                ----------------------------------------------------------------
                -- read a token
                local tok = self.lines[i].tokens:byte(j)
                -- place this token in the output
                out_line = out_line .. string.char(tok)
                -- how many characters will the token print?
                len = len + self.tokens[tok].size
                -- we will need as many space bytes
                -- as contains that many non-spaces!
                while len > 0 do
                    -- fetch a byte of spaces
                    local spc = table.remove(self.lines[i].spaces, 1)
                    -- add the byte of spaces into the output
                    out_line = out_line .. string.char(spc)
                    -- subtract the number of non-space characters
                    len = len - self.bits[spc]
                end
            end
            self.lines[i].tokens = out_line
        end
    end

    -- calculate the new size
    ----------------------------------------------------------------------------
    local i_size = 0
    for _, line in ipairs(self.lines) do
        i_size = i_size + #line.colour + #line.tokens
    end

    print(string.format("%10s", filesize(i_size)))
end

-- assign unique characters to the first initial tokens
--------------------------------------------------------------------------------
function Compress:tokeniseChars()
    ----------------------------------------------------------------------------
    io.stdout:write("> tokenising...               ")

    -- clear the current token definitions & character statistics.
    self.tokens = {}
    self.chars  = {}

    for i = 0, 255 do
        -- pre-populate all 256 possible chars, as Lua will stop
        -- iterating a table at the first 'gap' between indices
        self.chars[i]  = 0
        self.tokens[i] = {pair = "", size = 0}
    end

    -- walk all lines of text...
    --
    for _, line in ipairs(self.lines) do
        ------------------------------------------------------------------------
        -- walk the bytes...
        local j = 1
        while j <= #line.screen do
            --------------------------------------------------------------------
            -- count the character
            local char = line.screen:byte(j)
            self.chars[char] = (self.chars[char] or 0) + 1
            -- move to next character
            j = j + 1
        end
    end

    -- now we've counted the screen codes, begin assigning them to tokens;
    -- the order used is not actually important, but could perhaps be
    -- controlled in the future as some kind of arithmetic-coding
    --
    local token = 0

    -- check each of the possible unqiue screen codes...
    --
    for i = 0, 255 do
        ------------------------------------------------------------------------
        -- was the screen-code ever used?
        if self.chars[i] > 0 then
            -- define the token as a literal;
            -- the screen-code followed by a null
            self.tokens[token] = {
                pair = string.char(i, 0),
                size = 1
            }
            -- we're going to re-use our count to map the screen-code to
            -- its token for the complete line re-encoding we'll have to do
            self.chars[i] = token
            -- move to next token number
            token = token + 1
        end
    end

    -- re-encode all lines from screen-codes to tokens
    --
    for i = 1, #self.lines do
        ------------------------------------------------------------------------
        -- our source line, screen-codes
        local scr_line = self.lines[i].screen

        -- this will be the token-encoded version of the line
        local tok_line = ""
        -- used for bit-packing the spaces
        local spc_bits = {}
        local spc      = 0

        -- walk each screen-code
        -- in the source line:
        --
        for j = 1, #scr_line do
            --------------------------------------------------------------------
            -- is this the 8th character in a row?
            if j > 1 and (j-1) % 8 == 0 then
                -- yes: add the byte to the spaces bitmap
                table.insert(spc_bits, spc)
                -- reset the word / spaces bitmap
                spc = 0
            end
            -- determine the screen code
            local scr = scr_line:byte(j)
            -- not a space?
            if scr ~= str2scr[" "] then
                -- set the bit in the space bitmap
                -- to indicate a non-space
                spc = spc + 2 ^ ((j-1) % 8) | 0
                -- get the token for the screen-code
                local tok = self.chars[scr]
                -- add the token to the output
                tok_line = tok_line .. string.char(tok)
            end
        end
        -- add the last byte of spaces
        table.insert(spc_bits, spc)

        -- the line has been converted
        self.lines[i].tokens = tok_line
        self.lines[i].spaces = spc_bits
    end

    -- return the next available token number,
    -- this will happen to also be the count of unqiue characters + 1
    print(string.format("%3u tokens", token-1))
    return token
end

-- find the most common token-pair used across all lines
--------------------------------------------------------------------------------
function Compress:analysePairs()
    ----------------------------------------------------------------------------
    -- we only need to know the most common pair
    local max_pair  = nil
    local max_count = 0

    self.pairs = {}

    for _, t_line in ipairs(self.lines) do
        ------------------------------------------------------------------------
        local tok_line = t_line.tokens

        -- walk the bytes...
        local i = 1
        while i <= #tok_line do
            --------------------------------------------------------------------
            -- read a pair of bytes:
            --
            -- remember that we are reading overlapping pairs,
            -- not separate pairs; that is, "ab", "bc", "cd"
            -- instead of "ab", "cd"
            --
            local pair = tok_line:sub(i, i+1)
            -- if at the end of the line, this might be just one token
            if #pair == 2 then
                -- increase the count for this pair
                -- (or add it to the table, if not already present)
                self.pairs[pair] = (self.pairs[pair] or 0) + 1
                -- is it our top pair?
                if self.pairs[pair] >= max_count then
                    -- take the top spot
                    max_pair = pair
                    max_count = self.pairs[pair]
                end
            end
            i = i + 1
        end
    end

    -- return the most common token-pair,
    -- (and the quantity)
    return max_pair, max_count
end

-- output compression statistics
--------------------------------------------------------------------------------
--#function Compress:printStatistics()
--#    -------------------------------------------------------------------------
--#    print()
--#    print("Compression Statistics:")
--#    print("----------------------------------------")
--#    local byCount = function(a,b)
--#        return a[2] > b[2]
--#    end
--#
--#    -- the pairs array cannot be sorted in a 'pair = count' format
--#    -- (though this is a fast format when counting the pairs),
--#    -- so we copy the data to a different format for sorting
--#    local sorted_pairs = {}
--#    for pair,count in pairs(self.pairs) do
--#        table.insert(sorted_pairs, {pair:fromC64(), count})
--#    end
--#    table.sort(sorted_pairs, byCount)
--#
--#    local sorted_chars = {}
--#    for char,count in pairs(self.chars) do
--#        table.insert(sorted_chars, {char:fromC64(), count})
--#    end
--#    table.sort(sorted_chars, byCount)
--#
--#    for i = 1, 128 do
--#        if sorted_chars[i] then
--#            print(string.format(
--#                "%3u: %-9s x %4u | %-9s x %4u", i,
--#                sorted_pairs[i][1],
--#                sorted_pairs[i][2],
--#                sorted_chars[i][1],
--#                sorted_chars[i][2]
--#            ))
--#        elseif sorted_pairs[i] then
--#            print(string.format(
--#                "%3u: %-9s x %4u |", i,
--#                sorted_pairs[i][1],
--#                sorted_pairs[i][2]
--#            ))
--#        end
--#    end
--#end

-- generate an ACME assembly file for the compressed data
--------------------------------------------------------------------------------
function Compress:toACME(s_outfile)
    ----------------------------------------------------------------------------
    local s_out = [[
; auto-generated file, do not modify!

; set output file:
!to     "{{OUTFILE}}", cbm

; include constants / memory-layout
!source "nucomer.acme"

; the first 2 bytes of data are an offset to the end of the list of
; line-lengths. the load-address is pulled back two bytes so that the
; list of line-lengths begins at a page boundary ($xx00); this is used
; to detect when scrolling has hit the top of the article!
; 
* = nu_text - 2

        ; as mentioned above, the first word is the size
        ; of the line-lengths list that appears below the
        ; tokens table (fixed size)
        ;
        !word   (lines-lengths)-1

tokens_lo:
        ;-----------------------------------------------------------------------
        ; the lo-byte halves of the token-pairs (exactly 256 bytes)
        ;
{{TOKENS_LO}}

tokens_hi:
        ;-----------------------------------------------------------------------
        ; the hi-byte halves of the token-pairs (exactly 256 bytes)
        ;
{{TOKENS_HI}}

; if a line has colour-data, the upper-bit is set
LINE_COLOUR = %10000000

lengths:
        ;-----------------------------------------------------------------------
        ; the length, in bytes, for each line in the article
        ;
{{LENGTHS}}
        ; this byte marks the end of the list of line-lengths
        !byte   $80

lines:
        ;-----------------------------------------------------------------------
{{LINES}}
]]
    -- insert the output file name into the assembly file;
    -- this means that it does not need to be provided by the build-script,
    -- minimising the amount of data we have to share between environments
    s_out = s_out:gsub("%{%{OUTFILE%}%}", s_outfile)

    -- build the list of line-lengths:
    ----------------------------------------------------------------------------
    local s_temp = ""
    for i, out_line in ipairs(self.lines) do
        -- is there any colour data?
        if #out_line.colour > 0 then
            -- indicate clearly the number of extra bytes used by colour data
            s_temp = s_temp .. string.format(
                "        !byte   $%02x + ($%02x | LINE_COLOUR)"..
                "       ; line %u: %u bytes\n",
                #out_line.tokens, #out_line.colour,
                i, (#out_line.tokens + #out_line.colour)
            )
        else
            s_temp = s_temp .. string.format(
                "        !byte   $%02x"..
                "                             ; line %u: %u bytes\n",
                #out_line.tokens,
                i, (#out_line.tokens + #out_line.colour)
            )
        end
    end
    s_out = s_out:gsub("%{%{LENGTHS%}%}", s_temp)
    s_temp = ""

    -- build the list of line-data:
    ----------------------------------------------------------------------------
    for i, out_line in ipairs(self.lines) do
        -- do not output empty lines; on the C64, when a line-length of 0
        -- is encountered, the line-data pointer is not moved forward
        if #out_line.tokens > 0 then
            -- the bytes are output in reverse order for the benefit
            -- of the C64 as counting toward zero is faster / simpler
            local out_bytes = string.reverse(out_line.colour..out_line.tokens)

            s_temp = s_temp .. string.format(
                "        ; line %u: %q\n",
                i, out_line.source
            )

            local hex = ""
            for c = 1, #out_bytes do hex = hex .. string.format(
                "%02x ", string.byte(out_bytes, c)
            ); end

            s_temp = s_temp .. string.format(
                "        !hex    %s\n",
                hex
            )
        end
    end
    s_out = s_out:gsub("%{%{LINES%}%}", s_temp)
    s_temp = ""

    -- build the token lists:
    ----------------------------------------------------------------------------
    local s_left = ""
    local s_right = ""

    for i = 0, 255 do
        -- if the token is undefined fill it in blank
        -- as the tables must fill 256 bytes each
        --
        local i_left  = self.tokens[i].pair:byte(1) or 0
        local i_right = self.tokens[i].pair:byte(2) or 0

        s_left = s_left .. string.format(
            "        !byte   $%02x     ; token $%02x\n", i_left, i
        )
        s_right = s_right .. string.format(
            "        !byte   $%02x     ; token $%02x\n", i_right, i
        )
    end
    s_out = s_out:gsub("%{%{TOKENS_LO%}%}", s_left)
    s_out = s_out:gsub("%{%{TOKENS_HI%}%}", s_right)

    return s_out
end

-- a table of the number of bits in a byte
--
Compress.bits = {
    [0x00] = 0, -- %00000000
    [0x01] = 1, -- %00000001
    [0x02] = 1, -- %00000010
    [0x03] = 2, -- %00000011
    [0x04] = 1, -- %00000100
    [0x05] = 2, -- %00000101
    [0x06] = 2, -- %00000110
    [0x07] = 3, -- %00000111
    [0x08] = 1, -- %00001000
    [0x09] = 2, -- %00001001
    [0x0a] = 2, -- %00001010
    [0x0b] = 3, -- %00001011
    [0x0c] = 2, -- %00001100
    [0x0d] = 3, -- %00001101
    [0x0e] = 3, -- %00001110
    [0x0f] = 4, -- %00001111

    [0x10] = 1, -- %00010000
    [0x11] = 2, -- %00010001
    [0x12] = 2, -- %00010010
    [0x13] = 3, -- %00010011
    [0x14] = 2, -- %00010100
    [0x15] = 3, -- %00010101
    [0x16] = 3, -- %00010110
    [0x17] = 4, -- %00010111
    [0x18] = 2, -- %00011000
    [0x19] = 3, -- %00011001
    [0x1a] = 3, -- %00011010
    [0x1b] = 4, -- %00011011
    [0x1c] = 3, -- %00011100
    [0x1d] = 4, -- %00011101
    [0x1e] = 4, -- %00011110
    [0x1f] = 5, -- %00011111

    [0x20] = 1, -- %00100000
    [0x21] = 2, -- %00100001
    [0x22] = 2, -- %00100010
    [0x23] = 3, -- %00100011
    [0x24] = 2, -- %00100100
    [0x25] = 3, -- %00100101
    [0x26] = 3, -- %00100110
    [0x27] = 4, -- %00100111
    [0x28] = 2, -- %00101000
    [0x29] = 3, -- %00101001
    [0x2a] = 3, -- %00101010
    [0x2b] = 4, -- %00101011
    [0x2c] = 3, -- %00101100
    [0x2d] = 4, -- %00101101
    [0x2e] = 4, -- %00101110
    [0x2f] = 5, -- %00101111

    [0x30] = 2, -- %00110000
    [0x31] = 3, -- %00110001
    [0x32] = 3, -- %00110010
    [0x33] = 4, -- %00110011
    [0x34] = 3, -- %00110100
    [0x35] = 4, -- %00110101
    [0x36] = 4, -- %00110110
    [0x37] = 5, -- %00110111
    [0x38] = 3, -- %00111000
    [0x39] = 4, -- %00111001
    [0x3a] = 4, -- %00111010
    [0x3b] = 5, -- %00111011
    [0x3c] = 4, -- %00111100
    [0x3d] = 5, -- %00111101
    [0x3e] = 5, -- %00111110
    [0x3f] = 6, -- %00111111

    [0x40] = 1, -- %01000000
    [0x41] = 2, -- %01000001
    [0x42] = 2, -- %01000010
    [0x43] = 3, -- %01000011
    [0x44] = 2, -- %01000100
    [0x45] = 3, -- %01000101
    [0x46] = 3, -- %01000110
    [0x47] = 4, -- %01000111
    [0x48] = 2, -- %01001000
    [0x49] = 3, -- %01001001
    [0x4a] = 3, -- %01001010
    [0x4b] = 4, -- %01001011
    [0x4c] = 3, -- %01001100
    [0x4d] = 4, -- %01001101
    [0x4e] = 4, -- %01001110
    [0x4f] = 5, -- %01001111

    [0x50] = 2, -- %01010000
    [0x51] = 3, -- %01010001
    [0x52] = 3, -- %01010010
    [0x53] = 4, -- %01010011
    [0x54] = 3, -- %01010100
    [0x55] = 4, -- %01010101
    [0x56] = 4, -- %01010110
    [0x57] = 5, -- %01010111
    [0x58] = 3, -- %01011000
    [0x59] = 4, -- %01011001
    [0x5a] = 4, -- %01011010
    [0x5b] = 5, -- %01011011
    [0x5c] = 4, -- %01011100
    [0x5d] = 5, -- %01011101
    [0x5e] = 5, -- %01011110
    [0x5f] = 6, -- %01011111

    [0x60] = 2, -- %01100000
    [0x61] = 3, -- %01100001
    [0x62] = 3, -- %01100010
    [0x63] = 4, -- %01100011
    [0x64] = 3, -- %01100100
    [0x65] = 4, -- %01100101
    [0x66] = 4, -- %01100110
    [0x67] = 5, -- %01100111
    [0x68] = 3, -- %01101000
    [0x69] = 4, -- %01101001
    [0x6a] = 4, -- %01101010
    [0x6b] = 5, -- %01101011
    [0x6c] = 4, -- %01101100
    [0x6d] = 5, -- %01101101
    [0x6e] = 5, -- %01101110
    [0x6f] = 6, -- %01101111

    [0x70] = 3, -- %01110000
    [0x71] = 4, -- %01110001
    [0x72] = 4, -- %01110010
    [0x73] = 5, -- %01110011
    [0x74] = 4, -- %01110100
    [0x75] = 5, -- %01110101
    [0x76] = 5, -- %01110110
    [0x77] = 6, -- %01110111
    [0x78] = 4, -- %01111000
    [0x79] = 5, -- %01111001
    [0x7a] = 5, -- %01111010
    [0x7b] = 6, -- %01111011
    [0x7c] = 5, -- %01111100
    [0x7d] = 6, -- %01111101
    [0x7e] = 6, -- %01111110
    [0x7f] = 7, -- %01111111

    [0x80] = 1, -- %10000000
    [0x81] = 2, -- %10000001
    [0x82] = 2, -- %10000010
    [0x83] = 3, -- %10000011
    [0x84] = 2, -- %10000100
    [0x85] = 3, -- %10000101
    [0x86] = 3, -- %10000110
    [0x87] = 4, -- %10000111
    [0x88] = 2, -- %10001000
    [0x89] = 3, -- %10001001
    [0x8a] = 3, -- %10001010
    [0x8b] = 4, -- %10001011
    [0x8c] = 3, -- %10001100
    [0x8d] = 4, -- %10001101
    [0x8e] = 4, -- %10001110
    [0x8f] = 5, -- %10001111

    [0x90] = 2, -- %10010000
    [0x91] = 3, -- %10010001
    [0x92] = 3, -- %10010010
    [0x93] = 4, -- %10010011
    [0x94] = 3, -- %10010100
    [0x95] = 4, -- %10010101
    [0x96] = 4, -- %10010110
    [0x97] = 5, -- %10010111
    [0x98] = 3, -- %10011000
    [0x99] = 4, -- %10011001
    [0x9a] = 4, -- %10011010
    [0x9b] = 5, -- %10011011
    [0x9c] = 4, -- %10011100
    [0x9d] = 5, -- %10011101
    [0x9e] = 5, -- %10011110
    [0x9f] = 6, -- %10011111

    [0xa0] = 2, -- %10100000
    [0xa1] = 3, -- %10100001
    [0xa2] = 3, -- %10100010
    [0xa3] = 4, -- %10100011
    [0xa4] = 3, -- %10100100
    [0xa5] = 4, -- %10100101
    [0xa6] = 4, -- %10100110
    [0xa7] = 5, -- %10100111
    [0xa8] = 3, -- %10101000
    [0xa9] = 4, -- %10101001
    [0xaa] = 4, -- %10101010
    [0xab] = 5, -- %10101011
    [0xac] = 4, -- %10101100
    [0xad] = 5, -- %10101101
    [0xae] = 5, -- %10101110
    [0xaf] = 6, -- %10101111

    [0xb0] = 3, -- %10110000
    [0xb1] = 4, -- %10110001
    [0xb2] = 4, -- %10110010
    [0xb3] = 5, -- %10110011
    [0xb4] = 4, -- %10110100
    [0xb5] = 5, -- %10110101
    [0xb6] = 5, -- %10110110
    [0xb7] = 6, -- %10110111
    [0xb8] = 4, -- %10111000
    [0xb9] = 5, -- %10111001
    [0xba] = 5, -- %10111010
    [0xbb] = 6, -- %10111011
    [0xbc] = 5, -- %10111100
    [0xbd] = 6, -- %10111101
    [0xbe] = 6, -- %10111110
    [0xbf] = 7, -- %10111111

    [0xc0] = 2, -- %11000000
    [0xc1] = 3, -- %11000001
    [0xc2] = 3, -- %11000010
    [0xc3] = 4, -- %11000011
    [0xc4] = 3, -- %11000100
    [0xc5] = 4, -- %11000101
    [0xc6] = 4, -- %11000110
    [0xc7] = 5, -- %11000111
    [0xc8] = 3, -- %11001000
    [0xc9] = 4, -- %11001001
    [0xca] = 4, -- %11001010
    [0xcb] = 5, -- %11001011
    [0xcc] = 4, -- %11001100
    [0xcd] = 5, -- %11001101
    [0xce] = 5, -- %11001110
    [0xcf] = 6, -- %11001111

    [0xd0] = 3, -- %11010000
    [0xd1] = 4, -- %11010001
    [0xd2] = 4, -- %11010010
    [0xd3] = 5, -- %11010011
    [0xd4] = 4, -- %11010100
    [0xd5] = 5, -- %11010101
    [0xd6] = 5, -- %11010110
    [0xd7] = 6, -- %11010111
    [0xd8] = 4, -- %11011000
    [0xd9] = 5, -- %11011001
    [0xda] = 5, -- %11011010
    [0xdb] = 6, -- %11011011
    [0xdc] = 5, -- %11011100
    [0xdd] = 6, -- %11011101
    [0xde] = 6, -- %11011110
    [0xdf] = 7, -- %11011111

    [0xe0] = 3, -- %11100000
    [0xe1] = 4, -- %11100001
    [0xe2] = 4, -- %11100010
    [0xe3] = 5, -- %11100011
    [0xe4] = 4, -- %11100100
    [0xe5] = 5, -- %11100101
    [0xe6] = 5, -- %11100110
    [0xe7] = 6, -- %11100111
    [0xe8] = 4, -- %11101000
    [0xe9] = 5, -- %11101001
    [0xea] = 5, -- %11101010
    [0xeb] = 6, -- %11101011
    [0xec] = 5, -- %11101100
    [0xed] = 6, -- %11101101
    [0xee] = 6, -- %11101110
    [0xef] = 7, -- %11101111

    [0xf0] = 4, -- %11110000
    [0xf1] = 5, -- %11110001
    [0xf2] = 5, -- %11110010
    [0xf3] = 6, -- %11110011
    [0xf4] = 5, -- %11110100
    [0xf5] = 6, -- %11110101
    [0xf6] = 6, -- %11110110
    [0xf7] = 7, -- %11110111
    [0xf8] = 5, -- %11111000
    [0xf9] = 6, -- %11111001
    [0xfa] = 6, -- %11111010
    [0xfb] = 7, -- %11111011
    [0xfc] = 6, -- %11111100
    [0xfd] = 7, -- %11111101
    [0xfe] = 7, -- %11111110
    [0xff] = 8, -- %11111111
}

return Compress