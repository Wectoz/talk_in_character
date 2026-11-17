local ADDON, BT = ...

-- Moods colour a message after the voices have spoken. They work on shielded text, so links
-- and names (held as "\1n\2") are never touched, and runs with bytes above 127 are left alone.
local Moods = {}
BT.Moods = Moods

local WORD = "[%a'\128-\255]+"
local ANGRY_CLOSERS = { "Grr!", "Enough!", "Bah!" }

local function Plain(run) return not run:find("[\128-\255]") end

--- Splits off trailing spaces, so punctuation lands on the last word.
local function Body(text) return text:match("^(.-)(%s*)$") end

local function Angry(text, random, voices)
  text = text:gsub(WORD, function(run)
    if Plain(run) and #run >= 4 and random(100) <= 15 then return run:upper() end
  end)
  local body, tail = Body(text)
  if body:find("%.$") then body = body:sub(1, -2) .. "!" elseif not body:find("[!?]$") then body = body .. "!" end
  if random(100) <= 30 then
    local closers = {}
    for _, voice in ipairs(voices) do
      local extra = voice.moods and voice.moods.angry and voice.moods.angry.closers
      if extra then for _, line in ipairs(extra) do closers[#closers + 1] = line end end
    end
    if #closers == 0 then closers = ANGRY_CLOSERS end
    body = body .. " " .. closers[random(#closers)]
  end
  return body .. tail
end

local function Drunk(text, random)
  local hiccuped = false
  return (text:gsub(WORD, function(run)
    if Plain(run) then
      local shout = #run > 1 and run == run:upper()
      run = run:gsub("([sS])(h?)", function(s, h)
        if h ~= "" then return s .. h end
        return s .. (shout and "H" or "h")
      end)
    end
    local hic = random(100) <= 8 and not hiccuped
    hiccuped = hic
    if hic then return run .. " *hic*" end
    return run
  end))
end

local function Scared(text, random)
  text = text:gsub(WORD, function(run)
    if Plain(run) and #run >= 3 and run:find("^%a") and random(100) <= 20 then
      return run:sub(1, 1) .. "-" .. run
    end
  end)
  local body, tail = Body(text)
  if not body:find("[!?]$") then body = body:gsub("%.*$", "") .. "..." end
  return body .. tail
end

local RULES = { angry = Angry, drunk = Drunk, scared = Scared }

function Moods.Apply(text, mood, random, voices)
  local rule = RULES[mood]
  if not rule then return text end
  return rule(text, random, voices or {})
end
