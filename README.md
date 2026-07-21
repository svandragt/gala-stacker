# gala-stacker

I wanted [PaperWM](https://github.com/paperwm/PaperWM)-style tiling on
elementaryOS, so this is a horizontal tiling plugin for
[Gala](https://github.com/elementary/gala), the window manager behind
Pantheon.

Windows on a workspace sit in a single horizontal row, each one full height.
You reorder them, switch between them with the keyboard, and the focused
window gets a highlighted border so you can always tell where you are.

It does **not** touch how workspaces work – Pantheon's existing workspace
switching (`Super+Left/Right` by default) is untouched. It's only the layout
*within* a workspace that changes.

## What it does

- Every normal window on a workspace tiles edge-to-edge in a row, full
  height, keeping whatever width it currently has – windows never overlap,
  except a maximised window, which is left alone to fill the monitor as
  normal and snaps back into its row slot on unmaximise.
- Each monitor gets its own independent row per workspace.
- A newly opened window lands right after whichever window you last had
  focused in that row, not always at the end.
- The focused window gets a highlighted border, so you can always tell which
  window has focus at a glance.
- Windows dragged onto a different monitor move into that monitor's row.
- Resizing the edge a window shares with its row-neighbour moves that shared
  boundary like elementary's own snapped-window divider – the neighbour
  resizes in tandem instead of leaving a gap or an overlap. That one I added
  after noticing it's how elementary already handles two windows snapped
  left/right, and it felt wrong not to have it for tiled windows too.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `Super+[` / `Super+]` | Move keyboard focus to the window left/right in the row |
| `Super+Shift+[` / `Super+Shift+]` | Move the focused window itself left/right in the row |
| `Super+R` | Cycle the focused window's width between 33%, 50%, and 67% of the monitor |

Every `Super`+arrow-key combination is already claimed by Pantheon/GNOME
defaults (workspace switching, move-to-monitor, move-to-workspace, tiling),
so these use the bracket keys instead — check `gsettings list-recursively`
against `org.gnome.desktop.wm.keybindings`, `org.gnome.mutter.keybindings`,
and `io.elementary.desktop.wm.keybindings` before picking something else.

Rebind these in a terminal with `gsettings`, e.g.:

```
gsettings set org.pantheon.desktop.gala.plugins.stacker focus-left "['<Super>comma']"
```

## Mouse

Drag a window and drop it between two others in the row to reorder it there.

Drag the edge a window shares with its row-neighbour to resize both at once,
the shared boundary moving like a divider.

## Installing

Requires `libgala-dev` and a Gala source checkout (for `libmutter-14.vapi`,
which Ubuntu's Mutter packages don't ship separately — point
`gala_vapi_dir` at yours if it's not at the default path in `meson_options.txt`).

```
make install
```

(equivalent to `meson setup build && ninja -C build && sudo ninja -C build install`)

Then reload Gala to pick it up:

- **X11 session**: run `gala --replace &` from a terminal in that session.
- **Wayland session**: log out and back in (a running Wayland compositor
  can't be replaced in place).

## Uninstalling

```
make uninstall
```

Then reload Gala the same way as above.

## Known limitations

- Built and tested against Gala 8.5.1 / Mutter 46 (elementaryOS 8-era). Other
  versions may need adjusting the `HAS_MUTTER*` defines in `meson.build`.
- Connecting or disconnecting a monitor while Gala is running isn't picked up
  live — restart Gala afterwards to get a row on the new monitor.
- No animation on retile yet; windows snap into place instantly.
- No horizontal scrolling/viewport: the row tiles left-to-right in fixed
  screen coordinates, so once it's wider than the monitor, overflowing
  windows stack on top of each other at the right edge instead of becoming
  pannable. I tried a real scrolling viewport twice and reverted both times.
  First because auto-scrolling to reveal the focused window turned into a
  feedback loop – moving its geometry made Mutter re-affirm focus, which
  re-triggered the reveal, which oscillated the scroll position. Second
  because there's no way to actually hide an out-of-view window: Mutter
  refuses to place a window far enough outside every monitor's bounds (I
  confirmed this live – even an external `wmctrl` move request gets silently
  clamped back near real screen bounds, per an unconditional constraint in
  Mutter's own placement logic with no bypass), and minimising it instead
  felt too disruptive, with the dock animation and the involuntary focus
  loss. A real fix would need a patch to Mutter itself, not just this
  plugin.
- This is a young, unofficial plugin, not an elementary/Gala project. If Gala
  crashes after installing it, remove the `.so` from the plugins directory
  and reload Gala to get back to a stock session.
