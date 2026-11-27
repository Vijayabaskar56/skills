// Run in the video generator page through any driver's eval, after replacing __B64__ with the
// start image's base64 and __NAME__ with its file name. Sets the "Start image" input the way a
// drop does. Prints "start image set" or "no image input".
(async () => {
  const bin = Uint8Array.from(atob("__B64__"), (c) => c.charCodeAt(0));
  const input = [...document.querySelectorAll("input[type=file]")].find((i) => i.accept.includes("image/png"));
  if (!input) return "no image input";
  const dt = new DataTransfer();
  dt.items.add(new File([bin], "__NAME__", { type: "image/png" }));
  input.files = dt.files;
  input.dispatchEvent(new Event("input", { bubbles: true }));
  input.dispatchEvent(new Event("change", { bubbles: true }));
  await new Promise((r) => setTimeout(r, 3000));
  return "start image set";
})();
