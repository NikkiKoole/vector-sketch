

Growing My Playtime Tool




intro

Hi, today i want to show you a tool i'm building, and how i got there.
We will start with the mipo puppetmakere, where you can create quite great characters,
but then its becoming obvious that just characters is not enough, you want a whole world for them to explore and to do stuff in.

So before i'll continue with the sotory i'll give a small overview of what will bein this video:

- begin: how the puppetmaker tool made it obvious that there should be a world editor
- geomteric shapes and joints
- per level scripts
- textures
- getting my characters into this editor
- end: talk about rebuilding the puppetmaker tool version2 using this editor, and adding a bunch of small worlds for the characters to play in.


At that time i decided to just maeke a sort of garden or field wehre you have a couple of them and some random activities, falling candy, handstands, but obviously not a world yet.

So then i figured, i will not just make a world, i'll make and endless world, and started working on the mountain app, i could have been the tour de france, or i something, i can't rememebr exactly, but it seemed added bicycles was a good idea.
but for every thing i wanted to add i needed to write custom boierplaet box2d code, think about joints and shapes, and plonk together rectangles and circles in code.  it was giving me so too much headaches and resistsance so that this project ended up shelved. and i starterd thinking.

I wanted to add new physics shapes without writing boilerplate Box2D code. arted building a small tool to just draw shapes and joints visually.



At some point i was here (puppetmaker, capable of quickly making weird little monsters)
and now they need a place to explore, to do stuff in.

It is a tool for rapidley making physics bodies, by just drawing them and not having to write boilerplate code .
The tool is growing into something  in which you can also script unique behaviors.
replay interactions for videos of multiple resoltions and scripted animations.
also the graphics layer is growing quite abit, we will touch all of this.

max 5 points

--> we start with what is missing from puppetmaker (adding stuff is hard, writing box2d code is boring)
1 -- show puppetmaker, missing a way to add new shapes for their world. painfull to add box2d shapes needed a tool for that
2 -- playtime basics (shapes + joints)
3 -- showing some scripts
4 -- adding mipos
5 -- playtime textureing
<-- we end with reimplementing puppetmaker in the other tool






----

Absolutely! Here's a refined version of your outline with more connective tissue — “the dance” — and a clear narrative structure. Each point flows from the previous one with cause-effect relationships and slight twists that justify the next step.

🎬 Script Outline: “From Puppetmaker to Playtime”
Intro
Hi! Today I want to show you a tool I’ve been building — and more importantly, how I got there.


It started with mipo puppetmaker, a fun tool to make these characters, and i'm still very curious where this (and they..) will go, but for these guys to do stuff, we will need a world. a place to do things.  S



When i started playing around in int, it became something much bigger — i wanted to make different levels, or scripted surroundings without writing code, a way to replay interactions and render videos in multiple resolutions

Let’s walk through how each of those features emerged — not all at once, but step by step, each solving the pain of the last.

1. What Puppetmaker Couldn't Do
We begin with the original problem: Puppetmaker was fun, but static.

You could build characters from parts, but you couldn’t really add new world elements or experiment beyond the built-in shapes. Want a big bouncy trampoline? Or a weird contraption made of jelly cubes? You had to write Box2D code. Boring
That friction pushed me to ask: What if I could draw a shape in some editor and use it as is aa physics body?

2. So I Built “Playtime” — A Drawing Playground for Physics
From that question came Playtime — a visual editor to draw shapes, connect joints, and simulate physics without ever touching code.

You just sketch a shape, drag on joints, and hit play.

But I quickly ran into a second problem: it was great for building… but not for interaction. You could make things, but not make them do things.

3. Scripting With Code
So next came behavior scripting
I wanted to describe how something reacts: if this button is pressed, the door opens. If the spring is stretched, trigger a sound. So I added a simple event-action system.

Suddenly, Playtime wasn’t just a construction kit — it became a theater. And that opened up a new possibility…

4. Adding Mipos and Recording Interactions
Now that I had behaviors, I wanted characters — so I brought in Mipos, my modular puppet creatures from the original app.

They could now walk through a Playtime world, press buttons, launch themselves off ramps — and all of that could be recorded. You could play, record, and export videos of those interactions.

But exporting videos needed another upgrade…

5. Playtime’s Graphics Layer
Rendering videos meant having better visuals. So I started upgrading the graphics layer: custom textures, layering, expressive visuals — all inside Playtime.

Now, it wasn’t just a playground — it was a stage with lighting, props, and actors.

Finale: Puppetmaker, Reborn in Playtime
And so, with all of that in place — drawing tools, scripting, mipos, graphics — I realized:

I could now rebuild Puppetmaker inside Playtime.

Everything that was hard in Puppetmaker — adding parts, testing interactions, expanding behaviors — is now effortless.

And that’s how the tool that started as “a better shape drawer” became a full creative playground for physics-based characters and stories.




-- transcribing:


Hi, today i want to show you a tool i'm building, and how i got there
before i'll continue with the story  i wil give a small overview of the things we'll be talking about:

at the beginnig is this old app i made, the puppetmaker, and how that made it obvious to nme  that there should be a world editor.
next up , ... oh hold on, this is boring, i can just put a list here[*] , . (skip this, just show a list onscreen)"" while beginning building the editor, we start with geometric shapes and joints. basic box2d stuff.
next up is about scripting, per level,
textures,
how to get the characters from the puppetmaker tool back into this editor,
futurre things, moving from a physics draw tool to a real game world editor (camera, interaction replay, ..)
"" (end skip)
and then i;ll end about how i'll pprobably end up rebuilding the whole puppetmaker tool completely in this new editor and why,
i can already tell you why, that is because using this new editor we can make a bunch of small one-screen worlds/places for my characters to nteract with and very important have fun makeing them.

so that is the why, now lets look at how:


-- cleaned up
Hi! Today I want to show you a tool I’m building—and how I got there.

Before I continue with the story, I’ll give a small overview of the things we’ll be talking about:

At the beginning, there's this old app I made—the Puppetmaker—and how that made it obvious to me that there should be a world editor.

Next up… oh, hold on, this is boring. I can just put a list here [*].
(skip this part, just show the list on screen)

Starting to build the editor: geometric shapes and joints, basic Box2D stuff

Scripting (per level)

Textures

Bringing characters from the Puppetmaker into this editor

Future steps: moving from a physics drawing tool to a real game world editor (camera, interaction replay, etc.)

(end skip)

And then I’ll end with why I’ll probably end up rebuilding the whole Puppetmaker tool completely in this new editor—and why that actually makes sense.

I can already tell you the reason: with this new editor, we can make a bunch of small, one-screen worlds or places for my characters to interact with—and, most importantly, have fun making them.

So that’s the why.
Now let’s look at the how:


--- my text



-- cleaned up



Hi, today i want to show you a tool i'm building, and how i got there
before i'll continue with the story  i wil give a small overview of the things we'll be talking about:

at the beginnig is this old app i made, the puppetmaker, and how that made it obvious to nme  that there should be a world editor.
next up , ... oh hold on, this is boring, i can just put a list here[*] , . (skip this, just show a list onscreen)"" while beginning building the editor, we start with geometric shapes and joints. basic box2d stuff.
next up is about scripting, per level,
textures,
how to get the characters from the puppetmaker tool back into this editor,
futurre things, moving from a physics draw tool to a real game world editor (camera, interaction replay, ..)
"" (end skip)
and then i;ll end about how i'll pprobably end up rebuilding the whole puppetmaker tool completely in this new editor and why,
i can already tell you why, that is because using this new editor we can make a bunch of small one-screen worlds/places for my characters to nteract with and very important have fun makeing them.

so that is the why, now lets look at how:


The Mipo Puppetmaker Tool—it’s a mouthful.

I call my characters Mipos, so now you know.

You can make—I think you can make—great little characters in there. They do look kind of fantastic. You can mix and match, and vary lots of details.
Hand-drawn, they are. Every part is hand-drawn. That’s very important to me.

Because children—or, well, anyone—will hopefully at some point just throw aside the iPad, grab a piece of paper, and start drawing.

It’s much better than all this screen stuff.

Anyway, you have these characters. They’re physics-based. But… there’s just not a lot for them to do.
You can drag them around, stack them on top of each other, let winegums fall from the sky—
(whispers) I can’t remember why—
Make them do handstands…
And that’s it, really.

It feels like they should be able to explore, right?
You want them to have worlds to see, places to visit, weird contraptions to suffer and enjoy.
Vehicles, trees, buildings—all that stuff.

So at some point, I figured:
I need to make another app.
The next app.

And it needs to be a world for them to explore.
If I remember correctly, there were going to be lots of rooms, and an overworld.
And it’s not just a world.
It would be… an endless world.

So I made it like a procedural thingie that generated an endless hilly—or mountainous—landscape.

I can’t remember why exactly, but I also figured your main character needed to be on a bike.
So they could cycle down the mountain.
(cut to Albert Hofmann LSD illustration)

And then I got stuck. Really stuck.

I wanted to add enormous cows and other strange stuff to these boring hills…
But everything was a pain to configure.
You had to think about geometric shapes and joints and write it all out in code.
Preferably correctly.
Because the cycle was: write some code, run the app, cycle down the hill, see your result…
And repeat that until it was good.
And that loop was so slow.
It was just a massive pain. A big headache.

I ended up shelving the project. Probably because of that.
I was stuck.

So that’s how I came to the idea of needing an editor.
A drawing program.
A place where you can quickly draw shapes, drag things around, and attach them to each other.

-- my text

 the mipo puppetmaker tool, its a mouth full
 i call my characters mipo's so now you know.
 you can make, i think you can maek, great little characters here, they do look kinda fantastic, you can mix and match and vary lot's of details handdrawn they are, all the parts are handdrawn that's very important for me.
 so children, or well anyone, will at some point, hopefully just throw aside the ipad and grab a piece of paper and start drawing.
 its much better then all this screen stuff.
 anyway, you have these characters, they are physics based, but they is just not a lot for them to do, you can drag them around, stack them on top of each other, let winedrops fall from the sky, (whisper) i can't remember why!, make them do handstands, and well thats it really.
 it feels like you want them to be able to explore right ?
you want worlds to see, places to visit, weird contarptions for them to suffer and enjoy.
vehicles, trees, buildings, all this stuff.

so at some point, i figured:
i need to make another app, the next app,
and it needs to be a world, for them to explore, iirc, there would be lots of rooms and an overworld, and its not just a world,
it will be an endless world.
So i made it like a procedural thingie, wwhich generated an endless hilly or mountaineous landscape.
I can't rememebr why exactly but i also figured you needed to have your main character on a bike
so he can cycle down the mountain (show lsd albert hoffman illustration)
and then  I GOT STUCK really,
i wanted to enormous cows and other stuff to these boring hills, but everyt hing was a pain to configure and write the boilerplate code for,
you needed to think about geomteric shapes and joints and write it all out in code, preferably correct at once because the cycle of experimenting writing some code, cycling down a hill and seeing your result and repating that utill it was good was  so very slow it basically was just a very big pain. a big headache.
I ended up shelving the project, probably because of this.  and i sort of yeah, was stuck.

So thats how i came to the idea of needing an editor, a drawing program where you can quickly draw shapes, drag things around and attach them to each other, copy and pasteing compoennts, playing with all the physics properties and being able to save and load levels or projects like that. just a tool to quickly throw together experiments like that and save the ones i'm happy with.
it's a simple insight, but well, you know, when you are doing the wrong thing its


 6:20
yeah so at the bgeinning of the development of thi new tool i was foccsuning o hooking up the box2d api, adding all the types of bodies, all the types of joints, enabling changing most the physiscs porperties you can. but via on sceen buttons versus code.
it offered, wel it made me, well, its fun , its fun to play with , add some shapes, see them fall and bounce

the thing next to the geomteric shapes, the next step, because i'm a bit of a sloppy guy right?, i like handdrawn stuff, crooked stuff, things that are off and not perfectly rectangular, like the opposite of geometric perfection.
so i added this thing where you can just draw a shape and it will become a physics body.

and yeah, now your able to make nice little levels really.

then the next idea here is about scripts,
we might not need to write or code the physics bodies with joints and everything ,
but now you will be writing logic for a level.
this is alos a nice place to experiment with features, instead of having to write code that is sort of in my main engine
i can just write a separate script supporting somethign, and play aroudn with it,
so for exmaple:
- i can play with buoncy
- elastic behaviors
- platforms
- redoing little games about angry birds and pigs.
- planets with their own gravity field
its just a fun place to experiment with things and see where they will go.

i still have to figure out a bit if there will also be a sort of 'project' script, or if you can have multiple scripts running, currently its just one 'room' or level script so to say. i havent yet needed something more, but i can imagine needing that. we'll see.

So to summarize, now we have this nice scripted environments for my physisc bodies right? you can add joints and change proeprties and have custom scritps running and all that great stuff But..

but it all looks like green geometric shapes.
and offcourse i want like, textures. scanned in pencil drawings coming to life.

10:30

MISSING basic box2d uitleg

in the context of box2d there isnt a texture, there is just a body, and a body has 1 or more fixtures attached to it.
if i want to 'attach' a texture to a body i need to put the texture data in some special type of fixture.


MISSING OMP text
there are now actually a few types of texture fixtures:
- 1) TEX-FIXTURE the first type of texture fixture, meanst to 'fill' 1 body,
MISSING text about multiple vertices (4/8), all the jazz there is with OMP and patterns etc.
- 2) CONNECTED-TEXTURE , a way to share one texture over a couple of bodies, to make ropes and limbs and thta kind of flexible stuff.
     it will be connecting the one texture over multiple points and those ponts are like the connections between bodies. quite a story, ill show its easier.
-3 ) TRACE-VERTICES texture, sort of similar to the connected one but now within one body, its a texture spreading over a few vertices of the shape of a body. i added this for the hairs for characters, but it can be used for much more.
- 4_ TILE-TEXTURE  mostly for backdrop elements i think, quite self explanatory,

a few types of textures already, they arent't set in stone yet, probaby not enough for everything i want , i can see a few things maybe being added, but we'll see. its enough for now.

So now we are able to make a good looking thing, n my opinion, not justa green math shapey kind of thin, but a dirty looking drawing. i hope atleast.

MIPO CHRACTERS
So waht we mentioned at te beginning, this tool began as a way for building places where my  mipos can do stuff. so obviously i also need my characters to be in this editor. the editor is able to save and load, so i need to be able to save and load the characters too, their geometric basics are easy but there is some logics attached that only is there for these characters, so i need ways to save , and restore that too. And also, it was quite tempting to just build an importer for my characters but i decided against it, i really wanted all the separate types of graphics requirements to drive the editor forward, thats why i have that trace-vertices texture for example,or the connected-texture, and i feel its good decision, to let the editor features originnate from these characters, they are usefull imemeadiatly and you never know for what other tpyye of crazy stuff they end up being usefull, it offers nice new options. (show this)

for example weird little vegetation patches with vertices-tracing or maybe rope? or the other way around, i feel my tile texture would be nice to make clothing for my characters. !

so yeah, thats textures, as i said ther is still things to add, and i am not sure of all the things needed, you never know i might want to make some app about water adn water lfow and decide i need more watercolory things in there or whatever, its probably never done done.
But yeah teh puppetmaker tool, where we inda started our story , i'll probably end up rebuilding that whole tool as a level or custom script in this editor, so then for one we get a nice way of changing characters in a game, for two its good to be just using the same file format projects files for both tools, and also (3) to make the circle round again, get back at where we started, i can build a few nice little worlds for these characters to be in. so you as a player can change your character how you want and play in a few difernt worlds.

and then we arrre there right?
some parts that are in this editor too that i havent mentioned much:
* jelly cubes, or the technical term, softbodies. i see their potential, not too sure about it yet.
* recording interactions, also layering them, so i can record an animation in a few takes, a bit like how you can record and layer a song.
  the i can replay the interaction on a few setups, when you deploy an app in the appp store, you need a few resolutions, screen artios even, this i svery annoying for me because i couldnt record the same video twice on different screen resolutions. and i dont like the black bars or cutting parts from the screen to work around it, so yeah, thats how this recording interactions came to be


chatgpt :

🌀 REVISED STRUCTURE (EMPHASIZING THE FULL-CIRCLE ENDING)
1. Intro: “I made a thing...”
Quick hook. Maybe even make it funny:

Let me show you how one app turned into... this whole thing.

2. The Puppetmaker (Where It All Began)
Your hand-drawn physics characters

They’re lovely. But they don’t do much.

3. The First Expansion Attempt: The Infinite World
Mountains, bikes, LSD cows.

Too slow to iterate. Too painful. Got stuck.

4. Realization: “I Need an Editor”
So I needed a way to build stuff quickly. Just throw shapes around. Save and share.

Now we enter the tool-building arc:

5. Building the Editor: Box2D + Drawing
Geometric bodies

Joints

Hand-drawn shapes become physics

Because I like crooked stuff.

6. Adding Logic: Scripting Levels
Now that shapes are easy, let’s make them do things.

You describe scripting gameplay (gravity, bouncing, planets, pigs, etc.).

7. Visuals: Textures and OMP
This is your texture tech deep-dive. Now's a good time to insert the missing OMP explanation.

🎯 Reframe this section with clarity:

But the world still looked like green test shapes. I wanted it to look like my drawings.

You now explain:

Box2D doesn’t support textures directly

So you invented a few texture fixtures:

1. Tex-Fixture: Fills a single body with a texture

2. Connected-Texture: Spreads across linked bodies (good for ropes, arms, etc.)

3. Trace-Vertices: Textures that follow the shape outline within one body (used for hair)

4. Tile-Texture: Great for backdrops, tiles, patterns
🎉 5. Patches (new one!)

“Then there’s patches—these are little free-floating blobs of texture that can be layered on top of things. Like decals, or splats, or clothing bits, or weird noise to make things look grimy.”

“They’re not bound to the shape outline, they’re more like... stickers or graffiti you can drop in anywhere. Very flexible.”

👉 Now Add OMP here:

For each texture, I use a thing I call OMP: Outline, Mask, and Pattern.

Outline: a hand-drawn edge or stroke to sit over the shape

Mask: defines where the texture goes and where it’s cut off

Pattern: the actual fill—like scanned pencil shading or ink hatching

It’s kind of like dressing up your physics shapes in real clothes.

Then wrap up with:
“So with all these texture tools—OMP, fixture types, and patches—I can finally make something that doesn’t look like a tech demo. It looks like a messed-up little comic drawing. That’s the vibe.”
Now it starts to look like a real, dirty, hand-drawn world—not a math diagram.

8. Supporting Cast: Extra Features
Put softbodies and interaction recording here.

You can frame it as:

There are also some smaller experiments tucked into the tool...

Softbodies / jelly physics: Still figuring them out. Could be great. Could be weird.

Recording and layering interactions: Like recording animation in takes. Super useful for replaying scenes in different screen sizes and aspect ratios.

Keep it quick. These are like bonus tracks, not your finale.

9. Mipo Characters Return: Driving the Editor Forward
Remember those Mipo characters? They’re the reason for everything.

You now talk about:

Not importing them, but letting their needs shape the tool

Trace-vertices → for hair

Connected textures → for arms, ropes

Tile textures → maybe clothing

This reinforces that the tool is character-driven, not just engine-driven.

10. 🎉 Finale: The Full Circle
End here, clearly.

So now I have this editor.
And I’ll probably just rebuild the Puppetmaker inside it.
Same file format. Same logic. But now in a world where the characters can explore and interact.
And that… that was the point all along.

✨ Boom. Emotional, satisfying, complete.

🔁 Summary of Where Everything Goes
Feature	Section #	Notes
Puppetmaker intro	2	Starting point
Infinite world (bike ride)	3	First expansion attempt
Editor realization	4	Turning point
Box2D bodies, joints	5	Foundation
Hand-drawn shapes	5	Vibe +
Scripting levels	6	Adds game logic
Textures & OMP	7	Tech + visuals
Softbodies & Recording	8	Bonus tools
Mipo characters again	9	Motivation & tool evolution
Puppetmaker in the editor	10	Finalé, resolution
