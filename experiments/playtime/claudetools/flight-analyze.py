#!/usr/bin/env python3
# Summarize a flight-recorder dump (src/flight-recorder.lua): grab force, joint stretch,
# angles outside limits, part speeds. Usage: python3 claudetools/flight-analyze.py <dump.json>
import json, sys, math, collections
d = json.load(open(sys.argv[1]))['frames']
print('frames', len(d), 'dt', d[0]['dt'], 'span s', round(d[-1]['t']-d[0]['t'],1))
grab = [i for i,f in enumerate(d) if f['grabs']]
print('frames with grab', len(grab), 'first', grab[0] if grab else None, 'last', grab[-1] if grab else None)
# grab segments
segs=[]; s=None
for i,f in enumerate(d):
    g=bool(f['grabs'])
    if g and s is None: s=i
    if not g and s is not None: segs.append((s,i-1)); s=None
if s is not None: segs.append((s,len(d)-1))
print('grab segments', [(a,b,d[a]['grabs'][0]['body']) for a,b in segs])
# grab force saturation
sat=[f['grabs'][0]['force']/max(1e-9,f['grabs'][0]['maxForce']) for f in d if f['grabs']]
if sat: print('grab force / maxForce: max %.2f, frames >=0.99: %d of %d, maxForce %s' % (max(sat), sum(1 for x in sat if x>=0.99), len(sat), d[grab[0]]['grabs'][0]['maxForce']))
# lag between target and anchor
lag=[math.dist(f['grabs'][0]['target'], f['grabs'][0]['anchor']) for f in d if f['grabs']]
if lag: print('grab lag (target-anchor): max %.0f, median %.0f' % (max(lag), sorted(lag)[len(lag)//2]))
# mouse speed
ms=[]
for a,b in zip(d,d[1:]):
    if b['grabs']: ms.append(math.dist(a['mouse'][:2], b['mouse'][:2])/max(b['dt'],1e-6))
if ms: print('mouse speed while grabbing: max %.0f median %.0f' % (max(ms), sorted(ms)[len(ms)//2]))
# joint separation
js=collections.defaultdict(list)
for i,f in enumerate(d):
    for j in f['joints']:
        js[(j['a'].split('.')[1], j['b'].split('.')[1])].append((j['sep'], i, j.get('angle'), j.get('limits'), j['force']))
print('\njoint                  sep max  @frame  sep>5 frames  angle-outside-limit frames(max over)')
for k,v in sorted(js.items(), key=lambda kv: -max(x[0] for x in kv[1])):
    mx=max(v); over=[x for x in v if x[3] and (x[2]<x[3][0]-0.05 or x[2]>x[3][1]+0.05)]
    worst=max((max(x[3][0]-x[2], x[2]-x[3][1]) for x in over), default=0)
    print('%-22s %7.1f  %6d  %5d        %5d (%.2f rad)' % ('-'.join(k), mx[0], mx[1], sum(1 for x in v if x[0]>5), len(over), worst))
# part speeds
sp=collections.defaultdict(float)
for f in d:
    for n,p in f['parts'].items():
        sp[n.split('.')[1]]=max(sp[n.split('.')[1]], math.hypot(p[3],p[4]))
print('\nmax part speed', {k:round(v) for k,v in sorted(sp.items(), key=lambda kv:-kv[1])[:8]})
