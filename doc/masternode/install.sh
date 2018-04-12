sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y
sudo apt-get install nano htop git -y
sudo apt-get install build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils software-properties-common libgmp3-dev  -y
sudo apt-get install libboost-all-dev -y
sudo add-apt-repository ppa:bitcoin/bitcoin -y
sudo apt-get update -y
sudo apt-get install libdb4.8-dev libdb4.8++-dev -y
sudo apt-get install libminiupnpc-dev -y
mkdir $HOME/tempABS
chmod -R 777 $HOME/tempABS
sudo git clone https://github.com/absolute-community/absolute.git $HOME/tempABS
cd $HOME/tempABS
chmod 777 autogen.sh
./autogen.sh
./configure
chmod +x share/genbuild.sh
sudo make
sudo make install
cd $HOME
mkdir $HOME/Absolute
mkdir $HOME/.absolutecore
cp $HOME/tempABS/src/absoluted $HOME/Absolute
cp $HOME/tempABS/src/absolute-cli $HOME/Absolute
chmod -R 777 $HOME/Absolute
chmod -R 777 $HOME/.absolutecore
sudo apt-get install -y pwgen
EXIP=`wget -qO- eth0.me`
PASS=`pwgen -1 20 -n`
printf "rpcuser=user\nrpcpassword=$PASS\nrpcport=18889\ndaemon=1\nlisten=1\nserver=1\nmaxconnections=256\nrpcallowip=127.0.0.1\nexternalip=$EXIP:18888\n" > /$HOME/.absolutecore/absolute.conf
