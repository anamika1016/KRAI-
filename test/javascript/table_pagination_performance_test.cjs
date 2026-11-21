const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync('app/javascript/layout.js', 'utf8');
const pagination = source.slice(source.indexOf('  const paginateTable ='), source.indexOf('  const closeColumnFilters ='));

function setup(count, search = '', filters = {}) {
  let writes = 0;
  const rows = Array.from({ length: count }, (_, index) => {
    let hidden = false;
    return {
      dataset: {}, textContent: `Farmer ${index}`, children: [{ textContent: `Farmer ${index}` }],
      get hidden() { return hidden; },
      set hidden(value) { hidden = value; writes++; }
    };
  });
  const table = { id: 'farmers', dataset: { pageSize: '15', columnFilters: JSON.stringify(filters) }, querySelectorAll: () => rows };
  const context = vm.createContext({ document: { querySelector: selector => selector.startsWith('[data-table-search=') ? { value: search } : null } });
  vm.runInContext(pagination + '\nglobalThis.paginate = paginateTable;', context);
  return { rows, table, paginate: page => context.paginate(table, page), writes: () => writes };
}

test('large tables change only rows entering or leaving a page', () => {
  const page = setup(2000);
  page.paginate(1);
  assert.equal(page.rows.filter(row => !row.hidden).length, 15);
  const initial = page.writes();
  page.paginate(2);
  assert.equal(page.writes() - initial, 30);
  assert.equal(page.rows[15].hidden, false);
  assert.equal(page.rows[0].hidden, true);
  const unchanged = page.writes();
  page.paginate(2);
  assert.equal(page.writes(), unchanged);
});

test('search and column filters retain matching rows and page bounds', () => {
  const page = setup(100, 'FARMER 2', { 0: { operator: 'ends', value: '2' } });
  page.paginate(99);
  assert.deepEqual(page.rows.filter(row => !row.hidden).map(row => row.textContent), ['Farmer 2', 'Farmer 22']);
});

test('empty-row detection batches rendered-text reads before attribute writes', () => {
  let writes = 0;
  const rows = ['Farmer One', 'No records saved yet.', 'Farmer Two'].map((label, index) => ({
    children: index === 1 ? [{}] : [{}, {}],
    get innerText() {
      assert.equal(writes, 0, 'rendered text must be read before attributes are written');
      return label;
    },
    dataset: new Proxy({}, { set(target, key, value) { writes++; target[key] = value; return true; } })
  }));
  const start = source.indexOf('    const emptyRows = rows.filter((row) => {');
  const end = source.indexOf('    const largeTable =', start);
  const context = vm.createContext({ rows, table: { id: 'module_saved_records' } });
  vm.runInContext(source.slice(start, end), context);
  assert.equal(writes, 1);
  assert.equal(rows[1].dataset.emptyRow, 'true');
  assert.equal(rows[0].dataset.emptyRow, undefined);
});

test('rows initially hidden by the server remain searchable and appear on later pages', () => {
  const page = setup(300);
  page.rows.slice(15).forEach(row => { row.hidden = true; });
  page.paginate(1);
  assert.deepEqual(page.rows.filter(row => !row.hidden).map(row => row.textContent), Array.from({ length: 15 }, (_, index) => `Farmer ${index}`));
  page.paginate(2);
  assert.deepEqual(page.rows.filter(row => !row.hidden).map(row => row.textContent), Array.from({ length: 15 }, (_, index) => `Farmer ${index + 15}`));
  const filtered = setup(300, 'Farmer 299');
  filtered.rows.slice(15).forEach(row => { row.hidden = true; });
  filtered.paginate(1);
  assert.deepEqual(filtered.rows.filter(row => !row.hidden).map(row => row.textContent), ['Farmer 299']);
});
