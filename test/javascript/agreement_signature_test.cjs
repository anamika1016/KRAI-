const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync('app/javascript/layout.js', 'utf8');

test('agreement login page initializes signature controls', () => {
  let initialized = 0;
  const code = source.slice(source.indexOf('const bootLayoutPage ='), source.indexOf('const queueBootLayoutPage ='));
  vm.runInNewContext(code + '\nbootLayoutPage();', {
    document: { querySelector: () => ({}) },
    initPasswordToggles() {},
    initDeferredLayoutPage() { initialized++; }
  });
  assert.equal(initialized, 1);
});

test('drawing enables acceptance, resize preserves signature, clear disables acceptance', () => {
  const handlers = {};
  const pen = { clearRect() {}, drawImage() {}, beginPath() {}, moveTo() {}, lineTo() {}, stroke() {} };
  let width = 300;
  const canvas = {
    width: 300, height: 150, style: {}, getContext: () => pen,
    getBoundingClientRect: () => ({ width, height: 150, left: 0, top: 0 }),
    setPointerCapture() {}, toDataURL: () => 'data:image/png;base64,signed',
    addEventListener: (name, fn) => { handlers[name] = fn; }
  };
  const input = { value: '' };
  const accept = { disabled: true };
  const clear = { addEventListener: (_, fn) => { handlers.clear = fn; } };
  const form = { addEventListener() {} };
  const shell = { dataset: {}, querySelector: selector => selector.includes('pad') ? canvas : clear };
  const start = source.indexOf('    document.querySelectorAll("[data-agreement-signature-shell]").forEach');
  const end = source.indexOf('    setLanguage(localStorage', start);
  vm.runInNewContext(source.slice(start, end), {
    document: {
      querySelectorAll: () => [shell],
      querySelector: selector => selector.includes('-input') ? input : selector.includes('-accept') ? accept : form,
      createElement: () => ({ getContext: () => pen })
    },
    window: { addEventListener: (_, fn) => { handlers.resize = fn; } }
  });
  handlers.pointerdown({ preventDefault() {}, pointerId: 1, clientX: 10, clientY: 10 });
  handlers.pointermove({ preventDefault() {}, clientX: 20, clientY: 20 });
  handlers.pointerup();
  assert.equal(accept.disabled, false);
  const signature = input.value;
  width = 400;
  handlers.resize();
  assert.equal(input.value, signature);
  assert.equal(accept.disabled, false);
  handlers.clear();
  assert.equal(input.value, '');
  assert.equal(accept.disabled, true);
});
