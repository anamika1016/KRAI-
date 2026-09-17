// Copy into the React app. baseUrl is the Rails origin, e.g. https://your-api.example.
// Keep the existing Admin and JJ dashboard clients unchanged.
export function createOfficeDashboardApi({ baseUrl = "", getToken, fetchImpl = fetch }) {
  const root = `${baseUrl.replace(/\/$/, "")}/api/v1/user-dashboard`;

  async function request(path, filters = {}, { signal, download = false } = {}) {
    const token = getToken();
    if (!token) throw new Error("Please log in before loading the dashboard.");
    const query = new URLSearchParams();
    for (const [key, value] of Object.entries(filters)) {
      if (value !== undefined && value !== null && value !== "") query.set(key, String(value));
    }
    const response = await fetchImpl(`${root}${path}${query.size ? `?${query}` : ""}`, {
      signal,
      headers: { Authorization: `Bearer ${token}`, Accept: download ? "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" : "application/json" }
    });
    if (download && response.ok) return response.blob();
    const body = await response.json();
    if (!response.ok || body.success === false) {
      const error = new Error(body.message || `Dashboard request failed (${response.status}).`);
      error.status = response.status;
      error.payload = body;
      throw error;
    }
    return body;
  }

  return {
    configuration: (options) => request("/configuration", {}, options),
    filters: (filters, options) => request("/filters", filters, options),
    dashboard: (filters, options) => request("", filters, options),
    widget: (key, filters, options) => request(`/widgets/${encodeURIComponent(key)}`, filters, options),
    list: (key, filters, options) => request(`/lists/${encodeURIComponent(key)}`, filters, options),
    exportList: (key, filters, options = {}) => request(`/lists/${encodeURIComponent(key)}/export`, filters, { ...options, download: true })
  };
}
