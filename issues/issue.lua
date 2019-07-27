-- issua.lua : produces the build artefacts for an issue

require "issues.c64"

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

print()
print("Issue#00")
print("========================================")

--------------------------------------------------------------------------------
-- read the JSON meta-data file for the issue:
-- this describes the contents of the issue and any associated properties
-- to customise the layout on the C64

f_json,err = io.open("issues/issue#00/issue.json", "r")
-- problem? exit
if err then io.stderr:write("! error: " .. err); os.exit(false); end

issue,err = json.decode(f_json:read("*all"))
if err then io.stderr:write ("! error: " .. err); os.exit(false); end

f_json:close()

--------------------------------------------------------------------------------
-- walk the JSON and process articles:

-- for each article processed, we add it to a list file that will be read
-- by the build Batch file to write the articles to C64 disk image. we do
-- the exomizing and 1541 creation from the OS-side rather than inside lua
list = {}

-- the outfit uses a small database of article
-- meta-data where each entry consits of:
--
-- # the title for the menu screen (including position)
-- # the file name (PETSCII) on disk to load
--
data = {
    -- the table of contents is a list of offsets into the database
    toc = {},
    -- a binary blob of combined strings. the offsets (above)
    -- give the starting point of each string
    bin = ""
}
offset = 0

-- walk the `articles` table that lists, in-order, the articles to be included
-- on disk; each of these will need converting to C64 formatted data
for _,article in ipairs(issue["articles"]) do
    -- each article begins with the offset into the binary database
    table.insert(data.toc, offset)

    local x = 1
    local y = 6

    -- notify user of current article being processed...
    io.stdout:write(truncate(article["title"]))
    -- formulate our input & output file paths
    -- (the output is arbitrary binary data so has no file-extension)
    local s_in  = "issues/issue#00/"..article["file"]
    local s_out = "build/i00_"..article["file"]:gsub("%.nu$", "")
    -- convert the article to C64 format
    assert(loadfile("issues/article.lua"))(s_in, s_out)
    -- write the output filepath to the article
    article["bin"] = s_out
    -- and to the list file used for packing onto 1541
    table.insert(list, s_out..";"..article["prg"])
    -- we need to integrate the article into the outfit:
    -- handle the article title used for the menu page
    local s_scr = article["scr"]
    local s_len = #s_scr
    -- set screen co-ordinates
    data.bin = data.bin .. string.char(x) .. string.char(y)
    -- set length of string
    data.bin = data.bin .. string.char(s_len)
    data.bin = data.bin .. s_scr
    offset = offset + 2 + 2 + s_len
    -- article complete, move to the next
    io.stdout:write("[OK]\n")
end

--------------------------------------------------------------------------------
-- write out the data file for outfit integration;
-- this file will be embedded directly into the outfit
--
f_out,err = io.open("build/i00_menu", "wb")
if err then io.stderr:write("! error: " .. err); os.exit(false); end

for _,i in ipairs(data.toc) do
    f_out:write(string.pack("<I2", i))
end
f_out:write(data.bin)

f_out:close()

--------------------------------------------------------------------------------
-- write out the list file:
--
f_lst,err = io.open("build/i00.lst", "wb")
if err then io.stderr:write("! error: " .. err); os.exit(false); end
-- dump filepaths, a line each (use CRLF for Windows Batch compatibility)
for _,i in ipairs(list) do f_lst:write(i .. "\r\n"); end

f_lst:close()

--------------------------------------------------------------------------------
