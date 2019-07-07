-- process articles and convert into data for the C64
-- my first lua program

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
print("txt2c64 < " .. infile)

-- (attempt) to open the output file
f_out,err = io.open(outfile, "wb")
-- problem? exit
if err then print ("! error: " .. err); os.exit(false); end

-- display the outfile now we have it open
print("txt2c64 > " .. outfile)

--------------------------------------------------------------------------------
-- table to convert ASCII codes to C64 screen codes
-- (not to be confused with PETSCII)
-- assumes lower-case character set
str2scr_low = {
    ["@"] = 0x00,
    ["a"] = 0x01,
    ["b"] = 0x02,
    ["c"] = 0x03,
    ["d"] = 0x04,
    ["e"] = 0x05,
    ["f"] = 0x06,
    ["g"] = 0x07,
    ["h"] = 0x08,
    ["i"] = 0x09,
    ["j"] = 0x0a,
    ["k"] = 0x0b,
    ["l"] = 0x0c,
    ["m"] = 0x0d,
    ["n"] = 0x0e,
    ["o"] = 0x0f,
    ["p"] = 0x10,
    ["q"] = 0x11,
    ["r"] = 0x12,
    ["s"] = 0x13,
    ["t"] = 0x14,
    ["u"] = 0x15,
    ["v"] = 0x16,
    ["w"] = 0x17,
    ["x"] = 0x18,
    ["y"] = 0x19,
    ["z"] = 0x1a,
    ["["] = 0x1b,
    ["£"] = 0x1c,
    ["]"] = 0x1d,
    ["^"] = 0x1e, -- upward pointing arrow
                    -- leftward pointing arrow
    [" "] = 0x20,
    ["!"] = 0x21,
    ['"'] = 0x22,
    ["#"] = 0x23,
    ["$"] = 0x24,
    ["%"] = 0x25,
    ["&"] = 0x26,
    ["'"] = 0x27,
    ["("] = 0x28,
    [")"] = 0x29,
    ["*"] = 0x2a,
    ["+"] = 0x2b,
    [","] = 0x2c,
    ["-"] = 0x2d,
    ["."] = 0x2e,
    ["/"] = 0x2f,
    ["0"] = 0x30,
    ["1"] = 0x31,
    ["2"] = 0x32,
    ["3"] = 0x33,
    ["4"] = 0x34,
    ["5"] = 0x35,
    ["6"] = 0x36,
    ["7"] = 0x37,
    ["8"] = 0x38,
    ["9"] = 0x39,
    [":"] = 0x3a,
    [";"] = 0x3b,
    ["<"] = 0x3c,
    ["="] = 0x3d,
    [">"] = 0x3e,
    ["?"] = 0x3f,
                    -- horizontal bar
    ["A"] = 0x41,
    ["B"] = 0x42,
    ["C"] = 0x43,
    ["D"] = 0x44,
    ["E"] = 0x45,
    ["F"] = 0x46,
    ["G"] = 0x47,
    ["H"] = 0x48,
    ["I"] = 0x49,
    ["J"] = 0x4a,
    ["K"] = 0x4b,
    ["L"] = 0x4c,
    ["M"] = 0x4d,
    ["N"] = 0x4e,
    ["O"] = 0x4f,
    ["P"] = 0x50,
    ["Q"] = 0x51,
    ["R"] = 0x52,
    ["S"] = 0x53,
    ["T"] = 0x54,
    ["U"] = 0x55,
    ["V"] = 0x56,
    ["W"] = 0x57,
    ["X"] = 0x58,
    ["Y"] = 0x59,
    ["Z"] = 0x5a,
}

-- read the whole file into a string
text = f_in:read("*all")
f_in:close()

-- walk through the string
index       = 1
line_len    = 0
prev_len    = 0     -- length in bytes of the previous line
line_bin    = ""    -- current output line (binary)

--------------------------------------------------------------------------------
function write_line ()
    -- all output lines begin with two bytes:
    -- the first is the number of bytes backwards to the previous line
    f_out:write(string.pack("B", prev_len))
    -- the second is the number of bytes forwards to the next line
    f_out:write(string.pack("B", line_len))
    -- write the screen codes
    f_out:write(line_bin)
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
    -- dispatch the current line;
    -- when two new-lines are in a row,
    -- a zero-length line will exist
    write_line()
    goto next
end

-- convert to screen code
scr64 = str2scr_low[ascii]

-- add to the current line
line_bin = line_bin .. string.char(scr64)

if line_len == 40 then
    -- line complete, dispatch
    write_line()
else
    line_len = line_len + 1
end

-- process next character
goto next

::eof::
--------------------------------------------------------------------------------
-- dispatch the final line
write_line()

f_out:close()
os.exit(true)
