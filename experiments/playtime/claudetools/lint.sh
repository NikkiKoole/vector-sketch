#!/bin/bash
# Static checks over Playtime, in one go (claudetools/README.md, "Checking the code").
#   claudetools/lint.sh          luacheck, unused functions, shellcheck, ruff
#   claudetools/lint.sh --all    also lua-language-server (slow, ~25 s, and noisy: counts per kind,
#                                the list in the scratch file it names) and luacheck's complexity list
# A missing tool is skipped with how to install it. luacheck should say 0 warnings (CLAUDE.md);
# the rest are lists to read, not all of it needs fixing.
cd "$(dirname "$0")/.." || exit 1
ALL=0; [ "$1" = "--all" ] && ALL=1
have() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n== %s\n' "$1"; }

section "luacheck (src/, main.lua)"
if have luacheck; then
    luacheck src/ main.lua --std "lua51+love" --formatter plain --no-color
    luacheck src/ main.lua --std "lua51+love" --no-color 2>&1 | tail -1
else echo "skipped: luarocks install luacheck"; fi

section "unused module functions"
python3 -I claudetools/unused-functions.py

section "shellcheck (warnings and up)"
if have shellcheck; then
    git ls-files '*.sh' | grep -v '^archive/' | xargs shellcheck -S warning -f gcc && echo "clean"
else echo "skipped: brew install shellcheck"; fi

section "ruff (claudetools/, tools/: real errors and likely bugs)"
if python3 -I -m ruff --version >/dev/null 2>&1; then
    python3 -I -m ruff check claudetools/ tools/ --select E9,F,B --ignore B905 --output-format concise --no-cache
else echo "skipped: python3 -I -m pip install --break-system-packages ruff"; fi

if [ $ALL = 1 ]; then
    section "luacheck complexity over 40 (the functions hardest to change safely)"
    luacheck src/ main.lua --std "lua51+love" --max-cyclomatic-complexity 40 --formatter plain --no-color \
        | grep cyclomatic | sed -E 's/^([^:]+:[0-9]+):[0-9]+: cyclomatic complexity of (function )?(.*) is too high \(([0-9]+) > 40\)/\4  \1  \3/' \
        | sort -rn

    section "lua-language-server (counts per kind)"
    if have lua-language-server; then
        OUT="${TMPDIR:-/tmp}/playtime-luals"; mkdir -p "$OUT"
        lua-language-server --check=. --configpath="$PWD/claudetools/luals.json" --logpath="$OUT" \
            --checklevel=Warning --check_format=json --check_out_path="$OUT/out.json" >/dev/null 2>&1
        python3 -I - "$OUT/out.json" <<'EOF'
import json, sys, collections, urllib.parse
d = json.load(open(sys.argv[1]))
c = collections.Counter(x['code'] for ds in d.values() for x in ds)
for k, v in c.most_common(): print(f'{v:5} {k}')
# the kinds most often real: printed in full
for f, ds in sorted(d.items()):
    for x in ds:
        if x['code'] in ('redundant-parameter', 'missing-parameter', 'duplicate-set-field', 'unreachable-code'):
            p = urllib.parse.unquote(f).split('playtime/')[-1]
            print(f"  {p}:{x['range']['start']['line'] + 1} {x['code']}: {x['message'].splitlines()[0]}")
print('all of it:', sys.argv[1])
EOF
    else echo "skipped: brew install lua-language-server"; fi
fi
