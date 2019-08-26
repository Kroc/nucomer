-- issua.lua : produces the build artefacts for an issue

-- theory of operation: (WIP)
--
-- # read issue meta-data
-- # process articles:
--   # split to lines
--   # word-wrap & hyphenate
--   # convert text to screen codes
--   # remove and bit-pack spaces(TODO?)
-- # analyse symbols across whole issue(TODO?)

require "scripts.c64"

hyphenate = require "scripts.hyphenate"
for _, s_exception in pairs({
    "pri-vate",
    "every-thing",
    "mag-azine",
    "to-day"
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
    -- split the word into hyphenation boundaries
    t_pieces = self:hyphenate(s_locale, s_word)
    -- if the word cannot be split, wrap the whole word
    if #t_pieces == 1 then
        return "", s_word
    end

    local left = ""     -- the part of the word to the left of the hyphen
    local right = ""    -- the part of the word to the right of the hyphen
    local broken = false

    -- add word pieces until we can't fit any more on the line...
    for _, piece in ipairs(t_pieces) do
        -- if a word-piece can fit (including a trailing hyphen!)
        -- then add it (sans-hyphen) and try the next piece
        if broken == false and #left + #piece + 1 <= s_len then
            left = left .. piece
        else
            -- the word-piece does not fit!
            -- add it to the right-hand side instead
            right = right .. piece
            broken = true
        end
    end
    -- add the hyphen to the left-hand side
    if #left > 0 then left = left .. "-"; end
    -- return the left & right sides
    return left, right
end

-- include the JSON library
-- <https://github.com/rxi/json.lua>
json = require "json"

function truncate(str)
        return string.format("%-36s", string.gsub(
            str,
            -- keep all chars up to the truncate point;
            -- lua does not support regex range patterns like `.{0,33}`
            "^(.?.?.?.?.?.?.?.?.?.?.?.?.?.?.?.?.?"
            ..".?.?.?.?.?.?.?.?.?.?.?.?.?.?.?.?)(.*)$",
            "%1..."
        ))
end

-- the Issue singleton builds a complete issue in one go
Issue = {
    -- this issue's number
    issue = 0,
    -- for each article processed, we add it to a list file that will be read
    -- by the build batch file to write the articles to C64 disk image. we do
    -- the exomizing and 1541 creation from the OS-side rather than inside lua
    list = {},
    -- the table of contents is a list of offsets into the database
    -- and screen positions for each menu entry
    toc = {},
    -- current offset into the string data
    offset = 0,

    x = 1,
    y = 6,

    -- table of the articles in the issue (Article classes)
    articles = {}
}

-- clear the internal state
--------------------------------------------------------------------------------
function Issue:reset()
    self.issue = 0
    self.list = {}
    self.toc = {}
    self.offset = 0
    self.x = 1
    self.y = 6
    self.articles = {}
end

-- build an issue, given a specific issue number
--------------------------------------------------------------------------------
function Issue:build(i_issue)
    ----------------------------------------------------------------------------
    -- clear internal state before starting a new issue
    self:reset()
    self.issue = i_issue

    -- read the JSON meta-data file for the issue:
    -- this describes the contents of the issue and any associated
    -- properties to customise the layout on the C64
    local f_json,err = io.open(
        "issues/issue#" .. string.format("%02u", i_issue) .."/issue.json", "r"
    )
    -- problem? exit
    if err then io.stderr:write("! error: " .. err); os.exit(false); end
    -- read and decode the whole file in one go
    local issue,err = json.decode(f_json:read("*all"))
    if err then io.stderr:write ("! error: " .. err); os.exit(false); end
    -- the JSON file is no longer needed once parsed
    f_json:close()

    -- walk the `articles` table that lists, in-order, the articles to be
    -- included on disk; each of these will need converting to C64 data
    for _,j_article in ipairs(issue["articles"]) do
        -- notify user of current article being processed...
        io.stdout:write(truncate(j_article["title"]))

        -- formulate our input & output file paths
        -- (the output is arbitrary binary data so has no file-extension)
        local s_in  = "issues/issue#00/"..j_article["file"]
        local s_out = "build/i00_"..j_article["file"]:gsub("%.nu$", "")

        -- convert the article text
        local article = {}
        article = Article:new()
        article.outfile = s_out
        article:read(s_in)
        -- add to the table of articles for whole-issue analysis
        -- and compression later on
        table.insert(self.articles, article)

        -- add the output filepath to the article
        j_article["bin"] = s_out
        -- and to the list file used for packing onto 1541
        table.insert(self.list, s_out..";"..j_article["prg"])

        -- we need to integrate the article into the outfit:
        -- the article title for the menu page needs to be converted to C64
        -- screen codes. two spaces are prefixed to make way for the "thorne"
        -- (the currently selected menu marker)
        local s_scr = c64_str2scr("  "..j_article["scr"])
        local s_len = #s_scr
        -- add the menu entry to the table of contents
        table.insert(self.toc, {
            off = self.offset,
            row = self.y,
            col = self.x,
            str = s_scr,
            prg = j_article["prg"]
        })
        self.offset = self.offset + s_len + 1
        self.y = self.y + 2

        -- article complete, move to the next
        io.stdout:write("[OK]\n")
    end

    ----------------------------------------------------------------------------
    -- write out the converted articles
    --
    self:_writeArticles()

    ----------------------------------------------------------------------------
    -- write out the data file for outfit integration;
    -- this file will be embedded directly into the outfit
    --
    self:_writedb()

    ----------------------------------------------------------------------------
    -- write out the list file:
    --
    local f_lst,err = io.open("build/i00.lst", "wb")
    if err then io.stderr:write("! error: " .. err); os.exit(false); end
    -- dump filepaths, a line each (use CRLF for Windows Batch compatibility)
    for _,i in ipairs(self.list) do f_lst:write(i .. "\r\n"); end

    f_lst:close()
end

-- write all articles in the issue to disk
--------------------------------------------------------------------------------
function Issue:_writeArticles()
    ----------------------------------------------------------------------------
    for _,article in ipairs(self.articles) do
        -- write the converted article to disk
        article:write()
    end
end

-- output the menu database used to integrate the issue into the outfit
--------------------------------------------------------------------------------
function Issue:_writedb ()
    ----------------------------------------------------------------------------
    local f_out,err = io.open("build/menu_db.acme", "w")
    if err then io.stderr:write("! error: " .. err); os.exit(false); end

    f_out:write("; auto-generated file, do not modify!\n")
    f_out:write("\n")
    f_out:write("MENU_DB_COUNT                   = ")
    f_out:write(string.format("%i\n", #self.toc))

    f_out:write("\n")
    f_out:write("menu_db_strlo:\n")
    ----------------------------------------------------------------------------
    for _,item in ipairs(self.toc) do
        f_out:write(string.format(
            "        !byte   <(menu_db_strs + $%04x)\n",
            item.off
        ))
    end

    f_out:write("\n")
    f_out:write("menu_db_strhi:\n")
    ----------------------------------------------------------------------------
    for _,item in ipairs(self.toc) do
        f_out:write(string.format(
            "        !byte   >(menu_db_strs + $%04x)\n",
            item.off
        ))
    end

    f_out:write("\n")
    f_out:write("menu_db_rows:\n")
    ----------------------------------------------------------------------------
    for _,item in ipairs(self.toc) do
        f_out:write(string.format(
            "        !byte   $%02x\n",
            item.row
        ))
    end

    f_out:write("\n")
    f_out:write("menu_db_cols:\n")
    ----------------------------------------------------------------------------
    for _,item in ipairs(self.toc) do
        f_out:write(string.format(
            "        !byte   $%02x\n",
            item.col
        ))
    end

    f_out:write("\n")
    f_out:write("menu_db_strs:\n")
    ----------------------------------------------------------------------------
    for _,item in ipairs(self.toc) do
        -- begin the line
        f_out:write("        !hex    ")
        for c = 1, #item.str do
            f_out:write(string.format("%02x", string.byte(item.str, c)))
        end
        -- null terminator
        f_out:write("00\n")
    end

    f_out:write("\n")
    f_out:write("menu_db_prg_lens:\n")
    f_out:write("        ; length of PRG filenames\n")
    ----------------------------------------------------------------------------
    for _,item in ipairs(self.toc) do
        f_out:write(string.format(
            "        !byte   %i\n",
            #item.prg
        ))
    end

    f_out:write("\n")
    f_out:write("menu_db_prg_strs:\n")
    f_out:write("        ; PRG filenames (padded to 16 bytes each)\n")
    ----------------------------------------------------------------------------
    for _,item in ipairs(self.toc) do
        -- use ACME to convert the ASCII filename to PETSCII
        f_out:write(string.format("        !pet    \"%s\"", item.prg))
        -- pad with zeroes?
        local pad = 16 - #item.prg
        if pad > 0 then
            for _ = 1, pad do
                f_out:write(", 0")
            end
        end
        -- don't forget to end the line!
        f_out:write("\n")
    end

    f_out:close()
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
    local word_str  = ""        -- current word (for word-wrapping)
    local word_len  = 0         -- character length of word (not byte-length!)
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
        -- we do not want to leave trailing spaces on lines, so when a word
        -- begins, we hold on to the space until the word ends and decide
        -- where it goes based on the word-wrapping

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
        index = 2
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

print()
print("Issue#00")
print("========================================")

Issue:build(0)

print(hyphenate:testWord("en-gb", "disciplined"))