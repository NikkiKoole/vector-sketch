# All fours — any Mipo down on four limbs, walking like an animal

status: active

Nikki (2026-11-16): "we have mipos facing direction, could we also have them go on 4 limbs ... so any old
mipos can go animal and on all 4?". Chosen: the head looks ahead, and a Mipo with longer legs than arms keeps
its back high (honest), not levelled.

Spike: `./playtime.sh play allfours` (`scripts/spikes/allfours.playtime.lua`); the pose and the gait are
`scripts/spikes/all-fours.lua` (`lib.tuning`, the panel's sliders). Keys: f all down / up, left / right held
go that way, g walk / trot, r new Mipos, n one more, h panel.

## How

- **Facing a side only**, as sitting (MIPO-FACING): a leg pointing at the camera can't be drawn in 2D. A Mipo
  facing front turns right as it goes down, and stays that way round when it stands up.
- **The body** tips over on its muscle (KEEP_ANGLE, soft and slow: kp 10, 4 rad/s), nose down by what's left
  of the difference between the legs' and arms' height once they're bent ('level' 1 evens it out).
- **The head** looks ahead: its muscle off, a motor in the neck holds it turned back up ('look'); the rig
  zones' crawl found the gaze and the neck limit fight a bent-over body otherwise.
- **The arms are front legs**: shoulder, elbow and wrist limits off while down; the hand stands as a paw.
- **Bending** (Nikki: "their legs need better bending"): a back leg's thigh leans forward and its shin back
  (a hind leg), a front leg's upper arm back and its forearm forward, by as much as brings the longer limbs
  down toward the shorter ones' height ('leg bend' of the way), at least 'min bend' degrees.
- **Ankles** (Nikki: "ankles need more freedom"): their limits off while down, each foot held at the flat
  angle it had standing, whatever the shin does.
- **Hips** (Nikki: "its legs are dragging behind him"): their limits off while down too. A thigh forward under
  a lying body folds the hip ~140 degrees; a standing hip stops near 90, so the thighs sat at the limit,
  pointing back, and the legs dragged.
- **Strength**: with the hips free the limbs need firmer muscles (kp 30; at 10 they pitched onto their heads or
  curled up), the body its own (90; at the limbs' it pitched nose down walking), and nose down at most 15
  degrees (a tiny body on long legs came to ~25 and tipped over).
- **Gaits**: walk (one foot at a time: back left, front left, back right, front right; each down 70% of the
  cycle) and trot (diagonal pairs, half and half), stepping by how far it's come; a foot coming forward lifts
  on more knee. The feet do the pushing (Nikki: "let the feet do the pushing"): toward the speed it wants,
  shared between the feet and hands down in the gait and touching something, applied at each of them (the
  floor's push where it meets the floor). Pushed at the torso's middle, the body pitched over its nose. Told the other way, it turns round on the spot (the body swings over).
- Up again: every muscle, limit and motor back as it was, `mipoActions.wake`, the walk let go.

## The spike's Mipos

Made with **two torso segments** and **arms and legs the same length** (each the average of the two), both on
by default and switchable in the panel for the next Mipos (Nikki: "lets give the mipos here 2 segmented torso,
might help, and lets arrange the arm and legs to be roughly same length"). It did help: walking, every body
stayed between 77 and 99 degrees over five samples (before, with their own limbs and one torso: up to 152, a
Mipo with long legs on a tiny body walked hunched at 100-120). Two segments read as a long animal back.

## Where it stands (2026-11-16)

They go down, stand on four limbs and walk and trot along at the speed asked. Rough still: a Mipo with long
arms creeps low with its elbows folded deep, one with short arms walks nose down; a big difference between
arms and legs reads oddest. Tested over the bridge, not yet by hand.

## The optimizer (2026-11-16)

Nikki: "is this also something we can solve with some better ai? so mipos really learn to move through the
world?". Not a learned controller (MIPO-LOCOMOTION: "not for us"), but the computer tuning the numbers:
`claudetools/fours-optimize_spec.lua` (claudetools/README.md), an evolution strategy over the nine physics
numbers (not the look: body tip, head), each try walking a batch of random Mipos headless, in main.lua's
tick order (~0.1 s a walk), scored on speed against the speed asked, how level and falls; the best checked
on 8 Mipos it never saw.

- First run: the search's centre drifted out of range, every try came out the same from generation 8 (now
  reflected and kept in range); and with 6 Mipos a try the best overfitted (worse on new Mipos than today's).
- Second run (15 generations, 8 Mipos a try), on 8 new Mipos: today's 2.13, 1 fell, 40% of the speed asked;
  the best 1.68, none fell, 44%. But a **stiff shuffle**: stride 10, knee lift ~0, bending off. It found the
  score's loophole: nothing in it asks for the walk to look like an animal's. In the spike: `o` switches
  today's and the optimizer's numbers.
- Even the best gets under half the speed asked: the gait itself (how the feet push) holds it back, not
  the numbers.
- Next, if it comes back: search only the physics (muscles, step length, push) with the look fixed, or
  score the look too (feet clearing the floor, knees bending), or fix the push first.

## Open

- [ ] **AF1. Nikki plays it** and says what reads as an animal and what doesn't.
- [ ] **AF2. Getting down and up** as a move (hands first, then the hips), not every muscle at once.
- [ ] **AF3. Draw order** on all fours: the near front and back legs over the body, the far ones behind
  (facing does about half of it).
- [ ] **AF4. Into the engine** (a Mipo action, `mipoActions` / the motor) once it reads right.
