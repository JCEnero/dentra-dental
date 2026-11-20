// Node harness for the compiled production Dart/JS interop implementation.
globalThis.self = globalThis;
globalThis.dentraPermission = 'granted';
globalThis.dentraAgent = 'Mozilla/5.0 Chrome/146.0.0.0';
globalThis.dentraQueryThrows = false;
Object.defineProperty(globalThis, 'navigator', { configurable: true, value: {
  get userAgent() { return globalThis.dentraAgent; },
  permissions: { async query({ name }) {
    if (name !== 'local-network') throw Error('Unexpected permission query');
    if (globalThis.dentraQueryThrows) throw TypeError('Unknown permission');
    return { state: globalThis.dentraPermission };
  } },
} });
globalThis.fetch = async (url, options) => {
  globalThis.dentraRecordedRequest = { url, options };
  return { status: 200, text: async () => '{"ok":true}' };
};
