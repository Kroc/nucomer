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
require "scripts.string"

--------------------------------------------------------------------------------
local hyphenate = require "scripts.hyphenate"

for _, s_exception in pairs({
    -- where the hyphenation algorithm fails, I am referring to the
    -- "Collins Gem Dictionary Of English Spelling", 1994 reprint,
    -- ISBN: 0-00-458725-1
    --
    "al-tered", "de-fined", "every-thing", "pri-vate", "pro-vid-ed",
    "with-out",

    -- currently unchecked hyphenations:
    -- (to be cross-checked with dictionary)
    --
    -- x
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
        ------------------------------------------------------------------------
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
    infile    = "",
    outfile   = "",
    lines     = {},
    length    = 0,
    footnotes = {}
}

-- create a new instance of the Article class
--------------------------------------------------------------------------------
function Article:new()
    ----------------------------------------------------------------------------
    -- crate new, empty, instance
    local article = {
        infile    = "",
        outfile   = "",
        lines     = {},
        length    = 0,          -- no. of lines in the article, sans footnotes!
        footnotes = {}
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

    -- open the provided source file
    local f_in,err = io.open(self.infile, "r")
    if err then print ("! error: " .. err); os.exit(false); end

    -- seek to the end, to get the file size
    print(string.format("%10s", filesize(f_in:seek("end"))))
    print("----------------------------------------")
    f_in:seek("set") -- (return to start of file)

    -- get a line-reading iterator and read all lines in.
    -- the file will automatically close when all lines are read
    local f_lines = f_in:lines()
    local src_lines = {}
    for src_line in f_lines do table.insert(src_lines, src_line); end

    io.stdout:write("> word-wrapping...           ")

    -- TODO:
    -- due to the off-screen scrolling used on the C64, we need to add one
    -- blank line before the article and one-blank line after, though we
    -- strip excess leading / trailing lines first
    --
    -- add the leading line to account for the off-screen top row:
    --
    -- NOTE: in Lua, you cannot pass an empty table to a function
    --       as it gets optimised away into nil, so this line here
    --       is actually critical!
    --
    self:addLine("")

    -- add the trailing line to the lines yet to be processed;
    -- this gives us an effective one-line "look-ahead"
    -- without having to check for nil
    table.insert(src_lines, "")

    -- walk each source line:
    -- (each source line may produce, 0, 1, or more output lines!)
    --
    local i = 1
    while i <= #src_lines do
        ------------------------------------------------------------------------
        local src_line = src_lines[i]
        local is_block = false

        -- are we currently processing a literal block?
        --
        if is_block then
            --------------------------------------------------------------------
            -- has the literal block ended?
            --
            if src_line:sub(1, 3) == "```" then
                -- this ends the block
                is_block = false
                -- note how the literal block marker
                -- is never output to the C64
            else
                -- process as literal text
                self:readLiteralLine(self.lines, src_line)
            end

        -- is this a literal block?
        --
        elseif src_line:sub(1, 3) == "```" then
            --------------------------------------------------------------------
            -- this is the beginning of a literal-block;
            -- process the following lines as literal characters,
            -- i.e. ASCII / PETSCII and don't use text-compression
            is_block = true
            -- note how the literal block marker
            -- is never output to the C64

        -- [^n]: footnote definition
        --
        elseif src_line:match("^%[%^.+%]:") then
            --------------------------------------------------------------------
            -- we don't need to modify the line, just mark this as a footnote.
            -- first extract the footnote's identifier:
            local id = src_line:match("^%[%^(.+)%]:")

            -- footnotes can be defined "in-line", rather than having to be at
            -- the end of the article. we extract the footnote and append it
            -- to the end of the article for you, therefore define a temporary
            -- holding space for the footnote text separate from the article
            --
            -- NOTE: an empty table cannot be passed into a function,
            --       it'll appear as nil!
            --
            local fn_txt = {{source = ""}}

            -- process the footnote (source) line, this will likely
            -- be split into multiple (output) lines
            self:readLine(fn_txt, src_line)

            -- add an entry to the footnote table
            table.insert(self.footnotes, {
                id     = id,
                lines  = fn_txt,
                -- when the footnotes are appended to the article,
                -- these properties will be assigned:
                begin  = 0,     -- starting line number of footnote
                length = 0,     -- number of lines to print
            })

            -- to allow for in-lining of footnotes, we need to ignore the
            -- blank line following the footnote text used to separate
            -- the footnote, but not desired as part of the article
            i = i + 1

        else
            --------------------------------------------------------------------
            -- process as regular text
            self:readLine(self.lines, src_line)
        end

        -- note that in Lua, you can't manually increment
        -- the index in a for-loop!
        i = i + 1
    end

    -- append the footnotes to the end of the article:
    ----------------------------------------------------------------------------
    -- at this point we know the length of the article, sans footnotes.
    -- this value is what will be given to the C64 to set the scrolling
    -- limits so that the footnotes do not scroll into view
    -- (they can only be accessed by their keys)
    --
    self.length = #self.lines

    -- walk the defined footnotes (if any)
    --
    for _, fn in ipairs(self.footnotes) do
        ------------------------------------------------------------------------
        -- set the footnote's beginning line & length
        fn.begin  = #self.lines+1
        fn.length = #fn.lines-1
        -- append the footnote to the article
        for j = 2, #fn.lines do
            table.insert(self.lines, fn.lines[j])
        end
    end

    -- article read, print the number of lines produced, including footnotes
    io.stdout:write(string.format("%5u lines\n", #self.lines-2))
end

-- add a line of source (ASCII) text to article
--------------------------------------------------------------------------------
function Article:addLine(src_line)
    ----------------------------------------------------------------------------
    -- trim any trailing spaces on the line
    src_line = src_line:gsub("%s+$", "")
    -- add to the internal lines table
    table.insert(self.lines, {
        source = src_line
    })
end

-- take an input line of ASCII text and create C64-length line(s)
--------------------------------------------------------------------------------
function Article:readLine(out_lines, src_line)
    ----------------------------------------------------------------------------
    -- line-lenth we'll be breaking against
    local scr_width = 40

    local line          = ""    -- current line being built
    local index         = 1     -- current byte index in the line (1-based)
    local word_str      = ""    -- current word (for word-wrapping)
    local indent        = 0     -- size of the indent when breaking lines

    -- handles nesting of style class changes;
    -- the base is the default style
    local style         = STYLE_DEFAULT
    local style_stack   = {style}

    -- flag for indicating when we're between / within words, as certain markup
    -- only applies at the beginning of a word, e.g. titles, URLs
    local is_word   = false
    -- flag to indicate if a trailing space
    -- should be added after the current word
    local is_space  = false

    local is_bold   = false
    local is_noun   = false
    local is_name   = false
    local is_soft   = false
    -- indicates that the current word is a URL and therefore
    -- needs to be word-wrapped differently
    local is_url    = false

    -- (private) add character to the current word
    ----------------------------------------------------------------------------
    function _addChar(i_char)
        ------------------------------------------------------------------------
        word_str = word_str .. string.char(i_char)
        is_word  = true
    end

    -- (private) change to a new style class, remembering the previous
    ----------------------------------------------------------------------------
    function _pushStyle(i_style)
        ------------------------------------------------------------------------
        -- push the old style on top of the stack
        table.insert(style_stack, style)
        -- change to the new style
        style = i_style
        -- return the escape code for the new style
        return _escStr(style)
    end

    -- (private) change to the previously used style class
    ----------------------------------------------------------------------------
    function _popStyle(i_style)
        ------------------------------------------------------------------------
        -- retrieve the previously used style
        style = table.remove(style_stack, i_style)
        -- return the escape code for the previous style
        return _escStr(style)
    end

    -- returns the escape-sequence for a given style class number
    ----------------------------------------------------------------------------
    function _escStr(i_style)
        ------------------------------------------------------------------------
        return ESC..tostring(i_style)
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
        local c64_old = line
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
            line = line .. word_str
            -- if the word fits exactly, we don't want to start
            -- the next line with an errant space
            if #c64_new < scr_width then
                -- should we add a space after the word?
                if is_space then line = line .. " "; end
            end

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
                    scr_width - #c64_old
                )
            end

            --#print(before, after)

            -- add the part of the word that fits (if any)
            if #before > 0 then line = line .. before; end
            -- dispatch the current line
            _addLine()
            -- begin the new line with the remainder of the word, if any
            if #after > 0 then
                -- the remainder may still be too long!
                -- (particularly with URLs)
                if #after > (scr_width-indent) then
                    word_str = after
                    _addWord()
                    return
                else
                    line = line .. after
                    -- do we need to append a space?
                    if is_space then line = line .. " "; end
                end
            end
        end

        -- reset the current word
        word_str    = ""
        is_word     = false
        is_url      = false     -- URLs have no spaces
        is_space    = false
    end

    -- (private) add the current line to the article, and start another
    ----------------------------------------------------------------------------
    function _addLine()
        ------------------------------------------------------------------------
        -- add the line to the given line array
        table.insert(out_lines, {
            -- trim any trailing spaces
            source = line:gsub("%s+$", ""),
        })
        -- start a new line
        line = ""
        -- apply the indent
        if indent > 0 then line = line .. string.rep(" ", indent); end
        -- apply the style from the previous line
        -- e.g. when a long title line-breaks
        --
        if style ~= STYLE_DEFAULT then
            -- add the escape code to switch style classes
            line = line .. _escStr(style)
        end
        -- begin a new word, allowing for
        -- start-of-word specific markup
        is_word = false
    end

    -- indent?
    ----------------------------------------------------------------------------
    if src_line:match("^%s+") then
        -- how much?
        local s_indent = src_line:match("^%s+")
        -- set the property on the line object so that if a line-break occurs
        -- (e.g. word-wrap), the indent is carried on to subsequent lines
        indent = #s_indent
        -- add the indent to the output line
        line = line .. s_indent
        -- skip these spaces, effectively restarting the line
        -- (this is needed to allow for indent + bullet point, for example)
        index = #s_indent+1
    end

    -- look for special markup at the beginning of the line
    ----------------------------------------------------------------------------
    -- :: title
    --
    if src_line:match("^:: ", index) then
        ------------------------------------------------------------------------
        -- switch to the title style for the rest of the line
        line = line .. _pushStyle(STYLE_TITLE)
        -- move the index forward over the marker
        index = index + 3

    -- horizontal bar?
    -- ---------------
    elseif src_line:match("^%-%-%-%-", index) then
        ------------------------------------------------------------------------
        -- swich to the title style for the rest of the line
        line = line .. ESC_TITLE
            -- build a horizontal bar directly out of screen-codes;
            -- (the escape code, 0x1b, allows embedding screen codes
            --  that won't be converted from ASCII)
            .. string.rep(string.char(0x1b, 0xf1), scr_width-indent)

       -- no need to process any more of the source line
       -- just add the bar we've given and exit
       _addLine()
       return

    -- bullet list:
    -- * ...
    elseif src_line:match("^%* ", index) then
        ------------------------------------------------------------------------
        -- switch "*" for the bullet-point character
        line = line .. _pushStyle(STYLE_BOLD).."•".._popStyle().." "
        -- indent on line-break
        indent = indent + 2
        -- begin after the bullet-point
        index = index + 2

    -- list item "-":
    -- - ...
    elseif src_line:match("^%- ", index) then
        ------------------------------------------------------------------------
        line = line .. _pushStyle(STYLE_BOLD).."–".._popStyle().." "
        -- indent on line-break
        indent = indent + 2
        -- begin after the bullet-point
        index = index + 2

    -- numbered list:
    -- 1. / a. / i. / A.
    elseif src_line:match("^%w+%. ", index) then
        ------------------------------------------------------------------------
        -- get the details
        local s_numeral = src_line:match("^%w+%.", index)
        -- add it to the output line (excluding the space!)
        line = line .. _pushStyle(STYLE_BOLD)..s_numeral.._popStyle()
        -- set the hanging indent for line-breaks
        indent = indent + 2
        -- skip the detected numeral point
        index = index + #s_numeral + 1
    end

    -- appending a space to the text being processed gives us an easy solution
    -- for look-ahead without having to double the regexes for "end-of-line"
    -- (the additional space is not included in output)
    --
    src_line = src_line .. " "
    ----------------------------------------------------------------------------
    while index <= #src_line-1 do
        ------------------------------------------------------------------------
        -- special handling for start of words;
        -- some formatting we do not want to match in the middle of a word
        --
        if is_word == false then
            --------------------------------------------------------------------
            -- url?
            --------------------------------------------------------------------
            if src_line:match("^<%S+>", index) then
                local match = src_line:match("^<%S+>", index)
                -- extract the URL, (skip "<" & ">")
                local url = match:sub(2, -2)
                -- set the URL as the current word,
                -- and apply the URL style class
                word_str    = url
                is_url      = true      -- use URL word-wrapping
                -- switch to the URL style class
                line = line .. _pushStyle(STYLE_URL)
                -- add the URL to line
                _addWord()
                line = line .. _popStyle()
                -- skip over the URL text
                index = index + #match-1
                -- skip the sigil
                index = index + 1

            -- *bold*
            --------------------------------------------------------------------
            elseif src_line:match("^%*%g", index) then
                -- switch to the 'bold' style class
                line = line .. _pushStyle(STYLE_BOLD)
                -- set the flags for when line-breaks occur
                is_bold = true
                is_word = true
                -- skip the sigil
                index = index + 1

            -- ~noun~
            --------------------------------------------------------------------
            elseif src_line:match("^%~%g", index) then
                -- switch to the 'noun' style class
                line = line .. _pushStyle(STYLE_NOUN)
                -- set the flags for when line-breaks occur
                is_noun = true
                is_word = true
                -- skip the sigil
                index = index + 1

            -- _name_
            --------------------------------------------------------------------
            elseif src_line:match("^%_%g", index) then
                -- switch to the 'name' style class
                line = line .. _pushStyle(STYLE_NAME)
                -- set the flags for when line-breaks occur
                is_name = true
                is_word = true
                -- skip the sigil
                index = index + 1

            -- ((soft))
            --------------------------------------------------------------------
            elseif src_line:match("^%(%(%g", index) then
               -- switch to the 'soft' style class
               line = line .. _pushStyle(STYLE_SOFT)
               -- set the flags for when line-breaks occur
               is_soft = true
               is_word = true
               -- skip the sigil
               index = index + 2
            end
        end

        -- read a single byte
        local ascii = src_line:byte(index)

        -- end of bold
        ------------------------------------------------------------------------
        if src_line:match("^%*[%s%p]", index) then
            _addWord()
            is_bold = false
            line = line .. _popStyle()

        -- end of noun class
        ------------------------------------------------------------------------
        elseif src_line:match("^%~[%s%p]", index) then
            _addWord()
            is_noun = false
            line = line .. _popStyle()

        -- end of name class
        ------------------------------------------------------------------------
        elseif src_line:match("^%_[%s%p]", index) then
            _addWord()
            is_name = false
            line = line .. _popStyle()

        -- end of soft class
        ------------------------------------------------------------------------
        elseif src_line:match("^%)%)", index) then
            -- special edge case for soft-with-brackets
            if src_line:match("^%)%)%)", index) then
                -- append the closing bracket before adding to the line
                _addChar(ascii)
                -- skip the additional bracket
                index = index + 1
            end
            _addWord()
            is_soft = false
            line = line .. _popStyle()
            -- skip the additional byte
            index = index + 1

        -- punctuation that line-breaks before (but not after)
        -- e.g. wrapping punctuation such as "(..."
        --
        elseif src_line:match("^[%(%[]", index) then
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
        elseif src_line:match("^[\\/%)%]]", index) then
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
        elseif src_line:match("^ ?— ?", index) then
            --------------------------------------------------------------------
            -- how many bytes is that?
            local em = src_line:match("^ ?— ?", index)
            -- add current word, treating the em-dash as a word-break
            _addWord()
            -- add the em-dash as its own word
            word_str = "—"
            _addWord()
            -- skip the extra byte(s)
            index = index + #em-1

        elseif src_line:match("^ ?%-%- ?") then
            --------------------------------------------------------------------
            -- how many bytes is that?
            local em = src_line:match("^ ?%-%- ?", index)
            -- add current word, treating the em-dash as a word-break
            _addWord()
            -- add the em-dash as its own word
            word_str = "—"
            _addWord()
            -- skip the extra byte
            index = index + #em-1

        -- space = word-break
        --
        elseif ascii == 0x20 then
            --------------------------------------------------------------------
            -- the current word is complete, add it to the line
            -- and handle the trailing space according to word-wrap
            is_space = true; _addWord()

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
function Article:readLiteralLine(out_lines, line)
    ----------------------------------------------------------------------------
    -- add line to the article line array
    table.insert(out_lines, {
        source = line
    })
end

--------------------------------------------------------------------------------
function Article:write()
    ----------------------------------------------------------------------------
    -- clear the compressor
    -- (may contain previous article)
    compress:clear()
    -- populate the compressor with the lines of the article
    for _, src_line in ipairs(self.lines) do
        -- add the line to the compressor
        compress:addLine(src_line)
    end

    compress:compressLines()

    -- write converted article as assembly source
    ----------------------------------------------------------------------------
    local f_out,err = io.open(self.outfile..".acme", "w")
    if err then print ("! error: " .. err); os.exit(false); end

    local s_out = compress:toACME(self.outfile..".prg")

    f_out:write(s_out)
    f_out:close()
end