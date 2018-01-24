/*
 * Copyright (c) 2011-2018 elementary LLC. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA  02110-1301, USA.
 */

namespace Power {
    private GLib.Settings settings;
    private MainView main_view;
    private Gtk.Grid main_grid;

    public class Plug : Switchboard.Plug {
        private Gtk.SizeGroup label_size;
        private Gtk.StackSwitcher stack_switcher;

        private Battery battery;
        private PowerSupply power_supply;

        construct {
            settings = new GLib.Settings ("org.gnome.settings-daemon.plugins.power");

            battery = new Battery ();
            power_supply = new PowerSupply ();
        }

        public Plug () {
            var supported_settings = new Gee.TreeMap<string, string?> (null, null);
            supported_settings["power"] = null;

            Object (category: Category.HARDWARE,
                code_name: "system-pantheon-power",
                display_name: _("Power"),
                description: _("Configure display brightness, power buttons, and sleep behavior"),
                icon: "preferences-system-power",
                supported_settings: supported_settings);
        }

        public override Gtk.Widget get_widget () {
            if (main_view == null) {
                label_size = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);

                main_grid = new Gtk.Grid ();
                main_grid.margin = 24;
                main_grid.column_spacing = 12;
                main_grid.row_spacing = 12;

                var stack = new Gtk.Stack ();

                var plug_grid = create_notebook_pages (true);
                stack.add_titled (plug_grid, "ac", _("Plugged In"));

                stack_switcher = new Gtk.StackSwitcher ();
                stack_switcher.homogeneous = true;
                stack_switcher.stack = stack;

                if (battery.check_present ()) {
                    var battery_grid = create_notebook_pages (false);
                    stack.add_titled (battery_grid, "battery", _("On Battery"));

                    var left_sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
                    left_sep.hexpand = true;

                    var right_sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
                    right_sep.hexpand = true;

                    var switcher_grid = new Gtk.Grid ();
                    switcher_grid.margin_top = 24;
                    switcher_grid.margin_bottom = 12;
                    switcher_grid.add (left_sep);
                    switcher_grid.add (stack_switcher);
                    switcher_grid.add (right_sep);

                    main_grid.attach (switcher_grid, 0, 7, 2, 1);
                }

                main_grid.attach (stack, 0, 8, 2, 1);

                main_view = new MainView ();
                main_view.margin_bottom = 12;
                main_view.add (main_grid);
                main_view.show_all ();

                // hide stack switcher if we only have ac line
                stack_switcher.visible = stack.get_children ().length () > 1;
            }

            return main_view;
        }

        public override void shown () {
            var stack = stack_switcher.get_stack ();
            if (stack == null) {
                return;
            }

            if (battery.check_present ()) {
                stack.visible_child_name = "battery";
            } else {
                stack.visible_child_name = "ac";
            }
        }

        public override void hidden () {

        }

        public override void search_callback (string location) {

        }

        // 'search' returns results like ("Keyboard → Behavior → Duration", "keyboard<sep>behavior")
        public override async Gee.TreeMap<string, string> search (string search) {
            var search_results = new Gee.TreeMap<string, string> ((GLib.CompareDataFunc<string>)strcmp, (Gee.EqualDataFunc<string>)str_equal);
            search_results.set ("%s → %s".printf (display_name, _("Sleep button")), "");
            search_results.set ("%s → %s".printf (display_name, _("Power button")), "");
            search_results.set ("%s → %s".printf (display_name, _("Display inactive")), "");
            search_results.set ("%s → %s".printf (display_name, _("Dim display")), "");
            search_results.set ("%s → %s".printf (display_name, _("Lid close")), "");
            search_results.set ("%s → %s".printf (display_name, _("Display brightness")), "");
            search_results.set ("%s → %s".printf (display_name, _("Automatic brightness adjustment")), "");
            search_results.set ("%s → %s".printf (display_name, _("Inactive display off")), "");
            search_results.set ("%s → %s".printf (display_name, _("Docked lid close")), "");
            search_results.set ("%s → %s".printf (display_name, _("Sleep inactive")), "");
            return search_results;;
        }

        private Gtk.Grid create_notebook_pages (bool ac) {
            var sleep_timeout_label = new Gtk.Label (_("Sleep when inactive for:"));
            sleep_timeout_label.xalign = 1;
            label_size.add_widget (sleep_timeout_label);

            string type = "battery";
            if (ac) {
                type = "ac";
            }

            var scale_settings = @"sleep-inactive-%s-timeout".printf (type);
            var sleep_timeout = new TimeoutComboBox (settings, scale_settings);

            var grid = new Gtk.Grid ();
            grid.column_spacing = 12;
            grid.row_spacing = 12;
            grid.attach (sleep_timeout_label, 0, 1, 1, 1);
            grid.attach (sleep_timeout, 1, 1, 1, 1);

            if (!ac && backlight_detect ()){
                var dim_label = new Gtk.Label (_("Dim display when inactive:"));
                dim_label.xalign = 1;

                var dim_switch = new Gtk.Switch ();
                dim_switch.halign = Gtk.Align.START;

                settings.bind ("idle-dim", dim_switch, "active", SettingsBindFlags.DEFAULT);

                grid.attach (dim_label, 0, 0, 1, 1);
                grid.attach (dim_switch, 1, 0, 1, 1);

                label_size.add_widget (dim_label);
            }

            return grid;
        }

        private static bool backlight_detect () {
            var interface_path = File.new_for_path ("/sys/class/backlight/");

            try {
                var enumerator = interface_path.enumerate_children (
                GLib.FileAttribute.STANDARD_NAME,
                FileQueryInfoFlags.NONE);
                FileInfo backlight;
                if ((backlight = enumerator.next_file ()) != null) {
                    debug ("Detected backlight interface");
                    return true;
                }

            enumerator.close ();

            } catch (GLib.Error err) {
                critical ("%s", err.message);
            }

            return false;
        }
    }
}

public Switchboard.Plug get_plug (Module module) {
    debug ("Activating Power plug");
    var plug = new Power.Plug ();
    return plug;
}
