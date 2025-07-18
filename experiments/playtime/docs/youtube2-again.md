🎬 [The thumb comes alive. Things fall. I grab a thing—it falls too.]
Hi, hello, wow—hold why is everything so slipperly?! on—ahh—shoot—okay—anyway...
ok [deep breath] i'm fine.
So today… I want to show you a little thing I made. how it grew out of an older project, and why I think it could be a big deal.
Let me explain,

🎬 [On-screen list appears, no voiceover]
Origins
Shapes and Joints
Scripts
Textures
Characters
Finale


1) Origins
Almost two years ago, I made a weird little puppet app.
That was Mipo Puppetmaker.

A create-your-own-character tool.
You can drag them, pull their limbs, throw them, stack them…
and you can also make winegums fall…
(whispers) I honestly can’t remember why...
And they could even even do handstands. But that was kind of it.

I wanted more.
Adventures, Contraptions!
Funky locations, Fairy tales.
Weird physics puzzles, exploration.

So I started working on another app — this time with a procedural landscape.
I figured: let’s give them enough space to get lost in.

You were on a bike. In the mountains. It was weird.

But building the objects was slow. Everything had to be hardcoded.
At one point wanted a cow.
I spent HOURS cycling down a mountain just to test if the cow looked okay.
Spoiler: it didn’t.
You could say *I* got lost, instead of my characters.
Eventually I realized:
This wasn’t working.
I didn’t need another game.
I needed a sandbox.

A place to test ideas
That’s what I should’ve been building all along.

So I made
an editor

A stage for my puppets.

2) Shapes and Joints
I hooked up Box2D to my editor — bodies, joints, physics settings — all tweakable with buttons and sliders now. No more hand-coding every little thing.

Before, adding anything — even just a cow — meant writing out all the vertex points by hand.
Then figuring out the joints.
Then testing.
Then repeating.
It took hours.
soul-crushing hours

Now? I just draw a shape — and BLAM it works.

And it's fun:
Add a shape → it falls.
Add another → they bounce.
Connect them → they flop around.

I like the messier stuff even more.
So my favorite feature here right now is this: draw any shape (a freeform one) → boom, physics body.

Now you can build weird little levels in seconds. Okay, minutes.

3) Scripts
The physics engine behind all this handles gravity, collisions, movement…
Which is nice.
But what if you want something that hops?
Or explodes? Or if someone needs to  stands upright for once instead of just being a ragdoll?

scripting.

Each room can run a little script. One sandboxed bit of logic. That’s all I need (for now at least).
I use it to give things behavior.

Here are some things I made with it:

Buoyancy
Elastic blobs
Platforms
Angry birds & pigs
Planets with gravity
Snappy connections


4) Textures

I want the world to feel hand-drawn. Like someone scribbled it.
So I use a system  I invented in the Puppetmaker days. It’s called:
OMP
Outline, Mask, Pattern

Outline — pencil lines
Mask — shape silhouette
Pattern — texture or shading

Each layer?, Customizable.

But Box2D? It has no clue what a texture is.
Just bodies. Shapes. Fixtures. Joints.
And the shapes? Just boring old polygons.

So I made my own system: Texture Fixtures — a way to attach graphics data to physics bodies.

I made four kinds:

Vanilla — a PNG attached to one shape (supports OMP + shape bending)
Connected-texture — spans across limbs via joints (like a stretchy arm)
Trace-Vertices — follows vertex paths inside a shape (for hair)
Tile — repeating textures for backgrounds or flooring or clothes
(Clothes? Not yet. They’re still nudists. I can respect that.)

5) Mipo Characters

Everything so far?
It’s for the Mipos.
to give them a place to live.

But what are they in this editor ?
At the physics level, they’re just shapes and joints — plus a bit of custom rendering.
The editor already handles that. It can load their bodies, their textures — all of it.

But there’s another layer: their DNA.

Their structure.
What counts as a limb?
Is that blob a head? A torso? A potatohead?
If two Mipos had kids — what would they look like?

I rebuilt the characters from scratch, inside this new editor.

They needed stuff, so I built it.
They grew. The tool grew.
It got… weirdly wholesome.

That’s why trace-vertices exist — because they have hair.
Why connected-textures exist — because they have limbs.

And then at some point… something flipped.

The features I added for the characters turned out to be useful for the world too.
Hair systems became plants.
Limb systems became ropes.
Suddenly, tools made for puppets started growing a whole world.

(Still no faces though. That’s another video: lips, eyes, noses, emotions—OH GOD THE EYEBROWS.)

Softbodies? In progress.
Recording layers? I’m using them right now!

This is just the beginning.

6) 🎬 Finale
So yeah.
It started with a puppet.
Now, I have a stage.

I’m rebuilding Puppetmaker inside this thing too.

Same file format. Same logic.
One day, you’ll be able to drop your Mipo into any game I make.

But more importantly:
it’s actually fun to build weird little worlds now.
And maybe that was the point all along.

To play.
To make.
To see what happens next.
To have fun.
