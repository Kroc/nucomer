-- nücomer magazine (c) copyright Kroc Camen 2019. unless otherwise noted,
-- licenced under Creative Commons Attribution Non-Commercial Share-Alike 4.0
-- licence; you may reuse and modify this code how you please as long as you:
--
-- # retain the copyright notice
-- # use the same licence for your derived code
-- # do not use it for commercial purposes
--   (contact the author for a commercial licence)
--

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

require "scripts.article"

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
        -- add to the table of articles for whole-issue
        -- analysis and compression later on
        table.insert(self.articles, article)

        -- add the output file-path to the article
        j_article["bin"] = s_out
        -- and to the list file used for packing onto 1541
        table.insert(self.list, s_out..";"..j_article["prg"])

        -- we need to integrate the article into the outfit:
        -- the article title for the menu page needs to be converted to C64
        -- screen codes. two spaces are prefixed to make way for the "thorne"
        -- (the currently selected menu marker)
        local s_scr = string.toC64("  "..j_article["scr"])
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
    f_out:write("!ct \"build/scr_nucomer.ct\"")
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
        -- terminator
        f_out:write("ff\n")
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

print()
print("Issue#00")
print("========================================")

Issue:build(0)