#!/usr/bin/env python3
"""Builds dist/TalkInCharacter-<version>.zip holding only the TalkInCharacter/ folder."""
import os
import re
import zipfile

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
version = re.search(r"^## Version: *(\S+)", open("TalkInCharacter/TalkInCharacter.toc").read(), re.M).group(1)
os.makedirs("dist", exist_ok=True)
path = "dist/TalkInCharacter-%s.zip" % version
with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
    for folder, _, files in sorted(os.walk("TalkInCharacter")):
        for name in sorted(files):
            z.write(os.path.join(folder, name))
    names = z.namelist()
assert all(n.startswith("TalkInCharacter/") for n in names)
print("%s  (%d files)" % (path, len(names)))
