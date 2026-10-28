class_name MpWebKeepAlive
extends RefCounted

## Keeps a browser host simulating while its tab is hidden. A Godot web build runs its main loop on
## requestAnimationFrame, which a browser stops in a hidden tab (another tab in front, the window minimized or, in
## Chrome, covered): a host there would freeze its whole match. While enabled and hidden, the loop's
## requestAnimationFrame is answered from a Web Worker's timer (worker timers are not throttled with the tab) and
## drawing is off (RenderingServer.render_loop_enabled); visible again, the browser's own frames come back.
## Measured in Chromium: 60 ticks/s hidden for 8+ minutes, past Chrome's 5-minute intensive throttling. Mobile
## browsers freeze background tabs entirely: there the clients' host_silent (MpKit) is what is left.
## MpOnline enables it while a browser hosts; off the web it does nothing. Enable it while the tab is visible (the
## click that hosts): a frame the browser already holds for a hidden tab cannot be taken back.

const _JS := """
(() => {
  if (window.__mpkitKeepAlive) { window.__mpkitKeepAlive.enable(); return; }
  const native = window.requestAnimationFrame.bind(window);
  const cancelNative = window.cancelAnimationFrame.bind(window);
  let worker = null, queue = [], pending = null, on = false;
  const tick = () => { const run = queue; queue = []; const now = performance.now(); for (const cb of run) cb(now); };
  const hide = () => {
    if (!on) return;
    if (!worker) {
      worker = new Worker(URL.createObjectURL(new Blob(['let id = 0; onmessage = (e) => { clearInterval(id); if (e.data > 0) id = setInterval(() => postMessage(0), e.data); };'], { type: 'text/javascript' })));
      worker.onmessage = tick;
    }
    worker.postMessage(1000 / 60);
    if (pending) { cancelNative(pending.id); queue.push(pending.cb); pending = null; }
  };
  const show = () => {
    if (worker) worker.postMessage(0);
    const run = queue; queue = [];
    for (const cb of run) window.requestAnimationFrame(cb);
  };
  window.requestAnimationFrame = (cb) => {
    if (on && document.hidden) { queue.push(cb); return 0; }
    const entry = { cb, id: 0 };
    entry.id = native((t) => { if (pending === entry) pending = null; cb(t); });
    pending = entry;
    return entry.id;
  };
  window.cancelAnimationFrame = (id) => cancelNative(id);
  document.addEventListener('visibilitychange', () => (document.hidden ? hide() : show()));
  window.__mpkitKeepAlive = {
    enable() { on = true; if (document.hidden) hide(); },
    disable() { on = false; show(); if (worker) { worker.terminate(); worker = null; } },
  };
  window.__mpkitKeepAlive.enable();
})();
"""

static var _enabled: bool = false
static var _on_visibility: JavaScriptObject


static func is_enabled() -> bool:
	return _enabled


static func enable() -> void:
	if _enabled or not OS.has_feature("web"):
		return
	_enabled = true
	JavaScriptBridge.eval(_JS, true)
	if _on_visibility == null:
		_on_visibility = JavaScriptBridge.create_callback(_visibility_changed)
		JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _on_visibility)


static func disable() -> void:
	if not _enabled:
		return
	_enabled = false
	JavaScriptBridge.eval("window.__mpkitKeepAlive && window.__mpkitKeepAlive.disable();", true)
	RenderingServer.render_loop_enabled = true


static func _visibility_changed(_args: Array) -> void:
	var hidden := str(JavaScriptBridge.eval("document.visibilityState", true)) == "hidden"
	RenderingServer.render_loop_enabled = not (hidden and _enabled)
