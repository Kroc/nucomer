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
    self.lines = {}
    self.pairs = {}
    self.chars = {}
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
    table.insert(self.lines, {
        colour = out_colour,
        screen = out_screen,
        source = src_line,
        -- unused initially, but will hold the tokenised version of the line
        tokens = "",
    })

    --[[
    -- bit-pack the spaces
    ----------------------------------------------------------------------------
    -- a _lot_ of text is just spaces between words. if instead we represented
    -- the spaces as individual bits we could save a lot of space. early word-
    -- processors would use the high-bit of a byte to indicate the end of a
    -- word, and an implicit following space, but we'll need all 256 screen-
    -- codes at our disposal
    --
    -- instead of a high-bit, we'll built a bitmap of the characters in the
    -- line, where 0 = not a space and 1 = space. even though a full line of
    -- 40 characters will need 5 bytes (40 bits), most lines of such length
    -- already average five or more spaces whose bytes won't be needed;
    --
    local spaces = 0            -- current bit-pattern of spaces (8 bits)
    local word = ""             -- we build a set of chars, without spaces
    local out_chars = ""        -- compressed C64 text data

    --#print('"'..line..'"')
    --#io.stdout:write(".")

    -- walk through the characters in the line
    for i = 1, #src_chars do
        ------------------------------------------------------------------------
        -- is this character a space?
        if src_chars:byte(i) == nuspc then
            -- yes: set a bit in the spaces bitmap; the space
            -- character doesn't need to be added to the 'word'
            spaces = spaces * 2
            spaces = spaces + 1
            --#io.stdout:write("1")
        else
            -- no: add the character to the current 'word'
            word = word .. src_chars:sub(i, i)
            -- shift to the next space bit
            -- without marking a space
            spaces = spaces * 2
            --#io.stdout:write("0")
        end
        -- is this the 8th character in a row?
        if i % 8 == 0 then
            --#io.stdout:write("\n.")
            -- yes: output the spaces bitmap, and the 8 characters
            out_chars = out_chars .. string.char(spaces) .. word
            -- reset the word / spaces bitmap
            spaces = 0
            word = ""
        end
    end
    -- when we reach the end of the line, we might not
    -- have reached 8 charcters yet
    if #word > 0 then
        -- output the remaining characters
        out_chars = out_chars .. string.char(spaces) .. word
    end
    --#io.stdout:write("\n")

    -- TODO: pack 7 bits, and use the 8th to indicate "no spaces for 7 chars"?
    if #out_chars > #src_chars then
        print('"'..line..'"')
        print("#", #src_chars, #out_chars)
    end
    --]]
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

    if 1 then return; end

    while token <= 0xFF do
        ------------------------------------------------------------------------
        -- find the most common token pair
        -- (this might include existing compressed token-pairs!)
        local old_pair, old_count = self:analysePairs()

        if old_count ~= 0 then
            io.stdout:write(string.format(
                "  ? $%02X = $%02X,$%02X ",
                token,
                old_pair:byte(1),
                old_pair:byte(2)
            ))
        else
            break
        end

        -- define the new token as a pair of old tokens
        self.tokens[token] = old_pair

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

        print(string.format(
            "      %5d %10s",
            new_size-old_size,
            filesize(new_size)
        ))

        -- move to the next token number
        token = token + 1
    end
end

-- assign unique characters to the first initial tokens
--------------------------------------------------------------------------------
function Compress:tokeniseChars()
    ----------------------------------------------------------------------------
    io.stdout:write("> tokenising...               ")

    -- clear the current token definitions & character statistics.
    self.tokens = {}
    self.chars = {}

    -- pre-populate all 256 possible chars, as Lua will stop
    -- iterating a table at the first 'gap' between indices
    for i = 0, 255 do self.chars[i] = 0; end

    -- walk all lines of text...
    --
    for _, t_line in ipairs(self.lines) do
        ------------------------------------------------------------------------
        -- spaces are stripped from lines and bit-packed separately
        -- since they would out-number all other chars
        --
        local scr_line = t_line.screen
        --#scr_line = scr_line:gsub("\x00", ""):scr2lower()

        -- walk the bytes...
        local j = 1
        while j <= #scr_line do
            --------------------------------------------------------------------
            -- count the character
            local char = scr_line:byte(j)
            self.chars[char] = (self.chars[char] or 0) + 1
            -- move to next character
            j = j + 1
        end
    end

    -- now we've counted the screen codes, begin assigning them to tokens;
    -- the order used is not actually important, but could perhaps be
    -- controlled in the future as some kind of arithmetic-coding
    ----------------------------------------------------------------------------
    local token = 1
    -- check each of the possible unqiue screen codes...
    for i = 0, 255 do
        -- was the screen-code ever used?
        if self.chars[i] > 0 then
            -- define the token as a literal;
            -- a null followed by the screen-code
            self.tokens[token] = string.char(0, i)
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
        --#scr_line = scr_line:gsub("\x00", ""):scr2lower()

        -- this will be the token-encoded version of the line
        local tok_line = ""
        -- walk each screen-code in the source line
        for j = 1, #scr_line do
            -- determine the screen code
            local scr = scr_line:byte(j)
            -- ignore spaces?
            --#if scr == 0x00 then error("leaked space!"); end

            -- get the token for it
            local tok = self.chars[scr]
            -- add the token to the output
            tok_line = tok_line .. string.char(tok)
        end
        -- the line has been converted
        self.lines[i].tokens = tok_line
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
        !word   (lines-lengths)+1

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
        -- as the tables must align
        local i_left  = (self.tokens[i] or ""):byte(1) or 0
        local i_right = (self.tokens[i] or ""):byte(2) or 0

        s_left = s_left .. string.format(
            "        !byte   $%02x\n", i_left
        )
        s_right = s_right .. string.format(
            "        !byte   $%02x\n", i_right
        )
    end
    s_out = s_out:gsub("%{%{TOKENS_LO%}%}", s_left)
    s_out = s_out:gsub("%{%{TOKENS_HI%}%}", s_right)

    return s_out
end

return Compress