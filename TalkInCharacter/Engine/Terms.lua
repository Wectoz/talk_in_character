local ADDON, BT = ...

-- Game terms that must be read as typed. A voice, an accent or a mood never changes them.
--   strict: jargon and abbreviations. Always kept, and they mark the message as game talk.
--   loose:  everyday words with a game meaning. Kept only in a message that is game talk,
--           so "LFM BRD need tank" stays plain while "I need a drink" is still in voice.
local Terms = {}
BT.Terms = Terms

local function Set(words)
  local set = {}
  for word in words:gmatch("%S+") do set[word] = true end
  return set
end

local STRICT = Set([[
  lfg lfm lf lf1m lf2m lf3m lf4m lfw pst inv pug premade afk brb omw gtg g2g oom mb dc dced
  gg gj gz grats gratz ninja
  alt toon twink tank tanking tanked offtank healer dps mdps rdps mt ot spec respec ms os
  offspec mainspec prot dw 2h
  mob trash aggro aoe st dot debuff proc cd gcd taunt los cc dispel tps lockout
  bis prebis sidegrade boe bop soulbound de disenchant sr hr prio dkp gdkp ml
  wipe wiped prog brez enrage
  ap sp crit uncrittable snapshotting sim simming
  pvp pve bg wpvp gank ganked zerg inc def fc efc dr juke
  ah wtb wts wtt cod mats reagent undercut buyout
  dm vc gnomer sm gy lib cath zf mara brd lbrs ubrs dme dmw dmn dmt strat ud scholo
  rfc wc sfk bfd rfk rfd uld ulda mc ony bwl zg aq aq20 aq40 naxx wsg ab av
  afking ninjaed ninjaing procced proccing critted hitcap ganker ganking zerging zerged
  vendoring vendored aggroed aggroing manaless nerf nerfed nerfing leet zugzug ench healthstone
  pally pala lock sham shammy hpal rsham spriest resto ret enh ele feral boomkin moonkin disc
]])

local LOOSE = Set([[
  main ready static add pull pulling pulled pat threat cleave burst rotation priority
  peel kite kiting root snare interrupt kick silence cleanse purge swap mitigation
  defensive external upgrade need greed roll funnel council reserve
  instance run clear reset saved fresh progression farm farming stack spread soak bait
  burn nuke focus skull order check corpse hit cap expertise haste avoidance crushing
  glancing parry white yellow rage stance uptime parse mid train trinket
  consumes pot vendor grind flip deposit shuffle stocks tribute live undead
  fury arms holy combat
  warrior paladin hunter rogue priest shaman warlock druid mage
  kill heal boss bosses loot gold mount pet group party guild quest dungeon leader
  potion weapon sword armor dagger knife staff gun food water drink
  sell buy trade price free cheap expensive target attack fire ice curse spell
  buff rez res hot sheep left right
]])

-- Abbreviations that are an everyday word in any other letter case.
local EXACT = { HoT = true, HoTs = true }

Terms.strict = STRICT

--- Whether `lower`, or its singular, is in `set`.
local function Has(set, lower)
  return set[lower] or (#lower > 2 and lower:sub(-1) == "s" and set[lower:sub(1, -2)]) or false
end

-- A run keeps its bytes above 127, so part of a foreign word is never taken for a term.
local RUN = "[%w\128-\255]+"

--- Replaces every term in already shielded `text` with a placeholder held in `parts`.
function Terms.Shield(text, parts)
  local game = false
  for run in text:gmatch(RUN) do
    if EXACT[run] or Has(STRICT, run:lower()) then game = true break end
  end
  return (text:gsub(RUN, function(run)
    local lower = run:lower()
    -- Letters with digits are a code of some kind: LF1M, AQ40, 2H, 50g.
    if EXACT[run] or Has(STRICT, lower) or (game and Has(LOOSE, lower)) or (run:find("%a") and run:find("%d")) then
      parts[#parts + 1] = run
      return "\1" .. #parts .. "\2"
    end
  end))
end
