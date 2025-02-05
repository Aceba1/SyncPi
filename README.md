# SyncPi

SSH Project Synchronization for the Raspberry Pi!

## What is this

SyncPi is a utility script to remotely configure a Raspberry Pi to initialize and develop projects.
It uses SSH to synchronize settings, packages and directories to get a project up and running!

## Features

- Install and maintain APT packages from a list
- Append firmware settings to the Pi's configuration
- Register a systemd service to run the project on startup
- Upload necessary project files and folders to the Pi

## Setup

### Set up a new Raspberry Pi

- A bootable SD card can be prepared with the [Raspberry Pi Imager](https://www.raspberrypi.com/software/)

- "Raspberry Pi OS Lite" is recommended for headless projects where no desktop environment is required

### Preconfigure OS customizations

- **General**

  - Set a unique hostname to differentiate from other devices on the network
  - Set the user and change the default password
  - Set the wireless LAN to connect to your wifi
  - Set locale settings to match your timezone

- **Services**

  - Enable SSH!
  - Use password authentication if desired, otherwise provide the authorized public keys

### Set up the script

1. Add the `sync.sh` script under a new folder in the root of your project, such as `.syncpi/`

2. Copy and rename the `.env.sample` to `.env` in the same folder

   - Set the value of `SSH_USER` to the Pi's username (ex: `pi`)
   - Set the value of `SSH_SERVER` to the Pi's hostname (ex: `raspberrypi.local`)
   - Additional default values in the `.env.sample` file can be saved for sharing the project

3. Mark the script as executable:

   ```
   chmod +x sync.sh
   ```

4. Run the sync script to create the configuration files:

   ```
   ./sync.sh
   ```

5. If requested, log in to the device to add your SSH public key

   - If a public key hasn't been created yet, you can make a new one by running this command in the terminal:

     ```
     ssh-keygen -t rsa
     ```

## Configuration

Configuration files will be created in a `config/` folder next to the script. These files should be added to the project's git history.

### packages.ini

Packages in this list will be installed on the remote device. Packages installed by this script will be removed if they are no longer in this list.

- To disable this feature, set envrionment `SKIP_PACKAGES` to `true`
- To prevent automatically upgrading packages, set `SKIP_PACKAGES_UPGRADE` to `true`
- To prevent removing previously installed packages, set `SKIP_PACKAGES_REMOVAL` to `true`

### firmware.ini

Content in this file will be inserted to the [`config.txt`](https://www.raspberrypi.com/documentation/computers/config_txt.html) file in the remote device. Modifications to this file will update the inserted content and trigger a restart.

- To disable this feature, set envrionment `SKIP_FIRMWARE` to `true`
- To prevent automatic restarts, set `SKIP_REBOOT_DEVICE` to `true`

### service.ini

Service definition in this file will be copied and registered to the remote device. Modifications to this service file will be updated in the registered service.

The default service is configured to run `~/autostart` after a normal reboot.

- Set environment `SERVICE_NAME` to change the default name (defaults to `startup`)
- To disable this feature, set envrionment `SKIP_SERVICE` to `true`
- To prevent the service from stopping, set `SKIP_SERVICE_STOP_BEFORE_SCRIPT` to `true`
- To prevent the service from restarting, set `SKIP_SERVICE_START_AFTER_SCRIPT` to `true`

### syncpaths.ini

Files and folders in the project will be uploaded from the quoted paths using [rsync](https://rsync.samba.org/). Source paths relative to the project root will be uploaded to target paths on the remote device.

- Set environment `SYNC_CHMOD` to change the default permissions (defaults to `D755,F755`)
- Set environment `SYNC_CHOWN` to change the default owning user (defaults to the SSH user)
- To disable this feature, set envrionment `SKIP_FILESYNC` to `true`

### syncignore.ini

File patterns to ignore when uploading files and folders from the host to the target paths. Refer to the [rsync documentation](https://download.samba.org/pub/rsync/rsync.1) for `--exclude-from` for formatting.

Ignored file patterns will not be uploaded from the host or overwritten in the remote. This may be important for keeping files that are generated in the remote project's directories.

- This file can be left blank or removed if it is not required for the project

## Disclaimer

This script is designed to be used to configure a blank Raspberry Pi set up with SSH access, and will perform remote changes on the target device using sudo permissions.

Notekeeping files will be stored on the remote device to track installed packages and the synchronized service name.

File synchronization may override modifications or any existing content in targeted files or folder paths.

Use at your own risk!
