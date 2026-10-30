
playtime
========

I wanted a way to play around in box2d, writing the code by hand is no fun.

There are shapes, there are joints and special fixtures to pinpoint on shapes.
Then we have scripts to make stuff interactive.

upcoming
========
Also groups will be coming.
And behaviors which can be applied to groups or single parts..

running it
==========
On the desktop (LÖVE 11.5):

    ./playtime.sh start              # the editor
    ./playtime.sh play dollhouse     # straight into play mode; tab toggles the editor

In the browser:

    ./webtest/build-web.sh dollhouse     # about a minute, makes webtest/output-dollhouse/
    ./webtest/serve.sh 8080 dollhouse    # then open http://localhost:8080 and click once for sound

The web build needs love.js (`npm i -g love.js`); for the synth also emscripten
(`brew install emscripten`) and dreamengine checked out at ~/Projects/dreamengine.
Without those (or without native/desound/build.sh run on the desktop) there's no synth
music, and the Mipos use their sound samples instead. More in docs/WEB-EXPORT-LOVEJS.md.
