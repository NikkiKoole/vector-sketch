#!/usr/bin/env python3
"""Patches LÖVE's Box2D World wrapper (native/ios/love/src/modules/physics/box2d/wrap_World.cpp) for
Playtime: World:playtimeContactShadows, the contact shadows' rays and ovals in C++ (src/contact-shadows.lua,
docs/MEASURING.md M12). Run by device.sh; applied once (it looks for its marker first). Only the iOS build
has it: the desktop's love115.app and the web build keep the Lua path (the Lua checks for the method).

  n = world:playtimeContactShadows(casters, groups, out, strength, reachWidths, maxCasterWidth, minDepth, minReach)

casters: an array of Bodies; groups: their own Mipo's collision group (0: none), a surface in that group
is skipped. For each caster the same as contact-shadows.lua's compute: its extent from its solid fixtures,
up to three rays straight down for the first up-facing, non-sensor surface of another body, and the oval.
out gets 7 values a shadow (receiver Body, x, y, hw, hh, alpha, angle); returns how many shadows.
"""
import sys

path = sys.argv[1]  # src/modules/physics/box2d/wrap_World.cpp
src = open(path).read()

MARKER = 'playtimeContactShadows'

INCLUDE_ANCHOR = '#include "wrap_World.h"\n'
INCLUDES = INCLUDE_ANCHOR + '''// Playtime (native/ios/patch-love-physics.py)
#include "wrap_Body.h"
#include <cmath>
'''

FUNC_ANCHOR = 'int w_World_destroy(lua_State *L)\n'
FUNC = '''// Playtime (native/ios/patch-love-physics.py): the contact shadows' rays in C++
namespace
{
struct PlaytimeShadowRay : public b2RayCastCallback
{
	b2Body *self = nullptr;
	int group = 0;
	float32 best = 2.0f;
	b2Fixture *hit = nullptr;
	b2Vec2 point, normal;

	float32 ReportFixture(b2Fixture *fixture, const b2Vec2 &p, const b2Vec2 &n, float32 fraction) override
	{
		if (fixture->IsSensor() || n.y > -0.3f) return -1.0f;
		if (fixture->GetBody() == self) return -1.0f;
		if (group != 0 && fixture->GetFilterData().groupIndex == group) return -1.0f;
		if (fraction < best) { best = fraction; hit = fixture; point = p; normal = n; }
		return fraction;
	}
};
}

int w_World_playtimeContactShadows(lua_State *L)
{
	World *t = luax_checkworld(L, 1);
	luaL_checktype(L, 2, LUA_TTABLE);
	luaL_checktype(L, 3, LUA_TTABLE);
	luaL_checktype(L, 4, LUA_TTABLE);
	float strength = (float) luaL_checknumber(L, 5);
	float reachWidths = (float) luaL_checknumber(L, 6);
	float maxWidth = (float) luaL_checknumber(L, 7);
	float minDepth = (float) luaL_checknumber(L, 8);
	float minReach = (float) luaL_checknumber(L, 9);
	int n = (int) lua_objlen(L, 2);
	int count = 0;
	static const float offsets[3] = { 0.0f, -0.35f, 0.35f };
	for (int i = 1; i <= n; i++)
	{
		lua_rawgeti(L, 2, i);
		Body *caster = luax_checkbody(L, -1);
		lua_pop(L, 1);
		b2Body *body = caster->body;
		if (body == nullptr) continue;
		b2World *world = body->GetWorld(); // (World's own is private)
		lua_rawgeti(L, 3, i);
		int group = (int) lua_tointeger(L, -1);
		lua_pop(L, 1);

		float x0 = INFINITY, x1 = -INFINITY, top = INFINITY, bottom = -INFINITY;
		for (b2Fixture *f = body->GetFixtureList(); f; f = f->GetNext())
		{
			if (f->IsSensor()) continue;
			b2AABB box = Physics::scaleUp(f->GetAABB(0));
			x0 = std::min(x0, box.lowerBound.x); x1 = std::max(x1, box.upperBound.x);
			top = std::min(top, box.lowerBound.y); bottom = std::max(bottom, box.upperBound.y);
		}
		if (x0 == INFINITY) continue;
		float width = x1 - x0;
		if (!(width > 0.0f && width < maxWidth)) continue;
		float reach = std::max(width * reachWidths, minReach);
		float cx = (x0 + x1) / 2.0f;
		float from = bottom - std::min((bottom - top) * 0.5f, 20.0f);

		PlaytimeShadowRay ray;
		ray.self = body;
		ray.group = group;
		float hitX = cx;
		for (int k = 0; k < 3; k++)
		{
			hitX = cx + offsets[k] * width;
			ray.best = 2.0f;
			ray.hit = nullptr;
			world->RayCast(&ray, Physics::scaleDown(b2Vec2(hitX, from)), Physics::scaleDown(b2Vec2(hitX, reach + bottom)));
			if (ray.hit) break;
		}
		if (!ray.hit) continue;
		float surfaceY = Physics::scaleUp(ray.point.y);
		float tt = std::min(1.0f, std::max(0.0f, (surfaceY - bottom) / reach));
		float alpha = strength * (1.0f - tt) * (1.0f - tt);
		if (alpha <= 0.005f) continue;
		float hw = width * 0.5f * (1.05f + tt * 0.6f);
		float hh = std::max(hw * 0.28f, minDepth);
		float angle = atan2f(ray.normal.x, -ray.normal.y);
		float y = surfaceY + (cx - hitX) * tanf(angle);
		Body *receiver = (Body *) t->findObject(ray.hit->GetBody());
		if (!receiver) continue;
		int at = count * 7;
		luax_pushtype(L, receiver); lua_rawseti(L, 4, at + 1);
		lua_pushnumber(L, cx);      lua_rawseti(L, 4, at + 2);
		lua_pushnumber(L, y);       lua_rawseti(L, 4, at + 3);
		lua_pushnumber(L, hw);      lua_rawseti(L, 4, at + 4);
		lua_pushnumber(L, hh);      lua_rawseti(L, 4, at + 5);
		lua_pushnumber(L, alpha);   lua_rawseti(L, 4, at + 6);
		lua_pushnumber(L, angle);   lua_rawseti(L, 4, at + 7);
		count++;
	}
	lua_pushinteger(L, count);
	return 1;
}

''' + FUNC_ANCHOR

REG_ANCHOR = '\t{ "rayCast", w_World_rayCast },\n'
REG = REG_ANCHOR + '\t{ "playtimeContactShadows", w_World_playtimeContactShadows },\n'

if MARKER in src:
    sys.exit(0)
for anchor in (INCLUDE_ANCHOR, FUNC_ANCHOR, REG_ANCHOR):
    if src.count(anchor) != 1:
        sys.exit('patch-love-physics.py: ' + path + ' changed, the contact shadows patch no longer fits')
src = src.replace(INCLUDE_ANCHOR, INCLUDES, 1).replace(FUNC_ANCHOR, FUNC, 1).replace(REG_ANCHOR, REG, 1)
open(path, 'w').write(src)
print('▸ patched LÖVE: ' + MARKER)
