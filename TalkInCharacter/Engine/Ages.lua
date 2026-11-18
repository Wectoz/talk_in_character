local ADDON, BT = ...

-- Ages colour a message. A word goes to the age only when no voice changed it (Engine.lua asks
-- Ages.Word); the punctuation and asides come after the voices and before the mood. All of it
-- works on shielded text, so links, names and game terms are never touched.
local Ages = {}
BT.Ages = Ages

local CHANCE = 20 -- percent chance of an aside, on a message of three words or more

local RULES = {
  young = {
    words = { very = "sooo", really = "totally", definitely = "totally", so = "sooo",
      great = "awesome", amazing = "so cool", cool = "wicked", nice = "neat", good = "super good",
      bad = "yucky", big = "huge", small = "teeny", fast = "super fast", strong = "super strong",
      old = "super old", scary = "spooky", beautiful = "pretty", stupid = "dumb", boring = "sooo boring",
      yes = "yep", yeah = "yep", nope = "nuh-uh", ok = "okie", okay = "okie",
      hello = "hiya", hi = "hiya", hey = "hiya", bye = "bye bye", thanks = "thanks a bunch",
      please = "pretty please", sorry = "oops, sorry", wow = "whoa", lol = "hehe", haha = "hehe",
      friend = "buddy", friends = "buddies", guys = "you guys", mother = "mom", father = "dad",
      monster = "meanie", monsters = "meanies", enemy = "meanie", enemies = "meanies",
      tired = "sleepy", hungry = "starving", money = "pocket money", because = "cuz",
      maybe = "maybe maybe", never = "never ever" },
    closers = { "Can we go now?", "Are we there yet?", "Best day ever!", "Did you see that?" },
    -- Everything is exciting: a plain ending becomes "!".
    shape = function(text)
      local body, tail = text:match("^(.-)(%s*)$")
      if body:find("[^%.]%.$") then body = body:sub(1, -2) .. "!" elseif body:find("[%w\2]$") then body = body .. "!" end
      return body .. tail
    end,
  },
  elder = {
    words = { kid = "youngster", kids = "youngsters", boy = "sonny", girl = "young lady",
      noob = "whippersnapper", noobs = "whippersnappers", guys = "young ones", friend = "old friend",
      friends = "old friends", idiot = "young fool", stupid = "foolish",
      yes = "quite so", yeah = "indeed", nope = "I think not", ok = "very well", okay = "very well",
      hello = "good day", hi = "good day", hey = "ahem", bye = "farewell", thanks = "much obliged",
      please = "kindly", sorry = "beg pardon", wow = "my word", lol = "heh", haha = "heh heh",
      what = "eh, what", cool = "splendid", great = "splendid", awesome = "remarkable",
      amazing = "remarkable", nice = "lovely", good = "fine", bad = "dreadful", very = "rather",
      really = "truly", maybe = "perhaps", tired = "weary",
      old = "seasoned", money = "coin", think = "reckon", remember = "recall", sleep = "nap",
      hurry = "make haste" },
    openers = { "Hmm...", "Now then...", "Ah, yes..." },
    closers = { "Back in my day, we walked.", "Eh? What was I saying?", "These old bones remember.", "Mind my back, now." },
    -- Slow speech: some commas become a pause.
    shape = function(text, random)
      return (text:gsub(", ", function() if random(100) <= 30 then return "... " end end))
    end,
  },
}

--- What `age` says for the lowercase word `lower`, or nil.
function Ages.Word(lower, age)
  local rule = RULES[age]
  return rule and rule.words[lower]
end

--- The punctuation and asides of `age`. `words` is how many words were typed; `extras` false
--- means no aside is ever added. A voice's own closers for the age replace the plain ones.
function Ages.Apply(text, age, random, extras, words, voices)
  local rule = RULES[age]
  if not rule then return text end
  text = rule.shape(text, random)
  if extras == false or words < 3 or random(100) > CHANCE then return text end
  local openers = rule.openers
  if openers and random(2) == 1 then return openers[random(#openers)] .. " " .. text end
  local closers = {}
  for _, voice in ipairs(voices or {}) do
    local own = voice.ages and voice.ages[age] and voice.ages[age].closers
    if own then for _, line in ipairs(own) do closers[#closers + 1] = line end end
  end
  if #closers == 0 then closers = rule.closers end
  return BT.Engine.Append(text, closers[random(#closers)])
end
