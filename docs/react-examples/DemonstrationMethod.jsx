import React, { useEffect, useState } from 'react';

const labels = { general_training_meeting: 'General Training/Meeting', input_demo_inm: 'Input Demo INM',
  input_demo_pm: 'Input Demo PM', ffs: 'FFS Exposure' };
const box = { padding: 12, border: '1px solid #cddbd3', borderRadius: 8, flex: 1 };
function Metric({ value }) {
  return <div style={{ display: 'flex', gap: 8 }}>
    <div style={box}>Target<strong style={{ display: 'block' }}>{value.target}</strong></div>
    <div style={{ ...box, background: '#effaf3' }}>Achievement<strong style={{ display: 'block' }}>{value.achievement}</strong></div>
  </div>;
}

// Keep the api object stable (create once or useMemo in the parent).
export default function DemonstrationMethod({ api, month, fcoId }) {
  const [summary, setSummary] = useState(null);
  const [list, setList] = useState(null);
  const [page, setPage] = useState(1);
  const [error, setError] = useState('');
  useEffect(() => { setPage(1); }, [month, fcoId]);
  useEffect(() => {
    const controller = new AbortController();
    setSummary(null); setList(null); setError('');
    const query = { month, fco_id: fcoId };
    Promise.all([api.demonstrationSummary(query, controller.signal),
      api.demonstrationList({ ...query, page, per_page: 25 }, controller.signal)])
      .then(([summaryData, listData]) => { setSummary(summaryData); setList(listData); })
      .catch(error => { if (error.name !== 'AbortError') setError(error.message); });
    return () => controller.abort();
  }, [api, month, fcoId, page]);
  if (error) return <p role="alert">{error}</p>;
  if (!summary || !list) return <p>Loading…</p>;
  return <section>
    <h2>Demonstration Method — {month}</h2>
    <p>OPG Training Target: <strong>{summary.opg_target}</strong></p>
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 16 }}>
      {Object.entries({ total: summary.total, ...summary.methods }).map(([key, value]) =>
        <article key={key}><h3>{labels[key] || 'Total Training'}</h3><Metric value={value} /></article>)}
    </div>
    <h2>Demonstration Method View List</h2>
    <div style={{ overflowX: 'auto' }}><table>
      <thead><tr><th>FCO</th><th>Cluster Coordinator</th><th>JJ</th><th>Total Training</th>
        {Object.entries(labels).map(([key, label]) => <th key={key}>{label}</th>)}<th>Status</th></tr></thead>
      <tbody>{list.records.map(row => <tr key={`${row.fco_id}-${row.vrp_id}`}>
        <td>{row.fco_name}</td><td>{row.cluster_coordinator}</td><td>{row.vrp_name}</td>
        <td><Metric value={row.total} /></td>
        {Object.keys(labels).map(key => <td key={key}><Metric value={row.methods[key]} /></td>)}
        <td>{row.status}</td>
      </tr>)}</tbody>
    </table></div>
    {!list.count && <p>No records for this selection.</p>}
    <button disabled={page <= 1} onClick={() => setPage(page - 1)}>Previous</button>
    <span> Page {page} · {list.count} records </span>
    <button disabled={page * list.per_page >= list.count} onClick={() => setPage(page + 1)}>Next</button>
  </section>;
}
