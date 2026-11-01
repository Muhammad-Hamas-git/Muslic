"""Lists the licence of every Dart package the app ships with.

Reads .dart_tool/package_config.json (written by `flutter pub get`), finds
each package's LICENSE file and classifies it. Dev-only packages (tests,
icon generator) are marked, since they are not inside the app.
Run: python3 ci/licenses.py
"""
import json, os, re, sys
from urllib.parse import urlparse, unquote

ROOT = os.getcwd()
cfg = json.load(open(os.path.join(ROOT, ".dart_tool/package_config.json")))

# Packages that only run at build/test time, never inside the app.
DEV_ONLY = set()
try:
    deps = os.popen("flutter pub deps --style=compact --no-dev 2>/dev/null").read()
    shipped = set(re.findall(r"^- (\S+) ", deps, re.M))
except Exception:
    shipped = set()

RULES = [
    ("AGPL", r"GNU AFFERO GENERAL PUBLIC LICENSE"),
    ("LGPL", r"GNU LESSER GENERAL PUBLIC LICENSE|GNU LIBRARY GENERAL"),
    ("GPL", r"GNU GENERAL PUBLIC LICENSE"),
    ("MPL-2.0", r"Mozilla Public License"),
    ("Apache-2.0", r"Apache License"),
    ("BSD-3-Clause", r"Neither the name|neither the name"),
    ("BSD-2-Clause", r"Redistributions in binary form"),
    ("MIT", r"Permission is hereby granted, free of charge"),
    ("ISC", r"Permission to use, copy, modify, and/or distribute"),
    ("OFL-1.1", r"SIL Open Font License"),
    ("Zlib", r"This software is provided 'as-is'"),
]

def classify(text):
    for name, pat in RULES:
        if re.search(pat, text):
            return name
    return "UNKNOWN"

rows = []
for p in cfg["packages"]:
    name = p["name"]
    uri = p["rootUri"]
    path = unquote(urlparse(uri).path) if uri.startswith("file:") else os.path.normpath(
        os.path.join(ROOT, ".dart_tool", uri))
    lic = None
    for fn in ("LICENSE", "LICENSE.md", "LICENSE.txt", "COPYING"):
        f = os.path.join(path, fn)
        if os.path.exists(f):
            lic = open(f, errors="replace").read()
            break
    kind = classify(lic) if lic else "NO LICENSE FILE"
    where = "app" if (not shipped or name in shipped) else "dev only"
    rows.append((kind, name, where))

flag = {"AGPL", "LGPL", "GPL", "UNKNOWN", "NO LICENSE FILE"}
print("== Dart packages (%d)" % len(rows))
for kind, name, where in sorted(rows, key=lambda r: (r[0] not in flag, r[0], r[1])):
    mark = "  <-- CHECK" if kind in flag and where == "app" else ""
    print(f"{kind:16} {name:40} {where}{mark}")
print()
counts = {}
for kind, _, where in rows:
    if where == "app":
        counts[kind] = counts.get(kind, 0) + 1
print("== Shipped in the app, by licence:", ", ".join(f"{k}: {v}" for k, v in sorted(counts.items())))
