#!/bin/bash

set -e

shopt -s expand_aliases

source ~/.bash_aliases

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

if [[ "$DEV_MODE" == true ]]; then

	while true; do

		D_CLASS=$((RANDOM % (250 - 100 + 1) + 100))

		IP_ADDRESS=10.2.0.$D_CLASS

		if ! cat /etc/hosts | grep "$IP_ADDRESS"; then break; fi

	done

	if ! cat /etc/hosts | grep "$REPO_NAME"; then

		echo "$IP_ADDRESS      $REPO_NAME" | sudo tee -a /etc/hosts

	fi

	if ! [ -f docker-compose.yaml ]; then

	 	cp -f docker-compose.example.yaml docker-compose.yaml

	 	sed -i "s/10\.2\.0\.31/$IP_ADDRESS/g" docker-compose.yaml

	 	sed -i "s/cbc-laravel-php8/$REPO_NAME/g" docker-compose.yaml

	fi

	if ! [ -f .env ]; then

		cp -f .env.docker .env

		sed -i "s/cbc-laravel-php8/$REPO_NAME/g" .env

		if [ "$(docker container inspect -f '{{.State.Running}}' $REPO_NAME)" != "true" ]; then dockerup; fi

		art-docker key:generate

	fi

	composer --ignore-platform-reqs install

	npm install

	npm run dev

else

	if ! [ -f .env ]; then

		cp -f .env.prod .env

		php artisan key:generate

	fi

	composer install

fi

find storage/framework -maxdepth 1 -type d -exec chmod 777 {} +

chmod 777 storage/logs

setfacl -m "default:group::rw" storage/logs

chmod 777 bootstrap/cache