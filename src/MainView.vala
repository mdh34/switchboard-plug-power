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

public class Power.MainView : Gtk.Grid {
    private Gtk.Scale scale;
    private PowerSettings screen;

    private const string NO_PERMISSION_STRING  = _("You do not have permission to change this");
    private const string SETTINGS_DAEMON_NAME = "org.gnome.SettingsDaemon";
    private const string SETTINGS_DAEMON_PATH = "/org/gnome/SettingsDaemon/Power";

    construct {
        try {
            screen = Bus.get_proxy_sync (BusType.SESSION, SETTINGS_DAEMON_NAME, SETTINGS_DAEMON_PATH, DBusProxyFlags.GET_INVALIDATED_PROPERTIES);
        } catch (IOError e) {
            warning ("Failed to get settings daemon for brightness setting");
        }

        orientation = Gtk.Orientation.VERTICAL;

        var label = new Gtk.Label (_("Some changes will not take effect until you restart this computer"));

        var infobar = new Gtk.InfoBar ();
        infobar.message_type = Gtk.MessageType.WARNING;
        infobar.no_show_all = true;
        infobar.get_content_area ().add (label);
        infobar.hide ();

        var helper = LogindHelper.get_logind_helper ();
        if (helper != null) {
            helper.changed.connect (() => {
                infobar.no_show_all = false;
                infobar.show_all ();
            });
        }

        add (infobar);

        var label_size = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);

        if (lid_detect ()) {
            var lock_button = new Gtk.LockButton (get_permission ());

            var permission_label = new Gtk.Label (_("Some settings require administrator rights to be changed"));

            var permission_infobar = new Gtk.InfoBar ();
            permission_infobar.message_type = Gtk.MessageType.INFO;
            permission_infobar.get_content_area ().add (permission_label);

            var area_infobar = permission_infobar.get_action_area () as Gtk.Container;
            area_infobar.add (lock_button);

            permission_infobar.show_all ();

            add (permission_infobar);

            //connect polkit permission to hiding the permission infobar
            permission.notify["allowed"].connect (() => {
                if (permission.allowed) {
                    permission_infobar.no_show_all = true;
                    permission_infobar.hide ();
                }
            });

            var lid_closed_label = new Gtk.Label (_("When lid is closed:"));
            lid_closed_label.halign = Gtk.Align.END;
            lid_closed_label.sensitive = false;
            lid_closed_label.xalign = 1;

            var lid_closed_box = new LidCloseActionComboBox (false);
            lid_closed_box.sensitive = false;

            var lid_dock_label = new Gtk.Label (_("When lid is closed with external monitor:"));
            lid_dock_label.halign = Gtk.Align.END;
            lid_dock_label.sensitive = false;
            lid_dock_label.xalign = 1;

            var lid_dock_box = new LidCloseActionComboBox (true);
            lid_dock_box.sensitive = false;

            var lock_image = new Gtk.Image.from_icon_name ("changes-prevent-symbolic", Gtk.IconSize.BUTTON);
            lock_image.tooltip_text = NO_PERMISSION_STRING;
            lock_image.sensitive = false;

            var lock_image2 = new Gtk.Image.from_icon_name ("changes-prevent-symbolic", Gtk.IconSize.BUTTON);
            lock_image2.tooltip_text = NO_PERMISSION_STRING;
            lock_image2.sensitive = false;

            var permission = get_permission ();

            // lock and UI visible that settings are locked and unlocked
            permission.notify["allowed"].connect (() => {
                if (permission.allowed) {
                    lid_closed_box.sensitive = true;
                    lid_closed_label.sensitive = true;
                    lid_dock_box.sensitive = true;
                    lid_dock_label.sensitive = true;
                    lock_image.visible = false;
                    lock_image2.visible = false;
                } else {
                    lid_closed_box.sensitive = false;
                    lid_closed_label.sensitive = false;
                    lid_dock_box.sensitive = false;
                    lid_dock_label.sensitive = false;
                    lock_image.visible = true;
                    lock_image2.visible = true;
                }
            });

            main_grid.attach (lid_closed_label, 0, 5, 1, 1);
            main_grid.attach (lid_closed_box, 1, 5, 1, 1);
            main_grid.attach (lock_image2, 2, 5, 1, 1);
            main_grid.attach (lid_dock_label, 0, 6, 1, 1);
            main_grid.attach (lid_dock_box, 1, 6, 1, 1);
            main_grid.attach (lock_image, 2, 6, 1, 1);

            label_size.add_widget (lid_closed_label);
            label_size.add_widget (lid_dock_label);
        }

        if (backlight_detect ()) {
            var brightness_label = new Gtk.Label (_("Display brightness:"));
            brightness_label.halign = Gtk.Align.END;
            brightness_label.xalign = 1;

            var als_label = new Gtk.Label (_("Automatically adjust brightness:"));
            als_label.xalign = 1;

            var als_switch = new Gtk.Switch ();
            als_switch.halign = Gtk.Align.START;

            settings.bind ("ambient-enabled", als_switch, "active", SettingsBindFlags.DEFAULT);

            scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 10);
            scale.draw_value = false;
            scale.hexpand = true;
            scale.width_request = 480;

            scale.set_value (screen.brightness);

            scale.value_changed.connect (on_scale_value_changed);
            (screen as DBusProxy).g_properties_changed.connect (on_screen_properties_changed);

            main_grid.attach (brightness_label, 0, 0, 1, 1);
            main_grid.attach (scale, 1, 0, 1, 1);
            main_grid.attach (als_label, 0, 1, 1, 1);
            main_grid.attach (als_switch, 1, 1, 1, 1);

            label_size.add_widget (brightness_label);
            label_size.add_widget (als_label);
        }

        var screen_timeout_label = new Gtk.Label (_("Turn off display when inactive for:"));
        screen_timeout_label.halign = Gtk.Align.END;
        screen_timeout_label.xalign = 1;

        var pantheon_dpms_settings = new GLib.Settings ("org.pantheon.dpms");

        var screen_timeout = new TimeoutComboBox (pantheon_dpms_settings, "standby-time");
        screen_timeout.changed.connect (run_dpms_helper);

        var power_label = new Gtk.Label (_("Power button:"));
        power_label.halign = Gtk.Align.END;
        power_label.xalign = 1;

        var power_combobox = new ActionComboBox ("power-button-action");

        var main_grid = new Gtk.Grid ();
        main_grid.margin = 24;
        main_grid.column_spacing = 12;
        main_grid.row_spacing = 12;
        main_grid.attach (screen_timeout_label, 0, 3, 1, 1);
        main_grid.attach (screen_timeout, 1, 3, 1, 1);
        main_grid.attach (power_label, 0, 4, 1, 1);
        main_grid.attach (power_combobox, 1, 4, 1, 1);

        label_size.add_widget (screen_timeout_label);
        label_size.add_widget (power_label);

        add (main_grid);
        show_all ();
    }

    private void on_scale_value_changed () {
        var val = (int) scale.get_value ();
        (screen as DBusProxy).g_properties_changed.disconnect (on_screen_properties_changed);
        screen.brightness = val;
        (screen as DBusProxy).g_properties_changed.connect (on_screen_properties_changed);
    }

    private void on_screen_properties_changed (Variant changed_properties, string[] invalidated_properties) {
        var changed_brightness = changed_properties.lookup_value ("Brightness", new VariantType ("i"));
        if (changed_brightness != null) {
            var val = screen.brightness;
            scale.value_changed.disconnect (on_scale_value_changed);
            scale.set_value (val);
            scale.value_changed.connect (on_scale_value_changed);
        }
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

    private static bool lid_detect () {
        var interface_path = File.new_for_path ("/proc/acpi/button/lid/");

        try {
            var enumerator = interface_path.enumerate_children (
            GLib.FileAttribute.STANDARD_NAME,
            FileQueryInfoFlags.NONE);
            FileInfo lid;
            if ((lid = enumerator.next_file ()) != null) {
                debug ("Detected lid switch");
                return true;
            }

            enumerator.close ();

        } catch (GLib.Error err) {
            critical ("%s", err.message);
        }

        return false;
    }

    private static void run_dpms_helper () {
        try {
            string[] argv = { "elementary-dpms-helper" };
            Process.spawn_async (null, argv, Environ.get (),
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL | SpawnFlags.STDOUT_TO_DEV_NULL,
                null, null);
        } catch (SpawnError e) {
            warning ("Failed to reset dpms settings: %s", e.message);
        }
    }
}
