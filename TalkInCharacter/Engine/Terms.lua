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
  lfw lfp lfr summ summs hs hearth hearthed hearthing guildie gm gquit gkick ginvite gbank gchat
  rl raidlead bio bbl bbs ooc wp ding dinged dinging kek zug lok
  newb newbie nub lowbie pwn pwned pwnage altoholic bankalt tanky healbot dpser offtanking
  specced speccing respecced respeccing 1h mh melee meleeing
  aoeing aoed cleaving dotted dotting rebuff debuffed kiter kited cced ccing decurse decursing
  dispelled dispelling stunlock stunlocked sheeped sheeping poly polyed rezzed rezzing
  epgp deing attune attuned attunement unattuned critting spellpower spelldmg spellhit mp5 fsr
  agi stam sta spi defcap wcl warcraftlogs pvping pver hk dk dhk hwl ahing ahed prepot potting
  gph goldfarm goldfarming spawn respawn respawning
  stockades gnomeregan maraudon uldaman onyxia naxxramas
  ragnaros nef nefarian vael vaelastrasz razorgore chromag chromaggus firemaw ebonroc flamegor
  broodlord lucifron magmadar gehennas garr geddon shazzrah sulfuron golemagg majordomo domo
  hakkar jindo mandokir thekal arlokk venoxis jeklik marli cthun ouro huhuran fankriss skeram
  sartura viscidus kt kelthuzad sapphiron sapph patchwerk grobbulus gluth thaddius anub faerlina
  maexxna noth heigan loatheb razuvious gothik kazzak azuregos emeriss lethon taerar ysondre
  sw stormwind ironforge darnassus org orgrimmar tb uc undercity stv epl wpl ungoro xroads
  tm lhc gadgetzan
  pallies shammies hpally boomie warr huntard surv assa mut affli destro bm mm sv
  bt ww sb fb pom pyro kb evis snd loh boh bok bom soc sor motw gotw ff pws swp gheal fheal
  fearward wf lhw vw coe fd tranq
  tf thunderfury sulfuras dft hoj sgc tuf wbuff wb worldbuff dmf sayge chronoboon booned
  hc ssf deathlog fp flightpath zep profs herbing chanter lw alch engi fa xmute
  arcanite thorium mithril felcloth mooncloth runecloth devilsaur dreamfoil gromsblood plaguebloom
  macro addon dbm bigwigs weakaura questie elvui
  skyborne realmless ruleset campsite transmog tmog xmog rp rper rping rppvp erp
  lvl lvling lvled xp repgrind grp
  pally pala shammy hpal rsham spriest resto ret enh ele feral boomkin moonkin disc
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
  war lock sham port summon rank honor rep gear flask elixir epic layer phase elite rare
  raid raider solo duo legacy perk hardcore totem seal aura aspect trap stun fear sap bubble
  blink nova rag demo sub caster ranged hybrid camp dodge block resist frost shadow arcane
  nature affliction execute sunder renew shackle
]])

-- Abbreviations that are an everyday word in any other letter case.
local EXACT = { HoT = true, HoTs = true }

Terms.strict = STRICT

-- Everyday words that only look like a term with an ending: summ-er, def-er, cod-ed.
local NOT_A_FORM = Set([[
  summer summers summed summing defer coded coder coders coding muted muter mutter mutters
  simmer simmers doted doting nothing losing loser losers spied soccer sored alter alters
  otter otters udder warred warring tanker tankers
]])
local ENDINGS = { "ing", "ed", "er", "ers" }

--- Whether `lower` is in `set`, or is a plural or verb form of a word in it: tanks, taunting,
--- kited (kite), specced (spec).
local function Has(set, lower)
  if set[lower] then return true end
  if #lower > 2 and lower:sub(-1) == "s" and set[lower:sub(1, -2)] then return true end
  if NOT_A_FORM[lower] then return false end
  for _, ending in ipairs(ENDINGS) do
    local stem = lower:sub(1, -#ending - 1)
    -- Three letters at least: "st" must not claim "sting".
    if #stem >= 3 and lower:sub(-#ending) == ending then
      if set[stem] or set[stem .. "e"] then return true end
      if stem:sub(-1) == stem:sub(-2, -2) and set[stem:sub(1, -2)] then return true end
    end
  end
  return false
end

-- A run keeps its bytes above 127, so part of a foreign word is never taken for a term.
local RUN = "[%w\128-\255]+"

--- Replaces every term in already shielded `text` with a placeholder held in `parts`.
--- `keep` is the player's own set of words to leave alone. `force` treats the message as game
--- talk whatever it holds. Also returns whether the message held jargon of its own.
function Terms.Shield(text, parts, keep, force)
  local jargon = false
  for run in text:gmatch(RUN) do
    if EXACT[run] or Has(STRICT, run:lower()) then jargon = true break end
  end
  local game = jargon or force
  text = text:gsub(RUN, function(run)
    local lower = run:lower()
    -- Letters with digits are a code of some kind: LF1M, AQ40, 2H, 50g.
    if EXACT[run] or Has(STRICT, lower) or (game and Has(LOOSE, lower)) or (keep and keep[lower])
      or (run:find("%a") and run:find("%d")) then
      parts[#parts + 1] = run
      return "\1" .. #parts .. "\2"
    end
  end)
  return text, jargon
end
