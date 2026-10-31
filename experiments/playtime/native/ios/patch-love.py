#!/usr/bin/env python3
"""Patches the LÖVE iOS source in native/ios/love (appelflap) for Playtime. Run by device.sh;
each patch is applied once (it looks for its own marker first).

LoveIgnoreSilentSwitch: an Info.plist key, read when LÖVE sets up its audio session. Set, the
game plays through the silent switch, in the 'playback' category (like YouTube) and still mixed
with other apps. Unset, LÖVE does what it always did ('ambient'/'solo ambient': the switch mutes
the game). device.sh sets it for dev builds; whether the shipped app should is a separate
decision, made by setting the key or not.
"""
import sys

path = sys.argv[1]  # src/common/ios.mm
src = open(path).read()

MARKER = 'LoveIgnoreSilentSwitch'
ANCHOR = '''		if (mixEnabled)
			category = AVAudioSessionCategoryAmbient;
'''
PATCH = ANCHOR + '''
		// Playtime (native/ios/patch-love.py): play through the silent switch when the
		// app's Info.plist says so
		if ([[[NSBundle mainBundle] objectForInfoDictionaryKey:@"LoveIgnoreSilentSwitch"] boolValue])
		{
			AVAudioSessionCategoryOptions options = mixEnabled ? AVAudioSessionCategoryOptionMixWithOthers : 0;
			bool ok = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:options error:&err];
			if (!ok)
				NSLog(@"Error in AVAudioSession setCategory: %@", [err localizedDescription]);
			return ok;
		}
'''

if MARKER in src:
    sys.exit(0)
if ANCHOR not in src:
    sys.exit('patch-love.py: ' + path + ' changed, the audio session patch no longer fits')
open(path, 'w').write(src.replace(ANCHOR, PATCH, 1))
print('▸ patched LÖVE: ' + MARKER)
