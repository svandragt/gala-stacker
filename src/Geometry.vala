namespace Gala.Plugins.Xy {
    // Pure width/delta math pulled out of Row.cycle_width() and
    // Main.begin_divider_resize() so it can be unit tested without a live
    // Mutter session (see tests/geometry-test.vala).
    public class Geometry {
        // Given a window's current width and the monitor work-area width,
        // finds which of `fractions` it's currently closest to and returns
        // the pixel width of the next fraction after that, wrapping around.
        public static int next_fraction_width (int current_width, int area_width, double[] fractions) {
            int closest = 0;
            double best_diff = double.MAX;
            for (int i = 0; i < fractions.length; i++) {
                double diff = Math.fabs (current_width - area_width * fractions[i]);
                if (diff < best_diff) {
                    best_diff = diff;
                    closest = i;
                }
            }

            int next = (closest + 1) % fractions.length;
            return (int) Math.round (area_width * fractions[next]);
        }

        // Caps a resize delta so shrinking a neighbor by it never takes
        // the neighbor's width below min_width.
        public static int cap_delta_to_min_width (int neighbor_width, int delta, int min_width) {
            if (neighbor_width - delta < min_width) {
                return neighbor_width - min_width;
            }

            return delta;
        }

        // Horizontal edge-resize ops map to which row-neighbor (if any)
        // should mirror the drag: dragging the right edge (E) moves the
        // shared boundary with the neighbor to the right, dragging the
        // left edge (W) moves the boundary with the neighbor to the left.
        // Vertical-only resizes (N/S) don't touch a row boundary at all.
        public static int resize_delta_for_op (Meta.GrabOp op) {
            switch (op) {
                case Meta.GrabOp.RESIZING_E:
                case Meta.GrabOp.RESIZING_NE:
                case Meta.GrabOp.RESIZING_SE:
                    return 1;
                case Meta.GrabOp.RESIZING_W:
                case Meta.GrabOp.RESIZING_NW:
                case Meta.GrabOp.RESIZING_SW:
                    return -1;
                default:
                    return 0;
            }
        }

        // True for any interactive resize grab, mouse or keyboard-driven,
        // including the vertical-only (N/S) and diagonal ops that
        // resize_delta_for_op() maps to no row-neighbor at all. Used to
        // mark the window itself exempt from Row.retile() for the whole
        // grab, not just the subset that also drives a divider partner.
        public static bool is_resize_op (Meta.GrabOp op) {
            switch (op) {
                case Meta.GrabOp.RESIZING_N:
                case Meta.GrabOp.RESIZING_S:
                case Meta.GrabOp.RESIZING_E:
                case Meta.GrabOp.RESIZING_W:
                case Meta.GrabOp.RESIZING_NE:
                case Meta.GrabOp.RESIZING_NW:
                case Meta.GrabOp.RESIZING_SE:
                case Meta.GrabOp.RESIZING_SW:
                case Meta.GrabOp.KEYBOARD_RESIZING_UNKNOWN:
                case Meta.GrabOp.KEYBOARD_RESIZING_N:
                case Meta.GrabOp.KEYBOARD_RESIZING_S:
                case Meta.GrabOp.KEYBOARD_RESIZING_E:
                case Meta.GrabOp.KEYBOARD_RESIZING_W:
                case Meta.GrabOp.KEYBOARD_RESIZING_NE:
                case Meta.GrabOp.KEYBOARD_RESIZING_NW:
                case Meta.GrabOp.KEYBOARD_RESIZING_SE:
                case Meta.GrabOp.KEYBOARD_RESIZING_SW:
                    return true;
                default:
                    return false;
            }
        }
    }
}
