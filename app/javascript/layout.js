document.addEventListener("turbo:load", () => {
  document.querySelectorAll("[data-password-toggle]").forEach((button) => {
    button.addEventListener("click", () => {
      const input = button.closest(".password-field, .login-password-field")?.querySelector("[data-password-toggle-input]");
      if (!input) return;

      const showPassword = input.type === "password";
      input.type = showPassword ? "text" : "password";
      button.setAttribute("aria-label", showPassword ? "Hide password" : "Show password");
      button.title = showPassword ? "Hide password" : "Show password";
      button.classList.toggle("is-visible", showPassword);
    });
  });

  document.querySelectorAll(".side-module").forEach((module) => {
    module.addEventListener("toggle", () => {
      if (!module.open) return;

      document.querySelectorAll(".side-module[open]").forEach((openModule) => {
        if (openModule !== module) openModule.removeAttribute("open");
      });
    });
  });

  const selectAll = document.querySelector("[data-vrp-select-all]");
  if (selectAll) {
    selectAll.addEventListener("change", () => {
      document.querySelectorAll("[data-vrp-row-select]").forEach((checkbox) => {
        checkbox.checked = selectAll.checked;
      });
    });
  }

  const editButton = document.querySelector("[data-vrp-edit-selected]");
  if (editButton) {
    editButton.addEventListener("click", () => {
      const selected = Array.from(document.querySelectorAll("[data-vrp-row-select]:checked"));

      if (selected.length !== 1) {
        window.alert("Please select one VRP only");
        return;
      }

      window.location.href = `/vrps/${selected[0].value}/edit`;
    });
  }

  const csrfToken = document.querySelector("meta[name='csrf-token']")?.content;

  const submitPatch = (path) => {
    const form = document.createElement("form");
    form.method = "post";
    form.action = path;

    const methodInput = document.createElement("input");
    methodInput.type = "hidden";
    methodInput.name = "_method";
    methodInput.value = "patch";
    form.appendChild(methodInput);

    if (csrfToken) {
      const tokenInput = document.createElement("input");
      tokenInput.type = "hidden";
      tokenInput.name = "authenticity_token";
      tokenInput.value = csrfToken;
      form.appendChild(tokenInput);
    }

    document.body.appendChild(form);
    form.submit();
  };

  const deleteSelected = async (paths, message) => {
    if (paths.length === 0) {
      window.alert("Please select at least one record");
      return;
    }

    if (!window.confirm(message)) return;

    const responses = await Promise.all(paths.map((path) => {
      return fetch(path, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
        }
      });
    }));

    if (responses.some((response) => !response.ok)) {
      window.alert("Some selected record(s) could not be deleted.");
      return;
    }

    window.location.reload();
  };

  const vrpDeleteButton = document.querySelector("[data-vrp-delete-selected]");
  if (vrpDeleteButton) {
    vrpDeleteButton.addEventListener("click", () => {
      const paths = Array.from(document.querySelectorAll("[data-vrp-row-select]:checked"))
        .map((checkbox) => `/vrps/${checkbox.value}`);

      deleteSelected(paths, "Delete selected VRP record(s)?");
    });
  }

  const vrpSendButton = document.querySelector("[data-vrp-send-selected]");
  if (vrpSendButton) {
    vrpSendButton.addEventListener("click", () => {
      const selected = Array.from(document.querySelectorAll("[data-vrp-row-select]:checked"));

      if (selected.length !== 1) {
        window.alert("Please select one VRP only");
        return;
      }

      submitPatch(`/vrps/${selected[0].value}/send_for_approval`);
    });
  }

  document.querySelectorAll("[data-vrp-active-selected]").forEach((button) => {
    button.addEventListener("click", async () => {
      const selected = Array.from(document.querySelectorAll("[data-vrp-row-select]:checked"));
      const active = button.dataset.vrpActiveSelected;

      if (selected.length === 0) {
        window.alert("Please select at least one VRP");
        return;
      }

      const responses = await Promise.all(selected.map((checkbox) => {
        return fetch(`/vrps/${checkbox.value}/set_active?active=${encodeURIComponent(active)}`, {
          method: "PATCH",
          headers: {
            "X-CSRF-Token": csrfToken,
            "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
          }
        });
      }));

      if (responses.some((response) => !response.ok)) {
        window.alert("Some selected VRP record(s) could not be updated.");
        return;
      }

      window.location.reload();
    });
  });

  const moduleSelectAll = document.querySelector("[data-module-select-all]");
  if (moduleSelectAll) {
    moduleSelectAll.addEventListener("change", () => {
      document.querySelectorAll("[data-module-row-select]").forEach((checkbox) => {
        checkbox.checked = moduleSelectAll.checked;
      });
    });
  }

  const moduleEditButton = document.querySelector("[data-module-edit-selected]");
  if (moduleEditButton) {
    moduleEditButton.addEventListener("click", () => {
      const selected = Array.from(document.querySelectorAll("[data-module-row-select]:checked"));

      if (selected.length !== 1) {
        window.alert("Please select one record only");
        return;
      }

      window.location.href = selected[0].value;
    });
  }

  const moduleDeleteButton = document.querySelector("[data-module-delete-selected]");
  if (moduleDeleteButton) {
    moduleDeleteButton.addEventListener("click", () => {
      const paths = Array.from(document.querySelectorAll("[data-module-row-select]:checked"))
        .map((checkbox) => checkbox.value.replace(/\/edit$/, ""));

      deleteSelected(paths, "Delete selected record(s)?");
    });
  }

  document.querySelectorAll("[data-module-status-selected]").forEach((button) => {
    button.addEventListener("click", async () => {
      const selected = Array.from(document.querySelectorAll("[data-module-row-select]:checked"));
      const status = button.dataset.moduleStatusSelected;

      if (selected.length === 0) {
        window.alert("Please select at least one record");
        return;
      }

      const responses = await Promise.all(selected.map((checkbox) => {
        const path = `${checkbox.value.replace(/\/edit$/, "/set_status")}?status=${encodeURIComponent(status)}`;
        return fetch(path, {
          method: "PATCH",
          headers: {
            "X-CSRF-Token": csrfToken,
            "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
          }
        });
      }));

      if (responses.some((response) => !response.ok)) {
        window.alert("Some selected record(s) could not be updated.");
        return;
      }

      window.location.reload();
    });
  });

  document.querySelectorAll("[data-user-status-selected]").forEach((button) => {
    button.addEventListener("click", async () => {
      const selected = Array.from(document.querySelectorAll("[data-module-row-select]:checked"));
      const status = button.dataset.userStatusSelected;

      if (selected.length === 0) {
        window.alert("Please select at least one user");
        return;
      }

      await Promise.all(selected.map((checkbox) => {
        const path = `${checkbox.value.replace(/\/edit$/, "/set_status")}?status=${encodeURIComponent(status)}`;
        return fetch(path, {
          method: "PATCH",
          headers: {
            "X-CSRF-Token": csrfToken,
            "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
          }
        });
      }));

      window.location.reload();
    });
  });

  const uniquePresent = (values) => Array.from(new Set(values.map((value) => `${value || ""}`.trim()).filter(Boolean)));
  const stripDisplayName = (value) => `${value || ""}`.replace(/\s*\([^)]*\)\s*$/, "").trim();
  const displayNameFromLabel = (value) => {
    const match = `${value || ""}`.match(/\(([^)]*)\)\s*$/);
    return match ? match[1].trim() : "";
  };
  const normalizeOption = (value) => stripDisplayName(value).toLowerCase();
  const optionValue = (option) => (typeof option === "object" && option !== null ? option.value : option);
  const optionLabel = (option) => (typeof option === "object" && option !== null ? (option.label || option.value) : option);
  const makeOption = (value, label) => {
    const normalizedValue = `${value || ""}`.trim();
    if (!normalizedValue) return null;
    return { value: normalizedValue, label: `${label || normalizedValue}`.trim() || normalizedValue };
  };
  const optionWithFallbackName = (value, label, fallbackName) => {
    const normalizedValue = `${value || ""}`.trim();
    const normalizedLabel = `${label || ""}`.trim();
    if (!normalizedValue) return null;
    if (displayNameFromLabel(normalizedLabel) || !fallbackName) return makeOption(normalizedValue, normalizedLabel || normalizedValue);

    return makeOption(normalizedValue, `${normalizedValue} (${fallbackName})`);
  };
  const uniqueOptions = (options) => {
    const seen = new Set();
    return options.filter((option) => {
      if (!option) return false;

      const value = normalizeOption(optionValue(option));
      const label = `${optionLabel(option) || ""}`.trim().toLowerCase();
      const key = [value, label].join("|");
      if (!value || seen.has(key)) return false;

      seen.add(key);
      return true;
    });
  };

  const replaceSelectOptions = (select, values, blankLabel, selectedValue) => {
    if (!select) return;

    const selected = selectedValue || select.dataset.selectedValue || select.value;
    const normalizedSelected = normalizeOption(selected);
    const valueList = values.map((value) => optionValue(value));
    select.innerHTML = "";

    const blankOption = document.createElement("option");
    blankOption.value = "";
    blankOption.textContent = blankLabel;
    select.appendChild(blankOption);

    values.forEach((value) => {
      const option = document.createElement("option");
      option.value = stripDisplayName(optionValue(value));
      option.textContent = optionLabel(value);
      option.selected = normalizeOption(option.value) === normalizedSelected;
      select.appendChild(option);
    });

    if (selected && !valueList.some((value) => normalizeOption(value) === normalizedSelected)) {
      const option = document.createElement("option");
      option.value = stripDisplayName(selected);
      option.textContent = selected;
      option.selected = true;
      select.appendChild(option);
    }
  };

  document.querySelectorAll("[data-user-role-form]").forEach((formShell) => {
    const stakeholderSelect = formShell.querySelector("[data-role-stakeholder-select]");
    const stakeholderRoleSelect = formShell.querySelector("[data-stakeholder-role-select]");
    const roleSelect = formShell.querySelector("[data-role-select]");
    const roleNameSelect = formShell.querySelector("[data-role-name-select]");
    const userManagementRoleSelect = formShell.querySelector("[data-user-management-role-select]");
    const personTypeSelect = formShell.querySelector("[data-person-type-select]");
    const officeSelect = formShell.querySelector("[data-office-select]");
    if (!stakeholderSelect && !stakeholderRoleSelect && !roleSelect && !roleNameSelect && !userManagementRoleSelect && !personTypeSelect && !officeSelect) return;

    let mappings = [];
    try {
      mappings = JSON.parse(formShell.dataset.roleMap || "[]");
    } catch (_error) {
      mappings = [];
    }
    let officeMappings = [];
    try {
      officeMappings = JSON.parse(formShell.dataset.officeMap || "[]");
    } catch (_error) {
      officeMappings = [];
    }
    const selectedDisplayName = (select) => {
      if (!select) return "";

      const selectedOption = select.options[select.selectedIndex];
      return displayNameFromLabel(selectedOption?.textContent || select.value);
    };

    const mappedStakeholderRoles = (stakeholder) => {
      const normalizedStakeholder = normalizeOption(stakeholder);
      if (!normalizedStakeholder) return [];

      const filtered = mappings.filter((mapping) => {
        return normalizeOption(mapping.stakeholder) === normalizedStakeholder;
      });
      const stakeholderRoles = uniqueOptions(filtered.map((mapping) => makeOption(mapping.stakeholder_role, mapping.stakeholder_role_label)));
      return stakeholderRoles;
    };

    const mappedRoles = (stakeholder, stakeholderRole) => {
      const normalizedStakeholder = normalizeOption(stakeholder);
      const normalizedStakeholderRole = normalizeOption(stakeholderRole);
      if (!normalizedStakeholder) return [];

      const filtered = mappings.filter((mapping) => {
        const stakeholderMatches = normalizeOption(mapping.stakeholder) === normalizedStakeholder;
        const mappedStakeholderRole = normalizeOption(mapping.stakeholder_role);
        const stakeholderRoleMatches = !mappedStakeholderRole || mappedStakeholderRole === normalizedStakeholderRole;
        return stakeholderMatches && stakeholderRoleMatches;
      });
      const fallbackName = selectedDisplayName(stakeholderRoleSelect);
      const roles = uniqueOptions(filtered.map((mapping) => optionWithFallbackName(mapping.role, mapping.role_label, fallbackName)));
      return roles;
    };

    const mappedRoleNames = (stakeholder, stakeholderRole) => {
      const normalizedStakeholder = normalizeOption(stakeholder);
      const normalizedStakeholderRole = normalizeOption(stakeholderRole);
      if (!normalizedStakeholder || !normalizedStakeholderRole) return [];

      const filtered = mappings.filter((mapping) => {
        const stakeholderMatches = normalizeOption(mapping.stakeholder) === normalizedStakeholder;
        const stakeholderRoleMatches = normalizeOption(mapping.stakeholder_role) === normalizedStakeholderRole;
        return stakeholderMatches && stakeholderRoleMatches;
      });
      const fallbackName = selectedDisplayName(stakeholderRoleSelect);
      const roleNames = uniqueOptions(filtered.map((mapping) => optionWithFallbackName(mapping.role_name, mapping.role_name_label, fallbackName)));
      return roleNames;
    };

    const mappedUserManagementRoles = (stakeholder, stakeholderRole, role) => {
      const normalizedStakeholder = normalizeOption(stakeholder);
      const normalizedStakeholderRole = normalizeOption(stakeholderRole);
      const normalizedRole = normalizeOption(role);
      if (!normalizedStakeholder || !normalizedStakeholderRole || !normalizedRole) return [];

      const filtered = mappings.filter((mapping) => {
        const stakeholderMatches = normalizeOption(mapping.stakeholder) === normalizedStakeholder;
        const stakeholderRoleMatches = normalizeOption(mapping.stakeholder_role) === normalizedStakeholderRole;
        const roleMatches = normalizeOption(mapping.role) === normalizedRole;
        return stakeholderMatches && stakeholderRoleMatches && roleMatches;
      });
      const fallbackName = selectedDisplayName(roleSelect) || selectedDisplayName(stakeholderRoleSelect);
      const userManagementRoles = uniqueOptions(filtered.map((mapping) => optionWithFallbackName(mapping.user_management_role, mapping.user_management_role_label, fallbackName)));
      return userManagementRoles;
    };

    const mappedPersonTypes = (stakeholder, stakeholderRole, role, userManagementRole) => {
      const normalizedStakeholder = normalizeOption(stakeholder);
      const normalizedStakeholderRole = normalizeOption(stakeholderRole);
      const normalizedRole = normalizeOption(role);
      const normalizedUserManagementRole = normalizeOption(userManagementRole);
      if (!normalizedStakeholder || !normalizedStakeholderRole || !normalizedRole || !normalizedUserManagementRole) return [];

      const filtered = mappings.filter((mapping) => {
        const stakeholderMatches = normalizeOption(mapping.stakeholder) === normalizedStakeholder;
        const stakeholderRoleMatches = normalizeOption(mapping.stakeholder_role) === normalizedStakeholderRole;
        const roleMatches = normalizeOption(mapping.role) === normalizedRole;
        const userManagementRoleMatches = normalizeOption(mapping.user_management_role) === normalizedUserManagementRole;
        return stakeholderMatches && stakeholderRoleMatches && roleMatches && userManagementRoleMatches;
      });
      const fallbackName = selectedDisplayName(userManagementRoleSelect) || selectedDisplayName(roleSelect) || selectedDisplayName(stakeholderRoleSelect);
      const personTypes = uniqueOptions(filtered.map((mapping) => optionWithFallbackName(mapping.person_type, mapping.person_type_label, fallbackName)));
      return personTypes;
    };

    const refreshStakeholderRoles = () => {
      if (!stakeholderRoleSelect) return;
      const stakeholderRoles = mappedStakeholderRoles(stakeholderSelect?.value);
      replaceSelectOptions(stakeholderRoleSelect, stakeholderRoles, "Select Stakeholder Person Type");
    };

    const refreshRoles = () => {
      if (!roleSelect) return;
      const roles = mappedRoles(stakeholderSelect?.value, stakeholderRoleSelect?.value);
      replaceSelectOptions(roleSelect, roles, roleSelect.dataset.rolePrompt || "Select Role");
      refreshUserManagementRoles();
    };

    const refreshRoleNames = () => {
      if (!roleNameSelect) return;
      const roleNames = mappedRoleNames(stakeholderSelect?.value, stakeholderRoleSelect?.value);
      replaceSelectOptions(roleNameSelect, roleNames, "Select Role Name");
    };

    const refreshUserManagementRoles = () => {
      if (!userManagementRoleSelect) return;
      const userManagementRoles = mappedUserManagementRoles(stakeholderSelect?.value, stakeholderRoleSelect?.value, roleSelect?.value);
      replaceSelectOptions(userManagementRoleSelect, userManagementRoles, "Select User Management Person Type");
      refreshPersonTypes();
    };

    const refreshPersonTypes = () => {
      if (!personTypeSelect) return;
      const personTypes = mappedPersonTypes(stakeholderSelect?.value, stakeholderRoleSelect?.value, roleSelect?.value, userManagementRoleSelect?.value);
      replaceSelectOptions(personTypeSelect, personTypes, "Select Person Type");
    };

    const refreshOffices = () => {
      if (!officeSelect) return;
      const normalizedStakeholder = normalizeOption(stakeholderSelect?.value);
      const offices = uniquePresent(
        officeMappings
          .filter((mapping) => {
            const mappedStakeholder = normalizeOption(mapping.stakeholder);
            return !normalizedStakeholder || !mappedStakeholder || mappedStakeholder === normalizedStakeholder;
          })
          .map((mapping) => mapping.office)
      );
      replaceSelectOptions(officeSelect, offices, "Select Office");
    };

    stakeholderSelect?.addEventListener("change", () => {
      if (stakeholderRoleSelect) stakeholderRoleSelect.dataset.selectedValue = "";
      if (roleSelect) roleSelect.dataset.selectedValue = "";
      if (roleNameSelect) roleNameSelect.dataset.selectedValue = "";
      if (userManagementRoleSelect) userManagementRoleSelect.dataset.selectedValue = "";
      if (personTypeSelect) personTypeSelect.dataset.selectedValue = "";
      if (officeSelect) officeSelect.dataset.selectedValue = "";
      refreshStakeholderRoles();
      refreshRoles();
      refreshRoleNames();
      refreshUserManagementRoles();
      refreshPersonTypes();
      refreshOffices();
    });
    stakeholderRoleSelect?.addEventListener("change", () => {
      if (roleSelect) roleSelect.dataset.selectedValue = "";
      if (roleNameSelect) roleNameSelect.dataset.selectedValue = "";
      if (userManagementRoleSelect) userManagementRoleSelect.dataset.selectedValue = "";
      if (personTypeSelect) personTypeSelect.dataset.selectedValue = "";
      refreshRoles();
      refreshRoleNames();
      refreshUserManagementRoles();
      refreshPersonTypes();
    });
    roleSelect?.addEventListener("change", () => {
      if (userManagementRoleSelect) userManagementRoleSelect.dataset.selectedValue = "";
      if (personTypeSelect) personTypeSelect.dataset.selectedValue = "";
      refreshUserManagementRoles();
      refreshPersonTypes();
    });
    userManagementRoleSelect?.addEventListener("change", () => {
      if (personTypeSelect) personTypeSelect.dataset.selectedValue = "";
      refreshPersonTypes();
    });

    refreshStakeholderRoles();
    refreshRoles();
    refreshRoleNames();
    refreshOffices();
  });

  const locationLevels = ["state", "district", "block", "gram-panchayat", "village"];
  const locationKeys = {
    "state": "state",
    "district": "district",
    "block": "block",
    "gram-panchayat": "gram_panchayat",
    "village": "village"
  };
  const locationParents = {
    "district": ["state"],
    "block": ["state", "district"],
    "gram-panchayat": ["state", "district", "block"],
    "village": ["state", "district", "block", "gram-panchayat"]
  };

  const selectedLocationValues = (select) => {
    if (!select || !select.value) return [];

    const option = select.selectedOptions?.[0];
    return uniquePresent([select.value, option?.textContent]);
  };

  const locationRowMatchesParents = (row, selects, level) => {
    return (locationParents[level] || []).every((parentLevel) => {
      const parentValues = selectedLocationValues(selects[parentLevel]);
      if (parentValues.length === 0) return false;

      const parentKey = locationKeys[parentLevel];
      if (!row[parentKey]) return true;

      return parentValues.some((value) => normalizeOption(row[parentKey]) === normalizeOption(value));
    });
  };

  const optionMatchesLocationRow = (option, row, level) => {
    const key = locationKeys[level];
    return [row.id, row[key]].some((value) => {
      return normalizeOption(value) === normalizeOption(option.value) ||
        normalizeOption(value) === normalizeOption(option.textContent);
    });
  };

  const replaceLocationOptions = (select, originalOptions, allowedRows, level) => {
    if (!select) return;

    const selected = select.dataset.selectedValue || select.value;
    const blankOption = originalOptions.find((option) => option.value === "") || { value: "", label: `Select ${level}` };
    const filteredOptions = originalOptions.filter((option) => {
      if (option.value === "") return false;
      return allowedRows.some((row) => optionMatchesLocationRow(option, row, level));
    });

    const parentSelected = (locationParents[level] || []).every((parentLevel) => {
      return selectedLocationValues(select.closest("[data-location-form]")?.querySelector(`[data-location-level="${parentLevel}"]`)).length > 0;
    });
    const hasParents = (locationParents[level] || []).length > 0;
    const finalOptions = hasParents && !parentSelected
      ? []
      : (allowedRows.length > 0 || parentSelected ? filteredOptions : originalOptions.filter((option) => option.value !== ""));
    select.innerHTML = "";

    const prompt = document.createElement("option");
    prompt.value = "";
    prompt.textContent = blankOption.label;
    select.appendChild(prompt);

    finalOptions.forEach((optionData) => {
      const option = document.createElement("option");
      option.value = optionData.value;
      option.textContent = optionData.label;
      option.selected = optionData.value === selected || optionData.label === selected;
      select.appendChild(option);
    });
  };

  document.querySelectorAll("[data-location-form]").forEach((formShell) => {
    let mappings = [];
    try {
      mappings = JSON.parse(formShell.dataset.locationMap || "[]");
    } catch (_error) {
      mappings = [];
    }

    const selects = {};
    const originalOptions = {};
    locationLevels.forEach((level) => {
      const select = formShell.querySelector(`[data-location-level="${level}"]`);
      if (!select) return;

      selects[level] = select;
      originalOptions[level] = Array.from(select.options).map((option) => ({
        value: option.value,
        label: option.textContent
      }));
    });

    const refreshLocationLevel = (level) => {
      if (!selects[level]) return;

      const key = locationKeys[level];
      const allowedRows = mappings.filter((row) => row[key] && locationRowMatchesParents(row, selects, level));
      replaceLocationOptions(selects[level], originalOptions[level], allowedRows, level);
    };

    const refreshFrom = (level) => {
      const startIndex = locationLevels.indexOf(level) + 1;
      locationLevels.slice(startIndex).forEach((childLevel) => {
        if (selects[childLevel]) selects[childLevel].dataset.selectedValue = "";
        refreshLocationLevel(childLevel);
      });
    };

    locationLevels.forEach((level) => {
      selects[level]?.addEventListener("change", () => refreshFrom(level));
    });

    locationLevels.slice(1).forEach(refreshLocationLevel);
  });

  document.querySelectorAll("[data-vrp-ics-mapping]").forEach((shell) => {
    const vrpSelect = shell.querySelector("[data-vrp-ics-vrp]");
    const fcoSelect = shell.querySelector("[data-vrp-ics-fco]");
    const icsSelect = shell.querySelector("[data-vrp-ics-ics]");
    const villageSelect = shell.querySelector("[data-vrp-ics-village]");
    const farmersList = shell.querySelector("[data-vrp-ics-farmers]");
    const selectAll = shell.querySelector("[data-vrp-ics-select-all]");
    const countLabel = shell.querySelector("[data-vrp-ics-count]");
    const hiddenFcoName = shell.querySelector("[data-vrp-ics-fco-name]");
    const hiddenIcsName = shell.querySelector("[data-vrp-ics-ics-name]");
    const hiddenVillageName = shell.querySelector("[data-vrp-ics-village-name]");
    let editMapping = {};
    try {
      editMapping = JSON.parse(shell.dataset.editMapping || "{}");
    } catch (_error) {
      editMapping = {};
    }

    const escapeHtml = (value) => String(value || "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");

    const selectedText = (select) => select?.selectedOptions?.[0]?.textContent?.trim() || "";

    const updateHiddenNames = () => {
      if (hiddenFcoName) hiddenFcoName.value = fcoSelect?.value ? selectedText(fcoSelect) : "";
      if (hiddenIcsName) hiddenIcsName.value = icsSelect?.value ? selectedText(icsSelect) : "";
      if (hiddenVillageName) hiddenVillageName.value = villageSelect?.value ? selectedText(villageSelect) : "";
    };

    const fillSelect = (select, options, placeholder) => {
      if (!select) return;

      select.innerHTML = "";
      const blank = document.createElement("option");
      blank.value = "";
      blank.textContent = placeholder;
      select.appendChild(blank);

      options.forEach((optionData) => {
        const option = document.createElement("option");
        option.value = optionData.value || "";
        option.textContent = optionData.label || optionData.value || "";
        select.appendChild(option);
      });

      select.disabled = options.length === 0;
    };

    const fetchJson = async (url, params) => {
      const requestUrl = new URL(url, window.location.origin);
      Object.entries(params).forEach(([key, value]) => {
        if (value) requestUrl.searchParams.set(key, value);
      });

      const response = await fetch(requestUrl, { headers: { Accept: "application/json" } });
      if (!response.ok) throw new Error("Request failed");
      return response.json();
    };

    const selectedFarmerBoxes = () => Array.from(shell.querySelectorAll("[data-vrp-ics-farmer-checkbox]:checked"));

    const updateFarmerCount = () => {
      const count = selectedFarmerBoxes().length;
      if (countLabel) countLabel.textContent = `${count} farmer selected`;
      if (selectAll) {
        const allBoxes = Array.from(shell.querySelectorAll("[data-vrp-ics-farmer-checkbox]:not(:disabled)"));
        selectAll.checked = allBoxes.length > 0 && count === allBoxes.length;
        selectAll.indeterminate = count > 0 && count < allBoxes.length;
      }
    };

    const clearFarmers = (message = "Select FCO, ICS and Village to load farmers.") => {
      if (farmersList) farmersList.textContent = message;
      if (selectAll) {
        selectAll.checked = false;
        selectAll.indeterminate = false;
      }
      updateFarmerCount();
    };

    const renderFarmers = (farmers) => {
      if (!farmersList) return;

      if (!farmers.length) {
        clearFarmers("No farmers found for selected village.");
        return;
      }

      farmersList.innerHTML = farmers.map((farmer) => {
        const meta = [
          farmer.father_name ? `Father: ${farmer.father_name}` : "",
          farmer.tracenet_no ? `Tracenet: ${farmer.tracenet_no}` : "",
          farmer.mobile_no ? `Mobile: ${farmer.mobile_no}` : "",
          farmer.khasara_no ? `Khasara: ${farmer.khasara_no}` : ""
        ].filter(Boolean).join(" | ");

        return `
          <label class="vrp-ics-farmer-item${farmer.mapped_to_other ? " disabled" : ""}">
            <input type="checkbox" name="vrp_ics_mapping[afl_ids][]" value="${escapeHtml(farmer.id)}" data-vrp-ics-farmer-checkbox${farmer.mapped_to_other ? " disabled" : ""}${(editMapping.afl_ids || []).map(String).includes(String(farmer.id)) ? " checked" : ""}>
            <span>
              <strong>${escapeHtml(farmer.farmer_name || `Farmer #${farmer.id}`)}</strong>
              <small>${escapeHtml(meta)}${farmer.mapped_to_other ? " | Already mapped" : ""}</small>
            </span>
          </label>
        `;
      }).join("");

      farmersList.querySelectorAll("[data-vrp-ics-farmer-checkbox]").forEach((checkbox) => {
        checkbox.addEventListener("change", updateFarmerCount);
      });
      updateFarmerCount();
    };

    fcoSelect?.addEventListener("change", async () => {
      fillSelect(icsSelect, [], "Select ICS");
      fillSelect(villageSelect, [], "Select Village");
      clearFarmers();
      updateHiddenNames();

      if (!fcoSelect.value) return;

      try {
        const data = await fetchJson(shell.dataset.icsUrl, { fco_id: fcoSelect.value });
        fillSelect(icsSelect, data.options || [], "Select ICS");
      } catch (_error) {
        window.alert("ICS list load nahi ho payi.");
      }
    });

    icsSelect?.addEventListener("change", async () => {
      fillSelect(villageSelect, [], "Select Village");
      clearFarmers();
      updateHiddenNames();

      if (!fcoSelect?.value || !icsSelect.value) return;

      try {
        const data = await fetchJson(shell.dataset.villagesUrl, { fco_id: fcoSelect.value, ics_id: icsSelect.value });
        fillSelect(villageSelect, data.options || [], "Select Village");
      } catch (_error) {
        window.alert("Village list load nahi ho payi.");
      }
    });

    villageSelect?.addEventListener("change", async () => {
      clearFarmers(villageSelect.value ? "Loading farmers..." : "Select village to load farmers.");
      updateHiddenNames();

      if (!fcoSelect?.value || !icsSelect?.value || !villageSelect.value) return;

      try {
        const data = await fetchJson(shell.dataset.farmersUrl, {
          vrp_id: vrpSelect?.value,
          edit_id: editMapping.id,
          fco_id: fcoSelect.value,
          ics_id: icsSelect.value,
          village_id: villageSelect.value
        });
        renderFarmers(data.farmers || []);
      } catch (_error) {
        clearFarmers("Farmers load nahi ho paye.");
      }
    });

    selectAll?.addEventListener("change", () => {
      shell.querySelectorAll("[data-vrp-ics-farmer-checkbox]:not(:disabled)").forEach((checkbox) => {
        checkbox.checked = selectAll.checked;
      });
      updateFarmerCount();
    });

    const loadEditMapping = async () => {
      if (!editMapping.id || !fcoSelect?.value) return;

      try {
        const icsData = await fetchJson(shell.dataset.icsUrl, { fco_id: fcoSelect.value });
        fillSelect(icsSelect, icsData.options || [], "Select ICS");
        icsSelect.value = editMapping.ics_id || "";

        const villageData = await fetchJson(shell.dataset.villagesUrl, { fco_id: fcoSelect.value, ics_id: icsSelect.value });
        fillSelect(villageSelect, villageData.options || [], "Select Village");
        villageSelect.value = editMapping.village_id || "";
        updateHiddenNames();

        const farmersData = await fetchJson(shell.dataset.farmersUrl, {
          vrp_id: vrpSelect?.value,
          edit_id: editMapping.id,
          fco_id: fcoSelect.value,
          ics_id: icsSelect.value,
          village_id: villageSelect.value
        });
        renderFarmers(farmersData.farmers || []);
      } catch (_error) {
        clearFarmers("Saved mapping load nahi ho payi.");
      }
    };

    loadEditMapping();
  });

  document.querySelectorAll("[data-target-mapping]").forEach((shell) => {
    const vrpSelect = shell.querySelector("[data-target-vrp]");
    const rowsBody = shell.querySelector("[data-target-mapping-rows]");
    const countLabel = shell.querySelector("[data-target-mapping-count]");
    let editTarget = {};
    try {
      editTarget = JSON.parse(shell.dataset.editTarget || "{}");
    } catch (_error) {
      editTarget = {};
    }

    const escapeHtml = (value) => String(value || "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");

    const setCount = (text) => {
      if (countLabel) countLabel.textContent = text;
    };

    const renderRows = (mappings) => {
      if (!rowsBody) return;

      if (!mappings.length) {
        rowsBody.innerHTML = `<tr><td colspan="6">No VRP ICS mapping found for selected VRP.</td></tr>`;
        setCount("0 mapping selected");
        return;
      }

      rowsBody.innerHTML = mappings.map((mapping) => `
        <tr>
          <td>
            <input type="radio" name="target_mapping[vrp_ics_mapping_id]" value="${escapeHtml(mapping.id)}" required data-target-mapping-radio>
          </td>
          <td>${escapeHtml(mapping.fco)}</td>
          <td>${escapeHtml(mapping.ics)}</td>
          <td>${escapeHtml(mapping.village)}</td>
          <td>${escapeHtml(mapping.farmer_count)}</td>
          <td>
            <input type="number" min="0" step="0.01" placeholder="Enter target" disabled data-target-quantity-input>
          </td>
        </tr>
      `).join("");

      let preselected = false;
      rowsBody.querySelectorAll("[data-target-mapping-radio]").forEach((radio) => {
        radio.addEventListener("change", () => {
          rowsBody.querySelectorAll("[data-target-quantity-input]").forEach((input) => {
            input.disabled = true;
            input.required = false;
            input.removeAttribute("name");
          });
          const row = radio.closest("tr");
          const farmers = row?.children?.[4]?.textContent?.trim() || "0";
          const targetInput = row?.querySelector("[data-target-quantity-input]");
          if (targetInput) {
            targetInput.disabled = false;
            targetInput.required = true;
            targetInput.name = "target_mapping[target_quantity]";
            targetInput.focus();
          }
          setCount(`${farmers} registered farmers selected`);
        });

        if (String(radio.value) === String(editTarget.vrp_ics_mapping_id)) {
          radio.checked = true;
          radio.dispatchEvent(new Event("change", { bubbles: true }));
          const targetInput = radio.closest("tr")?.querySelector("[data-target-quantity-input]");
          if (targetInput) targetInput.value = editTarget.target_quantity || "";
          preselected = true;
        }
      });
      if (!preselected) setCount("0 mapping selected");
    };

    vrpSelect?.addEventListener("change", async () => {
      if (!rowsBody) return;

      if (!vrpSelect.value) {
        rowsBody.innerHTML = `<tr><td colspan="6">Select VRP to load mapped villages.</td></tr>`;
        setCount("0 mapping selected");
        return;
      }

      rowsBody.innerHTML = `<tr><td colspan="6">Loading mapped villages...</td></tr>`;

      const url = new URL(shell.dataset.mappingsUrl, window.location.origin);
      url.searchParams.set("vrp_id", vrpSelect.value);

      try {
        const response = await fetch(url, { headers: { Accept: "application/json" } });
        if (!response.ok) throw new Error("Request failed");
        const data = await response.json();
        renderRows(data.mappings || []);
      } catch (_error) {
        rowsBody.innerHTML = `<tr><td colspan="6">Mapped villages load nahi ho paye.</td></tr>`;
        setCount("0 mapping selected");
      }
    });

    if (editTarget.id && vrpSelect?.value) {
      vrpSelect.dispatchEvent(new Event("change", { bubbles: true }));
    }
  });

  document.querySelectorAll("[data-export-table]").forEach((button) => {
    button.addEventListener("click", () => {
      const table = document.getElementById(button.dataset.exportTable);
      if (!table) return;

      const rows = Array.from(table.querySelectorAll("tr")).map((row) => {
        return Array.from(row.children)
          .slice(1)
          .map((cell) => {
            const value = cell.matches("th") ? (cell.querySelector(".column-filter-label")?.innerText || cell.innerText) : cell.innerText;
            return `"${value.replaceAll('"', '""')}"`;
          })
          .join(",");
      });

      const blob = new Blob([rows.join("\n")], { type: "text/csv;charset=utf-8;" });
      const link = document.createElement("a");
      link.href = URL.createObjectURL(blob);
      link.download = `${button.dataset.exportTable}.csv`;
      link.click();
      URL.revokeObjectURL(link.href);
    });
  });

  const paginateTable = (table, page = 1) => {
    const pageSize = Number(table.dataset.pageSize || 15);
    const query = (document.querySelector(`[data-table-search='${table.id}']`)?.value || "").toLowerCase();
    const rows = Array.from(table.querySelectorAll("tbody tr"));
    const dataRows = rows.filter((row) => !row.dataset.emptyRow);
    const columnFilters = JSON.parse(table.dataset.columnFilters || "{}");
    const matchedRows = dataRows.filter((row) => {
      const globalMatch = row.innerText.toLowerCase().includes(query);
      if (!globalMatch) return false;

      return Object.entries(columnFilters).every(([columnIndex, filter]) => {
        const cellText = (row.children[Number(columnIndex)]?.innerText || "").toLowerCase();
        const filterValue = (filter.value || "").toLowerCase();
        if (!filterValue) return true;

        switch (filter.operator) {
          case "equals":
            return cellText === filterValue;
          case "starts":
            return cellText.startsWith(filterValue);
          case "ends":
            return cellText.endsWith(filterValue);
          default:
            return cellText.includes(filterValue);
        }
      });
    });
    const totalPages = Math.max(1, Math.ceil(matchedRows.length / pageSize));
    const currentPage = Math.min(Math.max(page, 1), totalPages);
    const start = (currentPage - 1) * pageSize;
    const visibleRows = matchedRows.slice(start, start + pageSize);

    dataRows.forEach((row) => {
      row.hidden = !visibleRows.includes(row);
    });

    const pagination = document.querySelector(`[data-pagination-for='${table.id}']`);
    if (pagination) {
      pagination.innerHTML = "";

      const summary = document.createElement("span");
      summary.textContent = `${matchedRows.length === 0 ? 0 : start + 1} to ${Math.min(start + pageSize, matchedRows.length)} of ${matchedRows.length}`;
      pagination.appendChild(summary);

      const previous = document.createElement("button");
      previous.type = "button";
      previous.textContent = "‹";
      previous.disabled = currentPage === 1;
      previous.addEventListener("click", () => paginateTable(table, currentPage - 1));
      pagination.appendChild(previous);

      const pageLabel = document.createElement("strong");
      pageLabel.textContent = `Page ${currentPage} of ${totalPages}`;
      pagination.appendChild(pageLabel);

      const next = document.createElement("button");
      next.type = "button";
      next.textContent = "›";
      next.disabled = currentPage === totalPages;
      next.addEventListener("click", () => paginateTable(table, currentPage + 1));
      pagination.appendChild(next);
    }
  };

  const closeColumnFilters = (exceptPanel = null) => {
    document.querySelectorAll(".column-filter-panel.open").forEach((panel) => {
      if (panel !== exceptPanel) panel.classList.remove("open");
    });
  };

  const renderColumnFilterState = (table, header, columnIndex, operator, value) => {
    const filters = JSON.parse(table.dataset.columnFilters || "{}");
    if (value) {
      filters[columnIndex] = { operator, value };
    } else {
      delete filters[columnIndex];
    }

    table.dataset.columnFilters = JSON.stringify(filters);
    header.classList.toggle("filtered", Boolean(value));
    paginateTable(table, 1);
  };

  const setupColumnFilters = (table) => {
    if (table.dataset.columnFiltersReady) return;

    table.dataset.columnFiltersReady = "true";
    table.dataset.columnFilters ||= "{}";

    table.querySelectorAll("thead th").forEach((header, columnIndex) => {
      if (header.querySelector("input[type='checkbox']")) return;
      if (header.querySelector(".column-filter-trigger")) return;

      const label = document.createElement("span");
      label.className = "column-filter-label";
      label.textContent = header.textContent.trim();

      const trigger = document.createElement("button");
      trigger.type = "button";
      trigger.className = "column-filter-trigger";
      trigger.textContent = "≡";
      trigger.setAttribute("aria-label", `Filter ${label.textContent || "column"}`);

      const panel = document.createElement("div");
      panel.className = "column-filter-panel";

      const operator = document.createElement("select");
      operator.innerHTML = `
        <option value="contains">Contains</option>
        <option value="equals">Equals</option>
        <option value="starts">Starts with</option>
        <option value="ends">Ends with</option>
      `;

      const input = document.createElement("input");
      input.type = "search";
      input.placeholder = "Filter...";

      panel.appendChild(operator);
      panel.appendChild(input);
      header.textContent = "";
      header.classList.add("column-filter-header");
      header.appendChild(label);
      header.appendChild(trigger);
      header.appendChild(panel);

      trigger.addEventListener("click", (event) => {
        event.stopPropagation();
        const shouldOpen = !panel.classList.contains("open");
        closeColumnFilters(panel);
        panel.classList.toggle("open", shouldOpen);
        if (shouldOpen) input.focus();
      });

      panel.addEventListener("click", (event) => event.stopPropagation());

      operator.addEventListener("change", () => {
        renderColumnFilterState(table, header, columnIndex, operator.value, input.value.trim());
      });

      input.addEventListener("input", () => {
        renderColumnFilterState(table, header, columnIndex, operator.value, input.value.trim());
      });
    });
  };

  document.addEventListener("click", () => closeColumnFilters());

  document.querySelectorAll("[data-paginated-table]").forEach((table) => {
    table.querySelectorAll("tbody tr").forEach((row) => {
      if (row.children.length === 1 || row.innerText.toLowerCase().includes("no records")) {
        row.dataset.emptyRow = "true";
      }
    });
    setupColumnFilters(table);
    paginateTable(table, 1);
  });

  document.querySelectorAll("[data-table-search]").forEach((input) => {
    input.addEventListener("input", () => {
      const table = document.getElementById(input.dataset.tableSearch);
      if (table) paginateTable(table, 1);
    });
  });

  document.querySelectorAll("[data-import-file]").forEach((input) => {
    input.addEventListener("change", () => {
      if (!input.files.length) return;

      const label = input.closest(".import-btn");
      if (label) label.firstChild.textContent = input.files[0].name;
    });
  });

  document.querySelectorAll("[data-upload-selected]").forEach((button) => {
    button.addEventListener("click", () => {
      const controls = button.closest(".list-controls") || button.closest(".dashboard-actions");
      const input = controls?.querySelector("[data-import-file]");

      if (!input || !input.files.length) {
        window.alert("Please choose an Excel/CSV file first.");
        return;
      }

      window.alert("Upload file selected. Backend bulk import parser is not connected yet.");
    });
  });

  document.querySelectorAll("[data-chip-multiselect]").forEach((select) => {
    if (select.nextElementSibling?.classList.contains("chip-multi-control")) return;

    const control = document.createElement("div");
    const chips = document.createElement("div");
    const dropdown = document.createElement("div");
    const arrow = document.createElement("span");
    const placeholder = select.dataset.placeholder || "Select";

    control.className = "chip-multi-control";
    chips.className = "chip-multi-values";
    dropdown.className = "chip-multi-dropdown";
    arrow.className = "chip-multi-arrow";
    arrow.textContent = "⌄";
    control.tabIndex = 0;

    select.classList.add("chip-source-select");
    select.insertAdjacentElement("afterend", control);
    control.appendChild(chips);
    control.appendChild(arrow);
    control.appendChild(dropdown);

    const selectedOptions = () => Array.from(select.options).filter((option) => option.selected);

    const render = () => {
      const selected = selectedOptions();
      chips.innerHTML = "";
      dropdown.innerHTML = "";
      control.classList.toggle("disabled", select.disabled);
      control.setAttribute("aria-disabled", select.disabled ? "true" : "false");

      if (!selected.length) {
        const empty = document.createElement("span");
        empty.className = "chip-placeholder";
        empty.textContent = placeholder;
        chips.appendChild(empty);
      }

      selected.forEach((option) => {
        const chip = document.createElement("button");
        chip.type = "button";
        chip.className = "chip-token";
        chip.innerHTML = `<span>${option.textContent}</span><strong>×</strong>`;
        chip.addEventListener("click", (event) => {
          event.stopPropagation();
          if (select.disabled) return;
          option.selected = false;
          select.dispatchEvent(new Event("change", { bubbles: true }));
          render();
        });
        chips.appendChild(chip);
      });

      const options = Array.from(select.options);

      if (!options.length) {
        const emptyOption = document.createElement("div");
        emptyOption.className = "chip-option empty";
        emptyOption.textContent = "No options saved yet";
        dropdown.appendChild(emptyOption);
      }

      options.forEach((option) => {
        const item = document.createElement("button");
        item.type = "button";
        item.className = "chip-option";
        item.textContent = option.textContent;
        item.dataset.selected = option.selected ? "true" : "false";
        item.disabled = select.disabled;
        item.addEventListener("click", (event) => {
          event.stopPropagation();
          if (select.disabled) return;
          option.selected = !option.selected;
          select.dispatchEvent(new Event("change", { bubbles: true }));
          render();
        });
        dropdown.appendChild(item);
      });
    };

    control.addEventListener("click", () => {
      if (select.disabled) return;

      document.querySelectorAll(".chip-multi-control.open").forEach((openControl) => {
        if (openControl !== control) openControl.classList.remove("open");
      });
      control.classList.toggle("open");
    });

    control.addEventListener("keydown", (event) => {
      if (event.key !== "Enter" && event.key !== " ") return;

      event.preventDefault();
      control.click();
    });

    document.addEventListener("click", (event) => {
      if (!control.contains(event.target)) control.classList.remove("open");
    });

    select.addEventListener("change", render);
    select.addEventListener("chip:refresh", render);

    render();
  });

  const dashboardSearch = document.querySelector("[data-dashboard-search]");
  if (dashboardSearch) {
    dashboardSearch.addEventListener("input", () => {
      const query = dashboardSearch.value.toLowerCase();
      document.querySelectorAll("[data-dashboard-card]").forEach((card) => {
        card.hidden = !card.innerText.toLowerCase().includes(query);
      });
    });
  }

  const dashboardClockTime = document.querySelector("[data-dashboard-clock-time]");
  const dashboardClockDate = document.querySelector("[data-dashboard-clock-date]");
  if (dashboardClockTime && dashboardClockDate) {
    if (window.dashboardClockTimer) window.clearInterval(window.dashboardClockTimer);

    const renderDashboardClock = () => {
      const now = new Date();
      dashboardClockTime.textContent = now.toLocaleTimeString("en-IN", {
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit"
      });
      dashboardClockDate.textContent = now.toLocaleDateString("en-IN", {
        weekday: "long",
        day: "2-digit",
        month: "long",
        year: "numeric"
      });
    };

    renderDashboardClock();
    window.dashboardClockTimer = window.setInterval(renderDashboardClock, 1000);
  }

  document.querySelectorAll("[data-approval-levels]").forEach((shell) => {
    const table = shell.querySelector("[data-approval-level-table]");
    const addButton = shell.querySelector("[data-add-approval-level]");
    const firstSelect = table?.querySelector("select[name^='module_record[approval_steps]']");
    const approverOptions = firstSelect
      ? Array.from(firstSelect.options).map((option) => ({ value: option.value, label: option.textContent }))
      : [{ value: "", label: "Select approval user" }];

    const approvalRowCount = () => new Set(Array.from(table?.querySelectorAll("[data-approval-row]") || []).map((cell) => cell.dataset.approvalRow)).size;

    const removeApprovalRow = (rowIndex) => {
      if (!table || approvalRowCount() <= 1) return;

      table.querySelectorAll(`[data-approval-row="${rowIndex}"]`).forEach((cell) => cell.remove());
    };

    const addApprovalRow = () => {
      if (!table) return;

      const rowIndex = Number(shell.dataset.nextApprovalLevel || approvalRowCount() + 1);
      const level = `Approval ${rowIndex}`;
      shell.dataset.nextApprovalLevel = String(rowIndex + 1);

      const levelCell = document.createElement("div");
      levelCell.className = "approval-level-cell";
      levelCell.dataset.approvalRow = String(rowIndex);
      levelCell.innerHTML = `<strong>${level}</strong><small>Approval step ${rowIndex}</small>`;

      const userCell = document.createElement("div");
      userCell.className = "approval-level-cell";
      userCell.dataset.approvalRow = String(rowIndex);
      const select = document.createElement("select");
      select.name = `module_record[approval_steps][${level}]`;
      approverOptions.forEach((optionData) => {
        const option = document.createElement("option");
        option.value = optionData.value;
        option.textContent = optionData.label;
        select.appendChild(option);
      });
      userCell.appendChild(select);
      const hint = document.createElement("small");
      hint.textContent = "Select the user responsible at this approval stage.";
      userCell.appendChild(hint);

      const actionCell = document.createElement("div");
      actionCell.className = "approval-level-cell";
      actionCell.dataset.approvalRow = String(rowIndex);
      const removeButton = document.createElement("button");
      removeButton.type = "button";
      removeButton.className = "remove-level-btn";
      removeButton.dataset.removeApprovalLevel = "true";
      removeButton.textContent = "Remove";
      actionCell.appendChild(removeButton);

      table.appendChild(levelCell);
      table.appendChild(userCell);
      table.appendChild(actionCell);
    };

    addButton?.addEventListener("click", addApprovalRow);

    table?.addEventListener("click", (event) => {
      const button = event.target.closest("[data-remove-approval-level]");
      if (!button) return;

      removeApprovalRow(button.closest("[data-approval-row]")?.dataset.approvalRow);
    });
  });

  const approvalModal = document.querySelector("[data-approval-modal]");
  const approvalModalForm = document.querySelector("[data-approval-modal-form]");
  const approvalModalTitle = document.querySelector("[data-approval-modal-title]");
  const approvalModalSubmit = document.querySelector("[data-approval-modal-submit]");
  const approvalRemarks = approvalModal?.querySelector("textarea[name='remarks']");

  document.querySelectorAll("[data-open-approval-modal]").forEach((button) => {
    button.addEventListener("click", () => {
      if (!approvalModal || !approvalModalForm) return;

      const action = button.dataset.approvalAction || "approve";
      approvalModalForm.action = button.dataset.approvalUrl;
      if (approvalModalTitle) approvalModalTitle.textContent = action === "reject" ? "Rejection Remarks" : "Approval Remarks";
      if (approvalModalSubmit) {
        approvalModalSubmit.textContent = action === "reject" ? "Reject" : "Approve";
        approvalModalSubmit.classList.toggle("deactive", action === "reject");
        approvalModalSubmit.classList.toggle("active", action !== "reject");
      }
      if (approvalRemarks) approvalRemarks.value = "";

      if (typeof approvalModal.showModal === "function") {
        approvalModal.showModal();
      } else {
        approvalModal.setAttribute("open", "open");
      }
    });
  });

  document.querySelectorAll("[data-close-approval-modal]").forEach((button) => {
    button.addEventListener("click", () => {
      if (!approvalModal) return;

      if (typeof approvalModal.close === "function") {
        approvalModal.close();
      } else {
        approvalModal.removeAttribute("open");
      }
    });
  });

  document.querySelectorAll("[data-vrp-bill-form]").forEach((billForm) => {
    const activityMap = JSON.parse(billForm.dataset.activityMap || "{}");
    const tciMap = JSON.parse(billForm.dataset.tciMap || "{}");
    const villageOptions = JSON.parse(billForm.dataset.villageOptions || "[]");
    const icsSelect = billForm.querySelector("[data-bill-ics-select]");
    const groupSelect = billForm.querySelector("[data-bill-activity-group]");
    const activityShell = billForm.querySelector("[data-bill-activity-shell]");
    const rowsBody = billForm.querySelector("[data-bill-activity-rows]");
    const grandUnits = billForm.querySelector("[data-grand-units]");
    const grandTotal = billForm.querySelector("[data-grand-total]");
    const tciModal = billForm.querySelector("[data-tci-modal]");
    const tciRows = billForm.querySelector("[data-tci-modal-rows]");
    let activeTciInput = null;
    let activeTciActivity = "";

    const escapeHtml = (value) => String(value || "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");

    const optionHtml = (options, selected = "") => {
      return options.map((option) => {
        const value = typeof option === "string" ? option : option.indicator;
        const isSelected = value === selected ? " selected" : "";
        return `<option value="${escapeHtml(value)}"${isSelected}>${escapeHtml(value)}</option>`;
      }).join("");
    };

    const recalculateBill = () => {
      let unitsTotal = 0;
      let amountTotal = 0;

      rowsBody?.querySelectorAll("tr:not([data-empty-bill-row])").forEach((row) => {
        const units = Number(row.querySelector("[data-bill-units]")?.value || 0);
        const rate = Number(row.querySelector("[data-bill-rate]")?.value || 0);
        const totalInput = row.querySelector("[data-bill-total]");
        const total = units * rate;

        unitsTotal += units;
        amountTotal += total;
        if (totalInput) totalInput.value = total.toFixed(2);
      });

      if (grandUnits) grandUnits.value = unitsTotal;
      if (grandTotal) grandTotal.value = amountTotal.toFixed(2);
    };

    const selectedValues = (select) => Array.from(select?.selectedOptions || []).map((option) => option.value).filter(Boolean);
    const selectedGroups = () => selectedValues(groupSelect);
    const selectedIcs = () => selectedValues(icsSelect);
    const normalizedActivityKey = (groupName) => {
      const normalizedGroup = String(groupName || "").trim().toLowerCase();
      return Object.keys(activityMap).find((key) => String(key || "").trim().toLowerCase() === normalizedGroup) || groupName;
    };

    const syncActivityGroupState = () => {
      if (!groupSelect || !icsSelect) return;

      const hasIcs = selectedIcs().length > 0;

      if (!hasIcs) {
        buildActivityRows([]);
      }

      groupSelect.dispatchEvent(new Event("chip:refresh"));
    };

    const buildActivityRows = (groupNames) => {
      if (!rowsBody) return;

      if (!groupNames.length) {
        if (activityShell) activityShell.hidden = true;
        rowsBody.innerHTML = "";
        recalculateBill();
        return;
      }

      if (activityShell) activityShell.hidden = false;
      const activities = groupNames.flatMap((groupName) => activityMap[normalizedActivityKey(groupName)] || []);
      rowsBody.innerHTML = "";

      if (activities.length === 0) {
        rowsBody.innerHTML = `<tr data-empty-bill-row><td colspan="6">No activity mapped for selected group.</td></tr>`;
        recalculateBill();
        return;
      }

      activities.forEach((activity, index) => {
        const activityName = activity.activity || "";
        rowsBody.insertAdjacentHTML("beforeend", `
          <tr>
            <td>
              ${escapeHtml(activityName)}
              <input type="hidden" name="module_record[bill_items][${index}][activity]" value="${escapeHtml(activityName)}">
            </td>
            <td>
              <button type="button" class="tci-open-btn" data-open-tci-modal data-activity="${escapeHtml(activityName)}" data-row-index="${index}">TCI</button>
              <input type="hidden" name="module_record[bill_items][${index}][tci_details]" value="[]" data-tci-details-input>
            </td>
            <td><input type="number" min="0" step="1" name="module_record[bill_items][${index}][no_of_unit]" value="0" data-bill-units></td>
            <td><input type="number" min="0" step="0.01" name="module_record[bill_items][${index}][rate]" value="0" data-bill-rate></td>
            <td><input type="number" min="0" step="0.01" name="module_record[bill_items][${index}][total_amount]" value="0" data-bill-total readonly></td>
            <td><input type="text" name="module_record[bill_items][${index}][remarks]" value=""></td>
          </tr>
        `);
      });

      recalculateBill();
    };

    const addTciRow = (data = {}) => {
      if (!tciRows) return;

      const indicators = tciMap[activeTciActivity] || tciMap.__all || [];
      const selectedIndicator = data.indicator || indicators[0]?.indicator || "";
      const mandatory = data.mandatory || indicators.find((row) => row.indicator === selectedIndicator)?.mandatory || "No";

      tciRows.insertAdjacentHTML("beforeend", `
        <tr>
          <td>
            <select data-tci-indicator>
              ${optionHtml(indicators, selectedIndicator)}
            </select>
          </td>
          <td><input type="text" value="${escapeHtml(mandatory)}" data-tci-mandatory readonly></td>
          <td>
            <select data-tci-village>
              <option value="">Select</option>
              ${optionHtml(villageOptions, data.village || "")}
            </select>
          </td>
          <td><input type="date" value="${escapeHtml(data.working_date || "")}" data-tci-date></td>
          <td><input type="number" min="0" step="1" value="${escapeHtml(data.number || "")}" data-tci-number></td>
          <td><button type="button" class="table-action danger" data-remove-tci-row>Remove</button></td>
        </tr>
      `);
    };

    icsSelect?.addEventListener("change", syncActivityGroupState);
    groupSelect?.addEventListener("change", () => buildActivityRows(selectedGroups()));

    rowsBody?.addEventListener("input", (event) => {
      if (event.target.matches("[data-bill-units], [data-bill-rate]")) recalculateBill();
    });

    rowsBody?.addEventListener("click", (event) => {
      const button = event.target.closest("[data-open-tci-modal]");
      if (!button || !tciModal) return;

      activeTciActivity = button.dataset.activity || "";
      activeTciInput = button.closest("tr")?.querySelector("[data-tci-details-input]");
      tciRows.innerHTML = "";

      let savedRows = [];
      try {
        savedRows = JSON.parse(activeTciInput?.value || "[]");
      } catch (_error) {
        savedRows = [];
      }

      if (savedRows.length) {
        savedRows.forEach((row) => addTciRow(row));
      } else {
        (tciMap[activeTciActivity] || tciMap.__all || []).forEach((row) => addTciRow(row));
      }

      if (!tciRows.children.length) {
        tciRows.innerHTML = `<tr><td colspan="6">No TCI mapped for this activity.</td></tr>`;
      }

      if (typeof tciModal.showModal === "function") {
        tciModal.showModal();
      } else {
        tciModal.setAttribute("open", "open");
      }
    });

    tciRows?.addEventListener("change", (event) => {
      if (!event.target.matches("[data-tci-indicator]")) return;

      const selected = event.target.value;
      const mandatory = (tciMap[activeTciActivity] || tciMap.__all || []).find((row) => row.indicator === selected)?.mandatory || "No";
      const mandatoryInput = event.target.closest("tr")?.querySelector("[data-tci-mandatory]");
      if (mandatoryInput) mandatoryInput.value = mandatory;
    });

    tciRows?.addEventListener("click", (event) => {
      const button = event.target.closest("[data-remove-tci-row]");
      if (button) button.closest("tr")?.remove();
    });

    billForm.querySelector("[data-add-tci-row]")?.addEventListener("click", () => addTciRow());

    billForm.querySelector("[data-apply-tci-modal]")?.addEventListener("click", () => {
      const details = Array.from(tciRows?.querySelectorAll("tr") || []).map((row) => ({
        indicator: row.querySelector("[data-tci-indicator]")?.value || "",
        mandatory: row.querySelector("[data-tci-mandatory]")?.value || "",
        village: row.querySelector("[data-tci-village]")?.value || "",
        working_date: row.querySelector("[data-tci-date]")?.value || "",
        number: row.querySelector("[data-tci-number]")?.value || ""
      })).filter((row) => row.indicator);

      if (activeTciInput) activeTciInput.value = JSON.stringify(details);
      if (typeof tciModal?.close === "function") tciModal.close();
      else tciModal?.removeAttribute("open");
    });

    billForm.querySelectorAll("[data-close-tci-modal]").forEach((button) => {
      button.addEventListener("click", () => {
        if (typeof tciModal?.close === "function") tciModal.close();
        else tciModal?.removeAttribute("open");
      });
    });

    syncActivityGroupState();
    if (selectedGroups().length) buildActivityRows(selectedGroups());
    else recalculateBill();
  });

  document.querySelectorAll("[data-list-action='pending']").forEach((button) => {
    button.addEventListener("click", () => {
      window.alert("This action is not configured yet.");
    });
  });
});
