#!/bin/bash

set -e

source ~/repos/cbc-development-setup/.bash_aliases

shopt -s expand_aliases

if [[ "$(whoami)" == "root" ]]; then echo-red "Do NOT run with sudo!"; exit 1; fi

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

	if dockerls | grep $REPO_NAME > /dev/null; then

		dockerdown

	fi

	if ! dockerls | grep cbc-mariadb > /dev/null; then

		upcbcstack

		sleep 5

	fi

	if [ ! -f "vendor/composer/installed.json" ]; then

		composer --ignore-platform-reqs install

	fi

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

 	dockerup

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

	echo; echo

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

touch is_installed