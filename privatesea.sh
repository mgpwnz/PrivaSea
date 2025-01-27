#!/bin/bash
while true
do

# Menu

PS3='Select an action: '
options=("Pre Install" "Create Account" "Install & RUN" "Logs" "Uninstall" "Exit")
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
docker pull privasea/acceleration-node-beta:latest
sudo mkdir -p $HOME/PrivateSea/config
cd $HOME/PrivateSea
docker run -it -v $HOME/PrivateSea/config:/app/config privasea/acceleration-node-beta:latest ./node-calc new_keystore

break
;;
"Install & RUN")
KEY_PATH=$(find $HOME/PrivateSea/config/ -type f | head -n 1)
if [ -z "$KEY_PATH" ]; then
  echo "Key not found!"
  exit 1
fi
KEY_NAME=$(basename $KEY_PATH)
mv $HOME/PrivateSea/config/$KEY_NAME $HOME/PrivateSea/config/wallet_keystore
read -p "Enter Password: " Password
echo 'export Password='${Password}
tee $HOME/PrivateSea/docker-compose.yml > /dev/null <<EOF
version: '3.8'

services:
  acceleration-node:
    image: privasea/acceleration-node-beta:latest
    container_name: acceleration-node
    environment:
      - KEYSTORE_PASSWORD=${Password}
    volumes:
      - $HOME/PrivateSea/config:/app/config
    restart: unless-stopped

EOF
docker compose -f $HOME/PrivateSea/docker-compose.yml up -d
docker logs -f acceleration-node --tail 100
break
;;

"Logs")
docker logs -f acceleration-node --tail 100
break
;;

"Uninstall")
if [ ! -d "$HOME/PrivateSea" ]; then
    break
fi
read -r -p "Remove node? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
docker compose -f $HOME/PrivateSea/docker-compose.yml down -v
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
