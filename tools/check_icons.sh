#!/bin/sh
# Checks that every voice icon is a real game icon, by asking Wowhead's public icon image
# server for it. Run after adding or changing a voice. Needs internet.
cd "$(dirname "$0")/.." || exit 1
bad=0
for name in $(grep -rhoE 'Interface\\\\Icons\\\\[A-Za-z0-9_]+' TalkInCharacter/Voices | sed 's/.*Icons\\\\//' | sort -u); do
  lower=$(echo "$name" | tr 'A-Z' 'a-z')
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 20 -A 'Mozilla/5.0' "https://wow.zamimg.com/images/wow/icons/large/$lower.jpg")
  if [ "$code" != "200" ]; then echo "MISSING ($code) $name"; bad=1; fi
done
[ "$bad" = 0 ] && echo "All voice icons exist." 
exit $bad
