#!/usr/bin/env python3
"""Uploads dist/TalkInCharacter-<version>.zip to CurseForge with curseforge/changelog-<version>.md.

Needs CF_API_TOKEN in the environment. Usage: tools/upload.py [release|beta|alpha]
"""
import json
import os
import re
import subprocess
import sys

PROJECT = 1812630
API = "https://wow.curseforge.com/api"

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
release = sys.argv[1] if len(sys.argv) > 1 else "release"
assert release in ("release", "beta", "alpha"), "release type must be release, beta or alpha"
token = os.environ.get("CF_API_TOKEN") or sys.exit("CF_API_TOKEN is not set")

toc = open("TalkInCharacter/TalkInCharacter.toc").read()
version = re.search(r"^## Version: *(\S+)", toc, re.M).group(1)
interface = re.search(r"^## Interface: *(\d+)", toc, re.M).group(1)
zip_path = "dist/TalkInCharacter-%s.zip" % version
changelog = open("curseforge/changelog-%s.md" % version).read()
assert os.path.exists(zip_path), "%s is missing, run tools/package.py first" % zip_path


def curl(*args):
    # The token goes in on stdin so it never shows up in the process list.
    done = subprocess.run(["curl", "-sS", "--fail-with-body", "-m", "120", "-H", "@-", *args],
                          input="X-Api-Token: " + token, capture_output=True, text=True)
    if done.returncode:
        sys.exit("CurseForge said no: %s %s" % (done.stdout, done.stderr))
    return json.loads(done.stdout)


game_versions = [v["id"] for v in curl(API + "/game/versions") if v["apiVersion"] == interface]
assert game_versions, "CurseForge has no game version for interface %s" % interface

metadata = {"changelog": changelog, "changelogType": "markdown", "displayName": "Talk in Character " + version,
            "gameVersions": game_versions, "releaseType": release}
reply = curl("--form-string", "metadata=" + json.dumps(metadata), "-F", "file=@" + zip_path,
             "%s/projects/%d/upload-file" % (API, PROJECT))
print("Uploaded %s as %s, file id %s" % (zip_path, release, reply["id"]))
