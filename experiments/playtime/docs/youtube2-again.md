🎬 [the thumb comes alive, things fall, I grab a thing—it falls too]
Hi, hello, wow—hold on—ahh—shoot—okay—anyway...
Today I’m showing you a weird little tool I built, how it grew out of an older project, and why I think it might actually be kind of a big deal.

Before we get into it, here’s a quick overview of what I’ll be talking about:

🎬 [on-screen list appears, no voiceover]

Why my Puppetmaker app needed a world editor

Shape building & joints

Per-level scripting

Textures & visuals

Adding characters

Rebuilding Puppetmaker inside the editor

And finally: how this lets you tell stories—not just make puppets.

1) Puppetmaker Origins
I made the very first version of Puppetmaker almost 2 years ago—you might’ve tried it.

Mipo Puppetmaker is a fun tool for making characters. But they had nowhere to go.
That’s when it hit me: puppets need a stage, but i'll get there.

You build little hand-drawn characters. That handdrawiness is important to me.
Because I hope, one day, someone tosses the iPad and grabs a real pencil.

They chaacters are physics-based. You can drag them,pull their limbs, throw them, stack them, make winegums fall…
(whispers) no idea why…
...make them do handstands. But that’s it.

They should explore. Visit places. Endure strange contraptions. Get lost in trees.

So I started working on another app, with a procedural landscape.
Endless options for exploring i figured.
You were on a bike. In the mountains, It was weird. testing was slow. I spent hours cycling down procedural hills just to test if a cow looked ok, I got stuck, eventually I shelved it.

That’s when I realized: I didn’t need a new  game. I needed an editor.
Somewhere to draw, attach shapes, test ideas fast. Save and load stuff.

That’s what I should’ve been doing all along.

2) Shapes and Joints
I hooked up Box2D. Bodies, joints, physics properties. things I used to hand-code, now tweakable and fast.

It was fun:
Add a shape → it bounces.
Add two → connect them → they flop around.

But I like messy stuff. So I added: draw *any* shape → boom, it’s a physics body.

Now you can build weird little levels in seconds.

3) Scripts
Once the shapes work, it’s time to make them do stuff.

The visual editor saves time — so scripting is where i can spend that.
Write one script per level or room. No engine changes, just: script → test → repeat.

here are a few:

Buoyancy
Elastic blobs
Platforms
Angry birds & pigs
Planets with gravity

Suddenly you have these interactive worlds. But they still look like green vector shapes…

Time for textures.

4) Textures — Making It Look Like a Drawing
Right now, it still looks like a physics prototype.
I want it to look hand-drawn—like Puppetmaker.

That uses OMP: made it up myself.

Outline — pencil strokes
Mask — shape silhouette
Pattern — texture or shading

So I brought OMP into the new tool.

Box2D doesn’t do visuals, so I made Texture Fixtures —graphics attached to physics bodies.

Here are the main types:

Vanilla — a PNG attached to one shape (supports OMP and distortion with 8 vertices)

Connected-texture — spans across limbs using joints (like a stretchy arm)

Trace-Vertices — stays inside one shape, follows vertex paths (for hair)

Tile — repeating textures for backgrounds or clothes
(But Right now? no clothes, Still nudists.)

Now it looks like a Mipo world: scrappy, sketched, alive. still nude.

🧠 5) Mipo Characters
The whole point of this editor is to give Mipos a place to live.

At the physics level, they’re just shapes and joints — plus a bit of custom rendering.
The editor already handles that. It can load their bodies, their textures, all of it.

But there’s another layer: their DNA.

Not biology, obviously — I mean their personality, their behavior, their structure.
What counts as a limb. Whether that blob is a head, a torso, or a potatohead.
How many torso segments they have. What makes them them.

I’m still figuring out how to manage and store that part — the deeper logic behind each Mipo.
There’s more going on inside these characters than just shapes.

So instead of importing the old ones directly, I let the Mipos shape the tool.
I re-implemented them from scratch — and whenever they needed something, I added it.

That’s why trace-vertices exist. Why connected-textures work.
Not because I planned them.
But because the Mipos — kind of — asked for them.

And then at some point… something flipped.

The features I added for characters turned out to be useful for the world too.
Hair systems became plants. Limb systems became ropes.

It goes both ways.

Who knows what we’ll discover next.

📎 Quick Mentions (Before I Forget)
Softbodies — still figuring them out. Could be great.

Recording & Layering — like animation takes. I’m using it in this video!

🎬 Finale
So yeah, that was a ride.
And yep — you guessed it — I’ll probably rebuild the Puppetmaker app inside this editor.

Same file format, same logic.
You’ll be able to swap characters into any new game I make.

But more importantly — building weird worlds for these puppets is finally fun.

And maybe that was the point all along:

To play.
To make.
To see what happens.

Let’s see where it takes us.
Let’s see what happens next with Puppetmaker.
