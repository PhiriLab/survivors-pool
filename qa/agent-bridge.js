/*
 * PhiriLab Agent QA Bridge v1
 *
 * Security model:
 * - no network calls
 * - no storage access
 * - no eval / dynamic code loading
 * - read-only by default
 * - host must explicitly register telemetry and allowlisted UI-only actions
 */
(function (global) {
  "use strict";

  const VERSION = "1.0.0";
  let adapter = null;

  function clone(value) {
    return value == null ? value : JSON.parse(JSON.stringify(value));
  }

  function assertAdapter(candidate) {
    if (!candidate || typeof candidate.getState !== "function") {
      throw new Error("PhiriLab QA adapter requires getState()");
    }
  }

  const api = Object.freeze({
    version: VERSION,

    register(candidate) {
      assertAdapter(candidate);
      adapter = {
        gameId: String(candidate.gameId || "unknown"),
        getState: candidate.getState,
        actions: Object.freeze({ ...(candidate.actions || {}) })
      };
      return { ok: true, gameId: adapter.gameId, version: VERSION };
    },

    snapshot() {
      if (!adapter) return { ok: false, error: "adapter-not-registered", version: VERSION };
      try {
        return {
          ok: true,
          version: VERSION,
          gameId: adapter.gameId,
          capturedAt: new Date().toISOString(),
          state: clone(adapter.getState())
        };
      } catch (error) {
        return { ok: false, error: "snapshot-failed", detail: String(error && error.message || error) };
      }
    },

    act(name, payload) {
      if (!adapter) return { ok: false, error: "adapter-not-registered" };
      const fn = adapter.actions[String(name || "")];
      if (typeof fn !== "function") return { ok: false, error: "action-not-allowlisted" };
      try {
        return clone(fn(clone(payload)));
      } catch (error) {
        return { ok: false, error: "action-failed", detail: String(error && error.message || error) };
      }
    },

    capabilities() {
      return {
        version: VERSION,
        gameId: adapter ? adapter.gameId : null,
        telemetry: !!adapter,
        actions: adapter ? Object.keys(adapter.actions) : []
      };
    }
  });

  Object.defineProperty(global, "__PHIRILAB_QA__", {
    value: api,
    configurable: false,
    enumerable: false,
    writable: false
  });
})(window);
