#!/usr/bin/env bash
indent="\ \ \ \ " # not a big fan of this

blank-make () {
    echo "This template will only create a project configured for REST and nothing else."
    echo "Making blank template.." 
    echo "$PWD"

    # i COULD use grep to find the appropriate lines 
    # but why do that when this works too
    sed -i "40 i ${indent}'corsheaders',\n${indent}'rest_framework'," ./$1/settings.py
    sed -i "52 i ${indent}'corsheaders.middleware.CorsMiddleware'," ./$1/settings.py

    echo "Input url for whitelist (leave blank for localhost:3000)"
    read whitelist

    if ["$whitelist" == ""]; then
	whitelist="http://localhost:3000"
    fi

    echo "CORS_ORIGIN_WHITELIST = [
	'$whitelist'
]" >> ./$1/settings.py
}

help () {
    echo "usage: drf-quicksetup -n [name] -m [mode]"
    exit 0
}

if (("$#" < 2 || "$#" > 4)); then
    echo "usage: drf-quicksetup -n [name] -m [mode]"
    exit 1
fi

mode="blank"
while getopts "hn:m:" opts; do
    case "${opts}" in
	h) help;;
	n) name=${OPTARG};;
	m) mode=${OPTARG};;
	*) help;;
    esac
done

echo "Creating project structure..."
mkdir "${name}"
cd "${name}/"

# setup django environment
python -m venv ./venv
source ./venv/bin/activate
pip install django django_rest_framework django-cors-headers
django-admin startproject "${name}backend"
cd "${name}backend"

# setup template
case "${mode}" in
    blank) blank-make "${name}backend";;
    # ecommerce) ecommerce-make $name;;
    # blog) blog-make $name;;
    *) 
	echo "not in modes"
	exit 1
	;;
esac

echo "Setup done."
echo "cd to ${name} to get started."
