-- nücomer diskzine (c) copyright Kroc Camen 2019-2023. unless otherwise noted,
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
-- # process SIDs:
--   # relocate SID to $1000 & $F0-$FF
--   # repackage SID to PRG (strip header)
--   # exomize PRG file
-- # process articles:
--   # split to lines
--   # word-wrap & hyphenate
--   # convert text to screen codes
--   # compress:
--     # tokenise screen-codes
--     # iteratively pair tokens

-- 3rd-party libraries:
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

--------------------------------------------------------------------------------
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
    articles = {},
    -- table of SID songs
    sids = {}
}

-- clear the internal state
--------------------------------------------------------------------------------
function Issue:reset()
    self.issue      = 0
    self.list       = {}
    self.toc        = {}
    self.offset     = 0
    self.x          = 1
    self.y          = 6
    self.articles   = {}
    self.sids       = {}
end

-- build an issue, given a specific issue number:
--------------------------------------------------------------------------------
function Issue:build(i_issue)
    ----------------------------------------------------------------------------
    -- clear internal state before starting a new issue
    self:reset()
    self.issue = i_issue

    -- the issue's source path:
    -- (where articles and other meta-data live)
    local issue_path = string.format("issues/issue#%02u/", i_issue)

    -- read the JSON meta-data file for the issue: this describes the contents
    -- of the issue and associated properties to customise layout on the C64
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
write "build/boot.prg"              "boot"
write "build/intro.prg"             "intro"
write "build/nucomer.exo.prg"       "nucomer"
write "src/bsod64/build/bsod64.prg" "bsod64"
]],     i_issue, "build/nucomer.d64"
    ))

    -- the base-path used for producing build-artefacts
    local build_path = "build/"

    ----------------------------------------------------------------------------
    -- process SID songs:
    --
    print("Process SIDs songs...")
    print("========================================")
    -- where to find the SID files for an issue:
    local sid_path = issue_path.."sid/"

    -- a list of the SIDs will be generated for
    -- the build script to exomize the songs
    local f_sids,err = io.open(
        -- note how this is written as a binary due to
        -- Windows batch files requiring CRLF line endings
        build_path..string.format("i%02u_sids.lst", i_issue), "wb"
    )
    if err then io.stderr:write("! error: " .. err); os.exit(false); end

    -- walk through the SIDs defined in the issue:
    --
    for i,j_sid in ipairs(j_issue["sids"]) do
        ------------------------------------------------------------------------
        -- display name of SID as we process it, this will take a while
        -- as we have to relocate, assemble and then exomize each song
        io.stdout:write(truncate(j_sid["file"]).."      ")

        local bin_sid = "bin\\sidreloc\\Release\\sidreloc.exe"

        local sid_name = string.format(
            -- note that the filename in the JSON does not include the
            -- file-type as several will be used during the build process
            "i%02u_s%02u_%s", i_issue, i-1,
            j_sid["file"]
        )

        -- relocate the SID binary:
        ------------------------------------------------------------------------
        -- TODO: this action should be in the build script,
        --       but we would need to re-architect to do that
        ok,r,e = os.execute(
            bin_sid..
            -- reloacte to $1000 and zero-page addresses to $80-$8F
            " -p 10 -z 88-8f -v"..
            -- input file:
            " \""..sid_path..j_sid["file"]..".sid\""..
            -- output file:
            " \""..build_path..sid_name..".sid\""..
            -- log file:
            " >\""..build_path..sid_name..".log\""..
            -- (output to the log, not the console)
            " 2>&1"
        )
        if not ok then
            io.stderr:write("! error: " .. err); os.exit(false)
        end

        ------------------------------------------------------------------------
        -- read the SID header to get the [relocated] init & play addresses;
        -- these will not always be $1000 & $1003!
        --
        local f_sid = io.open(build_path..sid_name..".sid", "rb")

        -- the first 4 bytes specify the SID file-type
        -- (either "PSID" or "RSID")
        local sid_type = f_sid:read(4)

        -- seek to byte 8 where the SID addresses begin
        if f_sid:seek("set", 9) ~= 9 then error("seek failed"); end
        -- read the load, init & play-address,
        -- and the song count & default song number:
        local sid_load, sid_init, sid_play, sid_songs, sid_song = string.unpack(
            -- 'read five, little-endian ("<") unsigned 16-bit integers ("I2")'
            "<I2I2I2I2I2", f_sid:read(10)
        )

        --#print(string.format(
        --#    "\n- %s: $%04X, $%04X, $%04X x%u:%u",
        --#    sid_type, sid_load, sid_init, sid_play, sid_songs, sid_song
        --#))

        f_sid:close()

        ------------------------------------------------------------------------
        -- create an ACME assembler file to repackage
        -- the SID program after relocation
        --
        local f_acme,err = io.open(
            build_path..sid_name..".acme", "w"
        )
        f_acme:write(string.format([[
; auto-generated file, do not modify!
!to     "%s", cbm
!source "nucomer.acme"

* = nu_song

!binary "%s",, $7c+2
]],         build_path..sid_name..".prg",
            build_path..sid_name..".sid"
        ))
        f_acme:close()

        ------------------------------------------------------------------------
        f_sids:write(
            -- swap slashes for Windows in the list file for use by DOS
            string.gsub(sid_name, "/", "\\").."\r\n"
        )
        -- add the song to the list of files to be included on the disk
        f_c1541:write(string.format(
            'write "%s" "%s"\n',
            -- TODO: change this to ".exo" to include the exomized SID
            build_path..sid_name..".prg",
            j_sid["prg"]:sub(1, 16)
        ))

        -- add the [converted] SID to the table of SIDs
        ------------------------------------------------------------------------
        -- this meta-data will be used to generate a table for the C64
        --
        table.insert(self.sids, {
            -- the name of the SID's program file on the C64 disk
            -- TODO: change this to ".exo" to include the exomized SID
            prg     = j_sid["prg"]:sub(1, 16),
            init    = sid_init,     -- address to call to intitialise SID
            play    = sid_play      -- address to call to play SID (each frame)
        })

        print("[OK]")
    end
    f_sids:close()
    print("========================================")

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

    f_out:write("; auto-generated file, do not modify!\n\n")
    f_out:write("!ct \"build/scr_nucomer.ct\"\n")
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

    -- output the SID data:
    ----------------------------------------------------------------------------
    -- the number of songs is provided as a constant
    -- so it can be assembled directly into the outfit
    f_out:write("\n")
    f_out:write(string.format(
        ".SID_DB_COUNT                   = %i\n\n",
        #self.sids
    ))

    f_out:write("sid_db:\n")

    -- table of initialisation addresses for each song
    f_out:write("sid_db_init_lo:\n")
    for _,sid in ipairs(self.sids) do
        f_out:write(string.format(
            "        !byte   <$%04x\n",
            sid.init
        ))
    end
    f_out:write("\n")

    f_out:write("sid_db_init_hi:\n")
    for _,sid in ipairs(self.sids) do
        f_out:write(string.format(
            "        !byte   >$%04x\n",
            sid.init
        ))
    end
    f_out:write("\n")

    -- table of play addresses for each song
    f_out:write("sid_db_play_lo:\n")
    for _,sid in ipairs(self.sids) do
        f_out:write(string.format(
            "        !byte   <$%04x\n",
            sid.play
        ))
    end
    f_out:write("\n")

    f_out:write("sid_db_play_hi:\n")
    for _,sid in ipairs(self.sids) do
        f_out:write(string.format(
            "        !byte   >$%04x\n",
            -- for reasons I don't understand, the play address in SID files
            -- has a high-byte of $00 and we need to re-use the init hi-byte
            sid.init
        ))
    end
    f_out:write("\n")

    f_out:write("sid_db_prg_strs:\n")
    f_out:write("        ; PRG filenames (padded to 16 bytes each)\n")
    for _,sid in ipairs(self.sids) do
        -- use ACME to convert the ASCII filename to PETSCII
        f_out:write(string.format("        !pet    \"%s\"", sid.prg))
        -- pad with zeroes?
        local pad = 16 - #sid.prg
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

Issue:build(0)