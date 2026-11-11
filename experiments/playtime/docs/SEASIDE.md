# Seaside — the water spikes in one: a sea, cups and a bath, all one see-through water

status: active

Nikki (2026-11-06): combine the water experiments into one: a sea, water that flows and can be
kept in cups, and it should look liquid and see-through. Borrow from the glass and the caustics.
Only in this spike scene for now, not for every LIQUID in every scene.

Scene `seaside` (`scripts/spikes/seaside.playtime.lua`): the `sea` spike (SEA.md) with a beach to
its right: a table with two cups, a cup by the water, a bath on the sand, a striped windbreak
behind the table so there's something to see bent through the water.

How it's put together:
- The sea is the sea spike's (waves, swell, floating, splashes, the water shader). The sky now
  draws into the scene canvas too, so water in front of the sky has something behind it.
- The cups and the bath are the LIQUID sfixture (`src/liquid.lua`, WATER.md W1/W3a: level water,
  sloshing, spilling). While the scene is on, `state.liquidDrawHook` is set: `liquid.draw` hands
  over the wavy surface line and the hollow (hull less the vessel) instead of drawing flat colour.
  `s.draw` draws each one with the same water shader as the sea, after the world canvas is done
  (the shader can't read the canvas it draws into), stencilled to the hollow. Depth counts from
  each water's own surface, so a cup stays clear and pale. `cupCaustics` sets the caustic size
  in cups (the sea's pattern is a cup wide). Other scenes have no hook and draw as before.
- Our vessels and the table draw themselves (pottery and ink); in play mode the plain body shapes
  are off, like the sea's props.

The water shader lives in `src/render/water-shader.lua` since 2026-11-11 (ENGINE-MERGE EM3), shared with
`src/water-look.lua`, which gives cups and baths in every other scene the same thin water.

Keys in play mode: m b c o u (Mipo, boat, crate, ball, cup), w a wave, r reset, h the panel.
A second game next to a running one: `PLAYTIME_BRIDGE_PORT=8004 love . --bridge --play seaside`.

- [x] **SS1. One water** (2026-11-06): cups, bath and sea drawn with the sea's shader.
- [x] **SS1b. Thin water thin** (2026-11-06, Nikki: "the thin layers of water in cups shouldn't
      have such a deep effect"): the shader's `viewDepth` (how much water you look through, 450 in
      the sea) and `bend` are per draw; cups get `cupView` 60 and `cupBend` 0.3, half the caustics,
      no silver underside, shafts or specks.
- [x] **SS2. Pouring** (2026-11-06). `liquid.update` hands what spills to `state.liquidSpillHook`
      (else it's lost, as before). Here `s.onSpill` lets out at most `FLOW` a second as drops from
      the rim's low corner (`liquid.mouthPoint`), the rest goes back in, so a pouring cup stays full
      to the brim. Drops (no Box2D bodies) landing in a cup or the bath add to it, in the sea they
      join it, on the sand, the table or a Mipo they splat into two small ones that fade.
      Drawn as one stream: soft blobs stretched along their flight added up in a field canvas, the
      stream shader shows water where the field is over a line, its slope bending what's behind
      (the glass spike's roundness), a bright edge and a highlight. The sea's splash drops too.
      Since WATERJAR WJ4 (2026-11-06) the poured water is particle water (`src/fluid.lua`): it
      splashes, puddles on the table and the sand and soaks away, instead of drops that splat.
- [ ] **SS3. Dipping.** A cup held under the sea fills up to its mouth.
- [x] **SS4. Floating in cups and the bath** (WATER.md W4), from the sea's `float`. Done 2026-11-11 in
      `src/liquid.lua`, so in every scene.
- [ ] **SS5. Glass touches** from `glass` (GLASS-BEADS.md): a bright line where the water meets
      the wall, the light gathered at the bottom. Only if the plain shader looks short in a cup.

Open: the stream has a thin dark fringe where its
edge bends an ink line in.

Known: water is drawn after the world, so a Mipo standing in front of a cup is seen through
its water; a cup under the sea shows its inside untinted by the sea.
