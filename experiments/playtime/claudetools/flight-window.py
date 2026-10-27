#!/usr/bin/env python3
# Frame-by-frame table of a flight-recorder dump around a moment.
# Usage: python3 claudetools/flight-window.py <dump.json> <fromFrame> <toFrame>
import json, sys, math
d = json.load(open(sys.argv[1]))['frames']
a, b = int(sys.argv[2]), int(sys.argv[3])
def joint(f, x, y):
    for j in f['joints']:
        if j['a'].endswith('.'+x) and j['b'].endswith('.'+y): return j
print('frame  mouseSpd torsoSpd luarmSpd  grabF/max  sep(torso-luarm) sep(luarm-llarm) angle(torso-luarm) limits')
for i in range(a, b):
    f, p = d[i], d[i-1]
    ms = math.dist(p['mouse'][:2], f['mouse'][:2]) / f['dt']
    t = [v for k, v in f['parts'].items() if k.endswith('.torso1')][0]
    u = [v for k, v in f['parts'].items() if k.endswith('.luarm')][0]
    g = f['grabs'][0] if f['grabs'] else None
    j1, j2 = joint(f, 'torso1', 'luarm'), joint(f, 'luarm', 'llarm')
    print('%5d %8.0f %8.0f %8.0f   %5s     %8.1f %16.1f %12.2f      %s' % (i, ms, math.hypot(t[3], t[4]), math.hypot(u[3], u[4]),
          '%.2f' % (g['force']/g['maxForce']) if g else '-', j1['sep'], j2['sep'], j1['angle'], j1.get('limits')))
