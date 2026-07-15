# FS25 "AI Traffic No Collision" — periodic stutter fix

A tested performance fix for the [AI Traffic No Collision](https://www.farming-simulator.com/mod.php?mod_id=352720)
mod (v1.0.0.0, by Huxinator) for Farming Simulator 25, offered to the author for adoption —
published here as a **patch you apply to your own downloaded copy**. This repository distributes
**no mod files**.

## The problem

The mod causes a metronomic ~24 ms main-thread stall every **1.009 seconds** (its 1000 ms scan
timer plus the discarded frame remainder). Measured with CapFrameX: **597 stutter events in a
10-minute capture**. Users report the same on ModHub ("fps drops every ~2 seconds") and in the
mod's [GIANTS forum thread](https://forum.giants-software.com/viewtopic.php?t=218044). Because
the stall is CPU-side, no graphics setting, DLSS, or frame generation helps.

**Root cause** — every second the mod re-derives the traffic set from scratch:

1. `overlapSphere` with `CollisionMask.ALL` at 90 m around up to 3 positions returns *every
   shape nearby* (often thousands); every hit costs a C++→Lua callback invocation even when
   rejected.
2. Rejected static geometry (fences, buildings, rocks) is re-classified from scratch every
   scan, forever — nothing is remembered between scans.
3. All scan positions are processed inside a single frame.

## The fix

Four changes, **detection semantics unchanged** (same classification logic, same collision
masks, same settings UI):

- query the overlap with the mod's own vehicle/traffic collision flags, so the engine returns
  dozens of hits instead of thousands (`CollisionMask.ALL` kept as fallback)
- persistent "not traffic" verdict cache (reset every 2 min to tolerate engine node-id reuse)
- per-hit classification deferred to a 24-hits-per-frame budget
- one scan position per fire (round-robin), memoized per-vehicle classification, throttled
  bookkeeping

## Measured results

10-minute CapFrameX captures, same savegame and scenario (Riverbend Springs, AI helpers active):

| build | metronomic stutter events | spike cost | p99 frametime |
| --- | --- | --- | --- |
| v1.0.0.0 original | 597 | ~26 ms | 41–53 ms |
| + cache / deferral / round-robin | 188 | ~13 ms | 29 ms |
| + targeted overlap mask | **10 (aperiodic)** | — | **27 ms** |

Functionality verified in-game after each step: AI traffic still doesn't collide with player or
AI vehicles.

## Applying the patch

Requires the mod already installed from the official ModHub (v1.0.0.0).

```powershell
git clone https://github.com/talontownsend/fs25-ai-traffic-no-collision-fix
cd fs25-ai-traffic-no-collision-fix
.\tools\Apply-Patch.ps1
```

The script backs up your zip (`*.pre-patch.bak`), verifies every hunk matches the expected mod
version (any mismatch aborts without changes), edits the script inside your copy, and rebuilds
the zip in place. Decline ModHub update prompts afterwards, or the patch is overwritten — which
is also how you adopt an official fix later: just accept the update.

Patched zips hash differently than ModHub's: fine in singleplayer; multiplayer requires all
players and the server to use the same zip.

## Rights & takedown

The mod remains the property of its author, Huxinator. The patch contains the minimal code
fragments needed to describe and apply the fix — standard bug-report practice — and nothing
here enables using the mod without downloading it from the official ModHub yourself. **If you
are the author and want anything changed or removed, open an issue and it will be done
promptly.** The goal of this repository is to get the fix into your official release, nothing
more.

The apply script and documentation are MIT-licensed (see LICENSE); the patch files include
fragments of the author's code, which remain under their rights.
