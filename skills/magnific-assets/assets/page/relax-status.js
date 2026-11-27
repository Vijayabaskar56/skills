// Run in a magnific.com page through any driver's eval. Prints "on", "off" or "signed-out".
// Reads the same endpoints the web app reads; changes nothing.
(async () => {
  const xsrf = decodeURIComponent(document.cookie.match(/XSRF-TOKEN=([^;]+)/)?.[1] || "");
  const headers = { accept: "application/json", "x-xsrf-token": xsrf };
  const me = await fetch("/app/api/auth/verify?lang=en_US", { headers });
  if (me.status !== 200) return "signed-out";
  const id = (await me.json()).userData?.fpId;
  if (!id) return "signed-out";
  const s = await (await fetch(`/app/api/unlimited-status?lang=en_US&user_id=${id}`, { headers })).json();
  return s.is_unlimited_mode_enabled ? "on" : "off";
})();
