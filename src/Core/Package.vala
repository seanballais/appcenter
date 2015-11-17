// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2015 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class AppCenterCore.Package : Object {
    public signal void changed ();
    public signal void progress_changed (string label, double progress);

    public AppStream.Component component { public get; private set; }
    public bool installed { public get; public set; }
    public bool update_available {
        public get {
            return update_size > 0;
        }
    }

    private uint64 _update_size = 0;
    public uint64 update_size {
        public get {
            return _update_size;
        }
        public set {
            if (_update_size != value) {
                _update_size = value;
                notify_property ("update-available");
            }
        }
    }

    private double progress = 1.0f;
    private Pk.Status status = Pk.Status.FINISHED;

    public Package (AppStream.Component component) {
        this.component = component;
    }

    public async void update () throws GLib.Error {
        var treeset = new Gee.TreeSet<AppCenterCore.Package> ();
        treeset.add (this);
        this.progress = 0.0f;
        try {
            yield AppCenterCore.Client.get_default ().update_packages (treeset, (progress, type) => {ProgressCallback (progress, type);});
            update_size = 0;
        } catch (Error e) {
            throw e;
        }
    }

    public async void install () throws GLib.Error {
        var treeset = new Gee.TreeSet<AppCenterCore.Package> ();
        treeset.add (this);
        this.progress = 0.0f;
        try {
            yield AppCenterCore.Client.get_default ().install_packages (treeset, (progress, type) => {ProgressCallback (progress, type);});
            installed = true;
        } catch (Error e) {
            throw e;
        }
    }

    public async void uninstall () throws GLib.Error {
        var treeset = new Gee.TreeSet<AppCenterCore.Package> ();
        treeset.add (this);
        this.progress = 0.0f;
        try {
            yield AppCenterCore.Client.get_default ().remove_packages (treeset, (progress, type) => {ProgressCallback (progress, type);});
            installed = false;
        } catch (Error e) {
            throw e;
        }
    }

    public void get_latest_progress (out string label, out double progress) {
        progress = this.progress;
        label = get_localized_status (status);
    }

    public void set_latest_progress (Pk.Status status, double progress) {
        this.status = status;
        this.progress = progress;
        progress_changed (get_localized_status (status), this.progress);
    }

    public static string get_localized_status (Pk.Status status) {
        switch (status) {
            case Pk.Status.SETUP:
                return _("Starting");
            case Pk.Status.WAIT:
                return _("Waiting in queue");
            case Pk.Status.RUNNING:
                return _("Running");
            case Pk.Status.QUERY:
                return _("Querying");
            case Pk.Status.INFO:
                return _("Getting information");
            case Pk.Status.REMOVE:
                return _("Removing packages");
            case Pk.Status.DOWNLOAD:
                return _("Downloading packages");
            case Pk.Status.INSTALL:
                return _("Installing packages");
            case Pk.Status.REFRESH_CACHE:
                return _("Refreshing software list");
            case Pk.Status.UPDATE:
                return _("Installing updates");
            case Pk.Status.CLEANUP:
                return _("Cleaning up packages");
            case Pk.Status.OBSOLETE:
                return _("Obsoleting packages");
            case Pk.Status.DEP_RESOLVE:
                return _("Resolving dependencies");
            case Pk.Status.SIG_CHECK:
                return _("Checking signatures");
            case Pk.Status.TEST_COMMIT:
                return _("Testing changes");
            case Pk.Status.COMMIT:
                return _("Committing changes");
            case Pk.Status.REQUEST:
                return _("Requesting data");
            case Pk.Status.FINISHED:
                return _("Finished");
            case Pk.Status.CANCEL:
                return _("Cancelling");
            case Pk.Status.DOWNLOAD_REPOSITORY:
                return _("Downloading repository information");
            case Pk.Status.DOWNLOAD_PACKAGELIST:
                return _("Downloading list of packages");
            case Pk.Status.DOWNLOAD_FILELIST:
                return _("Downloading file lists");
            case Pk.Status.DOWNLOAD_CHANGELOG:
                return _("Downloading lists of changes");
            case Pk.Status.DOWNLOAD_GROUP:
                return _("Downloading groups");
            case Pk.Status.DOWNLOAD_UPDATEINFO:
                return _("Downloading update information");
            case Pk.Status.REPACKAGING:
                return _("Repackaging files");
            case Pk.Status.LOADING_CACHE:
                return _("Loading cache");
            case Pk.Status.SCAN_APPLICATIONS:
                return _("Scanning applications");
            case Pk.Status.GENERATE_PACKAGE_LIST:
                return _("Generating package lists");
            case Pk.Status.WAITING_FOR_LOCK:
                return _("Waiting for package manager lock");
            case Pk.Status.WAITING_FOR_AUTH:
                return _("Waiting for authentication");
            case Pk.Status.SCAN_PROCESS_LIST:
                return _("Updating running applications");
            case Pk.Status.CHECK_EXECUTABLE_FILES:
                return _("Checking applications in use");
            case Pk.Status.CHECK_LIBRARIES:
                return _("Checking libraries in use");
            case Pk.Status.COPY_FILES:
                return _("Copying files");
            default:
                return _("Unknown state");
        }
    }

    private void ProgressCallback (Pk.Progress progress, Pk.ProgressType type) {
        switch (type) {
            case Pk.ProgressType.ITEM_PROGRESS:
                this.progress = ((double) progress.item_progress.percentage)/100;
                progress_changed (get_localized_status (status), this.progress);
                break;
            case Pk.ProgressType.STATUS:
                status = (Pk.Status) progress.status;
                if (status == Pk.Status.FINISHED) {
                    this.progress = 1.0f;
                }

                progress_changed (get_localized_status (status), this.progress);
                break;
        }
    }

    public string? get_name () {
        var _name = component.get_name ();
        if (_name != null) {
            return _name;
        }

        var package = find_package ();
        if (package != null) {
            return package.get_name ();
        }

        return null;
    }

    public string? get_summary () {
        var summary = component.get_summary ();
        if (summary != null) {
            return summary;
        }

        var package = find_package ();
        if (package != null) {
            return package.get_summary ();
        }

        return null;
    }

    public string? get_version () {
        var package = find_package ();
        if (package != null) {
            string returned = package.get_version ();
            returned = returned.split ("+", 2)[0];
            returned = returned.split ("-", 2)[0];
            returned = returned.split ("~", 2)[0];
            if (":" in returned) {
                returned = returned.split (":", 2)[1];
            }

            return returned;
        }

        return null;
    }

    private Pk.Package? find_package (bool installed = false) {
        try {
            Pk.Bitfield filter = 0;
            if (installed) {
                filter = Pk.Bitfield.from_enums (Pk.Filter.INSTALLED);
            }

            return AppCenterCore.Client.get_default ().get_app_package (component.get_pkgnames ()[0], filter);
        } catch (Error e) {
            critical (e.message);
            return null;
        }
    }
}
