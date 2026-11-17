#!/bin/sh
# Rewrites the file list at the end of the TOC from what is on disk. Run after adding a voice.
cd "$(dirname "$0")/.." || exit 1
toc=Bronzetongue/Bronzetongue.toc
{
  sed -n '/^##/p' "$toc"
  echo
  for f in Core.lua Engine/Protect.lua Engine/Voices.lua Engine/Engine.lua Engine/Moods.lua Engine/Phrases.lua; do echo "$f"; done
  echo
  (cd Bronzetongue && find Voices -name '*.lua' | sort)
  echo
  for f in Send.lua Preview.lua Wheel.lua Options.lua; do [ -f "Bronzetongue/$f" ] && echo "$f"; done
} | sed '/^##/!s|/|\\|g' > "$toc.new" && mv "$toc.new" "$toc"
