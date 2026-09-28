// In-app AI assistant: floating chat widget.
// Talks to POST /assistant/chat, keeps a short in-memory conversation history,
// and renders the exchange in a panel. No external dependencies.

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
    bubble.innerHTML = "<span></span><span></span><span></span>";
    messagesEl.appendChild(bubble);
    scrollToBottom();
    return bubble;
  }

  function setBusy(state) {
    busy = state;
    if (sendBtn) sendBtn.disabled = state;
    input.disabled = state;
  }

  function autoGrow() {
    input.style.height = "auto";
    input.style.height = Math.min(input.scrollHeight, 120) + "px";
  }

  async function send(text) {
    if (busy) return;
    const message = text.trim();
    if (!message) return;

    addMessage(message, "user");
    history.push({ role: "user", content: message });
    input.value = "";
    autoGrow();
    setBusy(true);
    const typing = addTyping();

    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken(),
          "Accept": "application/json"
        },
        body: JSON.stringify({ messages: history })
      });

      let data = {};
      try { data = await response.json(); } catch (e) { data = {}; }
      typing.remove();

      if (response.ok && data.reply) {
        addMessage(data.reply, "bot");
        history.push({ role: "assistant", content: data.reply });
      } else {
        // Roll back the unanswered user turn so history stays valid.
        history.pop();
        addMessage(data.error || "Sorry, something went wrong. Please try again.", "error");
      }
    } catch (e) {
      typing.remove();
      history.pop();
      addMessage("Network error. Please check your connection and try again.", "error");
    } finally {
      setBusy(false);
      input.focus();
    }
  }

  toggle.addEventListener("click", () => {
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
