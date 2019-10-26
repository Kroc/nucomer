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
require "scripts.line"

--------------------------------------------------------------------------------
local hyphenate = require "scripts.hyphenate"

for _, s_exception in pairs({
    -- where the hyphenation algorithm fails, I am referring to the
    -- "Collins Gem Dictionary Of English Spelling", 1994 reprint,
    -- ISBN: 0-00-458725-1
    "al-tered", "every-thing", "pri-vate", "with-out"
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
    self:readLine("")

    local is_block = false

    -- walk each source line:
    -- (each source line may produce, 0, 1, or more output lines)
    --
    for s_line in f_lines do
        ------------------------------------------------------------------------
        -- is this a literal block?
        if s_line:sub(1, 3) == "```" then
            -- if already within a literal block
            if is_block == true then
                -- this ends the block
                is_block = false
            else
                -- this is the beginning of a literal-block;
                -- process the following lines as literal characters,
                -- i.e. ASCII / PETSCII and don't use text-compression
                is_block = true
            end
            -- note how the literal block marker
            -- is never output to the C64
        else
            -- which mode of text are we processing?
            if is_block == false then
                -- process as regular text
                self:readLine(s_line)
            else
                -- process as literal text
                self:readLiteralLine(s_line)
            end
        end
    end
    -- add the trailing line to account for the off-screen bottom row
    self:readLine("")
end

-- take an input line of ASCII text and create C64 line(s)
--------------------------------------------------------------------------------
function Article:readLine(s_text)
    ----------------------------------------------------------------------------
    -- line-lenth we'll be breaking against
    local scr_width = 40

    -- create line-object to hold line meta-data
    local line          = Line:new()
    local index         = 1     -- current byte index in the line (1-based)
    local word_str      = ""    -- current word (for word-wrapping)
    local word_len      = 0     -- character length of word (not byte-length!)

    -- flag for indicating when we're between / within words, as certain markup
    -- only applies at the beginning of a word, e.g. titles, URLs
    local is_word   = false
    -- flag to indicate if a trailing space
    -- should be added after the current word
    local is_space  = false

    local is_bold   = false
    local is_noun   = false
    local is_name   = false
    -- indicates that the current word is a URL and therefore
    -- needs to be word-wrapped differently
    local is_url    = false

    -- (private) add character to the current word
    ----------------------------------------------------------------------------
    function _addChar(i_char)
        ------------------------------------------------------------------------
        word_str = word_str .. string.char(i_char)
        word_len = word_len + 1
        is_word  = true
    end

    -- returns the escape-sequence for a given style class number
    ----------------------------------------------------------------------------
    function _escStr(i_style)
        ------------------------------------------------------------------------
        if i_style == STYLE_DEFAULT then
            return ESC_DEFAULT
        elseif i_style == STYLE_TITLE then
            return ESC_TITLE
        elseif i_style == STYLE_BOLD then
            return ESC_BOLD
        elseif i_style == STYLE_NOUN then
            return ESC_NOUN
        elseif i_style == STYLE_NAME then
            return ESC_NAME
        elseif i_style == STYLE_SOFT then
            return ESC_SOFT
        elseif i_style == STYLE_URL then
            return ESC_URL
        elseif i_style == STYLE_WARN then
            return ESC_WARN
        end
    end

    -- (private) append current word to the current line
    ----------------------------------------------------------------------------
    function _addWord()
        ------------------------------------------------------------------------
        -- check the length of the line, assuming the word is added to the end.
        -- note: when converted to C64 screen codes, the word may amount to
        -- more or less characters than on its own, which is why we do the
        -- line-break check this way
        --
        local c64_old = line.source
        local c64_new = ""
        -- add the word to the end of this test line
        c64_new = c64_old .. word_str
        -- convert to C64 screen-codes,
        -- giving us the on-screen widths
        c64_old = c64_old:toC64()
        c64_new = c64_new:toC64()

        -- if the word fits the line, add as is
        --
        if #c64_new <= scr_width then
            --------------------------------------------------------------------
            if word_len > 0 then line:addString(word_str); end
            -- do we need to append a space?
            if is_space then line:addString(" "); end

        -- if the word would not fit on the line,
        -- hyphenate & word-wrap:
        --
        else
            --------------------------------------------------------------------
            local before, after
            -- is this a URL? (don't hyphenate)
            if is_url then
                -- how much of the URL will fit?
                local i = scr_width - #c64_old
                -- split the URL into two pieces
                before = word_str:sub(1, i)
                after  = word_str:sub(i+1)
            else
                -- hyphenate the word splitting into as much as can fit
                -- on the current line and the remainder for the next line
                before, after = hyphenate:breakWord(
                    "en-gb", word_str,
                    -- split the word according to how much line space remains
                    scr_width - line:getCharLen()
                )
            end
            --#print(before, after)
            -- add the part of the word that fits (if any)
            if #before > 0 then line:addString(before); end
            -- dispatch the current line
            _addLine()
            -- begin the new line with the remainder of the word, if any
            if #after > 0 then
                -- the remainder may still be too long!
                -- (particularly with URLs)
                if #after > (scr_width-line.indent) then
                    word_str = after
                    word_len = #after
                    _addWord()
                    return
                else
                    line:addString(after)
                    -- do we need to append a space?
                    if is_space then line:addString(" "); end
                end
            end
        end

        -- reset the current word
        word_str    = ""
        word_len    = 0
        is_word     = false
        is_url      = false     -- URLs have no spaces
        is_space    = false
    end

    -- (private) add the current line to the article, and start another
    ----------------------------------------------------------------------------
    function _addLine()
        ------------------------------------------------------------------------
        -- trim any trailing spaces on the line
        line.source = line.source:gsub("%s+$", "")
        -- when a line-break occurs, the next line must inherit the style
        -- of the current line; e.g. titles that span multiple lines
        local old_indent  = line.indent
        local old_literal = line.is_literal
        local old_default = line.default
        -- add line to the article line array
        table.insert(self.lines, line)
        -- start a new line
        line = Line:new()
        -- apply the properties from the old line
        line.indent     = old_indent
        line.is_literal = old_literal
        line.default    = old_default
        -- apply the indent
        if line.indent > 0 then
            line:addString(string.rep(" ", line.indent))
        end
        -- apply the style from the previous line
        -- e.g. when a long title line-breaks
        -- TODO: this should use a style class stack
        if line.default ~= STYLE_DEFAULT then
            line:addString(_escStr(line.default))
        end
        if is_noun  then line:addString(ESC_NOUN); end
        if is_name  then line:addString(ESC_NAME); end
        if is_bold  then line:addString(ESC_BOLD); end
        if is_url   then line:addString(ESC_URL);  end
        is_word = false
    end

    -- indent?
    ----------------------------------------------------------------------------
    if s_text:match("^%s+") then
        -- how much?
        local s_indent = s_text:match("^%s+")
        -- set the property on the line object so that if a line-break occurs
        -- (e.g. word-wrap), the indent is carried on to subsequent lines
        line.indent = #s_indent
        -- add the indent to the output line
        line:addString(s_indent)
        -- skip these spaces, effectively restarting the line
        -- (this is needed to allow for indent + bullet point, for example)
        index = #s_indent+1
    end

    -- look for special markup at the beginning of the line
    ----------------------------------------------------------------------------
    -- :: title
    --
    if s_text:match("^:: ", index) then
        ------------------------------------------------------------------------
        line.default = STYLE_TITLE  -- change the line's default style class
        line:addString(ESC_TITLE)
        index = index + 3           -- move the index forward over the marker

    -- horizontal bar?
    -- ---------------
    elseif s_text:match("^%-%-%-%-", index) then
        ------------------------------------------------------------------------
        line.default = STYLE_TITLE  -- change the line's default style class
        line.is_literal = true      -- set as literal text and do not convert

        line:addString(ESC_TITLE)
        line:addString(
            -- build a horizontal bar directly out of screen-codes;
            -- (the escape code, 0x1b, allows embedding screen codes
            --  that won't be converted from ASCII)
            string.rep(string.char(0x1b, 0xf1), scr_width-line.indent)
        )

       -- no need to process any more of the source line
       -- just add the bar we've given and exit
       _addLine()
       return

    -- bullet list:
    -- * ...
    elseif s_text:match("^%* ", index) then
        ------------------------------------------------------------------------
        -- switch "*" for the bullet-point character
        line:addString(ESC_BOLD.."•".._escStr(line.default).." ")
        -- indent on line-break
        line.indent = line.indent + 2
        -- begin after the bullet-point
        index = index + 2

    -- list item "-":
    -- - ...
    elseif s_text:match("^%- ", index) then
        ------------------------------------------------------------------------
        line:addString(ESC_BOLD.."-".._escStr(line.default).." ")
        -- indent on line-break
        line.indent = line.indent + 2
        -- begin after the bullet-point
        index = index + 2

    -- numbered list:
    -- 1. / a. / i. / A.
    elseif s_text:match("^%w+%. ", index) then
        ------------------------------------------------------------------------
        -- get the details
        local s_numeral = s_text:match("^%w+%.", index)
        -- add it to the output line (excluding the space!)
        line:addString(ESC_BOLD..s_numeral.._escStr(line.default))
        -- set the hanging indent for line-breaks
        line.indent = line.indent + 2
        -- skip the detected numeral point
        index = index + #s_numeral + 1
    end

    -- convert em-dashes and consume optional spaces either side
    --#s_text = s_text:gsub(" ?%-%- ?", "—") -- note that this is an em-dash!

    s_text = s_text .. " "
    ----------------------------------------------------------------------------
    while index <= #s_text-1 do
        ------------------------------------------------------------------------
        -- special handling for start of words;
        -- some formatting we do not want to match in the middle of a word
        --
        if is_word == false then
            --------------------------------------------------------------------
            -- url?
            --------------------------------------------------------------------
            if s_text:match("^<%S+>", index) then
                local match = s_text:match("^<%S+>", index)
                -- extract the URL, (skip "<" & ">")
                local url = match:sub(2, -2)
                -- set the URL as the current word,
                -- and apply the URL style class
                word_str    = url
                word_len    = #url
                is_url      = true      -- use URL word-wrapping
                -- switch to the URL style class
                line:addString(ESC_URL)
                -- add the URL to line
                _addWord()
                line:addString(_escStr(line.default))
                -- skip over the URL text
                index = index + #match-1
                -- skip the sigil
                index = index + 1

            -- *bold*
            --------------------------------------------------------------------
            elseif s_text:match("^%*%g", index) then
                -- switch to the 'bold' style class
                line:addString(ESC_BOLD)
                -- set the flags for when line-breaks occur
                is_bold = true
                is_word = true
                -- skip the sigil
                index = index + 1

            -- ~noun~
            --------------------------------------------------------------------
            elseif s_text:match("^%~%g", index) then
                -- switch to the 'noun' style class
                line:addString(ESC_NOUN)
                -- set the flags for when line-breaks occur
                is_noun = true
                is_word = true
                -- skip the sigil
                index = index + 1

            -- _name_
            --------------------------------------------------------------------
            elseif s_text:match("^%_%g", index) then
                -- switch to the 'name' style class
                line:addString(ESC_NAME)
                -- set the flags for when line-breaks occur
                is_name = true
                is_word = true
                -- skip the sigil
                index = index + 1

            end
        end

        -- read a single byte
        local ascii = s_text:byte(index)

        -- space = word-break
        --
        if ascii == 0x20 then
            --------------------------------------------------------------------
            -- the current word is complete, add it to the line
            -- and handle the trailing space according to word-wrap
            is_space = true; _addWord()

        -- punctuation that line-breaks before (but not after)
        -- e.g. wrapping punctuation such as "(..."
        --
        elseif s_text:match("^[%(%[]", index) then
            --------------------------------------------------------------------
            -- force a word-break
            _addWord()
            -- add the punctuation to the current word so it stays stuck to it
            _addChar(ascii)
            -- TODO: this allows a line-break immediately after a bracket :(
            _addWord()
            -- allow start-of-word markup
            is_word = false

        -- punctuation that line-breaks after (but not before)
        -- e.g. don't break "yes/no" such that a line begins with "/"
        --
        elseif s_text:match("^[\\/%)%]]", index) then
            --------------------------------------------------------------------
            -- add the punctuation to the current word so it stays stuck to it
            _addChar(ascii)
            -- force a word-break; if the characters after the punctuation
            -- don't fit, they will be moved to the next line
            _addWord()
            -- allow for start-of-word markup
            is_word = false

        -- an em-dash is a word-break either side
        --
        elseif s_text:match("^ ?— ?", index) then
            --------------------------------------------------------------------
            -- how many bytes is that?
            local em = s_text:match("^ ?— ?", index)
            -- add current word, treating the em-dash as a word-break
            _addWord()
            -- add the em-dash as its own word
            word_str = "—"
            word_len = 1
            _addWord()
            -- skip the extra byte(s)
            index = index + #em-1

        elseif s_text:match("^ ?%-%- ?") then
            --------------------------------------------------------------------
            -- how many bytes is that?
            local em = s_text:match("^ ?%-%- ?", index)
            -- add current word, treating the em-dash as a word-break
            _addWord()
            -- add the em-dash as its own word
            word_str = "—"
            word_len = 1
            _addWord()
            -- skip the extra byte
            index = index + #em-1

        -- end of bold
        ------------------------------------------------------------------------
        elseif s_text:match("^%*[%s%p]", index) then
            _addWord()
            is_bold = false
            -- TODO: we need a style stack, as this won't handle nesting
            line:addString(_escStr(line.default))

        -- end of noun class
        ------------------------------------------------------------------------
        elseif s_text:match("^%~[%s%p]", index) then
            _addWord()
            is_noun = false
            -- TODO: we need a style stack, as this won't handle nesting
            line:addString(_escStr(line.default))

        -- end of name class
        ------------------------------------------------------------------------
        elseif s_text:match("^%_[%s%p]", index) then
            _addWord()
            is_name = false
            -- TODO: we need a style stack, as this won't handle nesting
            line:addString(_escStr(line.default))

        else
            --------------------------------------------------------------------
            -- add to the current word
            _addChar(ascii)
        end

        -- move to the next character
        index = index + 1
    end
    ----------------------------------------------------------------------------
    -- add the current word to the end of the line.
    -- this might cause an additional line-break!
    _addWord()
    -- dispatch the final line
    _addLine()
end

--------------------------------------------------------------------------------
function Article:readLiteralLine(s_text)
    ----------------------------------------------------------------------------
    -- create line-object to hold line meta-data
    local line      = Line:new()
    -- set the line to encode as literal when converting to C64 data
    line.is_literal = true

    line:addString(s_text)

    -- add line to the article line array
    table.insert(self.lines, line)
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

    -- convert all lines to C64 colour-spans & screen-codes
    local lines = {}
    for i, line in ipairs(self.lines) do table.insert(lines, {
        colour  = line:getBinColour(),
        text    = line:getBinText()
    }); end

    -- the list of line-lengths:
    ----------------------------------------------------------------------------
    for _, line in ipairs(lines) do
        -- the length of the line-data, in bytes:
        local line_len = #line.colour + #line.text
        -- the presence of colour data is indicated by the high-bit
        -- (so that we don't need an extra byte for every uncoloured line)
        if #line.colour > 0 then line_len = line_len + 0x80; end
        -- write the line-length byte to the file
        f_out:write(string.pack("B", line_len))
    end
    -- the lines-length table is suffixed with 0x80
    -- to indicate when to stop scrolling downwards
    f_out:write(string.pack("B", 0x80))

    -- and then the binary line-data:
    ----------------------------------------------------------------------------
    for _, line in ipairs(lines) do
        -- do not output empty lines; on the C64, when a line-length of 0
        -- is encountered, the line-data pointer is not moved forward
        if #line.text > 0 then
            -- note that lines are written into the binary backwards!
            -- this is so that the line length can be used as a count-down
            -- index which is faster for 6502s to process
            f_out:write(string.reverse(line.colour..line.text))
        end
    end
end
