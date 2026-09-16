// React web: pass File/Blob objects. React Native: pass { uri, name, type } uploads.
export function createFarmerTargetApi({ baseUrl = '/api/v1', getToken }) {
  async function request(path, { method = 'GET', body, query, signal } = {}) {
    const search = new URLSearchParams();
    Object.entries(query || {}).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== '') search.set(key, String(value));
    });
    const multipart = typeof FormData !== 'undefined' && body instanceof FormData;
    const token = getToken?.();
    const response = await fetch(`${baseUrl.replace(/\/$/, '')}${path}${search.size ? `?${search}` : ''}`, {
      method, signal,
      headers: { Accept: 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(body && !multipart ? { 'Content-Type': 'application/json' } : {}) },
      body: body ? (multipart ? body : JSON.stringify(body)) : undefined
    });
    const data = await response.json();
    if (!response.ok || data.success === false) {
      const error = new Error(data.errors?.join('\n') || data.message || `HTTP ${response.status}`);
      error.status = response.status;
      error.errors = data.errors || [];
      throw error;
    }
    return data;
  }

  return {
    login: (login, password) => request('/login', { method: 'POST', body: { login, password } }),
    trainingOptions: () => request('/farmer-trainings/form-options'),
    trainingFormData: (query, signal) => request('/farmer-trainings/form-data', { query, signal }),
    trainingFarmers: (query, signal) => request('/farmer-trainings/farmers', { query, signal }),
    trainingList: () => request('/farmer-trainings'),
    training: id => request(`/farmer-trainings/${encodeURIComponent(id)}`),
    trainingPhotos: id => request(`/farmer-trainings/${encodeURIComponent(id)}/photos`),
    createTraining: (fields, uploads = {}) => request('/farmer-trainings', {
      method: 'POST', body: trainingFormData(fields, uploads)
    }),
    otherOptions: () => request('/other-targets/form-options'),
    otherList: () => request('/other-targets'),
    other: id => request(`/other-targets/${encodeURIComponent(id)}`),
    createOther: fields => request('/other-targets', { method: 'POST', body: { other_target: fields } }),
    demonstrationSummary: (query, signal) => request('/demonstration-methods/summary', { query, signal }),
    demonstrationList: (query, signal) => request('/demonstration-methods', { query, signal })
  };
}

export function trainingFormData(fields, uploads = {}) {
  const data = new FormData();
  for (const [key, value] of Object.entries({ ...fields, ...uploads })) {
    if (value === undefined || value === null || value === '') continue;
    if (Array.isArray(value)) value.forEach(item => data.append(`farmer_training[${key}][]`, item));
    else data.append(`farmer_training[${key}]`, value);
  }
  return data;
}

// Build this from a returned mapping, never from hardcoded target/identity values.
export function otherTargetFields(mapping, { achievement, selectedFarmerIds = [], completionDate }) {
  return {
    jeevika_jankar_id: mapping.vrp_id, month: mapping.month, ics: mapping.ics, village: mapping.village,
    main_activity: mapping.main_activity, sub_activity: mapping.sub_activity,
    achievement, selected_farmer_ids: selectedFarmerIds, completion_date: completionDate
  };
}
