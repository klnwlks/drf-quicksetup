#!/usr/bin/env bash
ind="    " # not a big fan of this
sind="\ \ \ \ "

blank-make () {
    echo "Creating project structure..."
    mkdir "${1}"
    cd "${1}/"

    # setup django environment
    projName="${1}backend"
    python -m venv ./venv
    source ./venv/bin/activate
    pip install django django_rest_framework django-cors-headers
    django-admin startproject "$projName"
    cd "$projName"

    sed -i "40 i ${sind}'corsheaders',\n${sind}'rest_framework'," ./$projName/settings.py
    sed -i "52 i ${sind}'corsheaders.middleware.CorsMiddleware'," ./$projName/settings.py

    echo "Input url for whitelist (leave blank for localhost:3000)"
    read whitelist

    if [ "$whitelist" == "" ]; then
	whitelist="http://localhost:3000"
    fi

    printf "%s\n"\
	"CORS_ORIGIN_WHITELIST = ["\
	"${ind}'$whitelist'"\
	"]" >> ./$projName/settings.py
}

mk-app () {
    echo "input project name"
    read projName

    if [ ! -f "manage.py" ]; then
	echo "Not in a valid django project directory root. Exiting.."
	exit 1
    fi

    python manage.py startapp $1
    sed -i "42 i ${sind}'$1'," $projName/settings.py

    printf "from rest_framework import serializers\n" >> $1/serializers.py
    printf "from .models import " >> $1/serializers.py
}

mk-serializer () {
    echo "Input app name"
    read appName

    if [ ! -d "${appName}/" ]; then
	echo "App doesn't exist in django project."
	exit 1
    fi

    if [ ! -f "manage.py" ]; then
	echo "Not in a valid django project directory root. Exiting.."
	exit 1
    fi

    echo "Input model to be serialized"
    read model

    check=$(cat $appName/models.py | grep -c "${model}")
    if (( check == 0 )); then
	echo "Model is not in app."
	exit 1
    fi

    length=$(grep -n "from .models" $appName/serializers.py)
    if (( ${#length} > 24 )); then 
	sed -i "2s/$/, ${model}/" $appName/serializers.py
    else
	sed -i "2s/$/${model}/" $appName/serializers.py
    fi

    printf "\n\n%s\n%s\n%s\n%s"\
	"class ${1}(serializers.ModelSerializer):"\
	"${ind}class Meta:"\
	"${ind}${ind}model = $model"\
	"${ind}${ind}fields = '__all__'" >> $appName/serializers.py

}

mk-model () {
    echo "Input app name"
    read appName

    if [ ! -d "${appName}/" ]; then
	echo "App doesn't exist in django project."
	exit 1
    fi

    if [ ! -f "manage.py" ]; then
	echo "Not in a valid django project directory root. Exiting.."
	exit 1
    fi

    declare -A fields
    echo "Declare model fields"
    echo "name type default"
    echo "types are [int, char, bool, str, date]"
    echo "\"end\" to stop adding fields"

    while true; do
	read attr
	if [[ "$attr" == "end" ]]; then 
	    break
	fi

	key=$(echo $attr | awk '{print $1}') 
	fields+=(["$key"]=$(sed -e 's/^[^ ]* //' <<< "$attr"))
    done

    model="class ${1}(models.Model):"
    # pair type to field
    for i in "${!fields[@]}"; do
	ttype=$(echo ${fields[$i]} | awk '{print $1}')
	default=$(echo ${fields[$i]} | awk '{print $2}')

	case "$ttype" in
	    int) 
		type="IntegerField(default=${default})"
		;;
	    char)
		type="CharField(default=${default}, max_length=100)"
		;;
	    bool)
		type="BooleanField(default=${default})"
		;;
	    str)
		type="TextField(default=${default})"
		;;
	    date)
		type="DateTimeField()"
		;;
	    end)
		break
		;;
	    *)
		echo "invalid type: ${ttype}"
		echo "Exiting.."
		exit 1
		;;
	esac

	model+="\n${ind}${i} = models.${type}"
    done

    echo "Review model to be added (y/n to continue)"
    printf "$model"

    echo ""
    read confirm
    if [[ "$confirm" != "y" ]]; then
	exit 1
    fi

    printf "$model\n\n" >> $appName/models.py

    echo "making migrations.."
    python manage.py makemigrations $appName
    python manage.py migrate
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

# setup template
case "${mode}" in
    blank)
	echo "This template will only create a project configured for REST and nothing else."
	echo "Making blank template.." 
	blank-make "${name}"
	echo "Finished setting up a blank template."
	echo "Setup done."
	echo "cd to ${name} and source venv to get started."
	exit 0
	;;
    mkmodel)
	mk-model "$name"
	echo "Added model ${name}"
	exit 0
	;;
    mkapp)
	mk-app "$name"
	echo "App ${name} created and registered"
	exit 0
	;;
    mkserializer)
	echo "Keep in mind that this will include all fields by default."
	mk-serializer "$name"
	echo "Created serializer ${name}"
	exit 0
	;;
    *) 
	echo "not in modes"
	exit 0
	;;
esac
