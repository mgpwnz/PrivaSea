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
            # Install Docker and Docker Compose
            touch $HOME/.bash_profile
            cd $HOME
            if ! command -v docker &> /dev/null; then
                sudo apt update
                sudo apt upgrade -y
                sudo apt install curl apt-transport-https ca-certificates gnupg lsb-release -y
                . /etc/*-release
                wget -qO- "https://download.docker.com/linux/${DISTRIB_ID,,}/gpg" | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                sudo apt update
                sudo apt install docker-ce docker-ce-cli containerd.io -y
            fi

            if ! docker compose version &> /dev/null; then
                sudo apt install wget jq -y
                docker_compose_version=$(wget -qO- https://api.github.com/repos/docker/compose/releases/latest | jq -r ".tag_name")
                sudo wget -O /usr/bin/docker-compose "https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-$(uname -s)-$(uname -m)"
                sudo chmod +x /usr/bin/docker-compose
            fi
            echo "Docker and Docker Compose installed successfully."
            break
            ;;

		"Create Account")
			# Pull and create account
			if [ -d "$HOME/PrivateSea" ] && [ -f "$HOME/PrivateSea/config/wallet_keystore" ]; then
				echo "Key already exists at $HOME/PrivateSea/config/wallet_keystore. No need to generate a new one."
				break
			fi

			docker pull privasea/acceleration-node-beta:latest
			sudo mkdir -p $HOME/PrivateSea/config
			cd $HOME/PrivateSea
			docker run -it -v $HOME/PrivateSea/config:/app/config privasea/acceleration-node-beta:latest ./node-calc new_keystore

			KEY_PATH=$(find $HOME/PrivateSea/config/ -type f | head -n 1)
			if [ -z "$KEY_PATH" ]; then
				echo "Key not found! Please try again."
			else
				KEY_NAME=$(basename "$KEY_PATH")
				mv "$HOME/PrivateSea/config/$KEY_NAME" "$HOME/PrivateSea/config/wallet_keystore"
				echo "Account created successfully. Key stored as wallet_keystore."
			fi
			break
			;;


		"Install & RUN")
			if [ -f "$HOME/PrivateSea/docker-compose.yml" ]; then
				echo "docker-compose.yml already exists. Checking container status..."

				# Перевіряємо, чи контейнер запущений
				if ! docker ps --filter "name=acceleration-node" --format "{{.Names}}" | grep -q "acceleration-node"; then
					echo "Container is not running. Starting the container..."
					docker compose -f $HOME/PrivateSea/docker-compose.yml up -d
				else
					echo "Container is already running."
				fi

				docker logs -f acceleration-node --tail 100
				break
			fi

			# Якщо файлу docker-compose.yml немає, створюємо його
			read -p "Enter Password: " Password
			if [ -z "$Password" ]; then
				echo "Password cannot be empty. Please try again."
				break
			fi
			echo "export Password=${Password}" >> $HOME/.bash_profile
			source $HOME/.bash_profile
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
                echo "No installation found."
                break
            fi
            read -r -p "Remove node? [y/N] " response
            case "$response" in
                [yY][eE][sS]|[yY]) 
                    docker compose -f $HOME/PrivateSea/docker-compose.yml down -v
                    echo "Node removed successfully."
                    ;;
                *)
                    echo "Canceled"
                    ;;
            esac
            break
            ;;

        "Exit")
            exit
            ;;

        *)
            echo "Invalid option $REPLY"
            ;;
    esac
done
done
