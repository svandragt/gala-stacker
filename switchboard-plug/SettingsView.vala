namespace Stacker {
    // A sidebar + stack, like every other multi-section Switchboard plug
    // (confirmed by inspecting io.elementary.settings.mouse-touchpad's
    // actual widget tree live: GtkPaned > [SettingsSidebar, GtkStack]) —
    // returning a plain Gtk.Box here instead left the shell with nothing to
    // put in its sidebar and no page-navigation chrome (no back button),
    // since both come from Switchboard.SettingsSidebar being bound to the
    // same Gtk.Stack the content lives in, not something the shell adds on
    // its own.
    //
    // Not a Gtk.Paned *subclass*: the same live inspection showed the real
    // plug's top widget type name is the literal "GtkPaned", not a custom
    // subclass — GTK4 keeps most widget instance structs opaque, so
    // `class Foo : Gtk.Paned` fails to compile ("field 'parent_instance'
    // has incomplete type"). Building a plain Gtk.Paned via composition,
    // like the real plug does, is the only option.
    public class SettingsView : GLib.Object {
        public Gtk.Widget build () {
            var settings = new GLib.Settings ("org.pantheon.desktop.gala.plugins.stacker");

            var stack = new Gtk.Stack ();
            stack.add_titled (new ShortcutsPage (settings), "shortcuts", "Shortcuts");
            stack.add_titled (new ExclusionsPage (settings), "exclusions", "Exclusions");

            var sidebar = new Switchboard.SettingsSidebar (stack);

            return new Gtk.Paned (Gtk.Orientation.HORIZONTAL) {
                start_child = sidebar,
                end_child = stack,
                resize_start_child = false,
                shrink_start_child = false
            };
        }
    }

    // SwitchboardSettingsSidebar reads title/header/status straight off
    // each stack page's child widget by casting it to Switchboard.SettingsPage
    // (confirmed by GLib-GObject-CRITICAL "invalid object type ... for value
    // type 'SwitchboardSettingsPage'" when a plain Gtk.Grid/Gtk.Box was used
    // instead) — a plain content widget isn't enough, every page must
    // actually be one.
    private abstract class BasePage : Switchboard.SettingsPage {
        protected GLib.Settings settings;

        protected BasePage (GLib.Settings settings, string page_title, string page_header) {
            Object (title: page_title, header: page_header);
            this.settings = settings;
            child = build_content ();
        }

        protected abstract Gtk.Widget build_content ();

        // Shown as comma-separated accelerator strings (e.g.
        // "<Super>bracketleft") rather than a capture-a-shortcut widget:
        // each key already supports more than one accelerator (it's a
        // gschema `as`, not `s`), which a single-shortcut recorder can't
        // represent anyway. Shared by every row (shortcuts and exclusions
        // alike), since every key involved is a gschema `as` either way.
        protected void add_strv_row (Gtk.Grid grid, int row, string label_text, string key, string? placeholder) {
            var label = new Gtk.Label (label_text) {
                xalign = 1,
                hexpand = false
            };
            label.add_css_class ("dim-label");

            var entry = new Gtk.Entry () {
                hexpand = true
            };
            if (placeholder != null) {
                entry.placeholder_text = placeholder;
            }

            settings.bind_with_mapping (
                key, entry, "text", GLib.SettingsBindFlags.DEFAULT,
                strv_to_text, text_to_strv, null, null
            );

            grid.attach (label, 0, row, 1, 1);
            grid.attach (entry, 1, row, 1, 1);
        }

        private static bool strv_to_text (GLib.Value value, GLib.Variant variant, void* user_data) {
            value.set_string (string.joinv (", ", variant.get_strv ()));
            return true;
        }

        private static GLib.Variant text_to_strv (GLib.Value value, GLib.VariantType expected_type, void* user_data) {
            string text = value.get_string ();
            string[] items = {};
            foreach (unowned string part in text.split (",")) {
                string trimmed = part.strip ();
                if (trimmed != "") {
                    items += trimmed;
                }
            }

            return new GLib.Variant.strv (items);
        }
    }

    private class ShortcutsPage : BasePage {
        public ShortcutsPage (GLib.Settings settings) {
            base (settings, "Shortcuts", "Keyboard Shortcuts");
        }

        protected override Gtk.Widget build_content () {
            var grid = new Gtk.Grid () {
                row_spacing = 12,
                column_spacing = 12,
                margin_top = 24,
                margin_bottom = 24,
                margin_start = 24,
                margin_end = 24
            };

            add_strv_row (grid, 0, "Focus window left", "focus-left", null);
            add_strv_row (grid, 1, "Focus window right", "focus-right", null);
            add_strv_row (grid, 2, "Move window left", "reorder-left", null);
            add_strv_row (grid, 3, "Move window right", "reorder-right", null);
            add_strv_row (grid, 4, "Cycle window width", "cycle-width", null);

            return grid;
        }
    }

    // Same keys Row.is_chrome_window() reads at runtime (see gala-stacker's
    // gschema) — a window matching either list is treated as system chrome
    // and never tiled.
    private class ExclusionsPage : BasePage {
        public ExclusionsPage (GLib.Settings settings) {
            base (settings, "Exclusions", "Excluded Windows");
        }

        protected override Gtk.Widget build_content () {
            var description = new Gtk.Label (
                "Windows matching any of these, or smaller than the minimum size, are left out of the row instead of being tiled."
            ) {
                wrap = true,
                xalign = 0,
                margin_bottom = 12
            };
            description.add_css_class ("dim-label");

            var grid = new Gtk.Grid () {
                row_spacing = 12,
                column_spacing = 12
            };

            add_strv_row (grid, 0, "Title contains", "excluded-title-keywords", "wingpanel, plank");
            add_strv_row (grid, 1, "Application ID is", "excluded-app-ids", "com.example.app");

            var min_size_label = new Gtk.Label ("Minimum size to tile (px)") {
                xalign = 1,
                hexpand = false
            };
            min_size_label.add_css_class ("dim-label");

            var min_size_spin = new Gtk.SpinButton.with_range (0, 1000, 10);
            settings.bind ("min-tileable-size", min_size_spin, "value", GLib.SettingsBindFlags.DEFAULT);

            grid.attach (min_size_label, 0, 2, 1, 1);
            grid.attach (min_size_spin, 1, 2, 1, 1);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                margin_top = 24,
                margin_bottom = 24,
                margin_start = 24,
                margin_end = 24
            };
            box.append (description);
            box.append (grid);
            return box;
        }
    }
}
