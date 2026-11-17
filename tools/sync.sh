#!/bin/sh
# Copies the addon into the Forever AddOns folder (WSL path). Run from anywhere.
cd "$(dirname "$0")/.." || exit 1
rsync -a --delete Bronzetongue/ "/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/Bronzetongue/"
echo "Synced. /reload in game."
