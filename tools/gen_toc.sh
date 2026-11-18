#!/bin/sh
# Rewrites the file list at the end of the TOC from what is on disk. Run after adding a voice.
cd "$(dirname "$0")/.." || exit 1
toc=TalkInCharacter/TalkInCharacter.toc
{
  sed -n '/^##/p' "$toc"
  echo
  for f in Core.lua Engine/Protect.lua Engine/Terms.lua Engine/Voices.lua Engine/Engine.lua Engine/Moods.lua Engine/Phrases.lua; do echo "$f"; done
  echo
  (cd TalkInCharacter && find Voices -name '*.lua' | sort)
  echo
  for f in Send.lua Preview.lua Wheel.lua Options.lua; do [ -f "TalkInCharacter/$f" ] && echo "$f"; done
} | sed '/^##/!s|/|\\|g' > "$toc.new" && mv "$toc.new" "$toc"
