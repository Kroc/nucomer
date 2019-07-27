-- lua functions for working with C64 stuff

--------------------------------------------------------------------------------
-- table to convert ASCII codes to C64 screen codes
-- (not to be confused with PETSCII)
-- assumes lower-case character set
local str2scr_low = {
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

-- convert an ASCII value to C64 screen code:
-- conversion is inherently incomplete; any ASCII code that cannot
-- be represented as a screen code will be returned as `nil`
--
function c64_asc2scr(x_in)
    ----------------------------------------------------------------------------
    if type(x_in) == "number" then
        return str2scr_low[string.char(x_in)]
    elseif type(x_in) == "string" then
        return str2scr_low[x_in]
    else
        return nil
    end
end

-- convert a string to C64 screen codes
--
function c64_str2scr(s_in)
    ----------------------------------------------------------------------------
    local s_out = ""

    for i = 1, #s_in do
        local c = c64_asc2scr(s_in:byte(i))
        if c ~= nil then
            s_out = s_out..string.char(c)
        end
    end

    return s_out
end