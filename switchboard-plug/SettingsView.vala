namespace Xy {
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
            var settings = new GLib.Settings ("org.pantheon.desktop.gala.plugins.xy");

            var stack = new Gtk.Stack ();
            stack.add_titled (new ShortcutsPage (settings), "shortcuts", "Shortcuts");
            stack.add_titled (new ExclusionsPage (settings), "exclusions", "Exclusions");

            // show_title_buttons reveals SettingsSidebar's own header bar,
            // which is what the shell's Adw.NavigationView back button rides
            // on once this plug is pushed as a non-root Adw.NavigationPage —
            // without it the header (and the back chrome) never appears,
            // confirmed against elementary/settings-desktop's Plug.vala,
            // which sets this explicitly on every multi-page plug.
            var sidebar = new Switchboard.SettingsSidebar (stack) {
                show_title_buttons = true
            };

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

            add_shortcut_row (grid, 0, "Focus window left", "focus-left");
            add_shortcut_row (grid, 1, "Focus window right", "focus-right");
            add_shortcut_row (grid, 2, "Move window left", "reorder-left");
            add_shortcut_row (grid, 3, "Move window right", "reorder-right");
            add_shortcut_row (grid, 4, "Cycle window width", "cycle-width");
            add_shortcut_row (grid, 5, "Toggle floating", "toggle-floating");

            return grid;
        }

        private void add_shortcut_row (Gtk.Grid grid, int row, string label_text, string key) {
            var label = new Gtk.Label (label_text) {
                xalign = 1,
                hexpand = false,
                valign = Gtk.Align.START
            };
            label.add_css_class ("dim-label");

            grid.attach (label, 0, row, 1, 1);
            grid.attach (new ShortcutEditor (settings, key), 1, row, 1, 1);
        }
    }

    // Reimplements the shortcut-capture pattern elementary/settings-keyboard
    // uses on its own Shortcuts tab (Keyboard.Shortcuts.ShortcutListBox.
    // ShortcutRow) rather than reusing that class directly: it's private to
    // settings-keyboard's own source tree (not exported by Granite or
    // Switchboard) and only ever edits a single accelerator per key, whereas
    // every keybinding here is a gschema `as` and genuinely supports more
    // than one binding (Gala's add_keybinding() allows it). Same capture
    // mechanics — keycap-styled labels via Gtk.accelerator_get_label(),
    // Gtk.EventControllerKey capturing key_released, normalized through
    // Gtk.accelerator_get_default_mod_mask() — as a small list of
    // independently-editable rows (one per existing binding) plus an "Add
    // Shortcut" row, instead of one fixed slot.
    private class ShortcutEditor : Gtk.Box {
        private GLib.Settings settings;
        private string key;
        private Gtk.ListBox list;

        public ShortcutEditor (GLib.Settings settings, string key) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 6);
            this.settings = settings;
            this.key = key;

            list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            list.add_css_class ("boxed-list");

            var add_button = new Gtk.Button.with_label ("Add Shortcut") {
                halign = Gtk.Align.START
            };
            add_button.add_css_class ("flat");
            add_button.clicked.connect (() => {
                var row = new ShortcutRow (this, null);
                list.append (row);
                row.start_recording ();
            });

            append (list);
            append (add_button);

            rebuild ();
        }

        private void rebuild () {
            unowned Gtk.Widget? child;
            while ((child = list.get_first_child ()) != null) {
                list.remove (child);
            }

            var accels = settings.get_strv (key);
            if (accels.length == 0) {
                list.append (new ShortcutRow (this, null));
            } else {
                foreach (unowned string accel in accels) {
                    list.append (new ShortcutRow (this, accel));
                }
            }
        }

        // Called by a ShortcutRow whenever its own accelerator changes
        // (captured, or removed) to write every row's current value back to
        // the gschema array in one go, then re-derive the row list from
        // gsettings again — keeps the widget authoritative on what's
        // actually stored rather than trusting its own transient state.
        public void commit () {
            string[] accels = {};
            unowned Gtk.Widget? child = list.get_first_child ();
            while (child != null) {
                unowned var row = (ShortcutRow) child;
                if (row.accelerator != null && row.accelerator != "") {
                    accels += row.accelerator;
                }
                child = child.get_next_sibling ();
            }

            settings.set_strv (key, accels);
            rebuild ();
        }
    }

    private class ShortcutRow : Gtk.ListBoxRow {
        public string? accelerator;
        private unowned ShortcutEditor editor;
        private Gtk.Box content;
        private bool recording = false;

        public ShortcutRow (ShortcutEditor editor, string? accelerator) {
            this.editor = editor;
            this.accelerator = accelerator;

            content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin_top = 6,
                margin_bottom = 6,
                margin_start = 12,
                margin_end = 12
            };
            child = content;

            var click = new Gtk.GestureClick ();
            click.pressed.connect (() => start_recording ());
            add_controller (click);

            var key_controller = new Gtk.EventControllerKey ();
            key_controller.key_released.connect (on_key_released);
            add_controller (key_controller);

            var focus_controller = new Gtk.EventControllerFocus ();
            focus_controller.leave.connect (() => {
                if (recording) {
                    recording = false;
                    render ();
                }
            });
            add_controller (focus_controller);

            render ();
        }

        public void start_recording () {
            recording = true;
            grab_focus ();
            render ();
        }

        private void on_key_released (uint keyval, uint keycode, Gdk.ModifierType state) {
            if (!recording || is_modifier_key (keyval)) {
                return;
            }

            var mods = state & Gtk.accelerator_get_default_mod_mask ();
            accelerator = Gtk.accelerator_name (keyval, mods);
            recording = false;
            editor.commit ();
        }

        // Gtk.EventControllerKey.key_released fires once per physical key,
        // including the modifier keys themselves as they're released after
        // a combo (e.g. releasing Super after Super+[) — without this, that
        // trailing release would overwrite the just-captured accelerator
        // with a bare, mod-less keyval.
        private bool is_modifier_key (uint keyval) {
            switch (keyval) {
                case Gdk.Key.Shift_L:
                case Gdk.Key.Shift_R:
                case Gdk.Key.Control_L:
                case Gdk.Key.Control_R:
                case Gdk.Key.Alt_L:
                case Gdk.Key.Alt_R:
                case Gdk.Key.Super_L:
                case Gdk.Key.Super_R:
                case Gdk.Key.Meta_L:
                case Gdk.Key.Meta_R:
                case Gdk.Key.ISO_Level3_Shift:
                case Gdk.Key.Caps_Lock:
                    return true;
                default:
                    return false;
            }
        }

        private void render () {
            unowned Gtk.Widget? existing;
            while ((existing = content.get_first_child ()) != null) {
                content.remove (existing);
            }

            if (recording) {
                var label = new Gtk.Label ("Enter new shortcut…") {
                    hexpand = true,
                    xalign = 0
                };
                label.add_css_class ("dim-label");
                content.append (label);
            } else if (accelerator == null || accelerator == "") {
                var label = new Gtk.Label ("Disabled") {
                    hexpand = true,
                    xalign = 0
                };
                label.add_css_class ("dim-label");
                content.append (label);
            } else {
                uint keyval;
                Gdk.ModifierType mods;
                Gtk.accelerator_parse (accelerator, out keyval, out mods);
                string label_text = Gtk.accelerator_get_label (keyval, mods);

                var keys_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3) {
                    hexpand = true
                };
                foreach (unowned string part in label_text.split ("+")) {
                    var keycap = new Gtk.Label (part.strip ());
                    keycap.add_css_class ("keycap");
                    keys_box.append (keycap);
                }
                content.append (keys_box);
            }

            var remove_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic") {
                valign = Gtk.Align.CENTER
            };
            remove_button.add_css_class ("flat");
            remove_button.clicked.connect (() => {
                accelerator = null;
                editor.commit ();
            });
            content.append (remove_button);
        }
    }

    // Same keys Row.is_chrome_window() reads at runtime (see gala-xy's
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
