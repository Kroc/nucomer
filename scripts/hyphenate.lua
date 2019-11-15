-- nücomer magazine (c) copyright Kroc Camen 2019. unless otherwise noted,
-- licenced under Creative Commons Attribution Non-Commercial Share-Alike 4.0
-- licence; you may reuse and modify this code how you please as long as you:
--
-- # retain the copyright notice
-- # use the same licence for your derived code
-- # do not use it for commercial purposes
--   (contact the author for a commercial licence)
--

-- hyphenate.lua
--------------------------------------------------------------------------------
-- word-breaking algorithm, published originally in 1983
-- by Franklin Mark Liang: <https://www.tug.org/docs/liang/liang-thesis.pdf>
--
-- this Lua script is a rough port from Ned Batchelder's Python code,
-- <https://nedbatchelder.com/code/modules/hyphenate.html> which was
-- the simplest example I could find that *had any comments*!
-- seriously people, comment your code
--
local Hyphenate = {
    langs = {},                 -- table of languages
}

-- string split function with the semantics of Python:
-- <http://lua-users.org/wiki/SplitJoin>
--
-- (I couldn't express this with the built in lua patterns
--  and my current level of lua knowledge)
--------------------------------------------------------------------------------
function string:split(sSeparator, nMax, bRegexp)
    ----------------------------------------------------------------------------
    assert(sSeparator ~= '')
    assert(nMax == nil or nMax >= 1)

    local aRecord = {}

    if self:len() > 0 then
        local bPlain = not bRegexp
        nMax = nMax or -1

        local nField, nStart = 1, 1
        local nFirst,nLast = self:find(sSeparator, nStart, bPlain)
        while nFirst and nMax ~= 0 do
            aRecord[nField] = self:sub(nStart, nFirst-1)
            nField = nField+1
            nStart = nLast+1
            nFirst,nLast = self:find(sSeparator, nStart, bPlain)
            nMax = nMax-1
        end
        aRecord[nField] = self:sub(nStart)
    end

    return aRecord
end

--------------------------------------------------------------------------------
function Hyphenate:addLanguage(s_locale, s_file_patterns, s_file_exceptions)
    ----------------------------------------------------------------------------
    local f_patterns, f_exceptions, err
    f_patterns,err = io.lines(s_file_patterns)
    if err then print ("! error: " .. err); os.exit(false); end
    f_exceptions,err = io.lines(s_file_exceptions)
    if err then print ("! error: " .. err); os.exit(false); end

    -- add the language name to the language pool
    self.langs[s_locale] = {}
    self.langs[s_locale]["exceptions"] = {}

    -- build a character tree from the patterns:
    for s_pattern in f_patterns do
        -- ignore comments (licence information)
        if s_pattern:sub(1,1) ~= "#" then
            self:insertPattern(s_locale, s_pattern)
        end
    end
    for s_exception in f_exceptions do
        -- ignore comments (licence information)
        if s_exception:sub(1,1) ~= "#" then
            self:insertException(s_locale, s_exception)
        end
    end
end

-- convert a hyphenation pattern into a table of inter-character weights:
--------------------------------------------------------------------------------
function Hyphenate:patternToPoints(s_pattern)
    ----------------------------------------------------------------------------
    local t_points = {}
    for _, s_point in pairs(s_pattern:split("[.a-z]", nil, true)) do
        local i_point = 0
        if tonumber(s_point) then i_point = tonumber(s_point); end
        table.insert(t_points, i_point)
    end
    return t_points
end

--------------------------------------------------------------------------------
function Hyphenate:insertPattern(s_locale, s_pattern)
    ----------------------------------------------------------------------------
    -- for building the branches of the tree, use just the letters
    -- of the pattern word, without the numerical weights
    local s_chars = string.gsub(s_pattern, "[0-9]", "")
    local t_points = self:patternToPoints(s_pattern)

    -- start at the base of the tree
    local node = self.langs[s_locale]

    for c = 1, #s_chars do
        local s_char = s_chars:sub(c, c)
        -- does this branch have this character yet?
        -- if not, create another branch
        if type(node[s_char]) == "nil" then node[s_char] = {}; end
        -- move down the branch to the next level
        node = node[s_char]
    end
    -- having reached the end of the word (and tree-depth)
    -- the leaf node is the list of inter-letter weights
    node.points = t_points
end

--------------------------------------------------------------------------------
function Hyphenate:insertException(s_locale, s_exception)
    ----------------------------------------------------------------------------
    -- exceptions are treated as "as-is" hyphenation results,
    -- a straight lookup of source word to points-list without a tree
    local t_points = {0}
    for _, s_point in pairs(s_exception:split("[.a-z]", nil, true)) do
        -- a weight of 1 is given to inter-character
        -- gaps that contain hyphens
        local i_point = 0; if s_point == "-" then i_point = 1; end
        table.insert(t_points, i_point)
    end
    self.langs[s_locale].exceptions[s_exception:gsub("-", "")] = t_points
end

--------------------------------------------------------------------------------
function Hyphenate:testWord(s_locale, s_word)
    ----------------------------------------------------------------------------
    -- split the word into hyphenation boundaries and then rejoin
    -- the pieces with hyphens between each possible split
    return table.concat(self:hyphenate(s_locale, s_word), "-")
end

--------------------------------------------------------------------------------
function Hyphenate:hyphenate(s_locale, s_word)
    ----------------------------------------------------------------------------
    -- strip leading and trailing punctuation:
    --
    -- the dictionary tree containing the hyphenation patterns only consists
    -- of A-Z letters and a period to mark start/end-of-word -- ergo we cannot
    -- hyphenate a word if it has leading / trailing punctuation
    --
    local prfx = ""     -- once stripped, the leading symbols from the word
    local sufx = ""     -- once stripped, the trailing symbols from the word
    local s, e          -- "start" & "end" character positions

    s, e = s_word:find("^%W+")
    if s then
        prfx = s_word:sub(s, e)
        -- strip the leading symbols from the word
        s_word = s_word:sub(e+1)
    end

    s, e = s_word:find("%W+$")
    if s then
        sufx = s_word:sub(s, e)
        -- strip the trailing symbols from the word
        s_word = s_word:sub(1, s-1)
    end

    -- cannot hyphenate short words
    if #s_word <= 4 then return {prfx..s_word..sufx}; end

    -- the hyphenation dictionary is lower-case, and we pin the beginning
    -- and end of our source word so that we correctly apply hyphenation
    -- patterns that are dependent on the start and/or end of a word
    local s_work = "."..string.lower(s_word).."."

    -- is this word already in the exceptions list?
    -- TODO: how does this handle hyphens already in the word?
    local t_points = self.langs[s_locale].exceptions[string.lower(s_word)]
    if t_points then goto output; end

    --#-- if the word already contains hyphens, split using those
    --#-- and do not automatically hyphenate
    --#if s_word:match("-") then
    --#    t_points = {prfx}
    --#    for _, s_piece in pairs(s_word:split("-", nil, true)) do
    --#        table.insert(t_points, s_piece)
    --#    end
    --#    table.insert(t_points, sufx)
    --#    return t_points
    --#end

    -- having stripped leading / trailing punctuation, does the word
    -- contain any unsupported symbols? we cannot hyphenate a word
    -- that contains numbers, for example
    if s_word:find("%W") then return {prfx..s_word..sufx}; end

    ----------------------------------------------------------------------------
    -- create a points list to match our source word
    t_points = {}
    for i = 1, #s_work+1 do t_points[i] = 0; end

    -- loop over the letters of the source word
    for i = 1, #s_work do
        -- starting point of our search, the first level of the tree
        local node = self.langs[s_locale]

        for c = i, #s_work do
            local s_char = s_work:sub(c, c)
            -- is this character in this level of the tree?
            if type(node[s_char]) == "nil" then
                -- if not, word is not found at this point
                break
            else
                -- go to the next level of the tree
                node = node[s_char]
                -- is this the leaf-node at the end?
                if type(node.points) ~= "nil" then
                    local p = node.points
                    for j = 0, #p-1 do
                        t_points[i+j] = math.max(t_points[i+j], p[j+1])
                    end
                end
            end
        end
    end

::output::
    ----------------------------------------------------------------------------
    -- a hyphen cannot occur in the first or last two characters
    -- (set the weighting score for these positions to zero)
    t_points[2] = 0; t_points[#t_points-1] = 0
    t_points[3] = 0; t_points[#t_points-2] = 0

    -- build a table containing the word, split between hyphenation points
    local t_pieces = {prfx}
    for i = 1, #s_word do
        -- add the letter to the current slice
        t_pieces[#t_pieces] = t_pieces[#t_pieces] .. s_word:sub(i, i)
        -- would there by a hyphen here?
        if t_points[i+2] % 2 ~= 0  then
            -- start a new slice
            table.insert(t_pieces, "")
        end
    end
    t_pieces[#t_pieces] = t_pieces[#t_pieces] .. sufx

    return t_pieces
end

-- initialise the language tables
--------------------------------------------------------------------------------
-- work relatively from the location of this script file:
-- <stackoverflow.com/questions/6380820/get-containing-path-of-lua-file>
local here = debug.getinfo(1).source:sub(2):match("(.*[/\\])")

Hyphenate:addLanguage("en-gb",
    here.."hyphens.en-gb.patterns.lst",
    here.."hyphens.en-gb.exceptions.lst"
)

return Hyphenate