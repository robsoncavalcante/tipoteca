#!/usr/bin/env python3
"""Confere se todo texto do código (tr("...")) tem tradução em Resources/*.lproj e se os formatos (%@, %ld) batem."""
import glob, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STR = r'"((?:[^"\\]|\\.)*)"'
SPEC = re.compile(r'%(?:\d+\$)?(?:ld|lld|d|@|f|\.\d+f|lf)')

keys = set()
for path in glob.glob(f"{ROOT}/Sources/*.swift"):
    if path.endswith("Localization.swift"):
        continue
    text = open(path, encoding="utf-8").read()
    for m in re.finditer(r'\btr\(\s*' + STR, text):
        keys.add(m.group(1))
    for m in re.finditer(r'\btrPlural\([^"\n]*' + STR + r',\s*' + STR, text):
        keys.update([m.group(1), m.group(2)])

errors = []
tables = sorted(glob.glob(f"{ROOT}/Resources/*.lproj/Localizable.strings"))
if not tables:
    errors.append("nenhuma tradução em Resources/*.lproj")
for table in tables:
    lang = table.split("/")[-2]
    entries = {}
    for n, line in enumerate(open(table, encoding="utf-8"), 1):
        m = re.match(r'^' + STR + r'\s*=\s*' + STR + r';\s*$', line)
        if m:
            if m.group(1) in entries:
                errors.append(f"{lang}:{n}: chave duplicada: {m.group(1)[:60]}")
            entries[m.group(1)] = m.group(2)
        elif line.strip() and not line.startswith("/*"):
            errors.append(f"{lang}:{n}: linha inválida")
    for k in sorted(keys):
        if k not in entries:
            errors.append(f"{lang}: sem tradução: {k[:70]}")
    for k, v in entries.items():
        if k in keys and sorted(SPEC.findall(k)) != sorted(SPEC.findall(v)):
            errors.append(f"{lang}: formatos diferentes: {k[:50]} / {v[:50]}")
        if not v.strip():
            errors.append(f"{lang}: tradução vazia: {k[:60]}")

print(f"{len(keys)} textos no código, {len(tables)} idioma(s) conferido(s)")
for e in errors:
    print("  ERRO", e)
sys.exit(1 if errors else 0)
