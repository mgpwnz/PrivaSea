#!/bin/bash
while true
do

# Menu

PS3='Select an action: '
options=("Pre Install" "Create Account" "Install worker" "Logs" "Uninstall" "Exit")
select opt in "${options[@]}"
               do
                   case $opt in                          

"Pre Install")
#docker + compose
touch $HOME/.bash_profile
	cd $HOME
	if ! docker --version; then
		sudo apt update
		sudo apt upgrade -y
		sudo apt install curl apt-transport-https ca-certificates gnupg lsb-release -y
		. /etc/*-release
		wget -qO- "https://download.docker.com/linux/${DISTRIB_ID,,}/gpg" | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
		echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
		sudo apt update
		sudo apt install docker-ce docker-ce-cli containerd.io -y
		docker_version=`apt-cache madison docker-ce | grep -oPm1 "(?<=docker-ce \| )([^_]+)(?= \| https)"`
		sudo apt install docker-ce="$docker_version" docker-ce-cli="$docker_version" containerd.io -y
	fi
	if ! docker compose version; then
		sudo apt update
		sudo apt upgrade -y
		sudo apt install wget jq -y
		local docker_compose_version=`wget -qO- https://api.github.com/repos/docker/compose/releases/latest | jq -r ".tag_name"`
		sudo wget -O /usr/bin/docker-compose "https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-`uname -s`-`uname -m`"
		sudo chmod +x /usr/bin/docker-compose
		. $HOME/.bash_profile
	fi

break
;;

"Create Account")
# Pull
docker pull privasea/node-client:v0.0.1
sudo mkdir -p $HOME/PrivateSea/keys
cd $HOME/PrivateSea
docker run -it -v $HOME/PrivateSea/keys:/app/keys privasea/node-client:v0.0.1 account

break
;;
"Install & RUN")
KEY_PATH=$(find $HOME/PrivateSea/keys/ -type f | head -n 1)
if [ -z "$KEY_PATH" ]; then
  echo "Key not found!"
  exit 1
fi
KEY_NAME=$(basename $KEY_PATH)
read -p "Enter Password: " Password
echo 'export Password='${Password}
docker pull privasea/node-calc:v0.0.1
tee $HOME/PrivateSea/docker-compose.yml > /dev/null <<EOF
version: '3.8'

services:
  privasea:
    image: privasea/node-calc:v0.0.1
    ports:
      - "8181:8181"
    environment:
      HOST: "`wget -qO- eth0.me`:8181"
      KEYSTORE: "$KEY_NAME"
      KEYSTORE_PASSWORD: "${Password}"
    volumes:
      - $HOME/PrivateSea/keys:/app/config
    restart: always


volumes:
  analog:

EOF
docker compose -f $HOME/PrivateSea/docker-compose.yml up -d
break
;;

"Logs")
docker logs -f worker-basic-eth-pred
break
;;

"Uninstall")
if [ ! -d "$HOME/basic-coin-prediction-node" ]; then
    break
fi
read -r -p "Wipe all DATA? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
cd $HOME/basic-coin-prediction-node && docker compose down -v
rm -rf $HOME/basic-coin-prediction-node $HOME/allora-chain
        ;;
    *)
	echo Canceled
	break
        ;;
esac
break
;;

"Exit")
exit
;;
*) echo "invalid option $REPLY";;
esac
done
done
