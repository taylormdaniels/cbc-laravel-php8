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

REPO_NAME_SNAKE=$(echo "$REPO_NAME" | tr '[:upper:]' '[:lower:]' | tr '-' '_')

if [[ "$DEV_MODE" == true ]]; then

	composer --ignore-platform-reqs install

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

	echo; echo

	upcbcstack

	repos; cd $REPO_NAME

	dockerup

	echo; echo

	if ! [ -f .env ]; then

		cp -f .env.docker .env

		sed -i "s/cbc-laravel-php8/$REPO_NAME/g" .env

		sed -i "s/cbc_laravel_php8/$REPO_NAME_SNAKE/g" .env

		art-docker key:generate

	fi

	if ! mysql -h"cbc-mariadb" -u"root" -e "USE $REPO_NAME_SNAKE;" 2>/dev/null; then

        mysql -h"cbc-mariadb" -u"root" -e "CREATE DATABASE IF NOT EXISTS $REPO_NAME_SNAKE;"

    fi

    art-docker migrate

	if npm install; then true; fi

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