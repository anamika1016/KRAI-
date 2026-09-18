const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync('app/javascript/layout.js', 'utf8');

function setup(payloadIds, hiddenIds = []) {
  const context = vm.createContext({
    shell: { querySelectorAll: () => hiddenIds.map(value => ({ value })) },
    editTarget: { id: 242, main_activity_names: ["Farmers' Training"], afl_ids: payloadIds },
    weeklyPlanFarmerIds: {},
    weeklyPlanFarmerIdsDirty: new Set(),
    normalizeOption: value => String(value || '').trim().toLowerCase()
  });
  const savedIds = source.slice(source.indexOf('    const savedEditFarmerIds ='), source.indexOf('    let editTarget ='));
  const selections = source.slice(source.indexOf('    const weeklyRowKey ='), source.indexOf('    const weeklyPlanValue ='));
  vm.runInContext(savedIds + selections + `
    globalThis.restore = () => restoreEditFarmerSelections([{ mainActivity: '__common__' }]);
    globalThis.ids = () => Array.from(farmerIdsForRow('__common__'));
    globalThis.total = totalActivityFarmerSelections;
    globalThis.deselect = (id) => {
      farmerIdsForRow('__common__').delete(id);
      weeklyPlanFarmerIdsDirty.add('__common__');
    };
  `, context);
  return context;
}

test('edit restores saved farmers into the common plan row and total', () => {
  const page = setup(['101', '102'], ['101', '102']);
  page.restore();
  assert.deepEqual(Array.from(page.ids()), ['101', '102']);
  assert.equal(page.total(), 2);
});

test('JSON fallback keeps individual farmer IDs instead of one comma-separated ID', () => {
  const page = setup(['101', '102']);
  page.restore();
  assert.deepEqual(Array.from(page.ids()), ['101', '102']);
  assert.equal(page.total(), 2);
});

test('grouped payload includes farmers missing from the primary record', () => {
  const page = setup(['101', '102'], ['101']);
  page.restore();
  assert.deepEqual(Array.from(page.ids()), ['101', '102']);
});

test('re-rendering preserves a farmer deselection while editing', () => {
  const page = setup(['101', '102']);
  page.restore();
  page.deselect('101');
  page.restore();
  assert.deepEqual(Array.from(page.ids()), ['102']);
  assert.equal(page.total(), 1);
});
