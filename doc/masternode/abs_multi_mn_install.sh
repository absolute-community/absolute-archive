#!/bin/bash

# set script vars
abs_user="ABS_mn_user"
abs_port=18888
rpc_port=59001
root_path="$(pwd)"
abscore_root_path="$root_path/.absolutecore"
wallet_path="$root_path/Absolute"

# when new wallet release is published the next two lines needs to be updated
wallet_ver="v12.2.4"
wallet_file="absolute_12.2.4_linux.tar.gz"

wallet_url="https://github.com/absolute-community/absolute/releases/download/$wallet_ver"

function printError {
	printf "\33[0;31m%s\033[0m\n" "$1"
}

function printSuccess {
	printf "\33[0;32m%s\033[0m\n" "$1"
}

function printWarning {
	printf "\33[0;33m%s\033[0m\n" "$1"
}

function extractDaemon
{
	echo "Extracting..."
	tar -zxvf "$wallet_file" && mv "$wallet_dir_name" "$wallet_path"
	if [ -f "/usr/local/bin/absolute-cli" ]; then
		rm /usr/local/bin/absolute-cli
	fi
	if [ -f "/usr/local/bin/absoluted" ]; then
		rm /usr/local/bin/absoluted
	fi
	ln -s "$wallet_path"/absolute-cli /usr/local/bin/absolute-cli
	ln -s "$wallet_path"/absoluted /usr/local/bin/absoluted
	rm "$wallet_file"
	printSuccess "...done!"
}

function setupNode
{
	mkdir -p "$abscore_path" && touch "$abs_conf_file"

	{
		printf "\n#--- basic configuration --- \nrpcuser=$abs_user\nrpcpassword=$rpc_pass\nrpcport=$rpc_port\nbind=$mn_ip:$abs_port\nrpcbind=127.0.0.1:$rpc_port\nexternalip=$mn_ip:$abs_port\ndaemon=1\nlisten=1\nserver=1\nmaxconnections=256\nrpcallowip=127.0.0.1\n"
		printf "\n#--- masternode ---\nmasternode=1\nmasternodeprivkey=$privkey\n"
		printf "\n#--- new nodes ---\naddnode=45.77.138.219:18888\naddnode=192.3.134.140:18888\naddnode=107.174.102.130:18888\naddnode=107.173.70.103:18888\naddnode=107.173.70.105:18888\naddnode=107.174.142.252:18888\naddnode=54.93.66.231:18888\naddnode=66.23.197.121:18888\n"			
		printf "addnode=45.63.99.215:18888\naddnode=45.77.134.248:18888\naddnode=140.82.46.194:18888\naddnode=139.99.96.203:18888\naddnode=139.99.40.157:18888\naddnode=139.99.41.35:18888\naddnode=139.99.41.198:18888\naddnode=139.99.44.0:18888\n"
	} > "$abs_conf_file"
}

function setupSentinel 
{
	echo "*** Installing sentinel for masternode $((count+1)) ***"
	cd "$abscore_path" || return
	git clone https://github.com/absolute-community/sentinel.git --q
	cd "$sentinel_path" && virtualenv ./venv && ./venv/bin/pip install -r requirements.txt
	printSuccess "...done!"

	echo
	echo "*** Configuring sentinel ***"
	if grep -q -x "absolute_conf=$abs_conf_file" "$sentinel_conf_file" ; then
		printWarning "absolute.conf path already set in sentinel.conf!"
	else
		printf "absolute_conf=%s\n" "$abs_conf_file" >> "$sentinel_conf_file"
		printSuccess "...done!"
	fi
}

function setupCrontab
{
	echo
	echo "*** Configuring crontab ***"
	update-alternatives --set editor /bin/nano

	echo  "Set ABS daemon to run at vps reboot..."
	if crontab -l 2>/dev/null | grep -q -x "@reboot cd $wallet_path && ./absoluted -daemon -datadir=$abscore_path" >/dev/null ; then
		printWarning "ABS daemon already set to run when vps reboot!"
	else
		(crontab -l 2>/dev/null; echo "@reboot cd $wallet_path && ./absoluted -daemon -datadir=$abscore_path") | crontab -
		printSuccess "...done!"
	fi

	echo
	echo  "Set sentinel to run at every minute..."
	if crontab -l 2>/dev/null | grep -q -x "\* \* \* \* \* cd $sentinel_path && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" >/dev/null ; then
		printWarning "Sentinel run at every minute already set!"
	else
		(crontab -l 2>/dev/null; echo "* * * * * cd $sentinel_path && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1") | crontab -
		printSuccess "...done!"
	fi
}


# entry point
clear

printf "\n%s\n" "===== ABS multinode vps install ====="
printf "\n%s" "Installed OS: $(cut -d':' -f2 <<< "$(lsb_release -d)")"
printf "\n%s\n" "We are now in $(pwd) directory"
printf "ABS nodes will be installed in curent path!\n\n"

# check ubuntu version - we need 16.04
if [ -r /etc/os-release ]; then
	. /etc/os-release
	if [ "${VERSION_ID}" != "16.04" ] ; then
		echo "Script needs Ubuntu 16.04, exiting!"
		echo
		exit 1
	fi
else
	echo "Operating system is not Ubuntu 16.04, exiting!"
	echo
	exit 1
fi

# check syntax
if [ $# == 0 ]; then
	printError "Masternodes privkeys missing!!!"
	printWarning "Usage $0 mn_privkey1 mn_privkey2 mn_privkey3 ..."
	printWarning "This script will configure a number of nodes as many as the number of privatekeys provided as arguments."
	printWarning "The number of masternode privatekeys must not be greater then the number of ips your vps has."
	printWarning "Make sure you have at least 512Mb of RAM for each instance on your vps!"
	echo
	exit 0
fi

# get the number of ips
ips_no=$(ip -4 addr show | grep 'inet ' | awk '{print $2}' | cut -f1 -d'/' | grep -v '^127\.\|^10\.\|^172\.1[6-9]\.\|^172\.2[0-9]\.\|^172\.3[0-2]\.\|^192\.168\.' -c)
printSuccess "We found $ips_no ip address(es)!"

if [ $# -gt "$ips_no" ]; then
	printWarning "Number of privkeys is greater then number of ip addresses."
	printWarning "Check number of privkeys provided and try again."
	echo
	exit 0
fi

# let's do this
echo
printSuccess "You provided $# privkey(s)!"
echo
printSuccess "We will install $# masternode(s)!"
echo

echo "*** Updating system ***"
apt-get update -y -qq
apt-get upgrade -y -qq
printSuccess "...done!"

echo
echo "*** Install ABS daemon dependencies ***"
apt-get install nano mc dbus ufw fail2ban htop git pwgen python virtualenv python-virtualenv software-properties-common -y -qq
apt-get install libboost-system1.58.0 libboost-filesystem1.58.0 libboost-program-options1.58.0 libboost-thread1.58.0 libboost-chrono1.58.0 -y -qq
apt-get install libzmq5 libevent-pthreads-2.0-5 libminiupnpc10 libevent-2.0-5 -y -qq
add-apt-repository ppa:bitcoin/bitcoin -y
apt-get update -y -qq
apt-get upgrade -y -qq
apt-get install libdb4.8-dev libdb4.8++-dev -y -qq
printSuccess "...done!"

echo
echo "*** Download ABS daemon binaries ***"
if [ ! -f "$wallet_file" ]; then
	echo "Downloading..."
	wget "$wallet_url/$wallet_file" -q && printSuccess "...done!"
else
	printWarning "File already downloaded!"
fi

wallet_dir_name=$(tar -tzf $wallet_file | head -1 | cut -f1 -d"/")

if [ -z "$wallet_dir_name" ]; then
	printError "Failed - downloading ABS daemon binaries."
	exit 1
fi

echo
echo "*** Extract ABS daemon binaries ***"
if [ -d "$wallet_path" ]; then
	printWarning "Daemon directory already exist!"
	printWarning "Checking for running ABS daemon!"
	if [ -z "$(pgrep "absoluted")" ]; then
		printWarning "Running daemon not found!"
	else
		printError "Running daemon found! Killing it..."
		kill -9 "$(pgrep "absoluted")"
		sleep 10
		printSuccess "...done!"
	fi
	printWarning "Remove old daemon directory..."
	rm -r "$wallet_path"
	printSuccess "...done!"
	echo
fi
extractDaemon

# get the ip list
echo
echo "*** Get available ips ***"
declare -a ip_list
mapfile -t ip_list < <(ip -4 addr show | grep 'inet ' | awk '{print $2}' | cut -f1 -d'/' | grep -v '^127\.\|^10\.\|^172\.1[6-9]\.\|^172\.2[0-9]\.\|^172\.3[0-2]\.\|^192\.168\.')
echo "${ip_list[*]}"
printSuccess "...done!"

# find open rpc ports
echo
echo "*** Find necessary open rpc ports ***"
count=0
declare -a rpc_ports
while [ "$count" -lt "$#" ]; do
	if [ 0 -eq "$(netstat -tunlep | grep $rpc_port -c)" ]; then
		echo "Found RPC port $rpc_port open"
		rpc_ports["$count"]="$rpc_port"
		((++count))
	fi
	((++rpc_port))
done
printSuccess "...done!"

#configure folders, conf files, sentinel and crontab
echo
echo "*** Creating masternode folders and configuration ***"
count=0
for privkey in "${@}"; do
	rpc_pass=$(pwgen -1 20 -n)
	rpc_port="${rpc_ports[$count]}"
	mn_ip="${ip_list[$count]}"

	abscore_path="$abscore_root_path$((count+1))"
	abs_conf_file="$abscore_path/absolute.conf"

	sentinel_path="$abscore_path/sentinel"
	sentinel_conf_file="$sentinel_path/sentinel.conf"

	printSuccess "Configure ABS masternode $((count+1)) in $abscore_path with following settings:"
	printSuccess "  - ip: $mn_ip:$abs_port"
	printSuccess "  - private key: $privkey"

	echo
	if [ ! -d "$abscore_path" ]; then

		setupNode

		setupSentinel

		setupCrontab

	else
		printError "Configuration directory found! Remove $abscore_path directory or configure daemon manually!"
		printError "Failed - masternode configuration."
		echo
		exit 1
	fi
	echo
	cd "$root_path"
	printSuccess "Masternode $((count+1)) configuration ...done!"
	((++count))
	echo
done

echo "*** Following nodes were set up ***"
count=1
for privkey in "${@}"; do
	mn_ip="${ip_list[$count-1]}"
	printSuccess "Node $count was set up on ip $mn_ip:$abs_port with private key $privkey"
	((++count))
done

echo
echo "That's it! Everything is done! You just have to start the masternode(s) with next command(s):"
count=0
while [ "$count" -lt "$#" ]; do
	abscore_path="$abscore_root_path$((count+1))"
	printSuccess "absoluted -daemon -datadir=$abscore_path"
	((++count))
done
echo
