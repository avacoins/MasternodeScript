#!/bin/bash
# AVCCoin Masternode Setup Script V1 for Ubuntu 16.04 LTS
#
# Script will attempt to autodetect primary public IP address
# and generate masternode private key unless specified in command line
#
# Usage:
# bash AVC.autoinstall.sh
#

#Color codes
RED='\033[0;91m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#TCP port
PORT=8220
RPC=8219

#Clear keyboard input buffer
function clear_stdin { while read -r -t 0; do read -r; done; }

#Delay script execution for N seconds
function delay { echo -e "${GREEN}Sleep for $1 seconds...${NC}"; sleep "$1"; }

#Stop daemon if it's already running
function stop_daemon {
    if pgrep -x 'AVC' > /dev/null; then
        echo -e "${YELLOW}Attempting to stop AVC${NC}"
        AVC-cli stop
        sleep 30
        if pgrep -x 'AVC' > /dev/null; then
            echo -e "${RED}AVC daemon is still running!${NC} \a"
            echo -e "${RED}Attempting to kill...${NC}"
            sudo pkill -9 AVC
            sleep 30
            if pgrep -x 'AVC' > /dev/null; then
                echo -e "${RED}Can't stop AVC! Reboot and try again...${NC} \a"
                exit 2
            fi
        fi
    fi
}
#Function detect_ubuntu

 if [[ $(lsb_release -d) == *16.04* ]]; then
   UBUNTU_VERSION=16
else
   echo -e "${RED}You are not running Ubuntu 16.04, Installation is cancelled.${NC}"
   exit 1

fi

#Process command line parameters
genkey=$1
clear

echo -e "${GREEN} ------- AVC MASTERNODE INSTALLER v1.0.0--------+
 |                                                  |
 |                                                  |::
 |       The installation will install and run      |::
 |        the masternode under a user AVCd.         |::
 |                                                  |::
 |        This version of installer will setup      |::
 |           fail2ban and ufw for your safety.      |::
 |                                                  |::
 +------------------------------------------------+::
   ::::::::::::::::::::::::::::::::::::::::::::::::::S${NC}"
echo "Do you want me to generate a masternode private key for you?[y/n]"
read DOSETUP

if [[ $DOSETUP =~ "n" ]] ; then
          read -e -p "Enter your private key:" genkey;
              read -e -p "Confirm your private key: " genkey2;
    fi

#Confirming match
  if [ $genkey = $genkey2 ]; then
     echo -e "${GREEN}MATCH! ${NC} \a" 
else 
     echo -e "${RED} Error: Private keys do not match. Try again or let me generate one for you...${NC} \a";exit 1
fi
sleep .5
clear

# Determine primary public IP address
dpkg -s dnsutils 2>/dev/null >/dev/null || sudo apt-get -y install dnsutils
publicip=$(dig +short myip.opendns.com @resolver1.opendns.com)

if [ -n "$publicip" ]; then
    echo -e "${YELLOW}IP Address detected:" $publicip ${NC}
else
    echo -e "${RED}ERROR: Public IP Address was not detected!${NC} \a"
    clear_stdin
    read -e -p "Enter VPS Public IP Address: " publicip
    if [ -z "$publicip" ]; then
        echo -e "${RED}ERROR: Public IP Address must be provided. Try again...${NC} \a"
        exit 1
    fi
fi
if [ -d "/var/lib/fail2ban/" ]; 
then
    echo -e "${GREEN}Packages already installed...${NC}"
else
    echo -e "${GREEN}Updating system and installing required packages...${NC}"

sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade
sudo apt-get -y autoremove
sudo apt-get -y install wget nano htop jq
sudo apt-get install unzip
sudo apt install unzip
sudo apt -y install software-properties-common
sudo apt-get -y update
   fi

#Generating Random Password for  JSON RPC
rpcuser=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
rpcpassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

#Create 2GB swap file
if grep -q "SwapTotal" /proc/meminfo; then
    echo -e "${GREEN}Skipping disk swap configuration...${NC} \n"
else
    echo -e "${YELLOW}Creating 2GB disk swap file. \nThis may take a few minutes!${NC} \a"
    touch /var/swap.img
    chmod 600 swap.img
    dd if=/dev/zero of=/var/swap.img bs=1024k count=2000
    mkswap /var/swap.img 2> /dev/null
    swapon /var/swap.img 2> /dev/null
    if [ $? -eq 0 ]; then
        echo '/var/swap.img none swap sw 0 0' >> /etc/fstab
        echo -e "${GREEN}Swap was created successfully!${NC} \n"
    else
        echo -e "${RED}Operation not permitted! Optional swap was not created.${NC} \a"
        rm /var/swap.img
    fi
fi
 
#Installing Daemon
cd ~
rm -rf /usr/local/bin/AVC*
wget https://github.com/avacoins/AVCCoin/releases/download/v1.1/AVC-Daemon_Ubuntu_16.04.tar.gz
tar -xzvf AVC-Daemon_Ubuntu_16.04.tar.gz
sudo chmod -R 755 AVC-cli
sudo chmod -R 755 AVCd
cp -p -r AVCd /usr/local/bin
cp -p -r AVC-cli /usr/local/bin

 AVC-cli stop
 sleep 5
 #Create datadir
 if [ ! -f ~/.AVC/AVC.conf ]; then 
 	sudo mkdir ~/.AVC
 fi

cd ~
clear
echo -e "${YELLOW}Creating AVC.conf...${NC}"

# If genkey was not supplied in command line, we will generate private key on the fly
if [ -z $genkey ]; then
    cat <<EOF > ~/.AVC/AVC.conf
rpcuser=$rpcuser
rpcpassword=$rpcpassword
EOF

    sudo chmod 755 -R ~/.AVC/AVC.conf

    #Starting daemon first time just to generate masternode private key
    AVCd -daemon
sleep 7
while true;do
    echo -e "${YELLOW}Generating masternode private key...${NC}"
    genkey=$(AVC-cli createmasternodekey)
    if [ "$genkey" ]; then
        break
    fi
sleep 7
done
    fi
    
    #Stopping daemon to create AVC.conf
    AVC-cli stop
    sleep 5
cd ~/.AVC/ && rm -rf blocks chainstate sporks zerocoin
cd ~/.AVC/ && wget http://167.172.98.30/bootstrap.tar.gz
cd ~/.AVC/ && tar -xzvf bootstrap.tar.gz
sudo rm -rf ~/.AVC/bootstrap.tar.gz
# Create AVC.conf
cat <<EOF > ~/.AVC/AVC.conf
rpcuser=$rpcuser
rpcpassword=$rpcpassword
rpcallowip=127.0.0.1
rpcport=$RPC
port=$PORT
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=256
masternode=1
externalip=$publicip
bind=$publicip
masternodeaddr=$publicip
masternodeprivkey=$genkey
addnode=178.128.110.122
addnode=167.71.101.46
addnode=138.197.200.243
addnode=188.166.59.127
addnode=178.62.94.160
addnode=167.172.98.30
addnode=138.197.160.48
addnode=159.65.154.96
 
EOF
    AVCd -daemon
#Finally, starting daemon with new AVC.conf
printf '#!/bin/bash\nif [ ! -f "~/.AVC/AVC.pid" ]; then /usr/local/bin/AVCd -daemon ; fi' > /root/AVCauto.sh
chmod -R 755 AVCauto.sh
#Setting auto start cron job for AVC
if ! crontab -l | grep "AVCauto.sh"; then
    (crontab -l ; echo "*/5 * * * * /root/AVCauto.sh")| crontab -
fi

echo -e "========================================================================
${GREEN}Masternode setup is complete!${NC}
========================================================================
Masternode was installed with VPS IP Address: ${GREEN}$publicip${NC}
Masternode Private Key: ${GREEN}$genkey${NC}
Now you can add the following string to the masternode.conf file 
======================================================================== \a"
echo -e "${GREEN}AVCd_mn1 $publicip:$PORT $genkey TxId TxIdx${NC}"
echo -e "========================================================================
Use your mouse to copy the whole string above into the clipboard by
tripple-click + single-click (Dont use Ctrl-C) and then paste it 
into your ${GREEN}masternode.conf${NC} file and replace:
    ${GREEN}AVCd_mn1${NC} - with your desired masternode name (alias)
    ${GREEN}TxId${NC} - with Transaction Id from getmasternodeoutputs
    ${GREEN}TxIdx${NC} - with Transaction Index (0 or 1)
     Remember to save the masternode.conf and restart the wallet!
To introduce your new masternode to the AVC network, you need to
issue a masternode start command from your wallet, which proves that
the collateral for this node is secured."

clear_stdin
read -p "*** Press any key to continue ***" -n1 -s

echo -e "Wait for the node wallet on this VPS to sync with the other nodes
on the network. Eventually the 'Is Synced' status will change
to 'true', which will indicate a comlete sync, although it may take
from several minutes to several hours depending on the network state.
Your initial Masternode Status may read:
    ${GREEN}Node just started, not yet activated${NC} or
    ${GREEN}Node  is not in masternode list${NC}, which is normal and expected.
"
clear_stdin
read -p "*** Press any key to continue ***" -n1 -s

echo -e "
${GREEN}...scroll up to see previous screens...${NC}
Here are some useful commands and tools for masternode troubleshooting:
========================================================================
To view masternode configuration produced by this script in AVC.conf:
${GREEN}cat ~/.AVC/AVC.conf${NC}
Here is your AVC.conf generated by this script:
-------------------------------------------------${GREEN}"
echo -e "${GREEN}AVCd_mn1 $publicip:$PORT $genkey TxId TxIdx${NC}"
cat ~/.AVC/AVC.conf
echo -e "${NC}-------------------------------------------------
NOTE: To edit AVC.conf, first stop the AVC daemon,
then edit the AVC.conf file and save it in nano: (Ctrl-X + Y + Enter),
then start the AVC daemon back up:
to stop:              ${GREEN}AVC-cli stop${NC}
to start:             ${GREEN}AVCd${NC}
to edit:              ${GREEN}nano ~/.AVC/AVC.conf${NC}
to check mn status:   ${GREEN}AVC-cli getmasternodestatus${NC}
========================================================================
To monitor system resource utilization and running processes:
                   ${GREEN}htop${NC}
========================================================================
"