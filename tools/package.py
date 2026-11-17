#!/usr/bin/env python3
"""Builds dist/Bronzetongue-<version>.zip holding only the Bronzetongue/ folder."""
import os
import re
import zipfile

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
version = re.search(r"^## Version: *(\S+)", open("Bronzetongue/Bronzetongue.toc").read(), re.M).group(1)
os.makedirs("dist", exist_ok=True)
path = "dist/Bronzetongue-%s.zip" % version
with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
    for folder, _, files in sorted(os.walk("Bronzetongue")):
        for name in sorted(files):
            z.write(os.path.join(folder, name))
    names = z.namelist()
assert all(n.startswith("Bronzetongue/") for n in names)
print("%s  (%d files)" % (path, len(names)))
