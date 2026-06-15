document.addEventListener("turbo:load", () => {
  const vrpUiLabel = "Jeevika Jankar";
  const replaceVrpUiText = (value) => `${value || ""}`
    .replace(/\bvrp\b/gi, vrpUiLabel)
    .replace(/वीआरपी/g, vrpUiLabel)
    .replace(/व्हीआरपी/g, vrpUiLabel)
    .replace(/ଭିଆରପି/g, vrpUiLabel);

  const mobileMenuToggle = document.querySelector("[data-mobile-menu-toggle]");
  const mobileSidebar = document.querySelector("[data-mobile-sidebar]");
  const mobileSidebarBackdrop = document.querySelector("[data-mobile-sidebar-backdrop]");
  const setMobileMenuOpen = (isOpen) => {
    document.body.classList.toggle("mobile-menu-open", isOpen);
    mobileMenuToggle?.setAttribute("aria-expanded", isOpen ? "true" : "false");
  };

  mobileMenuToggle?.addEventListener("click", () => {
    setMobileMenuOpen(!document.body.classList.contains("mobile-menu-open"));
  });

  mobileSidebarBackdrop?.addEventListener("click", () => setMobileMenuOpen(false));
  mobileSidebar?.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => setMobileMenuOpen(false));
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") setMobileMenuOpen(false);
  });

  setMobileMenuOpen(false);

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

  const capitalizeFirstLetter = (input) => {
    const value = input.value;
    if (!value) return;

    const capitalized = value.charAt(0).toUpperCase() + value.slice(1);
    if (capitalized === value) return;

    const cursorStart = input.selectionStart;
    const cursorEnd = input.selectionEnd;
    input.value = capitalized;
    input.setSelectionRange(cursorStart, cursorEnd);
  };

  document.querySelectorAll("[data-capitalize-first]").forEach((input) => {
    capitalizeFirstLetter(input);
    input.addEventListener("input", () => capitalizeFirstLetter(input));
    input.form?.addEventListener("submit", () => capitalizeFirstLetter(input));
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
        window.alert(replaceVrpUiText("Please select one VRP only"));
        return;
      }

      window.location.href = `/vrps/${selected[0].value}/edit`;
    });
  }

  const csrfToken = document.querySelector("meta[name='csrf-token']")?.content;

  document.querySelectorAll("[data-dashboard-training-filter-select]").forEach((select) => {
    select.addEventListener("change", () => {
      const form = select.closest("form");
      if (!form) return;

      if (select.hasAttribute("data-dashboard-training-month-select")) {
        const subActivitySelect = form.querySelector("[data-dashboard-training-sub-activity-select]");
        if (subActivitySelect) subActivitySelect.value = "";
      }

      if (typeof form.requestSubmit === "function") {
        form.requestSubmit();
        return;
      }

      form.submit();
    });
  });

  const trainingDrilldown = document.querySelector("[data-training-participation-drilldown]");
  if (trainingDrilldown) {
    const drilldownTitle = trainingDrilldown.querySelector("[data-training-participation-drilldown-title]");
    const drilldownCount = trainingDrilldown.querySelector("[data-training-participation-drilldown-count]");
    const drilldownList = trainingDrilldown.querySelector("[data-training-participation-drilldown-list]");
    const trainingTriggers = Array.from(document.querySelectorAll("[data-training-participation-trigger]"));

    const statusLabels = {
      green: "Green Farmers",
      yellow: "Yellow Farmers",
      red: "Red Farmers"
    };

    const formatCountLabel = (count) => `${count} farmer${count === 1 ? "" : "s"}`;
    const formatTrainingDate = (value) => {
      const text = `${value || ""}`.trim();
      if (!text) return "-";

      const match = text.match(/^(\d{4})-(\d{2})-(\d{2})/);
      if (!match) return text;

      return `${match[3]}-${match[2]}-${match[1]}`;
    };

    const clearActiveTrainingTrigger = () => {
      trainingTriggers.forEach((button) => {
        button.classList.remove("is-active");
        button.setAttribute("aria-pressed", "false");
      });
    };

    const renderTrainingDetails = (details, status) => {
      const farmers = Array.isArray(details?.[status]) ? details[status] : [];
      if (!drilldownList) return;

      drilldownList.innerHTML = "";

      if (!farmers.length) {
        const row = document.createElement("tr");
        const cell = document.createElement("td");
        cell.colSpan = 7;
        cell.textContent = "No farmers found for this status.";
        row.appendChild(cell);
        drilldownList.appendChild(row);
        return;
      }

      farmers.forEach((farmer) => {
        const row = document.createElement("tr");
        const farmerCell = document.createElement("td");

        const farmerName = document.createElement("div");
        farmerName.textContent = farmer.farmer_name || "-";
        farmerCell.appendChild(farmerName);

        if (farmer.father_name) {
          const fatherName = document.createElement("small");
          fatherName.textContent = `Father: ${farmer.father_name}`;
          farmerCell.appendChild(fatherName);
        }

        [
          farmerCell,
          farmer.ics || "-",
          farmer.village || "-",
          farmer.vrp || "-",
          farmer.attendance_count ?? 0,
          farmer.status_label || statusLabels[status] || status,
          formatTrainingDate(farmer.work_date)
        ].forEach((value, index) => {
          if (index === 0) {
            row.appendChild(value);
            return;
          }

          const cell = document.createElement("td");
          cell.textContent = `${value}`;
          row.appendChild(cell);
        });

        drilldownList.appendChild(row);
      });
    };

    const activateTrainingDrilldown = (button) => {
      let details = {};
      try {
        details = JSON.parse(button.dataset.trainingParticipationDetails || "{}");
      } catch (_error) {
        details = {};
      }

      const status = button.dataset.trainingParticipationStatus || "green";
      const rows = Array.isArray(details[status]) ? details[status] : [];

      clearActiveTrainingTrigger();
      button.classList.add("is-active");
      button.setAttribute("aria-pressed", "true");

      if (drilldownTitle) {
        drilldownTitle.textContent = button.dataset.trainingParticipationTitle || statusLabels[status] || "Farmer Details";
      }

      if (drilldownCount) {
        drilldownCount.textContent = formatCountLabel(rows.length);
      }

      renderTrainingDetails(details, status);
    };

    trainingTriggers.forEach((button) => {
      button.setAttribute("aria-pressed", "false");
      button.addEventListener("click", () => activateTrainingDrilldown(button));
    });
  }

  document.querySelectorAll("[data-training-row-toggle]").forEach((button) => {
    button.addEventListener("click", () => {
      const targetId = button.dataset.trainingRowTarget;
      if (!targetId) return;

      const target = document.getElementById(targetId);
      if (!target) return;

      const isOpen = !target.hasAttribute("hidden");
      document.querySelectorAll("[data-training-row-details]").forEach((detail) => {
        detail.setAttribute("hidden", "");
      });
      document.querySelectorAll("[data-training-row-toggle]").forEach((toggle) => {
        toggle.setAttribute("aria-expanded", "false");
      });

      if (isOpen) {
        target.setAttribute("hidden", "");
        return;
      }

      target.removeAttribute("hidden");
      button.setAttribute("aria-expanded", "true");
    });
  });

  const themeToggle = document.querySelector("[data-theme-toggle]");
  const themeToggleIcon = document.querySelector("[data-theme-toggle-icon]");
  const themeToggleLabel = document.querySelector("[data-theme-toggle-label]");
  const applyTheme = (theme) => {
    const nextTheme = theme === "dark" ? "dark" : "light";
    document.documentElement.dataset.theme = nextTheme;
    localStorage.setItem("vrp_theme", nextTheme);
    if (themeToggleIcon) themeToggleIcon.textContent = nextTheme === "dark" ? "☀" : "☾";
    if (themeToggleLabel) themeToggleLabel.textContent = nextTheme === "dark" ? "Light" : "Dark";
    themeToggle?.setAttribute("aria-label", nextTheme === "dark" ? "Switch to light mode" : "Switch to dark mode");
  };

  applyTheme(localStorage.getItem("vrp_theme") || "light");
  themeToggle?.addEventListener("click", () => {
    applyTheme(document.documentElement.dataset.theme === "dark" ? "light" : "dark");
  });

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

      deleteSelected(paths, replaceVrpUiText("Delete selected VRP record(s)?"));
    });
  }

  const vrpSendButton = document.querySelector("[data-vrp-send-selected]");
  if (vrpSendButton) {
    vrpSendButton.addEventListener("click", () => {
      const selected = Array.from(document.querySelectorAll("[data-vrp-row-select]:checked"));

      if (selected.length !== 1) {
        window.alert(replaceVrpUiText("Please select one VRP only"));
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
        window.alert(replaceVrpUiText("Please select at least one VRP"));
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
        window.alert(replaceVrpUiText("Some selected VRP record(s) could not be updated."));
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

  const moduleRowPaths = (checkbox) => {
    if (!checkbox.dataset.moduleRowPaths) return [checkbox.value];

    try {
      const paths = JSON.parse(checkbox.dataset.moduleRowPaths);
      return Array.isArray(paths) && paths.length ? paths : [checkbox.value];
    } catch (_error) {
      return [checkbox.value];
    }
  };

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
        .flatMap((checkbox) => moduleRowPaths(checkbox))
        .map((path) => path.replace(/\/edit$/, ""));

      deleteSelected(paths, "Delete selected record(s)?");
    });
  }

  const selectedBillRows = () => Array.from(document.querySelectorAll("[data-module-row-select]:checked"))
    .filter((checkbox) => checkbox.dataset.billSendPath || checkbox.dataset.billDeletePath);

  const patchBillRows = async (paths, emptyMessage) => {
    if (!paths.length) {
      window.alert(emptyMessage);
      return;
    }

    const responses = await Promise.all(paths.map((path) => fetch(path, {
      method: "PATCH",
      credentials: "same-origin",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
      }
    })));

    if (responses.some((response) => !(response.ok || response.redirected))) {
      window.alert("Some selected bill(s) could not be updated.");
      return;
    }

    window.location.reload();
  };

  document.querySelector("[data-bill-send-selected]")?.addEventListener("click", () => {
    const paths = selectedBillRows().map((checkbox) => checkbox.dataset.billSendPath).filter(Boolean);
    patchBillRows(paths, "Please select at least one bill");
  });

  document.querySelectorAll("[data-bill-state-selected]").forEach((button) => {
    button.addEventListener("click", () => {
      const state = button.dataset.billStateSelected;
      const paths = selectedBillRows()
        .map((checkbox) => state === "Inactive" ? checkbox.dataset.billInactivePath : checkbox.dataset.billActivePath)
        .filter(Boolean);
      patchBillRows(paths, "Please select at least one bill");
    });
  });

  document.querySelector("[data-bill-delete-selected]")?.addEventListener("click", () => {
    const paths = selectedBillRows().map((checkbox) => checkbox.dataset.billDeletePath).filter(Boolean);
    deleteSelected(paths, "Delete selected bill(s)?");
  });

  document.querySelectorAll("[data-module-status-selected]").forEach((button) => {
    button.addEventListener("click", async () => {
      const selected = Array.from(document.querySelectorAll("[data-module-row-select]:checked"));
      const status = button.dataset.moduleStatusSelected;

      if (selected.length === 0) {
        window.alert("Please select at least one record");
        return;
      }

      const paths = selected.flatMap((checkbox) => moduleRowPaths(checkbox));
      const responses = await Promise.all(paths.map((selectedPath) => {
        const path = `${selectedPath.replace(/\/edit$/, "/set_status")}?status=${encodeURIComponent(status)}`;
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
    const parentOfficeSelect = formShell.querySelector("[data-parent-office-select]");
    const officeCategorySelect = formShell.querySelector("[data-office-category-select]");
    const officeNameSelect = formShell.querySelector("[data-office-name-select]");
    const subOfficeSelect = formShell.querySelector("[data-sub-office-name-select]");
    const officeSelect = subOfficeSelect || officeNameSelect || formShell.querySelector("[data-office-select]");
    const officeUserSelect = formShell.querySelector("[data-office-user-select]");
    const approvalOfficeCascade = formShell.dataset.approvalOfficeCascade === "true";
    if (!stakeholderSelect && !stakeholderRoleSelect && !roleSelect && !roleNameSelect && !userManagementRoleSelect && !personTypeSelect && !parentOfficeSelect && !officeCategorySelect && !officeNameSelect && !subOfficeSelect && !officeSelect && !officeUserSelect) return;

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
    let officeUserMappings = [];
    try {
      officeUserMappings = JSON.parse(formShell.dataset.officeUserMap || "[]");
    } catch (_error) {
      officeUserMappings = [];
    }
    const selectedDisplayName = (select) => {
      if (!select) return "";

      const selectedOption = select.options[select.selectedIndex];
      return displayNameFromLabel(selectedOption?.textContent || select.value);
    };
    const initialParentOfficeOptions = parentOfficeSelect
      ? Array.from(parentOfficeSelect.options).map((option) => option.value).filter(Boolean)
      : [];
    const initialOfficeNameOptions = officeNameSelect
      ? Array.from(officeNameSelect.options).map((option) => option.value).filter(Boolean)
      : [];
    const initialOfficeUserOptions = officeUserSelect
      ? Array.from(officeUserSelect.options)
          .filter((option) => option.value)
          .map((option) => makeOption(option.value, option.textContent))
      : [];

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

    const refreshParentOffices = () => {
      if (!parentOfficeSelect) return;
      const normalizedStakeholder = normalizeOption(stakeholderSelect?.value);
      const normalizedStakeholderRole = normalizeOption(stakeholderRoleSelect?.value);
      const mappedParentOffices = uniquePresent(
        officeMappings
          .filter((mapping) => {
            const mappedStakeholder = normalizeOption(mapping.stakeholder);
            const mappedStakeholderRole = normalizeOption(mapping.stakeholder_role);
            const stakeholderMatches = !normalizedStakeholder || !mappedStakeholder || mappedStakeholder === normalizedStakeholder;
            const stakeholderRoleMatches = !normalizedStakeholderRole || !mappedStakeholderRole || mappedStakeholderRole === normalizedStakeholderRole;
            return stakeholderMatches && stakeholderRoleMatches;
          })
          .map((mapping) => mapping.parent_office || mapping.office_category || (!mapping.office_name ? mapping.office : ""))
      );
      const parentOffices = uniquePresent(initialParentOfficeOptions.concat(mappedParentOffices));
      replaceSelectOptions(parentOfficeSelect, parentOffices, "Select Parent Office Name");
    };

    const officeMappingMatches = (mapping, stakeholder, parentOffice, officeCategory = "") => {
      const normalizedStakeholder = normalizeOption(stakeholder);
      const normalizedStakeholderRole = normalizeOption(stakeholderRoleSelect?.value);
      const normalizedParentOffice = normalizeOption(parentOffice);
      const normalizedOfficeCategory = normalizeOption(officeCategory);

      const mappedStakeholder = normalizeOption(mapping.stakeholder);
      const mappedStakeholderRole = normalizeOption(mapping.stakeholder_role);
      const mappedParentOffice = normalizeOption(mapping.parent_office);
      const mappedOfficeCategory = normalizeOption(mapping.office_category || mapping.category_name || (!mapping.office_name ? mapping.office : ""));
      const stakeholderMatches = approvalOfficeCascade
        ? mappedStakeholder === normalizedStakeholder
        : (!normalizedStakeholder || !mappedStakeholder || mappedStakeholder === normalizedStakeholder);
      const stakeholderRoleMatches = !normalizedStakeholderRole || !mappedStakeholderRole || mappedStakeholderRole === normalizedStakeholderRole;
      const parentOfficeMatches = !normalizedParentOffice || !mappedParentOffice || mappedParentOffice === normalizedParentOffice;
      const officeCategoryMatches = approvalOfficeCascade
        ? mappedOfficeCategory === normalizedOfficeCategory
        : (!normalizedOfficeCategory || !mappedOfficeCategory || mappedOfficeCategory === normalizedOfficeCategory);
      return stakeholderMatches && stakeholderRoleMatches && parentOfficeMatches && officeCategoryMatches;
    };

    const refreshOfficeNames = () => {
      if (!officeNameSelect) return;

      const normalizedStakeholder = normalizeOption(stakeholderSelect?.value);
      const normalizedParentOffice = normalizeOption(parentOfficeSelect?.value);
      if (!normalizedStakeholder && !normalizedParentOffice) {
        replaceSelectOptions(officeNameSelect, [], "Select Office Name");
        refreshOffices();
        return;
      }

      const officeNames = uniquePresent(
        officeMappings
          .filter((mapping) => {
            const mappedStakeholder = normalizeOption(mapping.stakeholder);
            const mappedParentOffice = normalizeOption(mapping.parent_office);
            const hasSubOffice = normalizeOption(mapping.office_name || mapping.sub_office_name);
            const stakeholderMatches = !normalizedStakeholder || !mappedStakeholder || mappedStakeholder === normalizedStakeholder;
            const parentOfficeMatches = !normalizedParentOffice || !mappedParentOffice || mappedParentOffice === normalizedParentOffice;
            return stakeholderMatches && parentOfficeMatches && !hasSubOffice;
          })
          .map((mapping) => mapping.office_category || mapping.category_name || mapping.office)
      );
      const options = normalizedStakeholder || normalizedParentOffice ? officeNames : uniquePresent(initialOfficeNameOptions.concat(officeNames));
      replaceSelectOptions(officeNameSelect, options, "Select Office Name");
      refreshOffices();
    };

    const refreshOfficeCategories = () => {
      if (!officeCategorySelect) return;
      const normalizedStakeholder = normalizeOption(stakeholderSelect?.value);
      const normalizedParentOffice = normalizeOption(parentOfficeSelect?.value);
      if (approvalOfficeCascade && !normalizedStakeholder) {
        replaceSelectOptions(officeCategorySelect, [], "Select Office Category");
        refreshOffices();
        return;
      }

      const officeCategories = uniquePresent(
        officeMappings
          .filter((mapping) => {
            const mappedStakeholder = normalizeOption(mapping.stakeholder);
            const mappedParentOffice = normalizeOption(mapping.parent_office);
            const stakeholderMatches = approvalOfficeCascade
              ? mappedStakeholder === normalizedStakeholder
              : (!normalizedStakeholder || !mappedStakeholder || mappedStakeholder === normalizedStakeholder);
            const parentOfficeMatches = !normalizedParentOffice || !mappedParentOffice || mappedParentOffice === normalizedParentOffice;
            return stakeholderMatches && parentOfficeMatches;
          })
          .map((mapping) => mapping.office_category || mapping.category_name || (!mapping.office_name ? mapping.office : ""))
      );
      replaceSelectOptions(officeCategorySelect, officeCategories, "Select Office Category");
      refreshOffices();
    };

    const refreshOffices = () => {
      if (!officeSelect) return;
      const selectedStakeholder = stakeholderSelect?.value || "";
      const selectedOfficeCategory = officeCategorySelect?.value || officeNameSelect?.value || "";
      if (subOfficeSelect && !normalizeOption(officeNameSelect?.value)) {
        replaceSelectOptions(subOfficeSelect, [], "Select Sub Office Name");
        refreshOfficeUsers();
        return;
      }

      if (approvalOfficeCascade && (!normalizeOption(selectedStakeholder) || !normalizeOption(selectedOfficeCategory))) {
        replaceSelectOptions(officeSelect, [], subOfficeSelect ? "Select Sub Office Name" : (officeNameSelect ? "Select Office Name" : "Select Office"));
        refreshOfficeUsers();
        return;
      }

      const offices = uniquePresent(
        officeMappings
          .filter((mapping) => {
            const hasSubOffice = normalizeOption(mapping.office_name || mapping.sub_office_name);
            return officeMappingMatches(mapping, selectedStakeholder, parentOfficeSelect?.value, selectedOfficeCategory) &&
              (!subOfficeSelect || hasSubOffice);
          })
          .map((mapping) => {
            if (subOfficeSelect) return mapping.office_name || mapping.sub_office_name || "";
            if (officeNameSelect) return mapping.office_name || "";

            return mapping.office || mapping.office_name || mapping.office_category;
          })
      );
      replaceSelectOptions(officeSelect, offices, subOfficeSelect ? "Select Sub Office Name" : (officeNameSelect ? "Select Office Name" : "Select Office"));
      refreshOfficeUsers();
    };

    const refreshOfficeUsers = () => {
      if (!officeUserSelect) return;

      const selectedOfficeCategory = normalizeOption(officeCategorySelect?.value);
      const selectedOfficeName = normalizeOption(officeSelect?.value);
      const selectedStakeholder = normalizeOption(stakeholderSelect?.value);
      if (approvalOfficeCascade && (!selectedStakeholder || !selectedOfficeCategory || !selectedOfficeName)) {
        replaceSelectOptions(officeUserSelect, [], "Select User Name");
        return;
      }

      const filteredUsers = officeUserMappings.filter((user) => {
        const mappedStakeholder = normalizeOption(user.stakeholder || user.stakeholder_name || user.stakeholder_category);
        const mappedOfficeCategory = normalizeOption(user.office_category || user.category_name);
        const mappedOfficeName = normalizeOption(user.office_name || user.office);
        const stakeholderMatches = approvalOfficeCascade
          ? mappedStakeholder === selectedStakeholder
          : (!selectedStakeholder || !mappedStakeholder || mappedStakeholder === selectedStakeholder);
        const categoryMatches = approvalOfficeCascade
          ? mappedOfficeCategory === selectedOfficeCategory
          : (!selectedOfficeCategory || !mappedOfficeCategory || mappedOfficeCategory === selectedOfficeCategory);
        const officeMatches = !selectedOfficeName || mappedOfficeName === selectedOfficeName;
        return stakeholderMatches && categoryMatches && officeMatches;
      });
      const users = uniqueOptions(
        (filteredUsers.length ? filteredUsers : (!selectedOfficeCategory && !selectedOfficeName ? officeUserMappings : []))
          .map((user) => makeOption(user.value, user.label || user.value))
      );
      const options = users.length ? users : (officeUserMappings.length ? [] : initialOfficeUserOptions);
      replaceSelectOptions(officeUserSelect, options, options.length ? "Select User Name" : "No User saved yet");
    };

    stakeholderSelect?.addEventListener("change", () => {
      if (stakeholderRoleSelect) stakeholderRoleSelect.dataset.selectedValue = "";
      if (roleSelect) roleSelect.dataset.selectedValue = "";
      if (roleNameSelect) roleNameSelect.dataset.selectedValue = "";
      if (userManagementRoleSelect) userManagementRoleSelect.dataset.selectedValue = "";
      if (personTypeSelect) personTypeSelect.dataset.selectedValue = "";
      if (parentOfficeSelect) parentOfficeSelect.dataset.selectedValue = "";
      if (officeCategorySelect) officeCategorySelect.dataset.selectedValue = "";
      if (officeNameSelect) officeNameSelect.dataset.selectedValue = "";
      if (subOfficeSelect) subOfficeSelect.dataset.selectedValue = "";
      if (officeSelect) officeSelect.dataset.selectedValue = "";
      refreshStakeholderRoles();
      refreshRoles();
      refreshRoleNames();
      refreshUserManagementRoles();
      refreshPersonTypes();
      refreshParentOffices();
      refreshOfficeCategories();
      refreshOfficeNames();
      refreshOffices();
    });
    parentOfficeSelect?.addEventListener("change", () => {
      if (officeCategorySelect) officeCategorySelect.dataset.selectedValue = "";
      if (officeNameSelect) officeNameSelect.dataset.selectedValue = "";
      if (subOfficeSelect) subOfficeSelect.dataset.selectedValue = "";
      if (officeSelect) officeSelect.dataset.selectedValue = "";
      refreshOfficeCategories();
      refreshOfficeNames();
      refreshOffices();
    });
    officeCategorySelect?.addEventListener("change", () => {
      if (officeSelect) officeSelect.dataset.selectedValue = "";
      if (officeUserSelect) officeUserSelect.dataset.selectedValue = "";
      refreshOffices();
    });
    officeNameSelect?.addEventListener("change", () => {
      if (!subOfficeSelect) return;

      subOfficeSelect.dataset.selectedValue = "";
      if (officeUserSelect) officeUserSelect.dataset.selectedValue = "";
      refreshOffices();
    });
    officeSelect?.addEventListener("change", () => {
      if (officeUserSelect) officeUserSelect.dataset.selectedValue = "";
      refreshOfficeUsers();
    });
    stakeholderRoleSelect?.addEventListener("change", () => {
      if (roleSelect) roleSelect.dataset.selectedValue = "";
      if (roleNameSelect) roleNameSelect.dataset.selectedValue = "";
      if (userManagementRoleSelect) userManagementRoleSelect.dataset.selectedValue = "";
      if (personTypeSelect) personTypeSelect.dataset.selectedValue = "";
      if (parentOfficeSelect) parentOfficeSelect.dataset.selectedValue = "";
      if (officeCategorySelect) officeCategorySelect.dataset.selectedValue = "";
      if (officeNameSelect) officeNameSelect.dataset.selectedValue = "";
      if (subOfficeSelect) subOfficeSelect.dataset.selectedValue = "";
      if (officeSelect) officeSelect.dataset.selectedValue = "";
      refreshRoles();
      refreshRoleNames();
      refreshUserManagementRoles();
      refreshPersonTypes();
      refreshParentOffices();
      refreshOfficeCategories();
      refreshOfficeNames();
      refreshOffices();
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
    refreshParentOffices();
    refreshOfficeCategories();
    refreshOfficeNames();
    refreshOffices();
    refreshOfficeUsers();
  });

  document.querySelectorAll("[data-parent-office-form]").forEach((formShell) => {
    const stakeholderSelect = formShell.querySelector("[data-parent-office-stakeholder-select]");
    const parentOfficeTypeSelect = formShell.querySelector("[data-parent-office-type-select]");
    const parentOfficeSelect = formShell.querySelector("[data-parent-office-select]");
    if (!parentOfficeTypeSelect && !parentOfficeSelect) return;

    let parentOfficeMappings = [];
    try {
      parentOfficeMappings = JSON.parse(formShell.dataset.parentOfficeMap || "[]");
    } catch (_error) {
      parentOfficeMappings = [];
    }

    const parentOfficeLabel = parentOfficeSelect?.closest("label");
    const initialParentOfficeOptions = parentOfficeSelect
      ? Array.from(parentOfficeSelect.options).map((option) => option.value).filter(Boolean)
      : [];

    const parentOfficeOptions = () => {
      const options = uniquePresent(
        parentOfficeMappings
          .map((mapping) => mapping.parent_office_name)
      );

      return options.length ? options : initialParentOfficeOptions;
    };

    const refreshParentOfficeField = () => {
      if (!parentOfficeSelect) return;

      const selectedType = normalizeOption(parentOfficeTypeSelect?.value);
      const isSubParentOffice = selectedType === normalizeOption("Sub Parent Office");

      if (parentOfficeLabel) parentOfficeLabel.hidden = false;
      parentOfficeSelect.disabled = !isSubParentOffice;
      parentOfficeSelect.required = isSubParentOffice;
      if (!isSubParentOffice) {
        parentOfficeSelect.value = "";
        parentOfficeSelect.dataset.selectedValue = "";
        return;
      }

      replaceSelectOptions(parentOfficeSelect, parentOfficeOptions(), "Select Parent Office");
    };

    stakeholderSelect?.addEventListener("change", () => {
      if (parentOfficeSelect) parentOfficeSelect.dataset.selectedValue = "";
      refreshParentOfficeField();
    });

    parentOfficeTypeSelect?.addEventListener("change", () => {
      if (parentOfficeSelect) parentOfficeSelect.dataset.selectedValue = "";
      refreshParentOfficeField();
    });

    refreshParentOfficeField();
  });

  document.querySelectorAll("[data-vrp-office-form]").forEach((formShell) => {
    const officeCategorySelect = formShell.querySelector("[data-vrp-office-category]");
    const officeNameSelect = formShell.querySelector("[data-vrp-office-name]");
    const clusterInchargeSelect = formShell.querySelector("[data-vrp-cluster-incharge]");
    if (!officeCategorySelect && !officeNameSelect && !clusterInchargeSelect) return;

    let officeMappings = [];
    let clusterUsers = [];
    try {
      officeMappings = JSON.parse(formShell.dataset.officeMap || "[]");
    } catch (_error) {
      officeMappings = [];
    }
    try {
      clusterUsers = JSON.parse(formShell.dataset.clusterUsers || "[]");
    } catch (_error) {
      clusterUsers = [];
    }

    const mappedOfficeNames = (officeCategory) => {
      const normalizedOfficeCategory = normalizeOption(officeCategory);
      return uniquePresent(
        officeMappings
          .filter((mapping) => {
            const mappedOfficeCategory = normalizeOption(mapping.office_category || mapping.category_name);
            return !normalizedOfficeCategory || mappedOfficeCategory === normalizedOfficeCategory;
          })
          .map((mapping) => mapping.office_name || mapping.office)
      );
    };

    const mappedClusterUsers = (officeCategory, officeName) => {
      const normalizedOfficeCategory = normalizeOption(officeCategory);
      const normalizedOfficeName = normalizeOption(officeName);
      return uniqueOptions(
        clusterUsers
          .filter((user) => {
            const categoryMatches = !normalizedOfficeCategory || normalizeOption(user.office_category) === normalizedOfficeCategory;
            const officeMatches = !normalizedOfficeName || normalizeOption(user.office_name || user.office) === normalizedOfficeName;
            return categoryMatches && officeMatches;
          })
          .map((user) => makeOption(user.value, user.label || user.value))
      );
    };

    const refreshOfficeNames = () => {
      if (!officeNameSelect) return;

      const offices = mappedOfficeNames(officeCategorySelect?.value);
      replaceSelectOptions(officeNameSelect, offices, "Select TO");
      refreshClusterIncharges();
    };

    const refreshClusterIncharges = () => {
      if (!clusterInchargeSelect) return;

      const users = mappedClusterUsers(officeCategorySelect?.value, officeNameSelect?.value);
      replaceSelectOptions(clusterInchargeSelect, users, "Select Cluster Incharge");
    };

    officeCategorySelect?.addEventListener("change", () => {
      if (officeNameSelect) officeNameSelect.dataset.selectedValue = "";
      if (clusterInchargeSelect) clusterInchargeSelect.dataset.selectedValue = "";
      refreshOfficeNames();
      refreshClusterIncharges();
    });
    officeNameSelect?.addEventListener("change", () => {
      if (clusterInchargeSelect) clusterInchargeSelect.dataset.selectedValue = "";
      refreshClusterIncharges();
    });

    refreshOfficeNames();
    refreshClusterIncharges();
  });

  document.querySelectorAll("[data-max-size-mb]").forEach((input) => {
    input.addEventListener("change", () => {
      const maxSizeMb = Number(input.dataset.maxSizeMb || 0);
      const file = input.files?.[0];
      if (!maxSizeMb || !file) return;

      if (file.size > maxSizeMb * 1024 * 1024) {
        window.alert(`Photo upload max ${maxSizeMb} MB allowed.`);
        input.value = "";
      }
    });
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

  const locationSelectedValuesFromDataset = (select) => {
    if (!select) return [];

    if (select.dataset.selectedValues) {
      try {
        const values = JSON.parse(select.dataset.selectedValues);
        if (Array.isArray(values)) return values.map((value) => String(value));
      } catch (_error) {
        return select.dataset.selectedValues.split(",").map((value) => value.trim());
      }
    }

    return select.dataset.selectedValue ? [select.dataset.selectedValue] : [];
  };

  const selectedLocationValues = (select) => {
    if (!select) return [];

    const selectedOptions = Array.from(select.selectedOptions || []).filter((option) => option.value);
    if (selectedOptions.length === 0) return [];

    return uniquePresent(selectedOptions.flatMap((option) => [option.value, option.textContent]));
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

    const selectedValues = uniquePresent(locationSelectedValuesFromDataset(select).concat(selectedLocationValues(select)));
    const blankOption = originalOptions.find((option) => option.value === "") || { value: "", label: `Select ${level}` };
    const filteredOptions = originalOptions.filter((option) => {
      if (option.value === "") return false;
      return allowedRows.some((row) => optionMatchesLocationRow(option, row, level));
    });

    const parentSelected = (locationParents[level] || []).every((parentLevel) => {
      return selectedLocationValues(select.closest("[data-location-form]")?.querySelector(`[data-location-level="${parentLevel}"]`)).length > 0;
    });
    const hasParents = (locationParents[level] || []).length > 0;
    const fallbackOptions = originalOptions.filter((option) => option.value !== "");
    const mergedOptions = [...filteredOptions];
    fallbackOptions.forEach((option) => {
      if (!mergedOptions.some((existing) => normalizeOption(existing.value) === normalizeOption(option.value))) {
        mergedOptions.push(option);
      }
    });
    const finalOptions = hasParents && !parentSelected
      ? []
      : (hasParents ? mergedOptions : fallbackOptions);
    finalOptions.sort((left, right) => left.label.localeCompare(right.label, undefined, { sensitivity: "base" }));
    select.innerHTML = "";

    const prompt = document.createElement("option");
    prompt.value = "";
    prompt.textContent = blankOption.label;
    select.appendChild(prompt);

    finalOptions.forEach((optionData) => {
      const option = document.createElement("option");
      option.value = optionData.value;
      option.textContent = optionData.label;
      option.selected = selectedValues.some((selected) => optionData.value === selected || optionData.label === selected);
      select.appendChild(option);
    });
    select.dispatchEvent(new Event("chip:refresh"));
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

    const syncLocationPrimary = (level) => {
      const select = selects[level];
      const hidden = formShell.querySelector(`[data-location-primary="${level}"]`);
      if (!select || !hidden) return;

      hidden.value = Array.from(select.selectedOptions || []).find((option) => option.value)?.value || "";
    };

    const syncLocationPrimaries = () => {
      Object.keys(selects).forEach(syncLocationPrimary);
    };

    const refreshLocationLevel = (level) => {
      if (!selects[level]) return;

      const key = locationKeys[level];
      const allowedRows = mappings.filter((row) => row[key] && locationRowMatchesParents(row, selects, level));
      replaceLocationOptions(selects[level], originalOptions[level], allowedRows, level);
      syncLocationPrimary(level);
    };

    const refreshFrom = (level) => {
      const startIndex = locationLevels.indexOf(level) + 1;
      locationLevels.slice(startIndex).forEach((childLevel) => {
        if (selects[childLevel]) {
          selects[childLevel].dataset.selectedValue = "";
          selects[childLevel].dataset.selectedValues = "[]";
        }
        refreshLocationLevel(childLevel);
      });
      syncLocationPrimaries();
    };

    locationLevels.forEach((level) => {
      selects[level]?.addEventListener("change", () => {
        delete selects[level].dataset.selectedValue;
        delete selects[level].dataset.selectedValues;
        syncLocationPrimary(level);
        refreshFrom(level);
      });
    });

    locationLevels.slice(1).forEach(refreshLocationLevel);
    syncLocationPrimaries();
  });

  document.querySelectorAll("[data-training-target-form]").forEach((formShell) => {
    let mappings = [];
    let monthOptions = [];
    try {
      mappings = JSON.parse(formShell.dataset.trainingTargetMap || "[]");
    } catch (_error) {
      mappings = [];
    }
    try {
      monthOptions = JSON.parse(formShell.dataset.trainingMonthOptions || "[]");
    } catch (_error) {
      monthOptions = [];
    }

	    const monthSelect = formShell.querySelector("[data-training-target-month]");
	    const icsSelect = formShell.querySelector("[data-training-target-ics]");
	    const villageSelect = formShell.querySelector("[data-training-target-village]");
	    const mainActivitySelect = formShell.querySelector("[data-training-main-activity]");
	    const subActivitySelect = formShell.querySelector("[data-training-sub-activity]");
	    const farmerPanel = formShell.querySelector("[data-training-farmer-panel]");
	    const farmerList = formShell.querySelector("[data-training-farmer-list]");
	    const farmerSelectAll = formShell.querySelector("[data-training-farmer-select-all]");
	    const farmerSelectAllButton = formShell.querySelector("[data-training-farmer-select-all-button]");
	    const farmerCount = formShell.querySelector("[data-training-farmer-count]");
	    const farmerCountInput = formShell.querySelector("[data-training-farmer-count-input]");
	    const geoLatitudeInput = formShell.querySelector("[data-training-geo-latitude]");
	    const geoLongitudeInput = formShell.querySelector("[data-training-geo-longitude]");
	    if (!icsSelect || !villageSelect) return;
	    const selectedFarmerIds = new Set(JSON.parse(farmerPanel?.dataset.selectedFarmerIds || "[]").map(String));

	    const escapeHtml = (value) => String(value || "")
	      .replaceAll("&", "&amp;")
	      .replaceAll("<", "&lt;")
	      .replaceAll(">", "&gt;")
	      .replaceAll('"', "&quot;")
	      .replaceAll("'", "&#039;");

    const selectOption = (select, option, selected) => {
      const value = optionValue(option);
      const label = optionLabel(option);
      select.selected = normalizeOption(value) === normalizeOption(selected) ||
        normalizeOption(label) === normalizeOption(selected);
    };

    const fillTrainingSelect = (select, options, placeholder) => {
      const selected = select.dataset.selectedValue || select.value;
      select.innerHTML = "";

      const blank = document.createElement("option");
      blank.value = "";
      blank.textContent = options.length ? placeholder : `No ${placeholder.replace(/^Select\s+/i, "")} saved yet`;
      select.appendChild(blank);

      options.forEach((optionData) => {
        const option = document.createElement("option");
        option.value = optionValue(optionData);
        option.textContent = optionLabel(optionData);
        selectOption(option, optionData, selected);
        select.appendChild(option);
      });
    };

    const targetRowsForSelection = ({
      requireMonth = false,
      requireVillage = false,
      includeMainActivity = true,
      requireMainActivity = false,
      includeSubActivity = true,
      requireSubActivity = false
    } = {}) => {
      const selectedMonth = normalizeOption(monthSelect?.value);
      const selectedIcs = normalizeOption(icsSelect.value);
      const selectedVillage = normalizeOption(villageSelect.value);
      const selectedMainActivity = includeMainActivity ? normalizeOption(mainActivitySelect?.value) : "";
      const selectedSubActivity = includeSubActivity ? normalizeOption(subActivitySelect?.value) : "";

      if (requireMonth && !selectedMonth) return [];
      if (requireVillage && !selectedVillage) return [];
      if (requireMainActivity && !selectedMainActivity) return [];
      if (requireSubActivity && !selectedSubActivity) return [];

      return mappings.filter((mapping) => {
        const monthMatches = !selectedMonth || normalizeOption(mapping.month) === selectedMonth;
        const icsMatches = !selectedIcs || normalizeOption(mapping.ics) === selectedIcs;
        const villageMatches = !selectedVillage || normalizeOption(mapping.village) === selectedVillage;
        const mainActivityMatches = !selectedMainActivity || normalizeOption(mapping.main_activity) === selectedMainActivity;
        const subActivityMatches = !selectedSubActivity || normalizeOption(mapping.sub_activity) === selectedSubActivity;
        return monthMatches && icsMatches && villageMatches && mainActivityMatches && subActivityMatches;
      });
    };

    const mappedMonthOptions = () => uniqueOptions(
      monthOptions.concat(mappings.map((mapping) => mapping.month)).map((month) => makeOption(month, month))
    ).map(optionValue);
    const mappedIcsOptions = () => uniqueOptions(targetRowsForSelection({ requireMonth: true }).map((mapping) => makeOption(mapping.ics, mapping.ics))).map(optionValue);
    const mappedMainActivityOptions = () => uniqueOptions(
      targetRowsForSelection({ requireMonth: true, includeMainActivity: false, includeSubActivity: false }).map((mapping) => makeOption(mapping.main_activity, mapping.main_activity))
    ).map(optionValue);
    const mappedSubActivityOptions = () => uniqueOptions(
      targetRowsForSelection({ requireMonth: true, requireMainActivity: true, includeSubActivity: false }).map((mapping) => makeOption(mapping.sub_activity, mapping.sub_activity))
    ).map(optionValue);
	    const mappedVillageOptions = () => {
	      const rows = targetRowsForSelection({ requireMonth: true });

	      return uniqueOptions(rows.map((mapping) => makeOption(mapping.village, mapping.village))).map(optionValue);
	    };

    const mappedFarmers = () => {
      const selectedVillage = normalizeOption(villageSelect.value);
      const selectedMainActivity = normalizeOption(mainActivitySelect?.value);
      const selectedSubActivity = normalizeOption(subActivitySelect?.value);
      if (!monthSelect?.value || !selectedVillage || !selectedMainActivity) return [];

      const farmersById = new Map();
      const completedFarmerIds = new Set();
      targetRowsForSelection({ requireMonth: true, requireVillage: true, requireMainActivity: true })
        .filter((mapping) => !selectedSubActivity || normalizeOption(mapping.sub_activity) === selectedSubActivity)
        .forEach((mapping) => {
          (mapping.completed_farmer_ids || []).forEach((id) => completedFarmerIds.add(String(id)));
          (mapping.farmers || []).forEach((farmer) => {
            if (!farmer.id) return;
	            if (completedFarmerIds.has(String(farmer.id)) && !selectedFarmerIds.has(String(farmer.id))) return;
	            farmersById.set(String(farmer.id), farmer);
	          });
	        });
	      return Array.from(farmersById.values());
	    };

	    const selectedFarmerBoxes = () => Array.from(formShell.querySelectorAll("[data-training-farmer-checkbox]:checked"));
	    const farmerBoxes = () => Array.from(formShell.querySelectorAll("[data-training-farmer-checkbox]"));

	    const updateFarmerCount = () => {
	      const count = selectedFarmerBoxes().length;
	      const boxes = farmerBoxes();
	      if (farmerCount) farmerCount.textContent = `${count} farmer selected`;
	      if (farmerCountInput) farmerCountInput.value = count ? String(count) : "";
	      if (farmerSelectAll) {
	        farmerSelectAll.checked = boxes.length > 0 && count === boxes.length;
	        farmerSelectAll.indeterminate = count > 0 && count < boxes.length;
	        farmerSelectAll.disabled = boxes.length === 0;
	      }
	      if (farmerSelectAllButton) {
	        farmerSelectAllButton.disabled = boxes.length === 0;
	        farmerSelectAllButton.textContent = boxes.length > 0 && count === boxes.length ? "Clear all" : "Select all";
	      }
	    };

	    const renderTrainingFarmers = () => {
	      if (!farmerList) return;
	      const farmers = mappedFarmers();

	      if (monthSelect && !monthSelect.value) {
	        farmerList.textContent = "Select Month to load target farmers.";
	        if (farmerSelectAll) farmerSelectAll.checked = false;
	        updateFarmerCount();
	        return;
	      }

	      if (!villageSelect.value) {
	        farmerList.textContent = "Select Village Name to load target farmers.";
	        if (farmerSelectAll) farmerSelectAll.checked = false;
	        updateFarmerCount();
	        return;
	      }

      if (!mainActivitySelect?.value) {
        farmerList.textContent = "Select Main Activity to load target farmers.";
        if (farmerSelectAll) farmerSelectAll.checked = false;
        updateFarmerCount();
        return;
      }

      if (mainActivitySelect?.value && !subActivitySelect?.value) {
        farmerList.textContent = "Select Sub Activity to narrow the target farmers.";
      }

      if (!farmers.length) {
        farmerList.textContent = "No pending target farmers found for selected activity.";
        if (farmerSelectAll) farmerSelectAll.checked = false;
	        updateFarmerCount();
	        return;
	      }

	      farmerList.innerHTML = farmers.map((farmer) => {
	        const meta = [
	          farmer.father_name ? `Father: ${farmer.father_name}` : "",
	          farmer.tracenet_no ? `Tracenet: ${farmer.tracenet_no}` : "",
	          farmer.mobile_no ? `Mobile: ${farmer.mobile_no}` : "",
	          farmer.khasara_no ? `Khasara: ${farmer.khasara_no}` : ""
	        ].filter(Boolean).join(" | ");
	        const checked = selectedFarmerIds.has(String(farmer.id)) ? " checked" : "";
	        return `
	          <label class="vrp-ics-farmer-item">
	            <input type="checkbox" name="module_record[selected_farmer_ids][]" value="${escapeHtml(farmer.id)}" data-training-farmer-checkbox${checked}>
	            <span>
	              <strong>${escapeHtml(farmer.farmer_name || `Farmer #${farmer.id}`)}</strong>
	              <small>${escapeHtml(meta)}</small>
	            </span>
	          </label>
	        `;
	      }).join("");

	      farmerList.querySelectorAll("[data-training-farmer-checkbox]").forEach((checkbox) => {
	        checkbox.addEventListener("change", () => {
	          if (checkbox.checked) {
	            selectedFarmerIds.add(String(checkbox.value));
	          } else {
	            selectedFarmerIds.delete(String(checkbox.value));
	          }
	          updateFarmerCount();
	        });
	      });
	      updateFarmerCount();
	    };

	    farmerSelectAll?.addEventListener("change", () => {
	      farmerBoxes().forEach((checkbox) => {
	        checkbox.checked = farmerSelectAll.checked;
	        if (checkbox.checked) {
	          selectedFarmerIds.add(String(checkbox.value));
	        } else {
	          selectedFarmerIds.delete(String(checkbox.value));
	        }
	      });
	      updateFarmerCount();
	    });

	    farmerSelectAllButton?.addEventListener("click", () => {
	      const boxes = farmerBoxes();
	      const shouldSelect = selectedFarmerBoxes().length !== boxes.length;
	      boxes.forEach((checkbox) => {
	        checkbox.checked = shouldSelect;
	        if (shouldSelect) {
	          selectedFarmerIds.add(String(checkbox.value));
	        } else {
	          selectedFarmerIds.delete(String(checkbox.value));
	        }
	      });
	      updateFarmerCount();
	    });

	    if (monthSelect) fillTrainingSelect(monthSelect, mappedMonthOptions(), "Select Month");
	    fillTrainingSelect(icsSelect, mappedIcsOptions(), "Select ICS Name");
	    fillTrainingSelect(villageSelect, mappedVillageOptions(), "Select Village Name");
	    if (mainActivitySelect) fillTrainingSelect(mainActivitySelect, mappedMainActivityOptions(), "Select Main Activity");
	    if (subActivitySelect) fillTrainingSelect(subActivitySelect, mappedSubActivityOptions(), "Select Sub Activity");
	    renderTrainingFarmers();

	    if (geoLatitudeInput && geoLongitudeInput && navigator.geolocation) {
	      navigator.geolocation.getCurrentPosition((position) => {
	        geoLatitudeInput.value = position.coords.latitude || "";
	        geoLongitudeInput.value = position.coords.longitude || "";
	      });
	    }

	    const resetTrainingTargetAfterMonth = () => {
	      icsSelect.dataset.selectedValue = "";
	      villageSelect.dataset.selectedValue = "";
	      icsSelect.value = "";
	      villageSelect.value = "";
	      if (mainActivitySelect) mainActivitySelect.dataset.selectedValue = "";
	      if (subActivitySelect) subActivitySelect.dataset.selectedValue = "";
	      if (mainActivitySelect) mainActivitySelect.value = "";
	      if (subActivitySelect) subActivitySelect.value = "";
	      fillTrainingSelect(icsSelect, mappedIcsOptions(), "Select ICS Name");
	      fillTrainingSelect(villageSelect, mappedVillageOptions(), "Select Village Name");
	      if (mainActivitySelect) fillTrainingSelect(mainActivitySelect, mappedMainActivityOptions(), "Select Main Activity");
	      if (subActivitySelect) fillTrainingSelect(subActivitySelect, mappedSubActivityOptions(), "Select Sub Activity");
	      selectedFarmerIds.clear();
	      renderTrainingFarmers();
	    };

	    monthSelect?.addEventListener("change", resetTrainingTargetAfterMonth);

	    icsSelect.addEventListener("change", () => {
	      villageSelect.dataset.selectedValue = "";
	      villageSelect.value = "";
	      if (mainActivitySelect) mainActivitySelect.dataset.selectedValue = "";
	      if (subActivitySelect) subActivitySelect.dataset.selectedValue = "";
	      if (mainActivitySelect) mainActivitySelect.value = "";
	      if (subActivitySelect) subActivitySelect.value = "";
	      fillTrainingSelect(villageSelect, mappedVillageOptions(), "Select Village Name");
	      if (mainActivitySelect) fillTrainingSelect(mainActivitySelect, mappedMainActivityOptions(), "Select Main Activity");
	      if (subActivitySelect) fillTrainingSelect(subActivitySelect, mappedSubActivityOptions(), "Select Sub Activity");
	      selectedFarmerIds.clear();
	      renderTrainingFarmers();
	    });
	    villageSelect.addEventListener("change", () => {
	      if (mainActivitySelect) mainActivitySelect.dataset.selectedValue = "";
	      if (subActivitySelect) subActivitySelect.dataset.selectedValue = "";
	      if (mainActivitySelect) mainActivitySelect.value = "";
	      if (subActivitySelect) subActivitySelect.value = "";
	      if (mainActivitySelect) fillTrainingSelect(mainActivitySelect, mappedMainActivityOptions(), "Select Main Activity");
	      if (subActivitySelect) fillTrainingSelect(subActivitySelect, mappedSubActivityOptions(), "Select Sub Activity");
	      selectedFarmerIds.clear();
	      renderTrainingFarmers();
	    });
	    mainActivitySelect?.addEventListener("change", () => {
	      if (subActivitySelect) subActivitySelect.dataset.selectedValue = "";
	      if (subActivitySelect) subActivitySelect.value = "";
	      if (subActivitySelect) fillTrainingSelect(subActivitySelect, mappedSubActivityOptions(), "Select Sub Activity");
	      selectedFarmerIds.clear();
	      renderTrainingFarmers();
	    });
	    subActivitySelect?.addEventListener("change", () => {
	      selectedFarmerIds.clear();
	      renderTrainingFarmers();
	    });
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
    const fcoSelect = shell.querySelector("[data-target-fco]");
    const icsSelect = shell.querySelector("[data-target-ics]");
    const villageSelect = shell.querySelector("[data-target-village]");
    const monthSelect = shell.querySelector("select[name='target_mapping[month_name]']");
    const mainActivitySelect = shell.querySelector("select[name='target_mapping[main_activity_name]']");
    const subActivitySelect = shell.querySelector("select[name='target_mapping[activity_name]']");
    const targetInput = shell.querySelector("[data-target-quantity-input]");
    const registeredCountInput = shell.querySelector("[data-target-registered-count]");
    const farmerPanel = shell.querySelector("[data-target-farmer-panel]");
    const farmerList = shell.querySelector("[data-target-farmer-list]");
    const farmerCountLabel = shell.querySelector("[data-target-farmer-count]");
    const farmerSelectAll = shell.querySelector("[data-target-farmer-select-all]");
    const form = shell.querySelector("form");
    let editTarget = {};
    let targetSubActivityRows = [];
    try {
      editTarget = JSON.parse(shell.dataset.editTarget || "{}");
    } catch (_error) {
      editTarget = {};
    }
    try {
      targetSubActivityRows = JSON.parse(shell.dataset.targetSubActivityMap || "[]");
    } catch (_error) {
      targetSubActivityRows = [];
    }

    const escapeHtml = (value) => String(value || "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");

    const selectedTargetBoxes = () => Array.from(shell.querySelectorAll("[data-target-farmer-checkbox]:checked"));
    const targetBoxes = () => Array.from(shell.querySelectorAll("[data-target-farmer-checkbox]"));
    const availableTargetBoxes = () => targetBoxes().filter((checkbox) => !checkbox.disabled);
    const locationValueParts = (value) => `${value || ""}`.split("||");
    const targetOptionMatches = (optionValueText, selectedValueText) => {
      const optionParts = locationValueParts(optionValueText);
      const selectedParts = locationValueParts(selectedValueText);
      if (selectedParts[1]) return normalizeOption(optionValueText) === normalizeOption(selectedValueText);

      return normalizeOption(optionParts[0]) === normalizeOption(selectedParts[0]);
    };

    const fillTargetSelect = (select, options, placeholder) => {
      if (!select) return;

      const selected = select.dataset.selectedValue || select.value;
      select.innerHTML = "";

      const blank = document.createElement("option");
      blank.value = "";
      blank.textContent = options.length ? placeholder : `No ${placeholder.replace(/^Select\s+/i, "")} saved yet`;
      select.appendChild(blank);

      options.forEach((optionData) => {
        const option = document.createElement("option");
        option.value = optionValue(optionData);
        option.textContent = optionLabel(optionData);
        option.selected = targetOptionMatches(option.value, selected);
        select.appendChild(option);
      });
      select.disabled = options.length === 0;
    };

    const targetSubActivityOptionsForMain = () => {
      const selectedMainActivity = normalizeOption(mainActivitySelect?.value);
      if (!selectedMainActivity) return [];

      return uniqueOptions(
        targetSubActivityRows
          .filter((row) => normalizeOption(row.main_activity) === selectedMainActivity)
          .map((row) => makeOption(row.sub_activity, row.sub_activity))
      );
    };

    const refreshTargetSubActivities = (resetSelection = false) => {
      if (!subActivitySelect) return;

      if (resetSelection) {
        subActivitySelect.dataset.selectedValue = "";
        subActivitySelect.value = "";
      }

      if (!mainActivitySelect?.value) {
        subActivitySelect.innerHTML = '<option value="">Select Main Activity first</option>';
        subActivitySelect.disabled = true;
        return;
      }

      fillTargetSelect(subActivitySelect, targetSubActivityOptionsForMain(), "Select Sub Activity");
    };

    const updateTargetFarmerCount = () => {
      const selectedCount = selectedTargetBoxes().length;
      const totalCount = targetBoxes().length;
      const availableCount = availableTargetBoxes().length;
      if (farmerCountLabel) farmerCountLabel.textContent = `${selectedCount} farmer selected`;
      if (registeredCountInput) registeredCountInput.value = String(totalCount);
      if (targetInput) targetInput.value = String(selectedCount);
      if (targetInput) targetInput.max = String(availableCount || selectedCount || 1);
      if (farmerSelectAll) {
        farmerSelectAll.checked = availableCount > 0 && selectedCount === availableCount;
        farmerSelectAll.indeterminate = selectedCount > 0 && selectedCount < availableCount;
        farmerSelectAll.disabled = availableCount === 0;
      }
    };

    const clearTargetFarmers = (message = "Select FCO Name, ICS and Village to load farmers.") => {
      if (farmerList) farmerList.textContent = message;
      updateTargetFarmerCount();
    };

    const renderTargetFarmers = (farmers) => {
      if (!farmerPanel || !farmerList) return;

      if (!farmers.length) {
        farmerList.textContent = "No farmers found for selected village.";
        updateTargetFarmerCount();
        return;
      }

      farmerList.innerHTML = farmers.map((farmer) => {
        const meta = [
          farmer.father_name ? `Father: ${farmer.father_name}` : "",
          farmer.tracenet_no ? `Tracenet: ${farmer.tracenet_no}` : "",
          farmer.mobile_no ? `Mobile: ${farmer.mobile_no}` : "",
          farmer.khasara_no ? `Khasara: ${farmer.khasara_no}` : ""
        ].filter(Boolean).join(" | ");
        const disabled = farmer.assigned_to_other ? " disabled" : "";
        const checked = farmer.selected ? " checked" : "";

        return `
          <label class="vrp-ics-farmer-item${farmer.assigned_to_other ? " disabled" : ""}">
            <input type="checkbox" name="target_mapping[afl_ids][]" value="${escapeHtml(farmer.id)}" data-target-farmer-checkbox${disabled}${checked}>
            <span>
              <strong>${escapeHtml(farmer.farmer_name || `Farmer #${farmer.id}`)}</strong>
              <small>${escapeHtml(meta)}${farmer.assigned_to_other ? " | Already assigned" : ""}</small>
            </span>
          </label>
        `;
      }).join("");

      farmerList.querySelectorAll("[data-target-farmer-checkbox]").forEach((checkbox) => {
        checkbox.addEventListener("change", updateTargetFarmerCount);
      });
      updateTargetFarmerCount();
    };

    const loadTargetData = async () => {
      const url = new URL(shell.dataset.mappingsUrl, window.location.origin);
      if (vrpSelect?.value) url.searchParams.set("vrp_id", vrpSelect.value);
      const fcoValue = fcoSelect?.value || fcoSelect?.dataset.selectedValue;
      const icsValue = icsSelect?.value || icsSelect?.dataset.selectedValue;
      const villageValue = villageSelect?.value || villageSelect?.dataset.selectedValue;
      if (fcoValue) url.searchParams.set("fco_id", fcoValue);
      if (icsValue) url.searchParams.set("ics_id", icsValue);
      if (villageValue) url.searchParams.set("village_id", villageValue);
      if (monthSelect?.value) url.searchParams.set("month_name", monthSelect.value);
      if (mainActivitySelect?.value) url.searchParams.set("main_activity_name", mainActivitySelect.value);
      if (subActivitySelect?.value) url.searchParams.set("activity_name", subActivitySelect.value);
      if (editTarget.id) url.searchParams.set("edit_id", editTarget.id);

      try {
        const response = await fetch(url, { headers: { Accept: "application/json" } });
        if (!response.ok) throw new Error("Request failed");
        const data = await response.json();
        fillTargetSelect(fcoSelect, data.fco_options || [], "Select FCO Name");
        fillTargetSelect(icsSelect, data.ics_options || [], "Select ICS");
        fillTargetSelect(villageSelect, data.village_options || [], "Select Village");

        if (villageSelect?.value || villageSelect?.dataset.selectedValue) {
          renderTargetFarmers(data.farmers || []);
        } else {
          clearTargetFarmers();
        }
      } catch (_error) {
        clearTargetFarmers("Farmers load nahi ho paye.");
      }
    };

    farmerSelectAll?.addEventListener("change", () => {
      availableTargetBoxes().forEach((checkbox) => {
        checkbox.checked = farmerSelectAll.checked;
      });
      updateTargetFarmerCount();
    });

    form?.addEventListener("submit", (event) => {
      const selectedCount = selectedTargetBoxes().length;
      const targetCount = Number(targetInput.value || 0);
      if (!selectedCount) {
        event.preventDefault();
        window.alert("Please select at least one farmer.");
        return;
      }
      if (targetCount !== selectedCount) {
        event.preventDefault();
        window.alert(`Target must match selected farmers count (${selectedCount}).`);
      }
    });

    fcoSelect?.addEventListener("change", () => {
      fcoSelect.dataset.selectedValue = "";
      if (icsSelect) icsSelect.dataset.selectedValue = "";
      if (villageSelect) villageSelect.dataset.selectedValue = "";
      if (icsSelect) icsSelect.value = "";
      if (villageSelect) villageSelect.value = "";
      clearTargetFarmers();
      loadTargetData();
    });
    icsSelect?.addEventListener("change", () => {
      icsSelect.dataset.selectedValue = "";
      if (villageSelect) villageSelect.dataset.selectedValue = "";
      if (villageSelect) villageSelect.value = "";
      clearTargetFarmers();
      loadTargetData();
    });
    villageSelect?.addEventListener("change", () => {
      villageSelect.dataset.selectedValue = "";
      clearTargetFarmers();
      loadTargetData();
    });
    vrpSelect?.addEventListener("change", loadTargetData);
    monthSelect?.addEventListener("change", loadTargetData);
    mainActivitySelect?.addEventListener("change", () => {
      refreshTargetSubActivities(true);
      loadTargetData();
    });
    subActivitySelect?.addEventListener("change", loadTargetData);

    refreshTargetSubActivities(false);
    loadTargetData();
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

  const ensureTableSearch = (table, index) => {
    if (!table.id) table.id = `auto_paginated_table_${index + 1}`;
    if (document.querySelector(`[data-table-search='${table.id}']`)) return;

    const shell = table.closest(".table-shell") || table;
    const controls = document.createElement("div");
    controls.className = "list-controls auto-list-controls";
    controls.innerHTML = `
      <div class="list-search">
        <span>⌕</span>
        <input type="search" placeholder="Search records" data-table-search="${table.id}">
      </div>
    `;
    shell.insertAdjacentElement("beforebegin", controls);
  };

  const ensureTablePagination = (table) => {
    if (!table.id || document.querySelector(`[data-pagination-for='${table.id}']`)) return;

    const pagination = document.createElement("div");
    pagination.className = "table-pagination";
    pagination.dataset.paginationFor = table.id;
    (table.closest(".table-shell") || table).insertAdjacentElement("afterend", pagination);
  };

  const sortTableRowsAlphabetically = (table) => {
    if (table.dataset.alphaSorted === "true") return;

    const tbody = table.tBodies[0];
    if (!tbody) return;

    const rows = Array.from(tbody.rows);
    const dataRows = rows.filter((row) => !row.dataset.emptyRow);
    const emptyRows = rows.filter((row) => row.dataset.emptyRow);
    const meaningfulText = (row) => {
      const cells = Array.from(row.cells).filter((cell) => !cell.querySelector("input[type='checkbox']"));
      const cell = cells.find((candidate) => candidate.innerText.trim()) || cells[0];
      return (cell?.innerText || "").trim();
    };

    dataRows
      .sort((left, right) => meaningfulText(left).localeCompare(meaningfulText(right), undefined, { sensitivity: "base", numeric: true }))
      .forEach((row) => tbody.appendChild(row));
    emptyRows.forEach((row) => tbody.appendChild(row));
    table.dataset.alphaSorted = "true";
  };

  document.querySelectorAll("[data-paginated-table]").forEach((table, index) => {
    table.querySelectorAll("tbody tr").forEach((row) => {
      if (row.children.length === 1 || row.innerText.toLowerCase().includes("no records")) {
        row.dataset.emptyRow = "true";
      }
    });
    ensureTableSearch(table, index);
    ensureTablePagination(table);
    sortTableRowsAlphabetically(table);
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
    const selectAllCheckbox = select.dataset.locationLevel
      ? select.closest("[data-location-form]")?.querySelector(`[data-chip-select-all-for="${select.dataset.locationLevel}"]`)
      : null;
    let chipSearchTerm = "";

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

    const selectableOptions = () => Array.from(select.options)
      .filter((option) => option.value !== "")
      .sort((left, right) => left.textContent.localeCompare(right.textContent, undefined, { sensitivity: "base" }));
    const selectedOptions = () => selectableOptions().filter((option) => option.selected);

    const syncSelectAllCheckbox = () => {
      if (!selectAllCheckbox) return;

      const options = selectableOptions();
      const selected = selectedOptions();
      selectAllCheckbox.disabled = select.disabled || options.length === 0;
      selectAllCheckbox.checked = options.length > 0 && selected.length === options.length;
      selectAllCheckbox.indeterminate = selected.length > 0 && selected.length < options.length;
    };

    const render = (focusSearch = false) => {
      const selected = selectedOptions();
      chips.innerHTML = "";
      dropdown.innerHTML = "";
      control.classList.toggle("disabled", select.disabled);
      control.setAttribute("aria-disabled", select.disabled ? "true" : "false");
      syncSelectAllCheckbox();

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

      const searchInput = document.createElement("input");
      searchInput.type = "search";
      searchInput.className = "chip-search-input";
      searchInput.placeholder = `Search ${placeholder}`;
      searchInput.value = chipSearchTerm;
      searchInput.disabled = select.disabled;
      searchInput.addEventListener("click", (event) => event.stopPropagation());
      searchInput.addEventListener("keydown", (event) => event.stopPropagation());
      searchInput.addEventListener("input", () => {
        chipSearchTerm = searchInput.value;
        render(true);
      });
      dropdown.appendChild(searchInput);

      const options = selectableOptions();
      const normalizedSearch = chipSearchTerm.trim().toLowerCase();
      const visibleOptions = normalizedSearch
        ? options.filter((option) => option.textContent.toLowerCase().includes(normalizedSearch))
        : options;

      if (!options.length) {
        const emptyOption = document.createElement("div");
        emptyOption.className = "chip-option empty";
        emptyOption.textContent = "No options saved yet";
        dropdown.appendChild(emptyOption);
      }

      if (options.length > 0 && !visibleOptions.length) {
        const emptyOption = document.createElement("div");
        emptyOption.className = "chip-option empty";
        emptyOption.textContent = "No matching options";
        dropdown.appendChild(emptyOption);
      }

      visibleOptions.forEach((option) => {
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

      if (focusSearch) {
        window.requestAnimationFrame(() => {
          searchInput.focus();
          searchInput.setSelectionRange(searchInput.value.length, searchInput.value.length);
        });
      }
    };

    selectAllCheckbox?.addEventListener("change", () => {
      if (select.disabled) return;

      selectableOptions().forEach((option) => {
        option.selected = selectAllCheckbox.checked;
      });
      select.dispatchEvent(new Event("change", { bubbles: true }));
      render();
    });

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
    const approvalLevelLabel = (sequence) => {
      const labels = {
        1: "First Approval",
        2: "Second Approval",
        3: "Third Approval",
        4: "Fourth Approval",
        5: "Fifth Approval",
        6: "Sixth Approval",
        7: "Seventh Approval",
        8: "Eighth Approval",
        9: "Ninth Approval",
        10: "Tenth Approval"
      };
      return labels[sequence] || `Approval ${sequence}`;
    };

    const approvalRowCount = () => new Set(Array.from(table?.querySelectorAll("[data-approval-row]") || []).map((cell) => cell.dataset.approvalRow)).size;

    const removeApprovalRow = (rowIndex) => {
      if (!table || approvalRowCount() <= 1) return;

      table.querySelectorAll(`[data-approval-row="${rowIndex}"]`).forEach((cell) => cell.remove());
    };

    const addApprovalRow = () => {
      if (!table) return;

      const rowIndex = Number(shell.dataset.nextApprovalLevel || approvalRowCount() + 1);
      const level = approvalLevelLabel(rowIndex);
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

  document.querySelectorAll("[data-user-hierarchy-levels]").forEach((shell) => {
    const table = shell.querySelector("[data-user-hierarchy-table]");
    const addButton = shell.querySelector("[data-add-user-row]");
    const firstSelect = table?.querySelector("[data-user-row] select");
    const userOptions = firstSelect
      ? Array.from(firstSelect.options).map((option) => ({ value: option.value, label: option.textContent }))
      : [{ value: "", label: "Select Level 2 User" }];

    const rowCount = () => new Set(Array.from(table?.querySelectorAll("[data-user-row]") || []).map((cell) => cell.dataset.userRow)).size;

    const removeUserRow = (rowIndex) => {
      if (!table || rowCount() <= 1) return;

      table.querySelectorAll(`[data-user-row="${rowIndex}"]`).forEach((cell) => cell.remove());
    };

    const buildUserSelect = (name, prompt) => {
      const select = document.createElement("select");
      select.name = name;
      userOptions.forEach((optionData, index) => {
        const option = document.createElement("option");
        option.value = optionData.value;
        option.textContent = index === 0 && !optionData.value ? prompt : optionData.label;
        select.appendChild(option);
      });
      return select;
    };

    const addUserRow = () => {
      if (!table) return;

      const rowIndex = Number(shell.dataset.nextUserRow || rowCount() + 1);
      shell.dataset.nextUserRow = String(rowIndex + 1);

      const levelCell = document.createElement("div");
      levelCell.className = "approval-level-cell";
      levelCell.dataset.userRow = String(rowIndex);
      levelCell.innerHTML = `<strong>Level 2</strong><small>User ${rowIndex}</small>`;

      const userCell = document.createElement("div");
      userCell.className = "approval-level-cell";
      userCell.dataset.userRow = String(rowIndex);
      userCell.appendChild(buildUserSelect(`module_record[level_2_mappings][${rowIndex}][level_2_user]`, "Select Level 2 User"));

      const actionCell = document.createElement("div");
      actionCell.className = "approval-level-cell";
      actionCell.dataset.userRow = String(rowIndex);
      const removeButton = document.createElement("button");
      removeButton.type = "button";
      removeButton.className = "remove-level-btn";
      removeButton.dataset.removeUserRow = "true";
      removeButton.textContent = "Remove";
      actionCell.appendChild(removeButton);

      table.appendChild(levelCell);
      table.appendChild(userCell);
      table.appendChild(actionCell);
    };

    addButton?.addEventListener("click", addUserRow);

    table?.addEventListener("click", (event) => {
      const button = event.target.closest("[data-remove-user-row]");
      if (!button) return;

      removeUserRow(button.closest("[data-user-row]")?.dataset.userRow);
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
      const isReturn = action === "return";
      const isReject = action === "reject";
      if (approvalModalTitle) {
        approvalModalTitle.textContent = isReturn ? "Return Remarks" : (isReject ? "Rejection Remarks" : "Approval Remarks");
      }
      if (approvalModalSubmit) {
        approvalModalSubmit.textContent = isReturn ? "Return" : (isReject ? "Reject" : "Approve");
        approvalModalSubmit.classList.toggle("deactive", isReject || isReturn);
        approvalModalSubmit.classList.toggle("active", !(isReject || isReturn));
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

  document.querySelectorAll("[data-jeevika-jankar-bill]").forEach((billForm) => {
    const vrpSelect = billForm.querySelector("[data-jeevika-vrp-select]");
    const monthSelect = billForm.querySelector("[data-jeevika-month-select]");
    const rowsBody = billForm.querySelector("[data-jeevika-bill-rows]");
    const totalTargetInput = billForm.querySelector("[data-jeevika-total-target]");
    const totalAchievementInput = billForm.querySelector("[data-jeevika-total-achievement]");
    const grandTotalInput = billForm.querySelector("[data-jeevika-grand-total]");
    let billRows = [];
    let savedItems = [];
    let achievementSummary = {};

    try {
      billRows = JSON.parse(billForm.dataset.billRows || "[]");
      savedItems = JSON.parse(billForm.dataset.savedItems || "[]");
      achievementSummary = JSON.parse(billForm.dataset.achievementSummary || "{}");
    } catch (_error) {
      billRows = [];
      savedItems = [];
      achievementSummary = {};
    }

    const escapeHtml = (value) => String(value || "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");

    const numberValue = (value) => Number(String(value || "0").replaceAll(",", "")) || 0;
    const savedItemFor = (row) => savedItems.find((item) => String(item.target_mapping_id || "") === String(row.target_mapping_id || "")) || {};
    const rowInputs = () => Array.from(rowsBody?.querySelectorAll("tr[data-bill-row]") || []);
    const selectedAchievementTotal = () => {
      const selectedVrp = String(vrpSelect?.value || "");
      if (!selectedVrp) return null;

      const total = achievementSummary?.[selectedVrp]?.__all;
      return total === undefined || total === null ? null : numberValue(total);
    };

    const farmerDetailsHtml = (farmers) => {
      if (!farmers?.length) return "<div class=\"jeevika-farmer-empty\">No target farmer list saved for this target.</div>";

      const rows = farmers.map((farmer) => `
        <tr>
          <td>${escapeHtml(farmer.name)}</td>
          <td>${escapeHtml(farmer.father_name || "-")}</td>
          <td>${escapeHtml(farmer.mobile_no || "-")}</td>
          <td>${escapeHtml(farmer.department || "-")}</td>
          <td>${escapeHtml(farmer.training_topic || "-")}</td>
          <td>${escapeHtml(farmer.training_subject || "-")}</td>
          <td>${escapeHtml(farmer.training_date || "-")}</td>
        </tr>
      `).join("");

      return `
        <div class="jeevika-farmer-detail">
          <table class="module-table">
            <thead>
              <tr>
                <th>Farmer</th>
                <th>Father</th>
                <th>Mobile</th>
                <th>Department</th>
                <th>Training Topic</th>
                <th>Training Subject</th>
                <th>Date</th>
              </tr>
            </thead>
            <tbody>${rows}</tbody>
          </table>
        </div>
      `;
    };

    const hiddenInput = (name, value) => `<input type="hidden" name="${name}" value="${escapeHtml(value)}">`;

    const recalculateJeevikaBill = () => {
      let totalTarget = 0;
      let totalAchievement = 0;
      let grandTotal = 0;

      rowInputs().forEach((row) => {
        const target = numberValue(row.dataset.targetQuantity);
        const achievement = numberValue(row.dataset.achievementCount);
        const rate = numberValue(row.querySelector("[data-jeevika-rate]")?.value);
        const amount = achievement * rate;
        const amountInput = row.querySelector("[data-jeevika-amount]");

        totalTarget += target;
        totalAchievement += achievement;
        grandTotal += amount;
        if (amountInput) amountInput.value = amount.toFixed(2);
      });

      if (totalTargetInput) totalTargetInput.value = String(totalTarget);
      const summaryAchievement = selectedAchievementTotal();
      if (summaryAchievement !== null) totalAchievement = summaryAchievement;
      if (totalAchievementInput) totalAchievementInput.value = String(totalAchievement);
      if (grandTotalInput) grandTotalInput.value = grandTotal.toFixed(2);
    };

    const renderJeevikaBillRows = () => {
      if (!rowsBody) return;

      const selectedVrp = String(vrpSelect?.value || "");
      const rows = billRows.filter((row) => String(row.vrp_id || "") === selectedVrp);

      if (!selectedVrp) {
        rowsBody.innerHTML = `<tr data-empty-bill-row><td colspan="9">Select Jeevika Jankar Name to load target achievement list.</td></tr>`;
        recalculateJeevikaBill();
        return;
      }

      if (!rows.length) {
        rowsBody.innerHTML = `<tr data-empty-bill-row><td colspan="9">No target mapping found for selected Jeevika Jankar.</td></tr>`;
        recalculateJeevikaBill();
        return;
      }

      rowsBody.innerHTML = rows.map((row, index) => {
        const savedItem = savedItemFor(row);
        const rate = savedItem.rate || "0.00";
        const farmerDetails = JSON.stringify(row.farmer_details || []);
        const inputPrefix = `module_record[bill_items][${index}]`;

        return `
          <tr data-bill-row data-target-quantity="${escapeHtml(row.target_quantity)}" data-achievement-count="${escapeHtml(row.achievement_count)}">
            <td>
              ${hiddenInput(`${inputPrefix}[target_mapping_id]`, row.target_mapping_id)}
              ${hiddenInput(`${inputPrefix}[vrp_id]`, row.vrp_id)}
              ${hiddenInput(`${inputPrefix}[vrp_name]`, row.vrp_name)}
              ${hiddenInput(`${inputPrefix}[month_name]`, row.month_name)}
              ${hiddenInput(`${inputPrefix}[fco]`, row.fco)}
              ${hiddenInput(`${inputPrefix}[ics]`, row.ics)}
              ${hiddenInput(`${inputPrefix}[village]`, row.village)}
              ${hiddenInput(`${inputPrefix}[main_activity]`, row.main_activity)}
              ${hiddenInput(`${inputPrefix}[activity]`, row.activity)}
              ${hiddenInput(`${inputPrefix}[target_quantity]`, row.target_quantity)}
              ${hiddenInput(`${inputPrefix}[assigned_count]`, row.assigned_count)}
              ${hiddenInput(`${inputPrefix}[achievement_count]`, row.achievement_count)}
              ${hiddenInput(`${inputPrefix}[pending_count]`, row.pending_count)}
              ${hiddenInput(`${inputPrefix}[same_activity_count]`, row.same_activity_count)}
              ${hiddenInput(`${inputPrefix}[other_activity_count]`, row.other_activity_count)}
              ${hiddenInput(`${inputPrefix}[timesheet_dates]`, row.timesheet_dates)}
              ${hiddenInput(`${inputPrefix}[farmer_details]`, farmerDetails)}
              ${escapeHtml(row.ics || "-")}
            </td>
            <td>${escapeHtml(row.village || "-")}</td>
            <td>${escapeHtml(row.main_activity || "-")}</td>
            <td>${escapeHtml(row.activity || "-")}</td>
            <td>${escapeHtml(row.target_quantity || 0)}</td>
            <td>${escapeHtml(row.achievement_count || 0)}</td>
            <td>${escapeHtml(row.pending_count || 0)}</td>
            <td><input type="number" min="0" step="0.01" name="${inputPrefix}[rate]" value="${escapeHtml(rate)}" data-jeevika-rate></td>
            <td><input type="number" min="0" step="0.01" name="${inputPrefix}[amount]" value="${escapeHtml(savedItem.amount || "0.00")}" data-jeevika-amount readonly></td>
          </tr>
          <tr class="jeevika-farmer-row">
            <td colspan="9">
              <details class="jeevika-farmer-details">
                <summary>Farmer List ${escapeHtml(row.achievement_count || 0)} / ${escapeHtml(row.assigned_count || 0)}</summary>
                ${farmerDetailsHtml(row.farmer_details || [])}
              </details>
            </td>
          </tr>
        `;
      }).join("");

      recalculateJeevikaBill();
    };

    rowsBody?.addEventListener("input", (event) => {
      if (event.target.matches("[data-jeevika-rate]")) recalculateJeevikaBill();
    });
    billForm.querySelector("form")?.addEventListener("submit", (event) => {
      if (rowInputs().length > 0) return;

      event.preventDefault();
      window.alert("Please select Jeevika Jankar Name and Bill Month with target mapping.");
    });
    vrpSelect?.addEventListener("change", renderJeevikaBillRows);
    monthSelect?.addEventListener("change", renderJeevikaBillRows);
    renderJeevikaBillRows();
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

  const initializeLanguageSwitcher = () => {
    const switcher = document.querySelector("[data-language-switcher]");
    const languageButtons = Array.from(document.querySelectorAll("[data-language-option]"));
    const originalText = window.__vrpOriginalText ||= new WeakMap();
    const attributeNames = ["placeholder", "title", "aria-label", "data-turbo-confirm"];
    const translations = {
      "Language": "भाषा",
      "Dashboard": "डैशबोर्ड",
      "Sign Out": "साइन आउट",
      "Training": "प्रशिक्षण",
      "Farmer Training": "किसान प्रशिक्षण",
      "Training Form": "प्रशिक्षण फॉर्म",
      "Farmer Training Form": "किसान प्रशिक्षण फॉर्म",
      "Training List": "प्रशिक्षण सूची",
      "Farmer Training Form List": "किसान प्रशिक्षण फॉर्म सूची",
      "Training Topic Mapping": "प्रशिक्षण टॉपिक मैपिंग",
      "Farmer Training Topic Mapping": "किसान प्रशिक्षण टॉपिक मैपिंग",
      "ट्रेनिंग प्रपत्र": "प्रशिक्षण फॉर्म",
      "VRP Targets": "वीआरपी लक्ष्य",
      "Recent Target Mappings": "हाल की लक्ष्य मैपिंग",
      "Target Mapping Master": "लक्ष्य मैपिंग मास्टर",
      "Target Mapping": "लक्ष्य मैपिंग",
      "Target Mapping Upload": "लक्ष्य मैपिंग अपलोड",
      "Target Mapping Data Upload": "लक्ष्य मैपिंग डेटा अपलोड",
      "AFL Upload": "एएफएल अपलोड",
      "VRP ICS Mapping": "वीआरपी आईसीएस मैपिंग",
      "LG Directory": "एलजी डायरेक्टरी",
      "All List": "सभी सूची",
      "State Entry": "राज्य प्रविष्टि",
      "District Entry": "जिला प्रविष्टि",
      "Block Entry": "ब्लॉक प्रविष्टि",
      "GP Entry": "जीपी प्रविष्टि",
      "Village Entry": "गांव प्रविष्टि",
      "Month Entry": "माह प्रविष्टि",
      "Stakeholder": "स्टेकहोल्डर",
      "Office Setup": "ऑफिस सेटअप",
      "Parent Office Add": "पैरेंट ऑफिस जोड़ें",
      "Parent Office": "पैरेंट ऑफिस",
      "Parent Office Name": "पैरेंट ऑफिस नाम",
      "Parent Office Type": "पैरेंट ऑफिस प्रकार",
      "Sub Parent Office": "सब पैरेंट ऑफिस",
      "Parent Category": "पैरेंट श्रेणी",
      "Sub Office Add": "सब ऑफिस जोड़ें",
      "Sub Office Name": "सब ऑफिस नाम",
      "Select Parent Office": "पैरेंट ऑफिस चुनें",
      "Select Parent Office Type": "पैरेंट ऑफिस प्रकार चुनें",
      "Project Add": "प्रोजेक्ट जोड़ें",
      "Project Name": "प्रोजेक्ट नाम",
      "Stakeholder Name": "स्टेकहोल्डर नाम",
      "Stakeholder Category": "स्टेकहोल्डर श्रेणी",
      "Stakeholder Role": "स्टेकहोल्डर व्यक्ति प्रकार",
      "Stakeholder Person Type": "स्टेकहोल्डर व्यक्ति प्रकार",
      "Role": "भूमिका",
      "Role Name": "भूमिका नाम",
      "Activity Setup": "गतिविधि सेटअप",
      "Main Activity": "मुख्य गतिविधि",
      "Main Activity Name": "मुख्य गतिविधि नाम",
      "Main Activity List": "मुख्य गतिविधि सूची",
      "Sub Activity": "उप गतिविधि",
      "Sub Activity Name": "उप गतिविधि नाम",
      "Sub Activity List": "उप गतिविधि सूची",
      "User Register": "यूज़र रजिस्टर",
      "All User": "सभी यूज़र",
      "Registration": "पंजीकरण",
      "User Mapping": "यूज़र मैपिंग",
      "User Hierarchy Mapping": "यूज़र हाइरार्की मैपिंग",
      "Resource Person Type": "रिसोर्स पर्सन प्रकार",
      "Access Control": "एक्सेस कंट्रोल",
      "Access Control List": "एक्सेस कंट्रोल सूची",
      "VRP Registration": "वीआरपी पंजीकरण",
      "VRP Type": "वीआरपी प्रकार",
      "VRP List": "वीआरपी सूची",
      "VRP Approval": "वीआरपी अनुमोदन",
      "VRP Approval Queue": "वीआरपी अनुमोदन क्यू",
      "VRP Approval Form": "वीआरपी अनुमोदन फॉर्म",
      "VRP Approval List": "वीआरपी अनुमोदन सूची",
      "Saved Records": "सेव रिकॉर्ड",
      "All Training Records": "सभी प्रशिक्षण रिकॉर्ड",
      "All Farmer Training Records": "सभी किसान प्रशिक्षण रिकॉर्ड",
      "All Main Activities": "सभी मुख्य गतिविधियां",
      "All Sub Activities": "सभी उप गतिविधियां",
      "All Task Completion Indicators": "सभी कार्य पूर्णता संकेतक",
      "All Approvals": "सभी अनुमोदन",
      "All Access Control": "सभी एक्सेस कंट्रोल",
      "All VRP Bills": "सभी वीआरपी बिल",
      "Fields": "फील्ड",
      "Edit Record": "रिकॉर्ड एडिट करें",
      "Features": "विशेषताएं",
      "Save": "सेव",
      "Update": "अपडेट",
      "Clear": "क्लियर",
      "Upload": "अपलोड",
      "Export": "एक्सपोर्ट",
      "Export Excel": "एक्सेल एक्सपोर्ट",
      "Choose Excel": "एक्सेल चुनें",
      "Edit": "एडिट",
      "Delete": "डिलीट",
      "Activate": "एक्टिव करें",
      "Deactivate": "डीएक्टिव करें",
      "Active": "एक्टिव",
      "Inactive": "इनएक्टिव",
      "Pending": "पेंडिंग",
      "Approved": "अनुमोदित",
      "Rejected": "अस्वीकृत",
      "Action": "कार्रवाई",
      "Actions": "कार्रवाई",
      "Status": "स्थिति",
      "Saved At": "सेव समय",
      "Updated": "अपडेट समय",
      "Search": "खोजें",
      "Search records": "रिकॉर्ड खोजें",
      "Search users": "यूज़र खोजें",
      "Search VRP": "वीआरपी खोजें",
      "Search Target Mapping": "लक्ष्य मैपिंग खोजें",
      "Search AFL": "एएफएल खोजें",
      "Search dashboard": "डैशबोर्ड खोजें",
      "FCO Name": "एफसीओ नाम",
      "Registered Farmers": "पंजीकृत किसान",
      "Farmer List": "किसान सूची",
      "Select FCO Name": "एफसीओ नाम चुनें",
      "Select all": "सभी चुनें",
      "Cancel": "रद्द करें",
      "Cancel Edit": "एडिट रद्द करें",
      "Add More": "और जोड़ें",
      "Add Level 2": "लेवल 2 जोड़ें",
      "Apply": "लागू करें",
	      "Remove": "हटाएं",
	      "Remove this VRP ICS mapping?": "यह वीआरपी आईसीएस मैपिंग हटाएं?",
	      "Remove this target mapping?": "यह लक्ष्य मैपिंग हटाएं?",
	      "Delete this VRP ICS mapping?": "यह वीआरपी आईसीएस मैपिंग डिलीट करें?",
	      "Delete this target mapping?": "यह लक्ष्य मैपिंग डिलीट करें?",
	      "Close": "बंद करें",
      "View": "देखें",
      "View Targets": "लक्ष्य देखें",
      "Send for Approval": "अनुमोदन के लिए भेजें",
      "Upload Date": "अपलोड तारीख",
      "Material Title": "सामग्री शीर्षक",
      "ICS / Block": "आईसीएस / ब्लॉक",
      "Gram Name": "ग्राम का नाम",
      "Gram Code": "ग्राम कोड",
      "GRAM NAME": "ग्राम का नाम",
      "GRAM CODE": "ग्राम कोड",
      "Trainee Department": "प्रशिक्षणार्थी विभाग",
      "Trainer Name": "प्रशिक्षक नाम",
      "Trainer Contact": "प्रशिक्षक संपर्क",
      "Training Date": "प्रशिक्षण तारीख",
      "Training Location": "प्रशिक्षण स्थान",
      "Department": "विभाग",
      "Training Topic": "प्रशिक्षण टॉपिक",
      "Training Subject": "प्रशिक्षण विषय",
      "Training Description": "प्रशिक्षण विवरण",
      "Farmer Count": "किसान संख्या",
      "Selected Farmers": "चुने गए किसान",
      "Male Count": "पुरुष संख्या",
      "Female Count": "महिला संख्या",
      "Next Farmer Training Date": "अगली किसान प्रशिक्षण तारीख",
      "Training Register Upload": "प्रशिक्षण रजिस्टर अपलोड",
      "Training Photo Upload with Geo Tag": "जियो टैग के साथ प्रशिक्षण फोटो अपलोड",
      "State": "राज्य",
      "State Name": "राज्य नाम",
      "State Code": "राज्य कोड",
      "District": "जिला",
      "District Name": "जिला नाम",
      "District Code": "जिला कोड",
      "Block": "ब्लॉक",
      "Block Name": "ब्लॉक नाम",
      "Block Code": "ब्लॉक कोड",
      "Gram Panchayat": "ग्राम पंचायत",
      "Gram Panchayat Name": "ग्राम पंचायत नाम",
      "GP Code": "जीपी कोड",
      "Village": "गांव",
      "Village Name": "गांव नाम",
      "Village Code": "गांव कोड",
      "VRP": "वीआरपी",
      "FCO": "एफसीओ",
      "ICS": "आईसीएस",
      "Farmers": "किसान",
      "Farmer": "किसान",
      "Mapped Farmers": "मैप किए किसान",
      "Target Farmers": "लक्षित किसान",
      "Select Village Name to load mapped farmers.": "मैप किए किसान लोड करने के लिए गांव नाम चुनें।",
      "Select Village Name to load target farmers.": "लक्षित किसान लोड करने के लिए गांव नाम चुनें।",
      "No mapped farmers found for selected village.": "चुने गए गांव के लिए कोई मैप किसान नहीं मिला।",
      "No target farmers found for selected village.": "चुने गए गांव के लिए कोई लक्षित किसान नहीं मिला।",
      "Mapped Villages": "मैप किए गांव",
      "Mapped Village Work Area": "मैप गांव कार्य क्षेत्र",
      "Assigned Target Progress": "दिए गए लक्ष्य की प्रगति",
      "Farmer Month Follow-up": "किसान मासिक फॉलो-अप",
      "Target": "लक्ष्य",
      "Targets": "लक्ष्य",
      "Target Quantity": "लक्ष्य मात्रा",
      "Completed": "पूर्ण",
      "Progress": "प्रगति",
      "Month": "माह",
      "Financial Year": "वित्तीय वर्ष",
      "Week": "सप्ताह",
      "Start Date": "प्रारंभ तारीख",
      "End Date": "समाप्ति तारीख",
      "Priority": "प्राथमिकता",
      "Remarks": "टिप्पणी",
      "Unit": "यूनिट",
      "Rate": "दर",
      "Total Amount": "कुल राशि",
      "Grand Total": "कुल योग",
      "Payment Status": "भुगतान स्थिति",
      "Completion Status": "पूर्णता स्थिति",
      "Task Completion Indicator": "कार्य पूर्णता संकेतक",
      "Task Completion Indicators": "कार्य पूर्णता संकेतक",
      "Indicator": "संकेतक",
      "Mandatory": "अनिवार्य",
      "Working Date": "कार्य तारीख",
      "Number": "संख्या",
      "User Type": "यूज़र प्रकार",
      "User Name": "यूज़र नाम",
      "Full Name": "पूरा नाम",
      "Name": "नाम",
      "Father Husband Name": "पिता / पति का नाम",
      "Gender": "लिंग",
      "Date of Birth": "जन्म तारीख",
      "Date of Joining": "जॉइनिंग तारीख",
      "Aadhar No": "आधार नंबर",
      "Account No": "खाता नंबर",
      "IFSC Code": "आईएफएससी कोड",
      "Bank Name": "बैंक नाम",
      "Address": "पता",
      "Mobile": "मोबाइल",
      "Mobile No": "मोबाइल नंबर",
      "Email": "ईमेल",
      "Registered By": "पंजीकरणकर्ता",
      "Enrollment Date": "नामांकन तारीख",
	      "Office Category Add": "ऑफिस श्रेणी जोड़ें",
	      "Office Category": "ऑफिस श्रेणी",
	      "Office Name": "ऑफिस नाम",
      "Sub Office Add": "सब ऑफिस जोड़ें",
      "Sub Office Name": "सब ऑफिस नाम",
      "Office Level": "ऑफिस लेवल",
      "Select Office Category": "ऑफिस श्रेणी चुनें",
      "Select Office Name": "ऑफिस नाम चुनें",
      "Office": "ऑफिस",
      "FCOC-C": "एफसीओसी-सी",
      "Select FCOC-C": "एफसीओसी-सी चुनें",
      "TO": "टीओ",
      "Select TO": "टीओ चुनें",
      "Cluster Incharge": "क्लस्टर इंचार्ज",
      "Select Cluster Incharge": "क्लस्टर इंचार्ज चुनें",
      "Menu": "मेनू",
      "Sub Menu": "सब मेनू",
      "Module Name": "मॉड्यूल नाम",
      "Sub Module Name": "सब मॉड्यूल नाम",
      "Can View": "देख सकते हैं",
      "Can Create": "बना सकते हैं",
      "Can Edit": "एडिट कर सकते हैं",
      "Can Delete": "डिलीट कर सकते हैं",
      "Yes": "हाँ",
      "No": "नहीं",
      "High": "उच्च",
      "Medium": "मध्यम",
      "Low": "निम्न",
      "Male": "पुरुष",
      "Female": "महिला",
      "Other": "अन्य",
      "No records saved yet.": "अभी कोई रिकॉर्ड सेव नहीं है।",
      "No target mapping saved yet.": "अभी कोई लक्ष्य मैपिंग सेव नहीं है।",
      "No users registered yet.": "अभी कोई यूज़र पंजीकृत नहीं है।",
      "No target mapping records uploaded yet.": "अभी कोई लक्ष्य मैपिंग रिकॉर्ड अपलोड नहीं है।",
      "Select VRP to load mapped villages.": "मैप किए गांव लोड करने के लिए वीआरपी चुनें।",
      "Select FCO, ICS and Village to load farmers.": "किसान लोड करने के लिए एफसीओ, आईसीएस और गांव चुनें।",
      "Select FCO Name, ICS and Village to load farmers.": "किसान लोड करने के लिए एफसीओ नाम, आईसीएस और गांव चुनें।",
      "No farmers found for selected village.": "चुने गए गांव के लिए कोई किसान नहीं मिला।",
      "Mapped FCO / ICS / Village List": "मैप एफसीओ / आईसीएस / गांव सूची",
      "0 mapping selected": "0 मैपिंग चुनी गई",
      "Dashboard Reports": "डैशबोर्ड रिपोर्ट",
      "Dashboard Module": "डैशबोर्ड मॉड्यूल",
      "VRP training details save karne ke liye.": "वीआरपी प्रशिक्षण विवरण सेव करने के लिए।",
      "Farmer training details save karne ke liye.": "किसान प्रशिक्षण विवरण सेव करने के लिए।",
      "Saved training records dekhne ke liye.": "सेव प्रशिक्षण रिकॉर्ड देखने के लिए।",
      "Saved farmer training records dekhne ke liye.": "सेव किसान प्रशिक्षण रिकॉर्ड देखने के लिए।",
      "Training documents/videos upload karna.": "प्रशिक्षण दस्तावेज / वीडियो अपलोड करने के लिए।",
      "Location hierarchy maintain karne ke liye.": "स्थान हाइरार्की बनाए रखने के लिए।",
      "State, District, Block, GP, Village ek sath maintain karne ke liye.": "राज्य, जिला, ब्लॉक, जीपी और गांव एक साथ बनाए रखने के लिए।",
      "Stakeholder name aur logo maintain karna.": "स्टेकहोल्डर नाम और लोगो बनाए रखने के लिए।",
      "Main activity add karne ke liye.": "मुख्य गतिविधि जोड़ने के लिए।",
      "Sub activity add karne ke liye.": "उप गतिविधि जोड़ने के लिए।",
      "Saved main activities dekhne ke liye.": "सेव मुख्य गतिविधियां देखने के लिए।",
      "Saved sub activities dekhne ke liye.": "सेव उप गतिविधियां देखने के लिए।",
      "VRP type add karne ke liye.": "वीआरपी प्रकार जोड़ने के लिए।",
      "Saved access control records dekhne ke liye.": "सेव एक्सेस कंट्रोल रिकॉर्ड देखने के लिए।",
      "Live VRP, bill, payment, target, activity, aur training summary.": "वीआरपी, बिल, भुगतान, लक्ष्य, गतिविधि और प्रशिक्षण का लाइव सारांश।",
      "Your mapped farmers, villages, assigned targets, and completed work summary.": "आपके मैप किसान, गांव, दिए गए लक्ष्य और पूर्ण कार्य का सारांश।"
    };
    const englishAliases = {
      "ट्रेनिंग प्रपत्र": "Training Form",
      "VRP training details save karne ke liye.": "Save VRP training details.",
      "Saved training records dekhne ke liye.": "View saved training records.",
      "Training documents/videos upload karna.": "Upload training documents/videos.",
      "Location hierarchy maintain karne ke liye.": "Maintain the location hierarchy.",
      "State, District, Block, GP, Village ek sath maintain karne ke liye.": "Maintain State, District, Block, GP, and Village together.",
      "Stakeholder name aur logo maintain karna.": "Maintain stakeholder name and logo.",
      "Main activity add karne ke liye.": "Add main activity.",
      "Sub activity add karne ke liye.": "Add sub activity.",
      "Saved main activities dekhne ke liye.": "View saved main activities.",
      "Saved sub activities dekhne ke liye.": "View saved sub activities.",
      "VRP type add karne ke liye.": "Add VRP type.",
      "Saved access control records dekhne ke liye.": "View saved access control records."
    };
	    const englishTranslations = {
	      ...Object.fromEntries(Object.entries(translations).map(([english, hindi]) => [hindi, english])),
	      ...englishAliases
	    };
	    const marathiTranslations = {
	      "Language": "भाषा",
	      "Dashboard": "डॅशबोर्ड",
	      "Sign Out": "साइन आउट",
	      "Target Mapping": "लक्ष्य मॅपिंग",
	      "Target Mapping Upload": "लक्ष्य मॅपिंग अपलोड",
	      "AFL Upload": "एएफएल अपलोड",
	      "Target Mapping Master": "लक्ष्य मॅपिंग मास्टर",
	      "VRP ICS Mapping": "व्हीआरपी आयसीएस मॅपिंग",
	      "Recent Target Mappings": "अलीकडील लक्ष्य मॅपिंग",
	      "Recent VRP ICS Mappings": "अलीकडील व्हीआरपी आयसीएस मॅपिंग",
	      "Office Setup": "ऑफिस सेटअप",
	      "Office Category": "ऑफिस श्रेणी",
	      "Office Name": "ऑफिस नाव",
      "Sub Office Add": "सब ऑफिस जोडा",
      "Sub Office Name": "सब ऑफिस नाव",
	      "Office Level": "ऑफिस लेवल",
	      "Select Office Category": "ऑफिस श्रेणी निवडा",
	      "Select Office Name": "ऑफिस नाव निवडा",
	      "FCOC-C": "एफसीओसी-सी",
	      "Select FCOC-C": "एफसीओसी-सी निवडा",
	      "TO": "टीओ",
	      "Select TO": "टीओ निवडा",
	      "Cluster Incharge": "क्लस्टर इंचार्ज",
	      "Select Cluster Incharge": "क्लस्टर इंचार्ज निवडा",
	      "VRP Registration": "व्हीआरपी नोंदणी",
	      "User Register": "यूज़र नोंदणी",
	      "Edit": "एडिट",
	      "Delete": "डिलीट",
	      "Remove": "काढा",
	      "Remove this VRP ICS mapping?": "हे व्हीआरपी आयसीएस मॅपिंग काढायचे?",
	      "Remove this target mapping?": "हे लक्ष्य मॅपिंग काढायचे?",
	      "Delete this VRP ICS mapping?": "हे व्हीआरपी आयसीएस मॅपिंग डिलीट करायचे?",
	      "Delete this target mapping?": "हे लक्ष्य मॅपिंग डिलीट करायचे?",
	      "Action": "कारवाई",
	      "Save Mapping": "मॅपिंग सेव करा",
	      "Update Mapping": "मॅपिंग अपडेट करा",
	      "Save Target": "लक्ष्य सेव करा",
	      "Update Target": "लक्ष्य अपडेट करा",
	      "Cancel Edit": "एडिट रद्द करा",
	      "Select VRP": "व्हीआरपी निवडा",
	      "Select FCO": "एफसीओ निवडा",
	      "Select FCO Name": "एफसीओ नाव निवडा",
	      "Select ICS": "आयसीएस निवडा",
	      "Select Village": "गाव निवडा",
	      "FCO Name": "एफसीओ नाव",
	      "Registered Farmers": "नोंदणीकृत किसान",
	      "Farmer List": "किसान सूची",
	      "Select FCO Name, ICS and Village to load farmers.": "किसान लोड करण्यासाठी एफसीओ नाव, आयसीएस आणि गाव निवडा.",
	      "No farmers found for selected village.": "निवडलेल्या गावासाठी कोणतेही किसान सापडले नाहीत.",
	      "Select all": "सर्व निवडा",
	      "No VRP ICS mapping saved yet.": "अजून कोणतेही व्हीआरपी आयसीएस मॅपिंग सेव नाही.",
	      "No target mapping saved yet.": "अजून कोणतेही लक्ष्य मॅपिंग सेव नाही."
      ,"Training Form": "प्रशिक्षण फॉर्म",
	      "Farmer Training": "किसान प्रशिक्षण",
	      "Farmer Training Form": "किसान प्रशिक्षण फॉर्म",
	      "Farmer Training Form List": "किसान प्रशिक्षण फॉर्म सूची",
      "Training Topic Mapping": "प्रशिक्षण टॉपिक मॅपिंग",
	      "Farmer Training Topic Mapping": "किसान प्रशिक्षण टॉपिक मॅपिंग",
	      "Trainer Name": "प्रशिक्षक नाव",
	      "Trainer Contact": "प्रशिक्षक संपर्क",
	      "Farmer Count": "किसान संख्या",
	      "Selected Farmers": "निवडलेले किसान",
	      "Training Photo Upload with Geo Tag": "जिओ टॅगसह प्रशिक्षण फोटो अपलोड",
	      "Mapped Farmers": "मॅप केलेले किसान",
	      "Target Farmers": "लक्षित किसान",
	      "Select Village Name to load mapped farmers.": "मॅप केलेले किसान लोड करण्यासाठी गाव नाव निवडा.",
	      "Select Village Name to load target farmers.": "लक्षित किसान लोड करण्यासाठी गाव नाव निवडा.",
	      "No mapped farmers found for selected village.": "निवडलेल्या गावासाठी कोणतेही मॅप किसान सापडले नाहीत.",
	      "No target farmers found for selected village.": "निवडलेल्या गावासाठी कोणतेही लक्षित किसान सापडले नाहीत."
	    };
	    const odiaTranslations = {
	      "Language": "ଭାଷା",
	      "Dashboard": "ଡ୍ୟାସବୋର୍ଡ",
	      "Sign Out": "ସାଇନ୍ ଆଉଟ୍",
	      "Target Mapping": "ଟାର୍ଗେଟ୍ ମ୍ୟାପିଂ",
	      "Target Mapping Upload": "ଟାର୍ଗେଟ୍ ମ୍ୟାପିଂ ଅପଲୋଡ୍",
	      "AFL Upload": "ଏଏଫଏଲ୍ ଅପଲୋଡ୍",
	      "Target Mapping Master": "ଟାର୍ଗେଟ୍ ମ୍ୟାପିଂ ମାଷ୍ଟର",
	      "VRP ICS Mapping": "ଭିଆରପି ଆଇସିଏସ୍ ମ୍ୟାପିଂ",
	      "Recent Target Mappings": "ସମ୍ପ୍ରତି ଟାର୍ଗେଟ୍ ମ୍ୟାପିଂ",
	      "Recent VRP ICS Mappings": "ସମ୍ପ୍ରତି ଭିଆରପି ଆଇସିଏସ୍ ମ୍ୟାପିଂ",
	      "Office Setup": "ଅଫିସ୍ ସେଟଅପ୍",
	      "Office Category": "ଅଫିସ୍ ବର୍ଗ",
	      "Office Name": "ଅଫିସ୍ ନାମ",
      "Sub Office Add": "ସବ୍ ଅଫିସ୍ ଯୋଡନ୍ତୁ",
      "Sub Office Name": "ସବ୍ ଅଫିସ୍ ନାମ",
	      "Office Level": "ଅଫିସ୍ ସ୍ତର",
	      "Select Office Category": "ଅଫିସ୍ ବର୍ଗ ବାଛନ୍ତୁ",
	      "Select Office Name": "ଅଫିସ୍ ନାମ ବାଛନ୍ତୁ",
	      "FCOC-C": "ଏଫସିଓସି-ସି",
	      "Select FCOC-C": "ଏଫସିଓସି-ସି ବାଛନ୍ତୁ",
	      "TO": "ଟିଓ",
	      "Select TO": "ଟିଓ ବାଛନ୍ତୁ",
	      "Cluster Incharge": "କ୍ଲଷ୍ଟର ଇନଚାର୍ଜ",
	      "Select Cluster Incharge": "କ୍ଲଷ୍ଟର ଇନଚାର୍ଜ ବାଛନ୍ତୁ",
	      "VRP Registration": "ଭିଆରପି ପଞ୍ଜୀକରଣ",
	      "User Register": "ୟୁଜର ପଞ୍ଜୀକରଣ",
	      "Edit": "ଏଡିଟ୍",
	      "Delete": "ଡିଲିଟ୍",
	      "Remove": "ହଟାନ୍ତୁ",
	      "Remove this VRP ICS mapping?": "ଏହି ଭିଆରପି ଆଇସିଏସ୍ ମ୍ୟାପିଂ ହଟାଇବେ?",
	      "Remove this target mapping?": "ଏହି ଟାର୍ଗେଟ୍ ମ୍ୟାପିଂ ହଟାଇବେ?",
	      "Delete this VRP ICS mapping?": "ଏହି ଭିଆରପି ଆଇସିଏସ୍ ମ୍ୟାପିଂ ଡିଲିଟ୍ କରିବେ?",
	      "Delete this target mapping?": "ଏହି ଟାର୍ଗେଟ୍ ମ୍ୟାପିଂ ଡିଲିଟ୍ କରିବେ?",
	      "Action": "କାର୍ଯ୍ୟ",
	      "Save Mapping": "ମ୍ୟାପିଂ ସେଭ୍ କରନ୍ତୁ",
	      "Update Mapping": "ମ୍ୟାପିଂ ଅପଡେଟ୍ କରନ୍ତୁ",
	      "Save Target": "ଟାର୍ଗେଟ୍ ସେଭ୍ କରନ୍ତୁ",
	      "Update Target": "ଟାର୍ଗେଟ୍ ଅପଡେଟ୍ କରନ୍ତୁ",
	      "Cancel Edit": "ଏଡିଟ୍ ବାତିଲ୍",
	      "Select VRP": "ଭିଆରପି ବାଛନ୍ତୁ",
	      "Select FCO": "ଏଫସିଓ ବାଛନ୍ତୁ",
	      "Select FCO Name": "ଏଫସିଓ ନାମ ବାଛନ୍ତୁ",
	      "Select ICS": "ଆଇସିଏସ୍ ବାଛନ୍ତୁ",
	      "Select Village": "ଗ୍ରାମ ବାଛନ୍ତୁ",
	      "FCO Name": "ଏଫସିଓ ନାମ",
	      "Registered Farmers": "ପଞ୍ଜୀକୃତ କୃଷକ",
	      "Farmer List": "କୃଷକ ତାଲିକା",
	      "Select FCO Name, ICS and Village to load farmers.": "କୃଷକ ଲୋଡ୍ କରିବାକୁ ଏଫସିଓ ନାମ, ଆଇସିଏସ୍ ଏବଂ ଗ୍ରାମ ବାଛନ୍ତୁ.",
	      "No farmers found for selected village.": "ବାଛିଥିବା ଗ୍ରାମ ପାଇଁ କୌଣସି କୃଷକ ମିଳିଲେ ନାହିଁ.",
	      "Select all": "ସବୁ ବାଛନ୍ତୁ",
	      "No VRP ICS mapping saved yet.": "ଏପର୍ଯ୍ୟନ୍ତ କୌଣସି ଭିଆରପି ଆଇସିଏସ୍ ମ୍ୟାପିଂ ସେଭ୍ ହୋଇନାହିଁ.",
	      "No target mapping saved yet.": "ଏପର୍ଯ୍ୟନ୍ତ କୌଣସି ଟାର୍ଗେଟ୍ ମ୍ୟାପିଂ ସେଭ୍ ହୋଇନାହିଁ."
      ,"Training Form": "ପ୍ରଶିକ୍ଷଣ ଫର୍ମ",
	      "Farmer Training": "କୃଷକ ପ୍ରଶିକ୍ଷଣ",
	      "Farmer Training Form": "କୃଷକ ପ୍ରଶିକ୍ଷଣ ଫର୍ମ",
	      "Farmer Training Form List": "କୃଷକ ପ୍ରଶିକ୍ଷଣ ଫର୍ମ ତାଲିକା",
      "Training Topic Mapping": "ପ୍ରଶିକ୍ଷଣ ଟପିକ୍ ମ୍ୟାପିଂ",
	      "Farmer Training Topic Mapping": "କୃଷକ ପ୍ରଶିକ୍ଷଣ ଟପିକ୍ ମ୍ୟାପିଂ",
	      "Trainer Name": "ପ୍ରଶିକ୍ଷକ ନାମ",
	      "Trainer Contact": "ପ୍ରଶିକ୍ଷକ ଯୋଗାଯୋଗ",
	      "Farmer Count": "କୃଷକ ସଂଖ୍ୟା",
	      "Selected Farmers": "ବାଛିଥିବା କୃଷକ",
	      "Training Photo Upload with Geo Tag": "ଜିଓ ଟ୍ୟାଗ୍ ସହିତ ପ୍ରଶିକ୍ଷଣ ଫଟୋ ଅପଲୋଡ୍",
	      "Mapped Farmers": "ମ୍ୟାପ୍ ହୋଇଥିବା କୃଷକ",
	      "Target Farmers": "ଲକ୍ଷ୍ୟ କୃଷକ",
	      "Select Village Name to load mapped farmers.": "ମ୍ୟାପ୍ ହୋଇଥିବା କୃଷକ ଲୋଡ୍ କରିବାକୁ ଗ୍ରାମ ନାମ ବାଛନ୍ତୁ.",
	      "Select Village Name to load target farmers.": "ଲକ୍ଷ୍ୟ କୃଷକ ଲୋଡ୍ କରିବାକୁ ଗ୍ରାମ ନାମ ବାଛନ୍ତୁ.",
	      "No mapped farmers found for selected village.": "ବାଛିଥିବା ଗ୍ରାମ ପାଇଁ କୌଣସି ମ୍ୟାପ୍ କୃଷକ ମିଳିଲେ ନାହିଁ.",
	      "No target farmers found for selected village.": "ବାଛିଥିବା ଗ୍ରାମ ପାଇଁ କୌଣସି ଲକ୍ଷ୍ୟ କୃଷକ ମିଳିଲେ ନାହିଁ."
	    };
	    const languageTranslations = {
	      hi: translations,
	      mr: marathiTranslations,
	      or: odiaTranslations
	    };

    const googleLanguageCodes = { en: "en", hi: "hi", mr: "mr", or: "or" };
    const setGoogleTranslateCookie = (language) => {
      const value = `/en/${googleLanguageCodes[language] || "en"}`;
      document.cookie = `googtrans=${value};path=/`;
      document.cookie = `googtrans=${value};path=/;domain=${window.location.hostname}`;
    };
    const loadGoogleTranslate = () => {
      if (window.google?.translate?.TranslateElement) return Promise.resolve();
      if (window.__vrpGoogleTranslateLoading) return window.__vrpGoogleTranslateLoading;

      window.__vrpGoogleTranslateLoading = new Promise((resolve) => {
        window.googleTranslateElementInit = () => {
          if (window.google?.translate?.TranslateElement) {
            new window.google.translate.TranslateElement({
              pageLanguage: "en",
              includedLanguages: "en,hi,mr,or",
              autoDisplay: false
            }, "google_translate_element");
          }
          resolve();
        };

        const script = document.createElement("script");
        script.src = "https://translate.google.com/translate_a/element.js?cb=googleTranslateElementInit";
        script.async = true;
        script.onerror = () => resolve();
        document.head.appendChild(script);
      });

      return window.__vrpGoogleTranslateLoading;
    };
    const applyGoogleLanguage = (language) => {
      setGoogleTranslateCookie(language);
      if (language === "en") {
        const combo = document.querySelector(".goog-te-combo");
        if (combo) {
          combo.value = "";
          combo.dispatchEvent(new Event("change"));
        }
        return;
      }

      loadGoogleTranslate().then(() => {
        const combo = document.querySelector(".goog-te-combo");
        if (!combo) return;

        combo.value = googleLanguageCodes[language] || "en";
        combo.dispatchEvent(new Event("change"));
      });
    };

    const preserveSpacing = (original, replacement) => {
      const leading = original.match(/^\s*/)?.[0] || "";
      const trailing = original.match(/\s*$/)?.[0] || "";
      return `${leading}${replacement}${trailing}`;
    };

    const translatePhrase = (text, language) => {
      const trimmed = text.trim();
      if (!trimmed) return text;
      if (/^[\s\d.,:;/%#()\-–—|]+$/.test(trimmed)) return text;

	      const selectedTranslations = languageTranslations[language] || {};
	      const exact = language === "en" ? englishTranslations[trimmed] : selectedTranslations[trimmed];
	      if (exact) return preserveSpacing(text, exact);
	      if (language === "en") return text;
	      if (language !== "hi") return text;

      let match = trimmed.match(/^Select (.+)$/);
      if (match) return preserveSpacing(text, `${translatePhrase(match[1], "hi").trim()} चुनें`);

      match = trimmed.match(/^Enter (.+)$/);
      if (match) return preserveSpacing(text, `${translatePhrase(match[1], "hi").trim()} दर्ज करें`);

      match = trimmed.match(/^Search (.+)$/);
      if (match) return preserveSpacing(text, `${translatePhrase(match[1], "hi").trim()} खोजें`);

      match = trimmed.match(/^No (.+) saved yet\.$/);
      if (match) return preserveSpacing(text, `अभी कोई ${translatePhrase(match[1], "hi").trim()} सेव नहीं है।`);

      match = trimmed.match(/^(\d+) records$/);
      if (match) return preserveSpacing(text, `${match[1]} रिकॉर्ड`);

      match = trimmed.match(/^Page (\d+) of (\d+)$/);
      if (match) return preserveSpacing(text, `पेज ${match[1]} / ${match[2]}`);

      match = trimmed.match(/^(\d+) to (\d+) of (\d+)$/);
      if (match) return preserveSpacing(text, `${match[1]} से ${match[2]} कुल ${match[3]}`);

      return text;
    };

    const translateTextNode = (node, language) => {
      if (!node.nodeValue.trim()) return;
      const parent = node.parentElement;
      if (!parent || parent.closest("script, style, textarea, code, pre")) return;

      const original = originalText.get(node) || node.nodeValue;
      originalText.set(node, original);
      node.nodeValue = replaceVrpUiText(translatePhrase(original, language));
    };

    const translateAttributes = (element, language) => {
      attributeNames.forEach((attribute) => {
        const value = element.getAttribute(attribute);
        if (!value) return;

        const dataKey = `i18nOriginal${attribute.replace(/(^|-)([a-z])/g, (_match, _dash, letter) => letter.toUpperCase())}`;
        const original = element.dataset[dataKey] || value;
        element.dataset[dataKey] = original;
        element.setAttribute(attribute, replaceVrpUiText(translatePhrase(original, language)));
      });

      if ((element.matches("input[type='submit'], input[type='button']")) && element.value) {
        element.dataset.i18nOriginalValue ||= element.value;
        element.value = replaceVrpUiText(translatePhrase(element.dataset.i18nOriginalValue, language)).trim();
      }
    };

    let languageMutationTimer = null;
    let languageApplying = false;
	    const applyLanguage = (language) => {
      languageApplying = true;
	      document.documentElement.lang = language;
      document.title = replaceVrpUiText(document.title);
      languageButtons.forEach((button) => {
        button.classList.toggle("active", button.dataset.languageOption === language);
      });

      document.querySelectorAll("body *").forEach((element) => {
        translateAttributes(element, language);
        element.childNodes.forEach((node) => {
          if (node.nodeType === Node.TEXT_NODE) translateTextNode(node, language);
        });
      });
      languageApplying = false;
	    };

	    const setLanguage = (language) => {
	      const nextLanguage = ["en", "hi", "mr", "or"].includes(language) ? language : "en";
      localStorage.setItem("vrp_language", nextLanguage);
      applyGoogleLanguage(nextLanguage);
      applyLanguage(nextLanguage);
    };

    if (switcher) {
      languageButtons.forEach((button) => {
        button.addEventListener("click", () => setLanguage(button.dataset.languageOption));
      });
    }

    setLanguage(localStorage.getItem("vrp_language") || "en");
    const languageObserver = new MutationObserver(() => {
      if (languageApplying) return;

      clearTimeout(languageMutationTimer);
      languageMutationTimer = setTimeout(() => {
        applyLanguage(localStorage.getItem("vrp_language") || "en");
      }, 120);
    });
    languageObserver.observe(document.body, { childList: true, subtree: true });
  };

  initializeLanguageSwitcher();
});
