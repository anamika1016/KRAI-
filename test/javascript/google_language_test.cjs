const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync('app/javascript/layout.js', 'utf8');
const code = source.slice(source.indexOf('    const googleLanguageCodes ='), source.indexOf('    const preserveSpacing ='));

function setup() {
  const timers = [];
  const scripts = [];
  const holder = { dataset: {} };
  let combo;
  let initialized = 0;
  const window = { location: { hostname: 'localhost' } };
  const document = {
    cookie: '',
    getElementById: () => holder,
    querySelector: () => combo,
    createElement: () => ({ remove() {} }),
    head: { appendChild(script) { scripts.push(script); } }
  };
  const context = vm.createContext({ window, document, Event, setTimeout: (fn) => timers.push(fn) });
  vm.runInContext(code + '\nglobalThis.apply = applyGoogleLanguage;', context);
  return {
    context, window, timers, scripts, holder,
    ready() {
      window.google = { translate: { TranslateElement: function () { initialized++; } } };
      window.googleTranslateElementInit();
    },
    combo() {
      const changes = [];
      combo = { options: ['en', 'hi', 'mr', 'or', 'gu'].map(value => ({ value })),
        dispatchEvent() { changes.push(this.value); } };
      return changes;
    },
    initialized: () => initialized,
    flush() { timers.splice(0).forEach(fn => fn()); }
  };
}

test('first click waits for asynchronously inserted Google options', async () => {
  const s = setup();
  s.context.apply('gu');
  s.ready();
  await Promise.resolve();
  const changes = s.combo();
  s.flush();
  assert.deepEqual(changes, ['gu']);
});

test('latest click wins, including switching back to English while loading', async () => {
  const s = setup();
  s.context.apply('hi');
  s.context.apply('mr');
  s.context.apply('en');
  s.ready();
  const changes = s.combo();
  await Promise.resolve();
  s.flush();
  assert.deepEqual(changes, ['en']);
  assert.equal(s.scripts.length, 1);
});

test('widget is recreated for a replaced Turbo page holder', async () => {
  const s = setup();
  s.context.apply('hi');
  s.ready();
  s.combo();
  await Promise.resolve();
  delete s.holder.dataset.googleInitialized;
  s.context.apply('mr');
  await Promise.resolve();
  assert.equal(s.initialized(), 2);
});

test('failed script can be retried and missing widget polling is bounded', async () => {
  const s = setup();
  s.context.apply('hi');
  s.scripts[0].onerror();
  await Promise.resolve();
  s.context.apply('mr');
  assert.equal(s.scripts.length, 2);
  s.ready();
  await Promise.resolve();
  for (let i = 0; i < 102; i++) s.flush();
  assert.equal(s.timers.length, 0);
});
