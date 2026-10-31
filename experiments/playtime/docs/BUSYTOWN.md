# Busytown — a town of Mipos with jobs, built from chunky parts

status: idea

**Started:** 2026-10-31. Three things put together: the room-toys brainstorm
(`DOLL-PLAY-MENU.md`, "From a brainstorm"), Fabuland (`FABULAND.md`, `INSPIRATIONS.md`) and
Richard Scarry's Busytown. Ideas to pick from, not a plan; the Sago rule (`one verb, a few weeks`)
still picks.

## What each brings

- **Fabuland** (the 1984 figure poster: *Alla Fabuland figurerna*): every figure is an animal
  with a job and the one thing that says it: Lasse Lejon the mayor, Gabriel Gorilla on drums,
  Kennet Kanin's accordion, Gösta Gris's tuba, Valter Valross the tourist, Kajsa Katt running the
  hotel, Paul Papegoja the press photographer, the police in caps, Lisa Lamm the doctor, Benny
  Bulldogg the fireman, Edvard Elefant the carpenter, Karin Kanin the flower girl with her
  watering can, Per Panda the "idealist" in a tub with a brush, Björn Bulldogg the postman,
  Gunilla Gris who eats a lot, Ricke Räv the happy baker, Frida Flodhäst on her lawnmower, two
  pilots, a painter, an artist, a lazybones. A job is a hat + a held thing + a building.
- **Richard Scarry** (*What Do People Do All Day?*, *Cars and Trucks and Things That Go*):
  everyone is busy, everyone has a vehicle, buildings are cut open so you see the floors inside,
  everything has a label, small mishaps everywhere (a pig slips on a banana, a truck spills its
  apples, nobody's hurt), and Goldbug hides on every page.
- **The room toys**: everything throwable, nothing breaks for good, no fail state; "where can I
  put this guy" is the game; machines in rooms (chutes, fans, pulleys, a xylophone floor,
  stacked rooms with trapdoors).

**Put together:** a Mipo is a Fabuland figure. Dress it with a hat and hand it a thing and it
has a job. Each job has a building made of Fabuland parts, cut open like Scarry's, and each
building is one or two physics toys. Mipos go from building to building and things travel
between them. Busy, not a goal.

## Jobs: a hat, a thing, a place, a toy

Hands already grab and hold (`src/physics/snap.lua`); hats are a snap point on the head
(`DOLL-PLAY-MENU`, "Hats"). A job is only that pair; what the Mipo does follows from the place.

| job | hat + thing | place | the physics toy there |
|---|---|---|---|
| baker | chef's hat, a tray | the bakery (exists as a room) | an oven: put dough in, a loaf pops out; the room smells of cookies (`DOLL-PLAY-MENU` pot) |
| firefighter | red helmet, a hose | fire station, its garage door | water drops from the hose (`liquid.lua`), a pole to slide down a floor |
| postman | cap, a bag | post office | a parcel chute that delivers to another room later; parcels stack on the cart |
| doctor | white cap, a bag | the clinic | a bed: a dazed Mipo lies down, gets a plaster, sits up happy |
| painter | beret, a brush | the workshop | paint changes a block's or a Mipo's colour (the pot that changes colours) |
| gardener | straw hat, a watering can | the garden | plants grow when watered (grass exists), a lawnmower that cuts it back |
| carpenter | cap, a hammer | the building yard | Fabuland parts click together with the hammer |
| musician | drum, accordion, tuba | the bandstand | the Mipo band (`src/mipo-band.lua`): give one an instrument and it plays its part |
| photographer | cap, a camera | anywhere | a flash: the screen freezes for a moment, the picture goes on a wall (screenshot) |
| pilot | goggles | the airfield | a little plane from cart parts and a propeller (the fan) |
| police | cap, a whistle | the crossing | a whistle stops the traffic: carts wait at a gate (signals exist) |
| hotel host | bow, a key | the hotel | rooms with beds: put a Mipo to bed and its window goes dark |
| mayor | top hat | the town hall (the Fabuland one) | a clock that rings the hour; the band comes out |
| tourist | sun hat, a suitcase | the bus stop | a bus that takes a Mipo to another room (a door on wheels) |
| idealist | a brush, a tub | anywhere | Per Panda in his tub: the Bathhouse wash, one tub in town |

## Busytown things

- **Cut-open buildings**: Fabuland blocks with the front off, floors you see into, stairs and a
  pole between them. Stacked rooms in one scene (R5's open question) fit Scarry's way of drawing.
  Needs depth layers (`DEPTH-LAYERS.md`): walls as back parts Mipos walk in front of, floors solid.
- **Vehicles everywhere**: carts from snap parts (exist), with the job's look: a bread van, a fire
  engine, a post van, a bus. Lowly Worm's apple car: a car shaped like a thing.
- **Mishaps, never harm**: a cart of apples tips and the apples roll everywhere, a parcel bounces
  off, a ladder slides. The physics makes these by itself; a "whoops" voice and a surprised face
  make them funny (`mipoVoice`, faces).
- **Labels**: tap a thing and its word shows, said in Mipomi (`PUPPETMAKER-SOUND.md` V2, the mipomi-lang repo): a
  picture dictionary like Scarry's *Best Word Book Ever*.
- **Goldbug**: one small thing hidden in every room to find (a ladybird, a Mipo-sized bug).
- **A day**: morning the baker bakes, noon the band plays, evening the lights go on, night they
  sleep (DOLL-PLAY R7, day and night).
- **Animals as breeds**: Fabuland's lion, pig, elephant, bulldog, rabbit match `MIPO-BREEDS.md`
  (teddy, fat, tall …): a breed could come with a favourite job.

## Where to start (if this gets picked)

One building, one job, one toy, done well, as the Sago rule asks. The bakery is the obvious
first: it already exists as a room, the oven is one toy (in, wait, out), the chef's hat is one
hat snap point, and a loaf is something to carry to another room. Everything else above is the
same recipe again.
