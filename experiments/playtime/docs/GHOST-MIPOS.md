# Ghost Mipos — only the hair and the mouth

status: parked — Nikki liked it as a look (2026-11-03), kept as an idea for an effect

A Mipo drawn with most of its parts hidden: only its hair (chest hair, tufts) and its mouth show, so it reads as a little ghost floating there. Found by accident: on Nikki's office machine Playtime showed only "chest hair", "mouth shape" and one more part per Mipo, probably because that machine's local `native/desound/libdesound.dylib` was old (it isn't in git, and every machine builds its own; dreamengine-4d's reading, not confirmed there).

tried 2026-11-03: seen as a bug, liked as a look. Not built as an effect.

Uses it could have: a Mipo that's asleep or dreaming, a Mipo in the dark (only what glows shows), a hide-and-seek game, the way a new Mipo appears (hair and mouth first, the body filling in), a spooky room.

How it could be made: a per-Mipo draw filter that skips every part but a list (hair, mouth), maybe with the outline faint. The drawing goes through `box2d-draw-textured.lua`, per drawable kind.
