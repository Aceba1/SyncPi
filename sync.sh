#!/bin/sh
#? SyncPi v0.1.3
#? SSH Project Synchronization for the Raspberry Pi
#? Arniel Ceballos - aceba1@proton.me
#? https://github.com/Aceba1/SyncPi

# region - Helper functions
temp_file() {
	mkdir --parents "$WORKING_PATH/.tmp/"
	mktemp --quiet "$WORKING_PATH/.tmp/$1.XXXX"
}

temp_clear() {
	if [ "$KEEP_TEMP" != "true" ]; then
		rm --recursive --force --dir "$WORKING_PATH/.tmp/"
	fi
}

stop() {
	temp_clear
	exit "$1"
}

info() {
	echo "$color_blue$1$color_white"
}

warn() {
	echo "$color_yellow$1$color_white"
}

read_without_comments() {
	sed "s/#.*\$//g" "$1"
}

ssh_command() {
	ssh -o BatchMode=true "$SSH_USER@$SSH_SERVER" "$1"
}
# endregion - Helper functions

# region - Variables
# Set local variables
script_version="0.1.3"

# Define colors
color_blue=$(tput setaf 153)
color_white=$(tput setaf 7)
color_yellow=$(tput setaf 3)
text_normal=$(tput sgr0)
text_underline=$(tput smul)

# Set default environment variables if unset
# Defining variables like this allows these values to be defined by the shell
: "${CONFIG_BLOCK_END:="# ==== End of SyncPi configuration ===="}"
: "${CONFIG_BLOCK_START:="# ==== Start of SyncPi configuration ===="}"
: "${KEEP_TEMP:="false"}"
: "${REBOOT_DEVICE:="false"}"
: "${REMOTE_PATH_PACKAGE_NOTE:="/syncpi/packages"}"
: "${REMOTE_PATH_SERVICE_NOTE:="/syncpi/service"}"
: "${SERVICE_NAME:="startup"}"
: "${SKIP_ENV_FILE:="false"}"
: "${SKIP_FILESYNC:="false"}"
: "${SKIP_FIRMWARE:="false"}"
: "${SKIP_PACKAGES_REMOVAL:="false"}"
: "${SKIP_PACKAGES_UPGRADE:="false"}"
: "${SKIP_PACKAGES:="false"}"
: "${SKIP_REBOOT_DEVICE:="false"}"
: "${SKIP_SERVICE_START_AFTER_SCRIPT:="false"}"
: "${SKIP_SERVICE_STOP_BEFORE_SCRIPT:="false"}"
: "${SKIP_SERVICE:="false"}"
: "${SSH_RESTART_PAUSE:="10"}"
: "${SSH_RESTART_TIMEOUT:="120"}"
: "${SSH_SERVER:="raspberrypi.local"}"
: "${SSH_USER:="pi"}"
: "${SYNC_CHMOD:="D755,F755"}"
: "${WORKING_PATH:="$(dirname "$0")"}"

# Load custom environment variables from .env file
: "${ENV_PATH:="$WORKING_PATH/.env"}"

# shellcheck disable=SC1090
if [ "$SKIP_ENV_FILE" != "true" ]; then
	if [ ! -e "$ENV_PATH" ]; then
		warn "Cannot find '$(basename "$ENV_PATH")' file!"
		echo "  - Make a copy of the '.env.sample' file and rename it to '$(basename "$ENV_PATH")'"
		echo "  - Set the values in there to connect to your device"
		stop 1
	elif ! . "$ENV_PATH"; then
		warn "Cannot read '$(basename "$ENV_PATH")' file!"
	fi
fi

# Define dependent variables if unset
: "${FILESYNC_PATH:="$(readlink --canonicalize "$(dirname "$WORKING_PATH")")"}"
: "${SYNC_CHOWN:="$SSH_USER"}"
: "${PATH_CONFIG_DIR:="$WORKING_PATH/config"}"
: "${PATH_PACKAGES_FILE:="$PATH_CONFIG_DIR/packages.ini"}"
: "${PATH_FIRMWARE_FILE:="$PATH_CONFIG_DIR/firmware.ini"}"
: "${PATH_SERVICE_FILE:="$PATH_CONFIG_DIR/service.ini"}"
: "${PATH_SYNCIGNORE_FILE:="$PATH_CONFIG_DIR/syncignore.ini"}"
: "${PATH_SYNCPATHS_FILE:="$PATH_CONFIG_DIR/syncpaths.ini"}"
# endregion - Variables

# Begin script!
info "SyncPi v$script_version"
echo

# Clear previous temp folder if it exists
temp_clear

# region - Add configuration files
# region - Config folder
if [ ! -d "$PATH_CONFIG_DIR" ]; then
	if mkdir -p "$PATH_CONFIG_DIR"; then
		info "Created 'config' folder!"
		echo "  - This directory will hold the configuration files specific to this project"
		echo
	else
		warn "Cannot make config directory!"
		stop 10
	fi
fi
# endregion - Config folder

# region - APT packages
if [ "$SKIP_PACKAGES" != "true" ] && [ ! -e "$PATH_PACKAGES_FILE" ]; then
	if printf "%s\n" \
		"# List of APT packages to be installed, separated by spaces or lines" \
		>"$PATH_PACKAGES_FILE"; then
		info "Created '$(basename "$PATH_PACKAGES_FILE")' template file!$"
		echo "  - Setup required APT packages here"
		echo "  - List the names of packages to be remotely installed"
		echo "  - File location: '$PATH_PACKAGES_FILE'"
	else
		warn "Cannot write $(basename "$PATH_PACKAGES_FILE") file!"
	fi
	echo

	SKIP_PACKAGES=true
fi
# endregion - APT packages

# region - Firmware config
if [ "$SKIP_FIRMWARE" != "true" ] && [ ! -e "$PATH_FIRMWARE_FILE" ]; then
	if printf "%s\n" \
		"[all]" \
		"# Configurations applied to all hardware" \
		"" \
		"[pi4]" \
		"# Configurations for Raspberry Pi 4" \
		"" \
		"[pi5]" \
		"# Configurations for Raspberry Pi 5" \
		>"$PATH_FIRMWARE_FILE"; then
		info "Created '$(basename "$PATH_FIRMWARE_FILE")' template file!"
		echo "  - Setup firmware configurations here"
		echo "  - Refer to this document for formatting: ${text_underline}https://www.raspberrypi.com/documentation/computers/config_txt.html${text_normal}"
		echo "  - File location: '$PATH_FIRMWARE_FILE'"
	else
		warn "Cannot write $(basename "$PATH_FIRMWARE_FILE") file!"
	fi
	echo

	SKIP_FIRMWARE=true
fi
# endregion - Firmware config

# region - Systemd service
if [ "$SKIP_SERVICE" != "true" ] && [ ! -e "$PATH_SERVICE_FILE" ]; then
	if printf "%s\n" \
		"[Unit]" \
		"Description=SyncPi $SERVICE_NAME service" \
		"After=multi-user.target" \
		"" \
		"[Service]" \
		"Type=exec" \
		"ExecStart=/home/$SSH_USER/autostart" \
		"" \
		"[Install]" \
		"WantedBy=multi-user.target" \
		>"$PATH_SERVICE_FILE"; then
		info "Created '$(basename "$PATH_SERVICE_FILE")' template file!"
		echo "  - Setup the start-up service here"
		echo "  - A new service will be registered to automatically run the project"
		echo "  - File location: '$PATH_SERVICE_FILE'"
	else
		warn "Cannot write $(basename "$PATH_SERVICE_FILE") file!"
	fi
	echo

	SKIP_SERVICE=true
fi
# endregion - Systemd service

# region - Sync paths
if [ "$SKIP_FILESYNC" != "true" ] && [ ! -e "$PATH_SYNCPATHS_FILE" ]; then
	if printf "%s\n" \
		"# List of quoted file and folder paths to be synchronized, one pair per line" \
		"# Only the contents within quotes will be used." \
		"# In example: \"Source Path\" \"Remote Path\"" \
		"" \
		"- \"build/\" \"/home/$SSH_USER/build/\"" \
		"- \"autostart\" \"/home/$SSH_USER/autostart\"" \
		>"$PATH_SYNCPATHS_FILE"; then
		info "Created '$(basename "$PATH_SYNCPATHS_FILE")' template file!"
		echo "  - Setup desired source and target paths to be synced here"
		echo "  - List the project folders and files to be sent to the remote device"
		echo "  - File location: '$PATH_SYNCPATHS_FILE'"
	else
		warn "Cannot write $(basename "$PATH_SYNCPATHS_FILE") file!"
	fi
	echo

	if [ ! -e "$PATH_SYNCIGNORE_FILE" ]; then
		if printf "%s\n" \
			"# List of file and folder patterns to exclude from file synchronization, one pattern per line" \
			>"$PATH_SYNCIGNORE_FILE"; then
			info "Created '$(basename "$PATH_SYNCIGNORE_FILE")' template file!"
			echo "  - Setup the optional exclude-from patterns here"
			echo "  - Refer to this document for formatting: ${text_underline}https://download.samba.org/pub/rsync/rsync.1#opt--exclude-from${text_normal}"
			echo "  - File location: '$PATH_SYNCIGNORE_FILE'"
		else
			warn "Cannot write $(basename "$PATH_SYNCIGNORE_FILE") file!"
		fi
		echo
	fi

	SKIP_FILESYNC=true
fi
# endregion - Sync paths
# endregion - Add configuration files

# region - Setup connection
# Test connection to device
info "Testing connection to '$SSH_SERVER'..."

if ! ping "$SSH_SERVER" -c 1 -W 1 >/dev/null; then
	warn "Cannot find remote!"
	echo "  - Is the device turned on?"
	echo "  - Is it accessible from this address?"
	stop 20
fi

if ! ssh_command true 2>/dev/null; then
	warn "Cannot connect to SSH server!"
	echo
	info "Attempting to register SSH key..."
	if ! ssh-copy-id "$SSH_USER@$SSH_SERVER"; then
		warn "Cannot add SSH key to server!"
		echo "  - Is the remote device properly set up for SSH access?"
		echo "  - Does a public key (identity) exist on the host device?"
		stop 21
	fi
	info "Key registered!"
fi
info "Connected to remote!"
echo
# endregion - Setup connection

# region - Stop service
if [ "$SKIP_SERVICE" != "true" ] && [ "$SKIP_SERVICE_STOP_BEFORE_SCRIPT" != "true" ]; then
	# Get remote service
	if remote_service_name=$(ssh_command "sudo cat '$REMOTE_PATH_SERVICE_NOTE'" 2>/dev/null); then
		is_active=$(ssh_command "systemctl is-active '$remote_service_name.service'")
		# Stop if the service is active
		if [ "$is_active" = "active" ]; then
			info "Stopping service '$remote_service_name'..."
			ssh_command "sudo systemctl start '$remote_service_name.service'"
			echo
		fi
	fi
fi
# endregion - Stop service

# region - Synchronization
# region - Sync APT packages
if [ "$SKIP_PACKAGES" != "true" ]; then
	# Update packages
	info "Updating packages..."
	ssh_command "sudo apt-get --quiet=2 update"
	echo

	# Upgrade packages
	if [ "$SKIP_PACKAGES_UPGRADE" != "true" ]; then
		info "Upgrading packages..."
		ssh_command "sudo apt-get --quiet upgrade --yes"
		echo
	fi

	# Utility to get currently installed packages
	get_installed_packages() {
		installed_packages=$(ssh_command "apt list --installed | sed 's/\/.*$//'" 2>/dev/null)
	}

	# Utility to check if package is installed
	is_installed() {
		# Ignore version numbers (=) when checking if a package name is installed
		echo "$installed_packages" | grep --fixed-strings --line-regexp --quiet "${1%%=*}"
	}

	# Get local and remote package lists
	local_packages=$(read_without_comments "$PATH_PACKAGES_FILE" | grep --only-matching --extended-regexp '[^\s]+' | sort)
	remote_packages=$(ssh_command "sudo cat '$REMOTE_PATH_PACKAGE_NOTE'" 2>/dev/null | sort)

	# Compare local and remote package lists
	temppath_local_packages=$(temp_file "local_packages")
	temppath_remote_packages=$(temp_file "remote_packages")
	echo "$local_packages" >"$temppath_local_packages"
	echo "$remote_packages" >"$temppath_remote_packages"

	packages_to_remove=$(comm -23 "$temppath_remote_packages" "$temppath_local_packages")
	packages_to_install=$(comm -13 "$temppath_remote_packages" "$temppath_local_packages")

	# region - Synchronize
	# Hold package list changes in variable
	new_remote_packages=$remote_packages

	# Check packages being removed
	remove_command=""
	get_installed_packages
	if [ -n "$packages_to_remove" ]; then
		for apt in $packages_to_remove; do
			if is_installed "$apt"; then
				remove_command="$remove_command $apt"

				# Remove package from remote package list
				# TODO: Check if packages are removed after running the command
				if [ "$SKIP_PACKAGES_REMOVAL" != "true" ]; then
					new_remote_packages=$(echo "$new_remote_packages" | sed "/^$apt\$/d")
				fi
			fi
		done
		echo
	fi

	# Remove packages
	if [ -n "$remove_command" ]; then
		if [ "$SKIP_PACKAGES_REMOVAL" != "true" ]; then
			info "Removing packages..."
			echo "  - $remove_command"
			echo
			ssh_command "sudo apt-get --quiet remove --yes $remove_command"
			ssh_command "sudo apt-get --quiet autoremove --yes"
			get_installed_packages
		else
			info "These packages are no longer required..."
			echo "  - Automatic package removal is disabled"
			echo "  - $remove_command"
		fi
		echo
	fi

	# Check packages being installed
	install_command=""
	if [ -n "$packages_to_install" ]; then
		for apt in $packages_to_install; do
			if ! is_installed "$apt"; then
				install_command="$install_command $apt"
			fi
		done
	fi

	# Install packages
	if [ -n "$install_command" ]; then
		info "Installing packages..."
		echo "  - $install_command"
		echo
		ssh_command "sudo apt-get --quiet install  --yes $install_command"
		get_installed_packages

		for apt in $install_command; do
			if is_installed "$apt"; then
				new_remote_packages=$(printf "%s\n" "$new_remote_packages" "$apt")
			else
				warn "  - Unable to install '$apt'"
			fi
		done
		echo
	fi
	# endregion - Synchronize

	# Completed
	info "Done synchronizing packages!"
	echo

	# Record changes to remote
	ssh_command "sudo mkdir --parents $(dirname "$REMOTE_PATH_PACKAGE_NOTE")" >/dev/null
	ssh_command "echo '$new_remote_packages' | sort | sudo tee '$REMOTE_PATH_PACKAGE_NOTE'" >/dev/null
fi
# endregion - Sync APT packages

# region - Sync firmware config
if [ "$SKIP_FIRMWARE" != "true" ]; then
	# Find location of config.txt
	if ssh_command "test -e /boot/firmware/config.txt"; then
		remote_config_path=/boot/firmware/config.txt
	else
		remote_config_path=/boot/config.txt
	fi

	# Read remote config.txt file
	remote_config_file=$(ssh_command "sudo cat '$remote_config_path'")

	# Setup config block regex
	config_regex=".$CONFIG_BLOCK_START.*$CONFIG_BLOCK_END."

	# Create local config block as a multiline variable
	local_config_block="
$CONFIG_BLOCK_START

$(cat "$PATH_FIRMWARE_FILE")

$CONFIG_BLOCK_END"

	# region - Synchronize
	# Check that the remote block exists
	if echo "$remote_config_file" | grep --null-data --extended-regexp --quiet "$config_regex"; then
		# Update the remote config if there are any changes
		remote_config_block=$(echo "$remote_config_file" | grep --null-data --extended-regexp --only-matching "$config_regex" | tr '\0' '\n')
		if [ "$remote_config_block" != "$local_config_block" ]; then
			info "Updating firmware configuration..."
			echo "  - $remote_config_path"

			# Remove previous block from file
			ssh_command "sudo sed --in-place --null-data \"s/$config_regex//\" \"$remote_config_path\""

			# Add new block to end of file
			ssh_command "echo '$local_config_block' | sudo tee --append '$remote_config_path'"
			echo

			REBOOT_DEVICE=true
		fi
	else
		# Remote config block doesn't exist yet
		info "Adding firmware configuration..."
		echo "  - $remote_config_path"

		# Add new block to end of file
		ssh_command "echo '$local_config_block' | sudo tee --append '$remote_config_path'"
		echo

		REBOOT_DEVICE=true
	fi
	# endregion - Synchronize

	# Completed
	info "Done synchronizing configuration!"
	echo
fi
# endregion - Sync firmware config

# region - Sync systemd service
if [ "$SKIP_SERVICE" != "true" ]; then
	# Service directory
	remote_services_path=/etc/systemd/system

	# Check if a service is already installed
	if ! remote_service_name=$(ssh_command "sudo cat '$REMOTE_PATH_SERVICE_NOTE'" 2>/dev/null); then
		remote_service_name="$SERVICE_NAME"
	fi

	remote_service_path="$remote_services_path/$remote_service_name.service"
	new_service_path="$remote_services_path/$SERVICE_NAME.service"

	# region - Synchronize
	# Does the service file exist?
	if ssh_command "test -e '$remote_service_path'"; then
		# Has the service name been updated?
		if [ "$remote_service_name" != "$SERVICE_NAME" ]; then
			# The service name has changed, disable and remove the previous service
			info "Removing outdated service '$remote_service_name'..."
			ssh_command "sudo systemctl stop '$remote_service_name.service'"
			ssh_command "sudo systemctl disable '$remote_service_name.service'"
			ssh_command "sudo rm --force '$remote_service_path'"
			echo
			info "Creating service '$SERVICE_NAME'..."
		else
			# Service is the same
			if [ "$(ssh_command "sudo cat '$remote_service_path'")" = "$(cat "$PATH_SERVICE_FILE")" ]; then
				# Service contents are the same, no update necessary
				skip_service_update=true
			else
				# Service contents have changed
				info "Updating service '$remote_service_name'..."
				ssh_command "sudo systemctl stop '$remote_service_name'" 2>/dev/null
			fi
		fi
	else
		# Service has not yet been created
		info "Creating service '$remote_service_name'..."
	fi

	# Create or update service file
	if [ "$skip_service_update" != "true" ]; then
		ssh_command "echo '$(cat "$PATH_SERVICE_FILE")' | sudo tee '$new_service_path'"
		echo

		# Reload services
		ssh_command "sudo systemctl daemon-reload"

		# Enable service
		info "Enabling service..."
		ssh_command "sudo systemctl enable '$new_service_path'"
		echo

		info "Service has been installed!"
		echo
	fi
	# endregion - Synchronize

	# Completed
	info "Done synchronizing service!"
	echo

	# Record changes to remote
	ssh_command "sudo mkdir --parents $(dirname "$REMOTE_PATH_SERVICE_NOTE")" >/dev/null
	ssh_command "echo '$SERVICE_NAME' | sort | sudo tee '$REMOTE_PATH_SERVICE_NOTE'" >/dev/null
fi
# endregion - Sync systemd service

# region - Sync file paths
if [ "$SKIP_FILESYNC" != "true" ]; then
	# Split sync pairs with a unique character
	sync_pairs=$(read_without_comments "$PATH_SYNCPATHS_FILE" | grep --only-matching --extended-regexp '[^"]*"[^"A-Za-z0-9_./]*"[^"]*' | sed --null-data 's/\n/\*/')

	if [ -n "$sync_pairs" ]; then
		info "Synchronizing files between host and target paths..."

		# Set syncignore variable if file exists
		if [ -e "$PATH_SYNCIGNORE_FILE" ]; then
			syncignore_path="$PATH_SYNCIGNORE_FILE"
		else
			syncignore_path=
		fi

		# region - Synchronize
		# Separate loop with the unique character
		prev_ifs="$IFS"
		IFS="*"
		for pair in $sync_pairs; do
			# Separate sync paths from pair
			source_path="${pair%%\"*}"
			remote_path="${pair##*\"}"

			# Prepend filesync path to source if root is not specified
			case $source_path in
			"/"*) ;;
			*) source_path="$FILESYNC_PATH/$source_path" ;;
			esac

			echo "  - $source_path => $remote_path"
			rsync \
				--archive \
				--chmod="$SYNC_CHMOD" \
				--chown="$SYNC_CHOWN:$SYNC_CHOWN" \
				--delete \
				--exclude-from="$syncignore_path" \
				--out-format="    [%o] %n%L" \
				--rsh="ssh" \
				--rsync-path="sudo rsync" \
				--super \
				"$source_path" "$SSH_USER@$SSH_SERVER:$remote_path"
			echo
		done
		# Restore previous separator
		IFS="$prev_ifs"
		# endregion - Synchronize
	fi

	info "Done syncrhonizing filepaths!"
	echo
fi
# endregion - Sync file paths
# endregion - Synchronization

# region - Reboot device
if [ "$SKIP_REBOOT_DEVICE" != "true" ] && [ "$REBOOT_DEVICE" = "true" ]; then
	# Temporarily disable the service to avoid running it on reboot
	if [ "$SKIP_SERVICE" != "true" ]; then
		is_enabled=$(ssh_command "systemctl is-enabled '$SERVICE_NAME.service'")
		if [ "$is_enabled" = "enabled" ]; then
			info "Disabling service '$SERVICE_NAME' for reboot..."
			ssh_command "sudo systemctl disable '$SERVICE_NAME.service'"
			echo
		fi
	else
		is_enabled=
	fi

	info "Rebooting the remote device!"
	ssh_command "sudo reboot now"
	echo

	# Loop until successful connection or time limit is reached
	info "Waiting to reconnect..."
	time_start=$(date +%s)
	time_limit=$((SSH_RESTART_TIMEOUT + time_start))

	# Wait for some amount of time before attempting to reconnect
	sleep "$SSH_RESTART_PAUSE"
	while true; do
		if ssh_command true 2>/dev/null; then
			echo "  - Reconnected after $(($(date +%s) - time_start)) seconds"
			echo

			if [ "$is_enabled" = "enabled" ]; then
				info "Re-enabling service '$SERVICE_NAME'..."
				ssh_command "sudo systemctl enable '$SERVICE_NAME.service'"
				echo
			fi
			break
		elif [ "$(date +%s)" -gt "$time_limit" ]; then
			warn "  - Timed out while waiting to reconnect! ($SSH_RESTART_TIMEOUT second limit)"
			echo
			break
		fi
	done
fi
# endregion - Reboot device

# region - Start service
if [ "$SKIP_SERVICE" != "true" ] && [ "$SKIP_SERVICE_START_AFTER_SCRIPT" != "true" ]; then
	is_active=$(ssh_command "systemctl is-active '$SERVICE_NAME.service'")
	# Start if the service is active
	if [ "$is_active" = "inactive" ]; then
		info "Starting service '$SERVICE_NAME'..."
		ssh_command "sudo systemctl start '$SERVICE_NAME.service'"
		echo
	fi
fi
# endregion - Start service

# Completed
info "Synchronizations are complete!"
echo

stop 0
