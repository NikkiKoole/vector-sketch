#!/usr/bin/env python3
"""
Replace `goto continue` / `::continue::` patterns with Lua 5.1 compatible code.
love.js uses PUC Lua 5.1 which doesn't support goto (LuaJIT/5.2+ feature).

Strategy: wrap loop body in `repeat ... until true`, replace `goto continue` with `break`.
The `repeat` goes right after the loop's `do`, and `until true` replaces `::continue::`.
"""
import re
import sys
import os


def get_indent(line):
    return len(line) - len(line.lstrip())


def patch_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    if 'goto continue' not in content:
        return False

    lines = content.split('\n')

    # Find all ::continue:: positions
    continue_labels = []
    for idx, line in enumerate(lines):
        if line.strip() == '::continue::':
            continue_labels.append(idx)

    if not continue_labels:
        return False

    # For each ::continue::, find the owning loop.
    # The owning loop is the `for ... do` or `while ... do` whose body contains
    # the ::continue:: label. The label sits at the END of the loop body,
    # just before the loop's closing `end`.
    # So the label's indent == the indent of code inside the loop.
    # The loop header (`for ... do`) is one indent level less.

    loop_headers = []  # indices of lines to append ` repeat` to
    for label_idx in continue_labels:
        label_indent = get_indent(lines[label_idx])
        # The loop header should be at indent = label_indent - 4 (or label_indent - one level)
        # Walk backwards to find it
        found = False
        for j in range(label_idx - 1, -1, -1):
            line = lines[j]
            stripped = line.strip()
            line_indent = get_indent(line)
            # Loop header is at a lower indent than the label
            if line_indent < label_indent and (
                re.match(r'for\b.*\bdo\b', stripped) or
                re.match(r'while\b.*\bdo\b', stripped)
            ):
                loop_headers.append(j)
                found = True
                break
        if not found:
            print(f"  WARNING: Could not find loop header for ::continue:: at line {label_idx + 1}")

    # Now apply transformations
    modified = list(lines)

    # Replace goto continue -> break
    for idx, line in enumerate(modified):
        if 'goto continue' in line:
            modified[idx] = line.replace('goto continue', 'break')

    # Replace ::continue:: -> until true
    for label_idx in continue_labels:
        indent = ' ' * get_indent(modified[label_idx])
        modified[label_idx] = indent + 'until true'

    # Add `repeat` after loop headers
    for header_idx in loop_headers:
        modified[header_idx] = modified[header_idx].rstrip() + ' repeat'

    result = '\n'.join(modified)
    with open(filepath, 'w') as f:
        f.write(result)

    count = len(continue_labels)
    print(f"  Patched {filepath}: {count} goto-continue pattern(s) replaced")
    return True


if __name__ == '__main__':
    build_dir = sys.argv[1] if len(sys.argv) > 1 else '/tmp/playtime-web-build'
    patched = 0
    for root, dirs, files in os.walk(os.path.join(build_dir, 'src')):
        for f in files:
            if f.endswith('.lua'):
                if patch_file(os.path.join(root, f)):
                    patched += 1
    print(f"Done: {patched} file(s) patched")
