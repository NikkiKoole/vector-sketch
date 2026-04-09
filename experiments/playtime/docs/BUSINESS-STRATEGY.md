# Business Strategy — Interactive Children's Books

## The pitch

"I'm an artist and developer who turns children's books into interactive physics experiences. I built my own tools to do it."

## Identity

- Father of 2, artist-developer
- Hand-drawn aesthetic is the brand, not a limitation
- Builds own tools (Playtime editor) — faster turnaround than anyone building from scratch
- Shipped Mipo Puppetmaker (own IP) — that's what landed the Knut deal

## The business model

Use Playtime to rapidly prototype physics-based interactive content for other people's IPs.

**Target clients:**
- Children's book publishers
- Educational game studios
- Advertising agencies wanting interactive demos

**Competitive edge:** Turnaround time. The Playtime editor lets you build a physics scene with hand-drawn art in hours, not weeks. Nobody else has a tool that combines texture-deformed characters with a live physics editor.

## Two tracks

### Track 1: Knut (client work — near term)
- External commission to make a game based on existing children's book IP
- Serves as: revenue + portfolio piece + demo reel for pitching other publishers
- Deliverable: 5-10 small interactive scenes, playable in browser (love.js)

### Track 2: Mipo (own IP — long term)
- Full creative control, own characters
- Visual reference: Childcraft encyclopedias (1970s hand-illustrated style)
- Puppetmaker app already shipped — foundation exists
- Long game: build the universe these characters live in

**Every hour on Knut pays off 4x:** it's a product, a portfolio piece, a demo reel, and a YouTube video.

## Distribution strategy

### Getting noticed (without being a social media person)

1. **Short video clips (15-30 sec)** — hand-drawn art flopping on physics = algorithm catnip. Post on Twitter/X, Instagram, TikTok. No talking needed, just show.

2. **YouTube video** — "I turn children's books into interactive toys." Scripts already drafted (see `docs/youtube-video-no2.md`, `docs/youtube2-again.md`). The "puppet needs a stage" narrative arc.

3. **Direct outreach** — send 10 publishers an email with a browser link (love.js). They click, they see it, done. No pitch deck, no meeting. Shy-friendly.

4. **Warm referrals** — if Knut publisher is happy, ask them to refer you. One warm intro beats 100 cold emails.

**Key insight:** You only need 2-3 clients to be independent. Not trying to go viral — just need a handful of publishers with books and budget.

### Web export as the secret weapon

A shareable URL removes all friction:
- Publisher clicks link → sees their book come alive → wants to talk
- Parents/teachers find it → no app install needed
- Embed on publisher's website as a demo

love.js web export is working (see `docs/WEB-EXPORT-LOVEJS.md`).

## The unfair advantage

Hand-made in an era of AI slop. Scanned children's book art, deformed over physics skeletons, in little interactive scenes. That has soul. The jankiness of hand-drawn art flopping around on ragdoll physics is charming in a way that polished 3D never will be.

Don't compete on polish. Compete on character.

## Priority order

1. Finish deform integration (scanned art on physics skeletons inside Playtime)
2. Build 3 Knut scenes (best ideas from notebook)
3. Add scene selector (dead simple menu)
4. Package for web (love.js — already proven)
5. Show to Knut publisher — this is the leverage for a real deal
6. Then: more scenes, mobile ports, pitch other publishers

Tool improvements should serve shipping scenes, not be abstract infrastructure.
