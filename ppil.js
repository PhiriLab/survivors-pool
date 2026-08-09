(function (global) {
  'use strict';

  const forbidden = ['name', 'email', 'phone', 'auth', 'token', 'supabase', 'user_id', 'userid', 'text', 'content'];

  class PPIL {
    constructor(options) {
      options = options || {};
      this.backend = options.backend || { capture: function () {} };
      this.consent = Boolean(options.consent);
    }

    setConsent(granted) { this.consent = Boolean(granted); }

    capture(name, properties) {
      properties = properties || {};
      if (!this.consent || !PPIL.isValid(name, properties)) return false;
      this.backend.capture({ name: name, properties: properties });
      return true;
    }

    static isValid(name, properties) {
      if (typeof name !== 'string' || !name.length || name.length > 80) return false;
      return Object.keys(properties).every(function (key) {
        const lower = key.toLowerCase();
        return !forbidden.some(function (term) { return lower.indexOf(term) !== -1; });
      });
    }
  }

  global.PPIL = PPIL;
})(typeof window !== 'undefined' ? window : globalThis);
