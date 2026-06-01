document.addEventListener("turbo:load", () => {
  document.querySelectorAll("[data-password-toggle]").forEach((button) => {
    button.addEventListener("click", () => {
      const input = button.closest(".login-password-field")?.querySelector("[data-password-toggle-input]");
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

  document.querySelectorAll("[data-export-table]").forEach((button) => {
    button.addEventListener("click", () => {
      const table = document.getElementById(button.dataset.exportTable);
      if (!table) return;

      const rows = Array.from(table.querySelectorAll("tr")).map((row) => {
        return Array.from(row.children)
          .slice(1)
          .map((cell) => `"${cell.innerText.replaceAll('"', '""')}"`)
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
    const matchedRows = dataRows.filter((row) => row.innerText.toLowerCase().includes(query));
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

  document.querySelectorAll("[data-paginated-table]").forEach((table) => {
    table.querySelectorAll("tbody tr").forEach((row) => {
      if (row.children.length === 1 || row.innerText.toLowerCase().includes("no records")) {
        row.dataset.emptyRow = "true";
      }
    });
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

  document.querySelectorAll("[data-clear-approval-level]").forEach((button) => {
    button.addEventListener("click", () => {
      const rowCells = [button.closest(".approval-level-cell")?.previousElementSibling, button.closest(".approval-level-cell")];
      rowCells.forEach((cell) => {
        const select = cell?.querySelector("select");
        if (select) select.value = "";
      });
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
