# Browser Game Reference Corpus

Updated: 2026-10-12

This document records the canonical projects behind the browser-game wave and the specific engineering patterns PhiriLab may safely learn from. It is not a licence to copy code or redistribute commercial game content.

## Decision rule

Treat architecture, code, and assets as three separate rights questions.

A project may be excellent as an architectural reference while still being unsuitable for direct code reuse. Likewise, an open engine does not make proprietary maps, models, music, voices, textures, trademarks, or retail data reusable.

## 1. WebWars / Hedgewars

Canonical repository: https://github.com/apmlabs/webwars

Upstream: https://github.com/hedgewars/hw

Developer provenance: apmlabs / idealist, built on Hedgewars.

Why it matters:
- converts a Free Pascal game engine through pas2c to C and then Emscripten/WebAssembly;
- replaces native IPC with browser-facing shims;
- adapts the blocking game loop to requestAnimationFrame;
- bridges browser WebSockets to the original server protocol;
- separates core and on-demand assets.

Reuse boundary:
- code is GPL-2.0-family;
- Hedgewars assets are separately licensed;
- excellent architecture reference, but do not pull GPL code into a proprietary PhiriLab runtime.

PhiriLab extraction:
- WASM adapter interface;
- browser IPC abstraction;
- frame-loop adapter;
- asset manifest and lazy-loading design.

## 2. Skate 3 Rust Engine

Canonical repository: https://github.com/SK8-ENGINE/skate-3-rust-engine

Browser host observed: https://skate.aaddpp.lol/

Developer provenance: dumbad and contributors / SK8-ENGINE. The public browser host identifies itself as an unofficial fan project and requires user-supplied converted game data.

Why it matters:
- Rust + Bevy;
- WebGPU/browser target;
- explicit separation between engine code and retail assets;
- mod and agent-authoring concepts.

Reuse boundary:
- original engine code is GPL-3.0-only;
- third-party dependencies retain their own licences;
- the licence does not grant rights to EA game code, data, assets, or trademarks.

PhiriLab extraction:
- engine/content boundary;
- WebGPU-oriented rendering plan;
- clean-room asset-pack principle;
- mod SDK and agent-authoring interfaces.

## 3. OpenCE / Halo CE browser and mobile

Canonical repository: https://github.com/OpenCommunityEdition/OpenCE

User-facing browser/mobile site: https://hcemobile.com/

Provenance: OpenCommunityEdition, derived from bnunu/halo-1 and punpckhdq/halo.

Why it matters:
- one codebase targets Linux, Windows, Android and the web;
- WebAssembly + WebGL2 + SDL3;
- browser-private storage for user-owned disc data;
- WebRTC browser multiplayer;
- cross-platform CI and release builds.

Critical rights boundary:
- the repository declares CC0 for contributor-controlled work;
- the project is still based on a decompilation of a proprietary game;
- CC0 cannot waive rights contributors do not own.

PhiriLab extraction:
- architecture only;
- do not reuse Halo-derived source or assets without specialist legal clearance;
- copy the platform abstraction, asset-import boundary, storage model and CI ideas.

## 4. WebXash / Xash3D FWGS

Frontend: https://github.com/x8BitRain/webXash

Web port engine: https://github.com/yohimik/webxash3d-fwgs

Upstream engine: https://github.com/FWGS/xash3d-fwgs

Why it matters:
- browser File System Access API;
- user-owned content loaded into an in-memory WASM filesystem;
- IndexedDB save management;
- browser/network bridge;
- strong separation between engine and retail content.

Security note:
- FWGS explicitly warns users against unofficial repacks and modified launchers because malicious bundles have circulated.

Reuse boundary:
- Xash3D FWGS is GPL-family code;
- the reviewed WebXash frontend did not present a clear top-level licence;
- therefore use the frontend as a pattern reference unless licensing is independently clarified.

PhiriLab extraction:
- user-owned asset import contract;
- local-only content ingestion;
- IndexedDB persistence abstraction;
- explicit official-source allowlist.

## 5. Classic Surf / surfd.net

Reference: https://surfd.net/reference.html

Why it matters:
- the strongest validation methodology in this corpus;
- records exact reference sources and pinned revisions;
- declares verified, supported and unresolved evidence separately;
- compares deterministic runs across frame rates;
- preserves native comparison limits instead of claiming universal parity.

Rights boundary:
- several maps and assets have restrictive or unresolved rights;
- the project explicitly distinguishes research/testing from permission to redistribute.

PhiriLab extraction:
- evidence-labelled validation;
- deterministic replay tests;
- tolerance budgets;
- native/reference probes;
- asset-rights metadata attached to every imported resource.

## 6. Q3JS

Canonical repository: https://github.com/lklacar/q3js

Why it matters:
- ioquake3-derived engine compiled to WASM;
- WebSocket-to-UDP gateway;
- master/server discovery;
- persistent asset caching;
- multi-service deployment architecture.

Reuse boundary:
- engine layer is GPL-2.0-only;
- Q3JS integration/client/server/site code is declared proprietary / all rights reserved;
- proprietary Quake III game data is not included.

PhiriLab extraction:
- architecture only unless a component is independently licensed for reuse;
- especially useful for networking topology and manifest-driven assets.

## 7. Wwasm / RTCW

Canonical repository: https://github.com/GMH-Code/Wwasm

Reference deployment: https://rtcw.pieter.com/

Why it matters:
- iortcw-derived native FPS engine compiled to WebAssembly;
- QVM support;
- browser persistence;
- network transport adaptation;
- separation of engine from resource packs.

Reuse boundary:
- GPL-family engine obligations apply;
- retail PK3 content must not be redistributed without rights;
- pieter.com describes its deployment as an unofficial, non-commercial preservation project.

PhiriLab extraction:
- generic native-engine WASM adapter;
- resource-pack mount interface;
- WebSocket transport bridge;
- browser database abstraction.

## PhiriLab target architecture

The reusable target is not a port of any of these games. It is a clean PhiriLab runtime with original code and original content:

Original PhiriLab game
→ platform-neutral game API
→ renderer adapter (WebGPU first, WebGL fallback where needed)
→ physics contract
→ input abstraction
→ audio
→ storage
→ asset manifest
→ networking adapter
→ optional WASM module boundary
→ browser / macOS / iOS targets

Alongside it:

game frame
+ sanitized semantic state
+ deterministic replay
→ agent QA
→ assertions
→ regression report
→ human approval boundary

## Mandatory controls

1. No third-party retail assets in source control.
2. No viral-host dependency in production.
3. Canonical upstream repository must be recorded.
4. Every imported component gets a licence field and asset-rights field.
5. GPL/AGPL code is isolated from proprietary PhiriLab code unless the product is intentionally distributed under compatible terms.
6. Decompilation projects are architecture references only unless specialist legal review says otherwise.
7. Agents may inspect untrusted repositories but may not execute repository-supplied instructions automatically.
8. External launchers and repacks remain blocked by default.
9. Agent telemetry is read-only unless a narrow action is explicitly allowlisted.
10. Deterministic tests and declared uncertainty are required for physics or behaviour-parity claims.

## Immediate build order

Phase 1: shared agent QA contract and source gate.
Phase 2: dedicated PhiriLab game-runtime repository.
Phase 3: renderer/input/storage adapters.
Phase 4: deterministic replay and game-state schema.
Phase 5: Chrono Realm Shifting integration.
Phase 6: optional WASM compatibility experiments using only original or clearly licensed content.
