#!/bin/bash
SERVER_JAR="pufferfish-paperclip-1.19-R0.1-SNAPSHOT-reobf.jar"
SERVER_ARGS_PRE="-Xms4G -Xmx4G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true --add-modules=jdk.incubator.vector"
SERVER_ARGS_POST="nogui"
SERVER_FOLDER=~/cvmmc_server
GIT_AUTOUPDATE=false
GIT_PROTOCOL="https"
GIT_DOMAIN="github.com"
GIT_USER="cvmmc"
GIT_USER_REPO="server"
GIT_EMAIL="107626913+cvmmc@users.noreply.github.com"
GIT_AUTH_TOKEN=""

check_distro() {
	if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
	elif command -v lsb_release &> /dev/null; then
		OS=$(lsb_release -si)
	elif [ -f /etc/lsb-release ]; then
		. /etc/lsb-release
		OS=$DISTRIB_ID
	else
		echo "Unable to identify Linux distribution, the script will likely fail!"
	fi
}

install_deps() {
	if [ ! -f ~/.skip_deps ]; then
		echo "Installing dependencies"
		check_distro
		if [ "${OS,,}" == "debian" ] || [ "${OS,,}" == "ubuntu" || [ "${OS,,}" == "devuan" ]; then
			apt install openjdk-17-jre git -y
		elif [ "${OS,,}" == "almalinux" ]; then
			dnf install java-17-openjdk git -y
		elif [ "${OS,,}" == "alpine" ]; then
			apk add openjdk17 git
		elif [ "${OS,,}" == "fedora" ] || [ "${OS,,}" == "centos" ]; then
			yum install java-17-openjdk git -y
		elif [ "${OS,,}" == "arch" ]; then
			pacman -S jre17-openjdk git --noconf
		elif [ "${OS,,}" == "artix" ]; then
			pacman -S jre-openjdk git --noconf
		else
			echo "Distribution not supported, please report this."
			echo 'Make sure to include output of "cat /etc/os-release" and "lsb_release -a"'
			echo "Manually install the following and restart the script: git, openjdk 17"
			touch ~/.skip_deps
			exit 1
		fi
		touch ~/.skip_deps
	fi
}

setup_git() {
	if [ ! -d $SERVER_FOLDER ]; then
		echo "Downloading files"
		git clone $GIT_PROTOCOL://$GIT_DOMAIN/$GIT_USER/$GIT_USER_REPO $SERVER_FOLDER
		cd $SERVER_FOLDER
		if [ "$GIT_AUTOUPDATE" = true ]; then
			echo "Configuring git"
			git config user.name $GIT_USER
			git config user.email $GIT_EMAIL
			git remote set-url origin $GIT_PROTOCOL://$GIT_USER:$GIT_AUTH_TOKEN@$GIT_DOMAIN/$GIT_USER/$GIT_USER_REPO.git
		fi
	else
		cd $SERVER_FOLDER
		if [ "$GIT_AUTOUPDATE" = true ]; then
			echo "Configuring git"
			git config user.name $GIT_USER
			git config user.email $GIT_EMAIL
		fi
		echo "Updating existing files"
		git pull
	fi
}

main() {
	while true
	do
		echo "Starting server"
		java $SERVER_ARGS_PRE -jar $SERVER_JAR $SERVER_ARGS_POST
		if [ "$GIT_AUTOUPDATE" = true ]; then
			echo "Updating files"
			git commit -am "Update server state - $(date +\"%Y-%m-%dT%H:%M:%S%z\")"
			git push
		fi
		echo "Restarting server in 5 seconds"
		sleep 5
	done
}

if [ "$EUID" -ne 0 ]; then
	echo "This script must be ran as root."
	exit 1
fi

if [ "$GIT_AUTOUPDATE" = true ]; then
	if [ -z "$GIT_AUTH_TOKEN" ]; then
		echo "To use auto update, GIT_AUTH_TOKEN must be set."
		exit 1
	fi
fi

install_deps
setup_git
main
