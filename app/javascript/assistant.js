// In-app AI assistant: floating chat widget.
// Talks to POST /assistant/chat, keeps a short in-memory conversation history,
// and renders the exchange in a panel. No external dependencies.

// Set when a drag finishes, so the trailing click does not toggle the panel.
let swallowNextClick = false;
// The single window-resize listener owned by the current launcher.
let keepLauncherInView = null;

function initAssistant() {
  const root = document.querySelector("[data-ai-assistant]");
  if (!root || root.dataset.aiReady === "true") return;
  root.dataset.aiReady = "true";

  const endpoint = root.dataset.endpoint || "/assistant/chat";
  const toggle = root.querySelector("[data-ai-toggle]");
  const panel = root.querySelector("[data-ai-panel]");
  const closeBtn = root.querySelector("[data-ai-close]");
  const form = root.querySelector("[data-ai-form]");
  const input = root.querySelector("[data-ai-input]");
  const sendBtn = root.querySelector("[data-ai-send]");
  const messagesEl = root.querySelector("[data-ai-messages]");

  if (!toggle || !panel || !form || !input || !messagesEl) return;

  // Conversation history sent to the server (excludes the greeting bubble).
  const history = [];
  let busy = false;
  let reportLinks = [];
  const reportPanel = root.querySelector("[data-ai-report-panel]");
  const reportList = root.querySelector("[data-ai-report-list]");
  const reportSearch = root.querySelector("[data-ai-report-search]");
  const welcome = root.querySelector("[data-ai-welcome]");
  const clearButton = root.querySelector("[data-ai-clear]");

  function safeLink(item) {
    if (!item || typeof item.url !== "string" || !item.url.startsWith("/") || item.url.startsWith("//")) return null;
    const url = new URL(item.url, window.location.origin);
    if (url.origin !== window.location.origin) return null;
    const link = document.createElement("a");
    link.href = url.href;
    link.textContent = (item.kind === "excel" ? "↓ " : "↗ ") + item.title;
    link.dataset.turbo = "false";
    return link;
  }

  function renderReports() {
    reportList.replaceChildren();
    const term = reportSearch.value.trim().toLowerCase();
    const matches = reportLinks.filter((item) => item.title.toLowerCase().includes(term));
    matches.forEach((item) => { const link = safeLink(item); if (link) reportList.appendChild(link); });
    if (!matches.length) reportList.textContent = "No matching reports. Try another report name.";
  }

  async function showReports() {
    reportPanel.hidden = false;
    reportList.textContent = "Loading reports…";
    try {
      const url = new URL(root.dataset.reportsEndpoint, window.location.origin);
      url.search = window.location.search;
      const response = await fetch(url, { headers: { Accept: "application/json" } });
      if (!response.ok) throw new Error("Reports unavailable");
      const data = await response.json();
      reportLinks = data.reports || [];
      renderReports();
    } catch (_) { reportList.textContent = "Reports could not load. Close and reopen Excel reports to retry."; }
    reportSearch.focus();
  }

  function csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.getAttribute("content") : "";
  }

  function openPanel() {
    panel.hidden = false;
    toggle.setAttribute("aria-expanded", "true");
    root.classList.add("ai-assistant--open");
    setTimeout(() => input.focus(), 50);
  }

  function closePanel() {
    panel.hidden = true;
    toggle.setAttribute("aria-expanded", "false");
    root.classList.remove("ai-assistant--open");
    toggle.focus();
  }

  function scrollToBottom() {
    messagesEl.scrollTop = messagesEl.scrollHeight;
  }

  function addMessage(text, who) {
    const bubble = document.createElement("div");
    bubble.className = "ai-assistant-msg ai-assistant-msg--" + who;
    bubble.textContent = text;
    messagesEl.appendChild(bubble);
    scrollToBottom();
    return bubble;
  }

  function addTyping() {
    const bubble = document.createElement("div");
    bubble.className = "ai-assistant-msg ai-assistant-msg--bot ai-assistant-typing";
    bubble.setAttribute("aria-label", "Preparing your answer");
    bubble.innerHTML = "<span></span><span></span><span></span>";
    messagesEl.appendChild(bubble);
    scrollToBottom();
    return bubble;
  }

  function setBusy(state) {
    busy = state;
    if (sendBtn) sendBtn.disabled = state;
    input.disabled = state;
    clearButton.disabled = state;
    messagesEl.setAttribute("aria-busy", String(state));
  }

  function autoGrow() {
    input.style.height = "auto";
    input.style.height = Math.min(input.scrollHeight, 120) + "px";
  }

  async function send(text) {
    if (busy) return;
    const message = text.trim();
    if (!message) return;

    if (welcome) welcome.hidden = true;
    addMessage(message, "user");
    history.push({ role: "user", content: message });
    input.value = "";
    autoGrow();
    setBusy(true);
    const typing = addTyping();

    const abortController = new AbortController();
    const timer = setTimeout(() => abortController.abort(), 90000);
    try {
      const response = await fetch(endpoint, {
        signal: abortController.signal,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken(),
          "Accept": "application/json"
        },
        body: JSON.stringify({ messages: history.slice(-20), context: Object.fromEntries(new URLSearchParams(window.location.search)) })
      });

      let data = {};
      try { data = await response.json(); } catch (e) { data = {}; }
      typing.remove();

      if (response.ok && data.reply) {
        const bubble = addMessage(data.reply, "bot");
        const actions = [...(data.downloads || []), ...(data.links || [])];
        if (actions.length) {
          const links = document.createElement("div");
          links.className = "ai-assistant-links";
          actions.forEach((item) => { const link = safeLink(item); if (link) links.appendChild(link); });
          bubble.appendChild(links);
          scrollToBottom();
        }
        if (data.show_reports && !actions.length) showReports();
        history.push({ role: "assistant", content: data.reply });
      } else {
        // Roll back the unanswered user turn so history stays valid.
        history.pop();
        addMessage(data.error || "Sorry, something went wrong. Please try again.", "error");
      }
    } catch (e) {
      typing.remove();
      history.pop();
      addMessage(e.name === "AbortError" ? "Response took too long. Please retry, or use Excel reports." : "Network error. Please check your connection and try again.", "error");
    } finally {
      clearTimeout(timer);
      setBusy(false);
      input.focus();
    }
  }

  reportSearch.addEventListener("input", renderReports);
  clearButton.addEventListener("click", () => {
    if (busy) return;
    history.length = 0;
    messagesEl.querySelectorAll(".ai-assistant-msg").forEach((message) => message.remove());
    if (welcome) welcome.hidden = false;
    input.focus();
  });
  root.querySelectorAll("[data-ai-prompt]").forEach((button) => button.addEventListener("click", () => send(button.dataset.aiPrompt)));
  root.addEventListener("keydown", (event) => { if (event.key === "Escape") closePanel(); });

  // ── Draggable launcher ──────────────────────────────────────────────────
  // The launcher floats over the bottom-right corner, where it covers table
  // pagination. Let the user shove it out of the way. The position is
  // deliberately not persisted: any refresh or navigation drops it back into
  // its CSS home corner.
  const DRAG_THRESHOLD_PX = 4;
  let drag = null;

  // A restored Turbo cache snapshot can carry the dragged inline styles back,
  // so clear them on every init to keep "refresh puts it back" true.
  root.style.cssText = "";
  root.classList.remove("ai-assistant--left", "ai-assistant--top", "ai-assistant--dragging");

  function moveTo(left, top) {
    const rect = root.getBoundingClientRect();
    const x = Math.min(Math.max(left, 0), Math.max(0, window.innerWidth - rect.width));
    const y = Math.min(Math.max(top, 0), Math.max(0, window.innerHeight - rect.height));
    root.style.left = `${x}px`;
    root.style.top = `${y}px`;
    root.style.right = "auto";
    root.style.bottom = "auto";
    // Re-anchor the panel so it never opens off-screen.
    root.classList.toggle("ai-assistant--left", x + rect.width / 2 < window.innerWidth / 2);
    root.classList.toggle("ai-assistant--top", y + rect.height / 2 < window.innerHeight / 2);
  }

  toggle.addEventListener("pointerdown", (event) => {
    if (event.pointerType === "mouse" && event.button !== 0) return;

    const rect = root.getBoundingClientRect();
    drag = {
      id: event.pointerId,
      grabX: event.clientX - rect.left,
      grabY: event.clientY - rect.top,
      fromX: event.clientX,
      fromY: event.clientY,
      moved: false
    };
  });

  toggle.addEventListener("pointermove", (event) => {
    if (!drag || event.pointerId !== drag.id) return;

    if (!drag.moved) {
      // Below the threshold this is still a click, not a drag.
      if (Math.abs(event.clientX - drag.fromX) < DRAG_THRESHOLD_PX &&
          Math.abs(event.clientY - drag.fromY) < DRAG_THRESHOLD_PX) return;

      drag.moved = true;
      root.classList.add("ai-assistant--dragging");
      toggle.setPointerCapture(drag.id);
    }
    event.preventDefault();
    moveTo(event.clientX - drag.grabX, event.clientY - drag.grabY);
  });

  function endDrag(event) {
    if (!drag || event.pointerId !== drag.id) return;

    if (toggle.hasPointerCapture(drag.id)) toggle.releasePointerCapture(drag.id);
    swallowNextClick = drag.moved;
    drag = null;
    root.classList.remove("ai-assistant--dragging");
  }
  toggle.addEventListener("pointerup", endDrag);
  toggle.addEventListener("pointercancel", endDrag);

  // Keep a dragged launcher on screen when the window is resized. Only one
  // listener may exist at a time -- Turbo re-runs this file on every page.
  if (keepLauncherInView) window.removeEventListener("resize", keepLauncherInView);
  keepLauncherInView = () => {
    if (!root.isConnected || !root.style.left) return;
    moveTo(parseFloat(root.style.left), parseFloat(root.style.top));
  };
  window.addEventListener("resize", keepLauncherInView);

  toggle.addEventListener("click", (event) => {
    // A drag ends with a click event on the button; don't open the panel then.
    if (swallowNextClick) {
      swallowNextClick = false;
      event.preventDefault();
      return;
    }
    if (panel.hidden) openPanel(); else closePanel();
  });
  if (closeBtn) closeBtn.addEventListener("click", closePanel);

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    send(input.value);
  });

  input.addEventListener("input", autoGrow);
  input.addEventListener("keydown", (event) => {
    // Enter sends; Shift+Enter makes a new line.
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      send(input.value);
    }
  });
}

document.addEventListener("turbo:load", initAssistant);
document.addEventListener("DOMContentLoaded", initAssistant);
