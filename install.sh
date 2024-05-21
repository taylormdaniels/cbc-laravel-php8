#!/bin/bash

set -e

shopt -s expand_aliases

source ~/.bash_aliases

unalias cp

DEV_MODE=false

while [[ "$#" -gt 0 ]]; do

    case "$1" in

        --dev)
            DEV_MODE=true
            ;;

        *)
            echo "Unknown option: $1"
            exit 1
            ;;

    esac

    shift

done

REPO_NAME=$(basename $(pwd))

REPO_NAME_SNAKE=$(echo "$REPO_NAME" | tr '[:upper:]' '[:lower:]' | tr '-' '_')

if [[ "$DEV_MODE" == true ]]; then

	if dockerls | grep $REPO_NAME; then dockerdown; fi

	composer --ignore-platform-reqs install

	while true; do

		D_CLASS=$((RANDOM % (250 - 100 + 1) + 100))

		IP_ADDRESS=10.2.0.$D_CLASS

		if ! cat /etc/hosts | grep "$IP_ADDRESS"; then break; fi

	done

	while true; do

		HOST_LINE=$(cat /etc/hosts | grep -n -m 1 $REPO_NAME | cut -d : -f 1)

		if ! [[ -z $HOST_LINE ]]; then

			sudo sed -i "${HOST_LINE}d" /etc/hosts

		else

			break

		fi

	done

	echo "$IP_ADDRESS      $REPO_NAME" | sudo tee -a /etc/hosts

 	cp -f docker-compose.example.yaml docker-compose.yaml

 	sed -i "s/10\.2\.0\.31/$IP_ADDRESS/g" docker-compose.yaml

 	sed -i "s/cbc-laravel-php8/$REPO_NAME/g" docker-compose.yaml

	echo; echo

	if ! [ -f .env ]; then

		cp -f .env.docker .env

		sed -i "s/cbc-laravel-php8/$REPO_NAME/g" .env

		sed -i "s/cbc_laravel_php8/$REPO_NAME_SNAKE/g" .env

		# Generate a random 32 character string
		APP_KEY=$(openssl rand -base64 1000 | tr -dc 'a-zA-Z0-9' | head -c 32)

		# Define the new APP_KEY line
		NEW_APP_KEY_LINE="APP_KEY=$APP_KEY"

		# Replace the third line in the .env file with the new APP_KEY line
		sed -i "3s/.*/$NEW_APP_KEY_LINE/" .env

	fi

else

	composer install

	if ! [ -f .env ]; then

		cp -f .env.prod .env

		php artisan key:generate

	fi

fi

find storage/framework -maxdepth 1 -type d -exec chmod 777 {} +

chmod 777 storage/logs

setfacl -m "default:group::rw" storage/logs

chmod 777 bootstrap/cache