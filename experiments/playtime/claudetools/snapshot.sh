#!/bin/bash
# Before/after snapshots for refactors that shouldn't change what you see (claudetools/snapshots/).
#   claudetools/snapshot.sh take before            # all three: scenes, mipos, editor
#   claudetools/snapshot.sh take after scenes      # one of them
#   claudetools/snapshot.sh diff before after      # identical, or what changed
# Run each "take" twice the first time on a new machine: the hashes should repeat.
# Stored in .snapshots/<name>/ (git-ignored). Run on a copy of the project while the game is
# running: lurker reloads half-made edits into it. Take before and after from the same state of
# everyone's uncommitted work: other modules drawing random numbers shift the Mipos (and the
# editor clicks after the potato-torso click that already fails, see docs/MEASURING.md).
cd "$(dirname "$0")/.." || exit 1
LOVE=${LOVE:-/Applications/love115.app/Contents/MacOS/love}
case "$1" in
take)
    name=${2:?name}; mkdir -p ".snapshots/$name"
    for kind in ${3:-scenes mipos editor}; do
        SNAPSHOT_OUT="$PWD/.snapshots/$name/$kind.txt" "$LOVE" . --specs "claudetools/snapshots/${kind}_spec.lua" \
            | grep -E "Error|Failure" -A6
        echo "$kind: $(wc -l < ".snapshots/$name/$kind.txt") lines"
    done ;;
diff)
    a=${2:?first}; b=${3:?second}; same=1
    for f in .snapshots/"$a"/*.txt; do
        kind=$(basename "$f")
        if cmp -s "$f" ".snapshots/$b/$kind"; then echo "$kind: identical"
        else same=0; echo "$kind: DIFFERS"; diff "$f" ".snapshots/$b/$kind" | head -10 | cut -c1-200; fi
    done
    [ $same = 1 ] ;;
*) sed -n '2,10p' "$0" ;;
esac
