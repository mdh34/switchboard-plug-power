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
    construct {
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
        }

        show_all ();
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
}
