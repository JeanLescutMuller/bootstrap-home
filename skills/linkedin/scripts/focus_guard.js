// Usage: osascript -l JavaScript focus_guard.js SECONDS
// While the LinkedIn MCP server runs, its browser ("Google Chrome for Testing") opens a window and takes the
// keyboard focus. This gives the focus back, at once, to the app that had it when the guard started.
function run(argv) {
  const secs = Number(argv[0] || 300);
  const app = Application.currentApplication(); app.includeStandardAdditions = true;
  const front = () => { try { return app.doShellScript('lsappinfo info -only bundleID "$(lsappinfo front)"').replace(/.*="?|"$/g, ''); } catch (e) { return '?'; } };
  const THIEF = 'com.google.chrome.for.testing';
  const owner = front();
  const end = Date.now() + secs * 1000;
  while (Date.now() < end) {
    if (front() === THIEF && owner !== THIEF && owner !== '?') {
      try { app.doShellScript(`open -b ${JSON.stringify(owner)}`); console.log(`${(Date.now() / 1000).toFixed(2)}\tgave focus back to ${owner}`); } catch (e) {}
    }
    delay(0.1);
  }
}
