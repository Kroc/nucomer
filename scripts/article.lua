-- article.lua : manages article text transformation

require "scripts.c64"

hyphenate = require "scripts.hyphenate"

for _, s_exception in pairs({
    "pri-vate", "every-thing", "mag-azine", "to-day"
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
    local broken = false

    for i, word in ipairs(words) do
        -- once the line-break has occurred, all remaining words are added
        -- after the line-break with no further hyphenation required
        if broken then
            after = after .. "-" .. word
        else
            -- split the word into hyphenation boundaries
            t_pieces = self:hyphenate(s_locale, word)
            -- with multiple words, we need to account for the explicit-hypehn
            -- that must be preserved between words (e.g. "cul-de-sac"). when
            -- one word has already been added to the line and wrapping has
            -- not yet occurred we have to add the explicit hyphen
            if i > 1 then
                -- will the explicit-hyphen, first word-piece
                -- and trailing hyphen fit on to the line?
                if #before + 1 + #t_pieces[1] + 1 <= s_len then
                    -- yes, the explicit hyphen can be included
                    before = before .. "-"
                end
                -- in the case where the explicit-hyphen does not fit,
                -- the line-break will convert it into an implicit hyphen
                -- avoiding it being added twice
            end
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
    -- we can now add the hyphen at the word-break point
    if #before > 0 then before = before .. "-"; end
    
    return before, after

--#    -- add word pieces until we can't fit any more on the line...
--#    for _, piece in ipairs(t_pieces) do
--#        -- if a word-piece can fit (including a trailing hyphen!)
--#        -- then add it (sans-hyphen) and try the next piece
--#        if broken == false and #left + #piece + 1 <= s_len then
--#            left = left .. piece
--#        else
--#            -- the word-piece does not fit!
--#            -- add it to the right-hand side instead
--#            right = right .. piece
--#            broken = true
--#        end
--#    end
--#    -- add the hyphen to the left-hand side
--#    if #left > 0 then left = left .. "-"; end
--#    -- return the left & right sides
--#    return left, right
end

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
    local word_str  = ""        -- current word (for word-wrapping)
    local word_len  = 0         -- character length of word (not byte-length!)

    -- we do not want to leave trailing spaces on lines, so when a word begins,
    -- we hold on to the space until the word ends and decide where it goes
    -- based on the word-wrapping
    local word_spc  = 0         -- number of pending spaces once word ends

    -- (private) add C64 character-code to the current line
    ----------------------------------------------------------------------------
    function add_char(i_char)
        ------------------------------------------------------------------------
        -- add the character to the word
        word_str = word_str .. string.char(i_char)
        word_len = word_len + 1
    end

    -- (private) append current word to the current line
    ----------------------------------------------------------------------------
    function add_word()
        ------------------------------------------------------------------------
        -- if the word will not fit on the line, hyphenate & word-wrap
        if line.length + word_len + word_spc > 40 then
            -- hyphenate the word splitting into as much as can fit
            -- on the current line and the remainder for the next line
            -- TODO: strip pre & post-fix punctuation when hyphenating
            local left, right = hyphenate:breakWord(
                -- split the word according to how much line space remains
                "en-gb", word_str, (40 - line.length) - word_spc
            )
            --#print(left, right)
            -- add the part of the word that fits (if any)
            if #left > 0 then
                -- add the pending spaces from before the word started
                if word_spc > 0 then
                    line:addString(string.rep(" ", word_spc))
                end
                -- add the hyphenated portion of the word
                line:addString(left)
                -- the pending spaces have been handled,
                -- don't add them again on the next line
                word_spc = 0
            end
            -- dispatch the current line
            add_line()
            -- begin the new line with the remainder of the word, if any
            if #right > 0 then
                line:addString(right)
                -- add a pending space for when the next word,
                -- technically the first word of a source line,
                -- gets added
                word_spc = 1
            end
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
    -- title?
    if s_text:match("^::") ~= nil then
        -- change the line's default style class
        line.default = 1
        -- move the index forward over the marker
        index = 3
    end

::next::
    ----------------------------------------------------------------------------
    local i_ascii

    -- move to the next character
    index = index + 1
    -- hit end of the line?
    if index > #s_text then goto eol; end

    -- read a single byte
    i_ascii = s_text:byte(index)

    -- space = word-break
    if i_ascii == 0x20 then
        -- the current word is complete, add it to the line
        -- and handle the pending space according to word-wrap
        add_word()
        -- queue another space
        word_spc = 1
    else
        -- add to the current word
        -- (and handle word-wrap)
        add_char(i_ascii)
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
    f_out:write(string.pack("<I2", 0x1FFE))

    -- how long the line-lengths list is (2-bytes)
    f_out:write(string.pack("<I2", #self.lines+2))
    -- the list of line-lengths
    for _, line in ipairs(self.lines) do
        if line.default ~= 0 then
            f_out:write(string.pack("B", line:getLen() + 0x80))
        else
            f_out:write(string.pack("B", line:getLen()))
        end
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
    ascii       = "",       -- original ASCII line representation
    colour      = "",       -- binary colour data for the line
    length      = 0,        -- length of line in *bytes*
    default     = 0,        -- default colour class
}

-- create a new instance of the Line class
--------------------------------------------------------------------------------
function Line:new()
    ----------------------------------------------------------------------------
    -- crate new, empty, instance
    local line = {
        ascii       = "",       -- the original ASCII line representation
        colour      = "",       -- binary colour data for the line
        length      = 0,        -- length of line in *bytes*
        default     = 0         -- default colour class
    }
    setmetatable(line, self)    -- set new instance to inherit from prototype
    self.__index = self         -- bind "self"
    return line                 -- return the new instance
end

-- add an ASCII character to the ASCII representation of the line
--------------------------------------------------------------------------------
function Line:addChar(i_byte)
    self.ascii = self.ascii .. string.char(i_byte)
    self.length = self.length + 1
end

--------------------------------------------------------------------------------
function Line:addString(s_text)
    ----------------------------------------------------------------------------
    self.ascii = self.ascii .. s_text
    self.length = self.length + #s_text
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
    -- add the text
    bin = bin .. c64_str2scr(self.ascii)
    -- note that lines are written into the binary backwards!
    -- this is so that the line length can be used as a count-down
    -- index which is faster for 6502s to process
    return bin:reverse()
end

-- length of the binary line, including colour-data (if present)
--------------------------------------------------------------------------------
function Line:getLen()
    return string.len(self:getBin())
end