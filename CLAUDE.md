# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`gala-paperwm`: a [PaperWM](https://github.com/paperwm/PaperWM)-inspired horizontal tiling
plugin for Gala (the window manager behind elementaryOS's Pantheon desktop), built against
the public `libgala-dev` plugin API — not a Gala fork. Windows on a workspace are tiled
edge-to-edge in a single horizontal row per monitor, full height, keeping their current
width. It does not touch Pantheon's workspace switching, only in-workspace layout.

## Build / install / reload

```
make build      # meson setup + ninja
make install    # build + sudo ninja install (installs .so + gschema)
make uninstall  # remove the .so and schema, recompile schemas
make clean      # rm -rf build
```

Requires `libgala-dev` and a Gala source checkout for `libmutter-14.vapi` (Ubuntu's
Mutter packages don't ship a standalone vapi). Point `gala_vapi_dir` in
`meson_options.txt` at your checkout if it isn't at the default path.

**Reloading after a change: log out and back in.** Do not use `systemctl --user kill` or
`gala --replace` to reload — both are known to trigger an unrelated, pre-existing Mutter
crash (`meta_x11_barriers_free` assertion on teardown), separate from anything in this
plugin, but confusing to debug around. `io.elementary.gala@x11.service` is a
dependency-only static unit; logging out lets it come back up cleanly on its own.

There is no automated test suite. This plugin is developed and debugged live against a
real elementaryOS X11 session — verify changes by installing, reloading, reproducing the
window-management behavior in question, and reading `journalctl _COMM=gala | grep paperwm`
for the plugin's `warning()` trace output.

## Architecture

Three Vala files compiled into one `libgala-paperwm.so`, registered via `register_plugin()`
at the bottom of `src/Main.vala` (`Gala.PluginFunction.ADDITION`, `IMMEDIATE` load priority).

- **`Main.vala`** — top-level orchestration. Tracks one `Row` per (workspace, monitor) pair
  via `track_workspace()`/`find_row()`, registers the five keybindings (reorder/focus
  left/right, cycle-width), and owns the interactive-drag lifecycle: `grab_op_begin`/`grab_op_end` →
  `on_window_dropped()` re-homes the dropped window into the correct monitor's row using a
  self-computed monitor (see below), then an event-driven settle mechanism
  (`restart_settle_timer()` + `Row.grabbed_window_churn`) waits out post-drop workspace
  signal churn before forcing a final `retile()` — deliberately not a fixed timeout (see
  git history / commit messages for why). `grab_op_begin`/`grab_op_end` also drive
  divider-style resize: `resize_delta_for_op()` maps a horizontal edge-resize op
  (`RESIZING_E`/`_NE`/`_SE` vs `RESIZING_W`/`_NW`/`_SW`) to which row-neighbor sits on the
  dragged side, `begin_divider_resize()` looks that neighbor up via `find_owning_row()` +
  `Row.neighbor()` and hooks the dragged window's `size_changed` to live-mirror the resize
  into it (facing edge tracks the drag, far edge fixed — same math as elementary's own
  snapped-window divider), and `end_divider_resize()` disconnects that hook and forces one
  more `retile()` on grab end. While a divider resize is in flight the partner is exempt
  from `retile()` via `Row.resize_partner`, the same mechanism as `Row.grabbed_window` but
  for "being driven directly by Main mid-resize" instead of "mid-move".
- **`Row.vala`** — one row = one monitor's tiled window order for one workspace. Holds
  `order` (a `GLib.List<weak Meta.Window>`), listens to `workspace.window_added`/
  `window_removed`, and lays windows out edge-to-edge left-to-right in `retile()`
  (deferred via `GLib.Idle.add` to avoid reentrant signal recursion). Key invariants
  enforced in `is_tileable()`/`add_window()`: a window must be normal, not minimized, not
  known system chrome (wingpanel/plank excluded by title — deliberately *not* by
  `is_always_on_all_workspaces()`, since Pantheon's secondary-monitor-is-a-shared-surface
  model means ordinary application windows opened there can carry that same flag), on
  **this row's own workspace** (not just the right monitor — a
  window can transiently touch a dynamically-created workspace during creation and get
  double-claimed by two Rows otherwise), and its monitor must match — but only at the point
  it's first claimed: `Row.claimed` (static, across every Row) records every window a Row has
  ever accepted, and `add_window()` refuses to re-derive ownership for a window already in
  that set from its current (possibly stale) `.get_monitor()` — a window can transiently
  report the wrong monitor for a tick or two right after creation, and this stops a later
  stray workspace signal from re-evaluating and stealing it. Mirrors the older
  `Row.grabbed_window` precedent, generalized from "the one window mid-drag" to "any window
  this Row already owns". Anything in `Main.vala` that acts on the *focused* window (reorder,
  focus-neighbor, cycle-width) likewise looks up its row via `find_owning_row()` (row
  containing the window), never via `find_row(workspace, window.get_monitor())` — the
  drag-drop path is the one legitimate exception, since a live drag's `get_monitor()`
  genuinely needs re-deriving (see `monitor_for_window()` in `Main.vala`). `retile()` clamps
  each window's target x to its own monitor's bounds — there's no scrolling viewport (a real
  one was attempted and reverted twice: once for an auto-scroll-to-reveal-focus feedback loop,
  once because there's no way to actually hide an out-of-view window — Mutter's placement
  constraints refuse to move a window far enough outside every monitor's bounds, confirmed
  live via `wmctrl`, and minimizing it instead was rejected as too disruptive; see README's
  "Known limitations" for the full account), so a row wider than one monitor would otherwise
  push later windows into the *next* monitor's real screen coordinates and have Mutter
  silently reassign their `.get_monitor()` to match; clamping makes overflow stack at the edge
  instead. `Row.grabbed_window` (static) suppresses workspace-signal reactions to whichever
  window is mid-drag, so Mutter's own churn during a live cross-monitor drag doesn't fight the
  user's pointer. `Row.resize_partner` (static, same shape) is `retile()`'s other exemption:
  whichever window `Main`'s divider-resize handling is currently driving directly, so an
  unrelated retile mid-drag doesn't snap it back to its pre-resize width. `cycle_width()` steps the focused window's width through fixed fractions of
  the monitor work area (1/3, 1/2, 2/3), re-deriving
  the closest current fraction from the window's live width each call rather than tracking
  cycle state on the window. `append()` inserts a newly tiled window right after
  `last_focused` (whichever of this row's windows last had focus, tracked via
  `note_focus()`/`Main.on_window_focused()`) instead of always at the tail, so a freshly
  opened window lands next to what you were actually working on. `retile()` also skips
  repositioning a currently-maximized window (`maximized_horizontally`/`maximized_vertically`
  — `is_maximized()` isn't available under `HAS_MUTTER46`), since it's meant to fill the
  monitor; `append()` hooks `notify["maximized-horizontally"/"vertically"]` to retile it back
  into its slot on unmaximize.
- **`FocusRing.vala`** — a `Gala.CanvasActor` subclass stroking a rounded-rect border (via
  `Gala.Drawing.Utilities.cairo_rounded_rectangle`, not `Clutter.Canvas`, which the vapi
  excludes as of Mutter 46) tracking the focused window's frame rect via `do_focus_window` +
  `position_changed`/`size_changed`. Drawn *inset* within the window's own frame rect rather
  than offset outside it, so it can't get clipped off the edge of the stage when a window is
  full-width/full-height on its monitor.

Recurring Vala/vapi gotcha throughout: several Mutter signal vapis declare `Meta.Window`
parameters non-nullable when Mutter actually passes null (e.g. focus cleared, grab ended
with no window) — always use a named handler with an explicit `Meta.Window?` parameter,
never an inline lambda, or Vala's auto-inserted null assertion crashes Gala.

## Known limitations

See `README.md`'s "Known limitations" section — notably, there is no horizontal
scrolling/viewport: once a row is wider than its monitor, overflow windows stack at the
monitor's right edge rather than becoming pannable. A real viewport needs a way to hide an
out-of-view window that Mutter doesn't have — see README for what was tried and why it was
reverted (an auto-scroll-on-focus feedback loop, then a hard placement-constraint wall in
Mutter itself with no clean bypass).
