-- process articles and convert into data for the C64
-- my first lua program

arg = {...}

require "issues.c64"

infile  = arg[1]    -- input file?
outfile = arg[2]    -- output file?

-- correct params?
if infile == nil or outfile == nil then
    print ("txt2c64.lua <infile> <outfile>")
    return 1
end

-- (attempt) to open the input file
f_in,err = io.open(infile, "r")
-- problem? exit
if err then print ("! error: " .. err); os.exit(false); end

-- display the infile now we have it open
--print("< " .. infile)

-- (attempt) to open the output file
f_out,err = io.open(outfile, "wb")
-- problem? exit
if err then print ("! error: " .. err); os.exit(false); end

-- write the PRG header
f_out:write(string.pack("<I2", 0x1FFE))

-- display the outfile now we have it open
--print("> " .. outfile)

-- read the whole file into a string
text = f_in:read("*all")
f_in:close()

-- walk through the string
index       = 0
line_len    = 0
prev_len    = 0     -- length in bytes of the previous line
line_bin    = ""    -- current output line (binary)

word_bin    = ""    -- current word (for word-wrapping)
word_len    = 0     -- character length of current word

lines_len   = {}    -- table of each line length
lines_bin   = {}    -- table of all lines generated (before output)

function add_char()
    ----------------------------------------------------------------------------
    -- add the character to the word
    word_bin = word_bin .. string.char(scr64)
    word_len = word_len + 1
end

function add_word ()
    ----------------------------------------------------------------------------
    -- if the word will not fit on the line, word-wrap
    if line_len + word_len >= 40 then
        -- dispatch the current line as-is
        add_line()
    end

    -- add the word to the line
    line_bin = line_bin .. word_bin
    line_len = line_len + word_len
    -- reset the current word
    word_bin = ""
    word_len = 0
end

function add_line ()
    ----------------------------------------------------------------------------
    -- add the line-length to the array of line-lengths
    table.insert(lines_len, line_len)
    -- add the line to the binary:
    -- when a line is zero-length, there's no text to add
    if line_len ~= 0 then
        -- note that lines are written into the binary backwards!
        -- this is so that the line length can be used as a count-down
        -- index which is faster for 6502s to process
        table.insert(lines_bin, line_bin:reverse())
    end
    -- erase the line
    line_bin = ""
    -- set the new "previous line" length
    prev_len = line_len
    line_len = 0
end

::next::
--------------------------------------------------------------------------------
-- move to the next character
index = index + 1
-- end of file?
if index >= #text then goto eof; end

-- TODO: multi-byte sequences (like macros & utf-8)
-- read a single byte
ascii = string.char(text:byte(index))

-- we only treat \n as new-line, all \r are ignored;
-- do not output, read the next character
if ascii == "\r" then goto next; end
-- if return, line has ended early
if ascii == "\n" then
    -- add the current word to the end of the line.
    -- this might cause an additional line-break!
    add_word()
    -- dispatch the current line;
    -- when two new-lines are in a row,
    -- a zero-length line will exist
    add_line()

    goto next
end
-- word-break
if ascii == " " then
    -- the current word is complete, add it to the line
    -- before we handle the space
    add_word()
    -- if an exact word-wrap occured, the space is not needed!
    if line_len > 0 then
        -- append the space to the line directly
        line_bin = line_bin .. string.char(0x20)
        line_len = line_len + 1
    end
    goto next
end

-- convert to screen code
scr64 = c64_asc2scr(ascii)
-- non-ASCII characters;
-- TODO: handle some utf-8 patterns
if scr64 == nil then scr64 = 0xbf; end  -- reverse "?"

-- add to the current word
-- (and handle word-wrap)
add_char()

-- process next character
goto next

::eof::
--------------------------------------------------------------------------------
-- add the final word
add_word()
-- and the final line
add_line()

-- the lines-length table is suffixed with $FF
-- to indicate when to stop scrolling downards
table.insert(lines_len, 255)

-- how long the line-lengths list is (2-bytes)
f_out:write(string.pack("<I2", #lines_len+1))

-- the list of line-lengths
for _, v in ipairs(lines_len) do
    f_out:write(string.pack("B", v))
end

-- and then the combined text binary
for _, v in ipairs(lines_bin) do
    f_out:write(v)
end

f_out:close()
--os.exit(true)
