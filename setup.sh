function backup_file_name() { 
	echo $1"_bak_"`date "+%Y%m%d_%H%M%S"` 
} 

function backup_file() {
	bak_file=`backup_file_name $1`
	sudo cp $dest_file $bak_file
	ls $(dirname $dest_file)
} 

function diff_file() { 
	echo "" 
	diff $diff_switch $1 $2 
	echo "" 
} 

function locale_settings() {
	# Change Keyboard Layout
	echo ">> Changing Keyboard Layout..."
	sudo sed -i 's/^XKBLAYOUT=".*\?"/XKBLAYOUT="us"/g' /etc/default/keyboard

	# Modify locale.gen file
	echo ">> Changing Locales..."
	sudo sed -i 's/^# en_US/en_US/g' /etc/locale.gen
	sudo sed -i 's/^en_GB/# en_GB/g' /etc/locale.gen

	# Generate Locales
	echo ">> Generating Locales..."
	sudo locale-gen

	# Change Locale
	echo ">> Updating Locales..."
	sudo update-locale LANG=en_US.UTF-8
	sudo update-locale LANGUAGE=en_US.UTF-8
	. /etc/default/locale
}

function system_software() {
	export DEBIAN_FRONTEND=noninteractive && \
	sudo apt-get update && \
	sudo apt full-upgrade -y && \
	sudo apt autoremove -y && \
	sudo apt clean -y && \
	sudo apt autoclean -y
}

function system_settings() {
	#
	# Disable SSH password check
	#
	echo ">> Disabling SSH password check"
	dest_file=/etc/pam.d/common-session
	backup_file $dest_file
	sudo sed -i 's/.*pam_chksshpwd.so/#&/g' $dest_file
	diff_file $bak_file $dest_file 

	#
	# Bluetooth
	# Configure LED
	#
	echo "disabling Bluetooth"
	dest_file=/boot/firmware/config.txt
	backup_file $dest_file

	echo "changing LED for heartbeat"
	if ! grep -q "dtparam=pwr_led_trigger=heartbeat" $dest_file ; then 
		cat <<-EOL | sudo tee -a $dest_file
		[all]
		dtoverlay=disable-bt
		dtparam=pwr_led_trigger=heartbeat
		EOL
	fi
}

function remove_unused_libs() {
	echo "removing unused libraries"
	sudo apt-get autoremove -y python3-pygame man manpages galculator unattended-upgrades
}

function remove_swap_file() {
	#
	# Remove Swap File
	# to check Swap file run 'free -h'
	echo "removing swap file"
	sudo swapoff --all && \
	sudo apt purge -y --auto-remove dphys-swapfile && \
	sudo rm -fr /var/swap
}

function temp_folder_settings() {
	#
	# Mount tmp folder to RAM disk
	# to check run 'df -h'
	#
	dest_file=/etc/fstab
	bak_file=`backup_file_name $dest_file`
	sudo cp $dest_file $bak_file
	add_str1="tmpfs /tmp tmpfs defaults,size=32m,noatime,mode=1777 0 0"
	add_str2="tmpfs /var/tmp tmpfs defaults,size=16m,noatime,mode=1777 0 0"
	add_str3="tmpfs /var/log tmpfs defaults,size=32m,noatime,mode=0755 0 0" 

	if ! grep -q "$add_str1" $dest_file ; then 
	cat <<-EOL | sudo tee -a $dest_file 
		$add_str1 
		$add_str2 
		$add_str3 
		EOL
	fi
}

function install_docker() {
	# Install Docker
	docker=false
	if [ -x "$(command -v docker)" ]; then
		echo "Docker is already installed."
		docker=true
	fi

	if ! $docker; then
		echo ">>f Installing Docker..."

		error_msg="Docker failed to install."
		curl -fsSL https://get.docker.com -o get-docker.sh

		while [[ $(sudo sh get-docker.sh >/dev/null 2>&1 || echo "${error_msg}") == "$error_msg" ]]; do
			sudo rm -rf /var/lib/dpkg/info/docker-ce*
			sleep 1
		done

		# Docker Permissions
		echo ">> Setting Docker Permissions..."
		sudo gpasswd -a $USER docker # takes effect on logout/reboot - need sudo for now
	fi

	# Clean that file up after
	if [ -e $SCRIPT_DIR/get-docker.sh ]; then
		sudo rm -rf $SCRIPT_DIR/get-docker.sh
	fi
}



function autostart_settings() {
	# Enable Autostart for labwc
	echo "#############################################"
	echo "enabling autostart"
	echo "#############################################"
	sudo cp $SCRIPT_DIR/imx500-demo.service /etc/systemd/system/imx500-demo.service
	sudo systemctl enable imx500-demo.service

	if [ ! -d ~/.config/labwc ]; then
		mkdir ~/.config/labwc
	fi
	touch ~/.config/labwc/autostart
	echo "[autostart]" >> ~/.config/labwc/autostart
	echo "bash $SCRIPT_DIR/startup.sh &" >> ~/.config/labwc/autostart

	# for wayland
	# touch ~/.config/wayfire.ini
	# echo "[autostart]" >>  ~/.config/wayfire.ini
	# echo "gaze-demo = /home/$USER/data/startup.sh" >> ~/.config/wayland.ini

	# remove files after reboot
	# sudo rm -rf /tmp/*
	# sudo rm -rf /var/tmp/*
	# sudo rm -rf /var/log/*
}

SCRIPT_DIR=$(cd $(dirname $0); pwd)

locale_settings
system_software
system_settings
remove_unused_libs
install_docker 
# remove_swap_file
# temp_folder_settings
# autostart_settings

# sudo reboot now

