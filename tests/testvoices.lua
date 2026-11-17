-- Inline voices for engine tests, so edits to shipped voices never break engine tests.
local function phrases(hello)
  local p = {}
  for _, k in ipairs({ "hello", "follow", "wait", "cheer", "battle", "bye", "help", "thanks" }) do p[k] = { "a.", "b.", "c." } end
  if hello then p.hello = hello end
  return p
end
return function(BT)
  BT.RegisterVoice({ id = "t_race", name = "T Race", kind = "race", icon = "i",
    swaps = { hello = { tier = 1, "ahoy" }, you = { tier = 2, "ye" }, my = { tier = 1, "me" } },
    sounds = { { tier = 2, pattern = "ing$", repl = "in'" } },
    openers = { "Arr," }, closers = { "Yarr!" }, phrases = phrases() })
  BT.RegisterVoice({ id = "t_class", name = "T Class", kind = "class", icon = "i",
    swaps = { kill = { tier = 1, "smite" }, hello = { tier = 1, "hail" } },
    sounds = {}, openers = {}, closers = {}, phrases = phrases() })
  BT.RegisterVoice({ id = "t_long", name = "T Long", kind = "race", icon = "i",
    swaps = { a = { tier = 1, "aaaaaaaaaa" } }, sounds = {}, openers = {}, closers = {}, phrases = phrases() })
  BT.RegisterVoice({ id = "p_race", name = "P Race", kind = "race", icon = "i", swaps = {}, sounds = {}, openers = {}, closers = {},
    phrases = phrases({ "Hi.", "Hi {target}.", "Yo." }) })
  BT.RegisterVoice({ id = "p_class", name = "P Class", kind = "class", icon = "i", swaps = {}, sounds = {}, openers = {}, closers = {},
    phrases = phrases({ "Hail.", "Hail!", "Hail?" }) })
end
