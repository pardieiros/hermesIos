(function () {
  "use strict";

  const SDK = window.__HERMES_PLUGIN_SDK__;
  if (!SDK || !window.__HERMES_PLUGINS__) return;

  const React = SDK.React;
  const { useState, useEffect } = SDK.hooks;
  const { fetchJSON } = SDK;
  const e = React.createElement;

  // ── Inline styles ────────────────────────────────────────────────────
  const S = {
    page: {
      minHeight: "100vh",
      background: "#0d0d0d",
      color: "#e8e8e8",
      fontFamily: "Menlo, Monaco, 'Courier New', monospace",
      padding: "32px",
      boxSizing: "border-box",
    },
    header: {
      display: "flex",
      alignItems: "center",
      gap: "16px",
      marginBottom: "36px",
    },
    iconBox: {
      width: "52px",
      height: "52px",
      background: "rgba(255,215,0,0.15)",
      borderRadius: "14px",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      fontSize: "24px",
      flexShrink: 0,
    },
    title: {
      margin: 0,
      fontSize: "22px",
      fontWeight: "700",
      color: "#FFD700",
      letterSpacing: "-0.3px",
    },
    subtitle: {
      margin: "4px 0 0",
      fontSize: "13px",
      color: "#5a5a5a",
    },
    grid: {
      display: "grid",
      gridTemplateColumns: "repeat(auto-fill, minmax(320px, 1fr))",
      gap: "16px",
      marginBottom: "20px",
    },
    card: {
      background: "#161616",
      border: "1px solid #2a2a2a",
      borderRadius: "12px",
      padding: "20px",
    },
    cardTitle: {
      fontSize: "11px",
      fontWeight: "600",
      color: "#5a5a5a",
      letterSpacing: "0.8px",
      textTransform: "uppercase",
      marginBottom: "14px",
    },
    row: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      marginBottom: "10px",
    },
    label: { fontSize: "13px", color: "#a0a0a0" },
    value: {
      fontSize: "13px",
      color: "#e8e8e8",
      fontWeight: "500",
      background: "#0d0d0d",
      padding: "4px 10px",
      borderRadius: "6px",
      border: "1px solid #2a2a2a",
      maxWidth: "200px",
      overflow: "hidden",
      textOverflow: "ellipsis",
      whiteSpace: "nowrap",
    },
    copyBtn: {
      background: "transparent",
      border: "1px solid #2a2a2a",
      borderRadius: "6px",
      color: "#a0a0a0",
      fontSize: "11px",
      padding: "4px 10px",
      cursor: "pointer",
      fontFamily: "inherit",
      transition: "all 0.15s",
    },
    stepList: {
      listStyle: "none",
      margin: 0,
      padding: 0,
    },
    step: {
      display: "flex",
      gap: "14px",
      marginBottom: "16px",
      alignItems: "flex-start",
    },
    stepNum: {
      width: "24px",
      height: "24px",
      background: "rgba(255,215,0,0.15)",
      color: "#FFD700",
      borderRadius: "50%",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      fontSize: "12px",
      fontWeight: "700",
      flexShrink: 0,
      marginTop: "1px",
    },
    stepText: { fontSize: "13px", color: "#a0a0a0", lineHeight: "1.6" },
    code: {
      display: "inline-block",
      background: "#1e1e1e",
      border: "1px solid #2a2a2a",
      borderRadius: "5px",
      padding: "2px 8px",
      color: "#39d353",
      fontSize: "12px",
    },
    badge: {
      display: "inline-flex",
      alignItems: "center",
      gap: "6px",
      padding: "4px 12px",
      borderRadius: "20px",
      fontSize: "12px",
      fontWeight: "600",
    },
    dot: {
      width: "7px",
      height: "7px",
      borderRadius: "50%",
    },
    divider: {
      height: "1px",
      background: "#2a2a2a",
      margin: "8px 0 16px",
    },
    tokenBox: {
      background: "#0d0d0d",
      border: "1px solid #2a2a2a",
      borderRadius: "8px",
      padding: "12px 14px",
      fontFamily: "Menlo, monospace",
      fontSize: "12px",
      color: "#FFD700",
      wordBreak: "break-all",
      lineHeight: "1.5",
    },
    sourceLink: {
      display: "inline-flex",
      alignItems: "center",
      gap: "6px",
      color: "#FFD700",
      fontSize: "13px",
      textDecoration: "none",
      borderBottom: "1px solid rgba(255,215,0,0.3)",
      paddingBottom: "1px",
    },
    warning: {
      background: "rgba(255,85,85,0.08)",
      border: "1px solid rgba(255,85,85,0.25)",
      borderRadius: "8px",
      padding: "10px 14px",
      fontSize: "12px",
      color: "#ff8888",
      marginTop: "10px",
    },
  };

  // ── Copy helper ──────────────────────────────────────────────────────
  function CopyButton({ text }) {
    const [copied, setCopied] = useState(false);
    const copy = function () {
      try { navigator.clipboard.writeText(text); } catch (_) {}
      setCopied(true);
      setTimeout(function () { setCopied(false); }, 1500);
    };
    return e("button", {
      style: {
        ...S.copyBtn,
        color: copied ? "#39d353" : "#a0a0a0",
        borderColor: copied ? "#39d353" : "#2a2a2a",
      },
      onClick: copy,
    }, copied ? "✓ Copied" : "Copy");
  }

  // ── Connection info row ──────────────────────────────────────────────
  function InfoRow({ label, value, copyValue }) {
    return e("div", { style: S.row },
      e("span", { style: S.label }, label),
      e("div", { style: { display: "flex", alignItems: "center", gap: "8px" } },
        e("span", { style: S.value, title: value }, value),
        copyValue !== undefined && e(CopyButton, { text: copyValue || value })
      )
    );
  }

  // ── Main page ────────────────────────────────────────────────────────
  function HermesIosPage() {
    const [status, setStatus] = useState(null);
    const [error, setError] = useState(null);

    useEffect(function () {
      fetchJSON("/api/status")
        .then(function (data) { setStatus(data); })
        .catch(function (err) { setError(String(err)); });
    }, []);

    const browserHost = window.location.hostname;
    const port = window.location.port || (window.location.protocol === "https:" ? "443" : "80");
    const token = window.__HERMES_SESSION_TOKEN__ || "";
    const isLoopback = browserHost === "localhost" || browserHost === "127.0.0.1";
    // If the browser is on localhost it may be SSH-tunnelled — the iPhone
    // needs the actual LAN/VPN IP. We extract it from the status API or
    // show a clear warning.
    const serverIp = (status && status.hostname) || (isLoopback ? null : browserHost);

    return e("div", { style: S.page },
      // Header
      e("div", { style: S.header },
        e("div", { style: S.iconBox }, "📱"),
        e("div", null,
          e("h1", { style: S.title }, "Hermes iOS"),
          e("p", { style: S.subtitle }, "Native terminal-style companion app for iPhone")
        )
      ),

      // Status + connection grid
      e("div", { style: S.grid },

        // Connection details card
        e("div", { style: S.card },
          e("div", { style: S.cardTitle }, "Connection Details"),

          // Warn when accessed via localhost — iPhone can't use that
          isLoopback && e("div", { style: {
            background: "rgba(255,215,0,0.08)",
            border: "1px solid rgba(255,215,0,0.25)",
            borderRadius: "8px",
            padding: "10px 14px",
            fontSize: "12px",
            color: "#FFD700",
            marginBottom: "14px",
          }},
            "⚠ Dashboard accessed via localhost — your iPhone needs the real server IP. " +
            "Run: ",
            e("span", { style: S.code }, "hermes dashboard --host 0.0.0.0 --insecure"),
            " then open the dashboard via the server IP (e.g. http://192.168.x.x:9119)."
          ),

          e(InfoRow, {
            label: "Host (browser)",
            value: browserHost,
          }),
          serverIp && !isLoopback && e(InfoRow, {
            label: "Host (for iPhone)",
            value: serverIp,
            copyValue: serverIp,
          }),
          e(InfoRow, { label: "Port", value: port, copyValue: port }),
          e(InfoRow, {
            label: "Protocol",
            value: window.location.protocol === "https:" ? "WSS (secure)" : "WS",
          }),
          status && e(InfoRow, {
            label: "Hermes version",
            value: status.version || "—",
          }),
          e("div", { style: S.divider }),
          e("div", { style: S.cardTitle }, "Session Token"),
          token
            ? e("div", null,
                e("div", { style: S.tokenBox }, token.slice(0, 32) + "…"),
                e("div", { style: { marginTop: "10px", display: "flex", justifyContent: "flex-end" } },
                  e(CopyButton, { text: token })
                ),
                e("div", { style: S.warning },
                  "⚠ Token grants full access to your Hermes instance. Only use on trusted devices."
                )
              )
            : e("div", { style: { color: "#5a5a5a", fontSize: "13px" } },
                "Token not available — reload the page if this persists."
              )
        ),

        // Setup steps card
        e("div", { style: S.card },
          e("div", { style: S.cardTitle }, "Setup"),
          e("ol", { style: S.stepList },
            e("li", { style: S.step },
              e("div", { style: S.stepNum }, "1"),
              e("div", { style: S.stepText },
                "Clone or install the app from GitHub. Build with Flutter: ",
                e("br"),
                e("span", { style: S.code }, "flutter run --release")
              )
            ),
            e("li", { style: S.step },
              e("div", { style: S.stepNum }, "2"),
              e("div", { style: S.stepText },
                "Open the app on your iPhone. Enter the host ",
                e("span", { style: S.code }, host),
                ", port ",
                e("span", { style: S.code }, port),
                ", and paste your session token."
              )
            ),
            e("li", { style: S.step },
              e("div", { style: S.stepNum }, "3"),
              e("div", { style: S.stepText },
                "Tap Connect. The app auto-connects on future launches with your saved credentials."
              )
            ),
            e("li", { style: S.step },
              e("div", { style: S.stepNum }, "4"),
              e("div", { style: S.stepText },
                "Make sure Hermes is accessible from your iPhone's network (same LAN, VPN, or port-forwarded)."
              )
            )
          )
        ),

        // Features card
        e("div", { style: S.card },
          e("div", { style: S.cardTitle }, "Features"),
          [
            ["💬", "Streaming chat with live token rendering"],
            ["🔧", "Tool call display with expandable input/output"],
            ["🧠", "Collapsible thinking / reasoning blocks"],
            ["✅", "Approval, clarify, sudo & secret dialogs"],
            ["⛔", "Interrupt running agent mid-turn"],
            ["📝", "Full Markdown rendering with code blocks"],
            ["🔄", "Auto-reconnect & session persistence"],
          ].map(function (f, i) {
            return e("div", { key: i, style: { display: "flex", gap: "10px", marginBottom: "9px", alignItems: "flex-start" } },
              e("span", { style: { fontSize: "15px", flexShrink: 0, marginTop: "1px" } }, f[0]),
              e("span", { style: { fontSize: "13px", color: "#a0a0a0", lineHeight: "1.5" } }, f[1])
            );
          })
        ),

        // Source card
        e("div", { style: S.card },
          e("div", { style: S.cardTitle }, "Source"),
          e("div", { style: { fontSize: "13px", color: "#a0a0a0", lineHeight: "1.7" } },
            "Built with Flutter. Requires iOS 12+ and Xcode to build.",
            e("br"), e("br"),
            "Install this plugin from your git repo URL in the Plugins Hub to see this page. The Flutter source lives alongside this manifest inside the same repository.",
            e("br"), e("br"),
            e("div", { style: { display: "flex", gap: "10px", flexWrap: "wrap" } },
              e("span", { style: { ...S.badge, background: "rgba(57,211,83,0.1)", color: "#39d353", border: "1px solid rgba(57,211,83,0.2)" } },
                e("span", { style: { ...S.dot, background: "#39d353" } }),
                "Flutter 3.x"
              ),
              e("span", { style: { ...S.badge, background: "rgba(255,215,0,0.1)", color: "#FFD700", border: "1px solid rgba(255,215,0,0.2)" } },
                e("span", { style: { ...S.dot, background: "#FFD700" } }),
                "iOS 12+"
              ),
              e("span", { style: { ...S.badge, background: "rgba(88,101,242,0.1)", color: "#8899ff", border: "1px solid rgba(88,101,242,0.2)" } },
                e("span", { style: { ...S.dot, background: "#8899ff" } }),
                "WebSocket JSON-RPC"
              )
            )
          )
        )
      )
    );
  }

  window.__HERMES_PLUGINS__.register("hermes-ios", HermesIosPage);
})();
