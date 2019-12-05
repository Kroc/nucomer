-- nücomer magazine (c) copyright Kroc Camen 2019. unless otherwise noted,
-- licenced under Creative Commons Attribution Non-Commercial Share-Alike 4.0
-- licence; you may reuse and modify this code how you please as long as you:
--
-- # retain the copyright notice
-- # use the same licence for your derived code
-- # do not use it for commercial purposes
--   (contact the author for a commercial licence)
--

-- issue.lua : produces the build artefacts for an issue
--------------------------------------------------------------------------------
-- theory of operation: (WIP)
--
-- # read issue meta-data
-- # process articles:
--   # split to lines
--   # word-wrap & hyphenate
--   # convert text to screen codes
--   # compress:
--     # remove and bit-pack spaces(TODO?)
--     # tokenise screen-codes
--     # iteratively pair tokens

--------------------------------------------------------------------------------
-- include the JSON library
-- <https://github.com/rxi/json.lua>
--
json = require "scripts.lib.json"

-- easy dumping of tables
-- why doesn't lua have this built in!!?
-- <https://github.com/kikito/inspect.lua>
--
inspect = require "scripts.lib.inspect"

-- easy, human-readable, file-size strings
-- <https://github.com/starius/lua-filesize>
--
filesize = require "scripts.lib.lua-filesize"

compress = require "scripts.compress"
require "scripts.article"

--------------------------------------------------------------------------------
function truncate(str)
        return string.format("%-30s", string.gsub(
            str,
            -- keep all chars up to the truncate point;
            -- lua does not support regex range patterns like `.{0,33}`
            "^(.?.?.?.?.?.?.?.?.?.?.?.?.?.?"
            ..".?.?.?.?.?.?.?.?.?.?.?.?.?)(.*)$",
            "%1..."
        ))
end

-- the Issue singleton builds a complete issue in one go
Issue = {
    -- this issue's number
    issue = 0,
    -- for each article processed, we add it to a list file that will be read
    -- by the build batch file to assemble and write to C64 disk image
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

    -- the issue's source path:
    -- (where articles and other meta-data live)
    local issue_path = string.format("issues/issue#%02u/", i_issue)

    -- read the JSON meta-data file for the issue:
    -- this describes the contents of the issue and any associated
    -- properties to customise the layout on the C64
    local f_json,err = io.open(issue_path .. "issue.json", "r")
    -- problem? exit
    if err then io.stderr:write("! error: " .. err); os.exit(false); end
    -- read and decode the whole file in one go
    local j_issue,err = json.decode(f_json:read("*all"))
    if err then io.stderr:write ("! error: " .. err); os.exit(false); end
    -- the JSON file is no longer needed once parsed
    f_json:close()

    -- each article will be packed onto a 1541 disk image by way of `c1541`;
    -- a list of commands is built specifically for this issue to remove the
    -- need for the build script's environment (Batch) to have to know any
    -- of these details
    --
    local f_c1541,err = io.open("build/c1541.txt", "w")
    if err then io.stderr:write ("! error: " .. err); os.exit(false); end
    -- provide the beginning of the script to initialise the disk-image
    -- and add the minimum required binaries
    f_c1541:write(string.format([[
format "nucomer,%02u" d64 "%s"
write "build/boot.prg"          "boot"
write "build/intro.prg"         "intro"
write "build/nucomer.prg"       "nucomer"
write "src/bsod64/bsod64.prg"   "bsod64"
write "build/admiral64.prg"     "admiral64"
]],     i_issue, "build/nucomer.d64"
    ))

    -- the base-path & file-name used for producing build-artefacts
    local build_path = string.format("build/i%02u_", i_issue)

    -- walk the `articles` table that lists, in-order, the articles to be
    -- included on disk; each of these will need converting to C64 data
    --
    for _,j_article in ipairs(j_issue["articles"]) do
        ------------------------------------------------------------------------
        -- formulate our input & output file paths;
        -- the output path is a base-name without extension as multiple files
        -- will be produced with the same name, e.g. ".acme", ".prg"
        local s_in  = issue_path .. j_article["file"]
        local s_out = build_path .. j_article["file"]:gsub("%.%w+$", "")

        -- notify user of current article being processed...
        io.stdout:write(truncate(j_article["title"]))

        -- convert the article text
        local article = Article:new()
        article.outfile = s_out
        article:read(s_in)

        -- add to the table of articles
        table.insert(self.articles, article)

        -- add the output file-path to the article
        j_article["bin"] = s_out

        -- add to the list of articles to be assembled
        table.insert(self.list, s_out..".acme")
        -- add to the list of files to go on the 1541 disk
        f_c1541:write(string.format(
            'write "%s" "%s"\n',
            s_out..".prg", j_article["prg"]
        ))

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

        -- write the article to disk;
        -- this will trigger the compression process
        article:write()

        -- article complete, move to the next
        print("----------------------------------------")
    end

    ----------------------------------------------------------------------------
    -- write out the data file for outfit integration;
    -- this file will be embedded directly into the outfit
    --
    self:_writedb()

    ----------------------------------------------------------------------------
    -- write out the list file:
    --
    local f_lst,err = io.open("build/issue.lst", "wb")
    if err then io.stderr:write("! error: " .. err); os.exit(false); end
    -- dump filepaths, a line each (use CRLF for Windows Batch compatibility)
    for _,i in ipairs(self.list) do f_lst:write(i .. "\r\n"); end

    f_lst:close()

    -- end the commands file for putting
    -- files on the 1541 disk-image
    f_c1541:write("quit")
    f_c1541:close()
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
    f_out:write(".MENU_DB_COUNT                  = ")
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