namespace Gala.Plugins.Stacker {
    /*
     * Draws the focused window's border as a rounded-rect stroke via
     * Gala.CanvasActor (Gala's own Cairo-backed canvas actor — not
     * Clutter.Canvas, which the vapi excludes as of Mutter 46, the version
     * this plugin targets). The stroke is drawn inset within the tracked
     * window's own frame rect rather than offset outside it: a window's
     * frame rect is always within the stage's own bounds, so an inset ring
     * can never get clipped off the edge of the screen the way an outset
     * one did when a window was full-width or full-height on its monitor.
     */
    internal class FocusRingContent : Gala.CanvasActor {
        public const int THICKNESS = 3;
        // elementary's own per-window corner radius is drawn client-side by
        // each app's CSD theme and isn't queryable from a plugin; this is an
        // approximation matching the common Granite/GTK default, not a
        // per-window-accurate value.
        private const int RADIUS = 6;
        private const Clutter.Color COLOR = { 0x64, 0xba, 0xff, 0xff };

        protected override void draw (Cairo.Context cr, int width, int height) {
            cr.set_operator (Cairo.Operator.CLEAR);
            cr.paint ();
            cr.set_operator (Cairo.Operator.OVER);

            cr.set_source_rgba (COLOR.red / 255.0, COLOR.green / 255.0, COLOR.blue / 255.0, COLOR.alpha / 255.0);
            cr.set_line_width (THICKNESS);
            Gala.Drawing.Utilities.cairo_rounded_rectangle (cr,
                THICKNESS / 2.0, THICKNESS / 2.0,
                width - THICKNESS, height - THICKNESS,
                RADIUS);
            cr.stroke ();
        }
    }

    public class FocusRing : GLib.Object {
        private Gala.WindowManager wm;
        private FocusRingContent ring;

        private unowned Meta.Window? tracked = null;
        private ulong position_signal = 0;
        private ulong size_signal = 0;
        // Guards against dereferencing `tracked` after it's destroyed: if
        // focus doesn't get reassigned before the tracked window is fully
        // gone, do_focus_window() may not fire in time, leaving `tracked`
        // dangling until the next focus change tries to disconnect its
        // (now invalid) signal ids. Untracking directly on unmanaged avoids
        // relying on that ordering.
        private ulong unmanaged_signal = 0;

        public FocusRing (Gala.WindowManager wm) {
            this.wm = wm;

            ring = new FocusRingContent ();
            ring.visible = false;

            wm.ui_group.add_child (ring);

            var display = wm.get_display ();
            display.do_focus_window.connect (on_focus_window);

            // Deliberately not calling track() eagerly here with whatever
            // window already has focus: `ring` was just add_child()'d this
            // same tick, and calling its position/size setters before
            // Clutter considers the actor realized logged a reproducible
            // `clutter_actor_get_width/height: assertion 'CLUTTER_IS_ACTOR
            // (self)' failed` on every single Gala start — and deferring
            // via a single GLib.Idle.add() wasn't a long enough wait to
            // fix it either. Mutter/Gala always assigns (or explicitly
            // clears) focus once during its own startup, so do_focus_window
            // fires on its own moments later regardless — by then `ring`
            // has had a full frame cycle to become valid, and the ring
            // simply appears a beat later than at eager-track, which
            // isn't perceptible.
        }

        // Named handler with an explicitly nullable window: the vapi
        // declares this signal's window argument as non-null, so a lambda
        // here would get Vala's auto-inserted `window != NULL` assertion
        // and crash whenever focus is cleared (e.g. right at Gala startup).
        private void on_focus_window (Meta.Display display, Meta.Window? window, int64 timestamp) {
            track (window);
        }

        private void track (Meta.Window? window) {
            if (tracked != null) {
                tracked.disconnect (position_signal);
                tracked.disconnect (size_signal);
                tracked.disconnect (unmanaged_signal);
                tracked = null;
            }

            // Shares Row.is_normal_app_window() rather than checking
            // Utils.get_window_is_normal() alone, so system chrome
            // (wingpanel/plank/Sidewing) that Row refuses to tile doesn't
            // pick up a focus-ring border either.
            if (window == null || !Row.is_normal_app_window (window)) {
                ring.visible = false;
                return;
            }

            tracked = window;
            position_signal = window.position_changed.connect (() => update ());
            size_signal = window.size_changed.connect (() => update ());
            unmanaged_signal = window.unmanaged.connect (() => track (null));
            ring.visible = true;
            update ();
        }

        private void update () {
            if (tracked == null) {
                return;
            }

            var rect = tracked.get_frame_rect ();
            ring.set_position (rect.x, rect.y);
            ring.set_size (rect.width, rect.height);
        }

        public void destroy () {
            if (tracked != null) {
                tracked.disconnect (position_signal);
                tracked.disconnect (size_signal);
                tracked.disconnect (unmanaged_signal);
            }

            ring.destroy ();
        }
    }
}
