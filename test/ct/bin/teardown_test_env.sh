#!/bin/bash

err() { echo "$@" >&2; exit 1; }

if [ "${OSTYPE:0:6}" = "darwin" ]; then
	GL=$(which greadlink)
	BASEDIR="$(dirname $0)/.."
	if [ $? -eq 0 ]; then
		if [ $(greadlink --version | head -c 8) = "readlink" ]; then
			BASEDIR=$(greadlink -f "$(dirname $0)/..")
		fi
	fi
else
	BASEDIR=$(readlink -f "$(dirname $0)/..")
fi

CONFIGDIR="$BASEDIR/config"
RMQCTL="sudo rabbitmqctl"

PASSWORD_FILE="$CONFIGDIR/password.do_not_commit"
CT_CONFIG_FILE="$CONFIGDIR/ct.config"
INTERACTIVE_CONFIG_FILE="$CONFIGDIR/interactive.config"
TYPE_FILE="$CONFIGDIR/type.do_not_commit"

if [ ! -e "$TYPE_FILE" ]; then
	err "Type file missing. Expected file: $TYPE_FILE"
fi

AMQP_TYPE=$(cat "$TYPE_FILE")

case $AMQP_TYPE in
	"manual")
		echo "Skipping configuration of AMQP broker"
		;;
	"rabbitmq")
		echo -n "Trying to sudo rabbitmqctl ... "
		if [ $($RMQCTL eval "ok." | head -n 1) != "ok" ]; then
		        err "FAILED."
		fi
		echo "OK."

		echo "Configuring rabbitmq broker"
		$RMQCTL clear_permissions -p deck36_amqp_client_test deck36_amqp_client_test
		$RMQCTL delete_vhost deck36_amqp_client_test
		$RMQCTL delete_user deck36_amqp_client_test
		;;
	*)
		err "Invalid AMQP type ($AMQP_TYPE)"
		;;
esac

echo "Removing configuration files"

# using if instead of -f to avoid desasters like CONFIG_FILE=" -r /"
rm_file() { if [ -e "$1" ]; then rm $1; fi; }

rm_file "$TYPE_FILE"
rm_file "$CT_CONFIG_FILE"
rm_file "$INTERACTIVE_CONFIG_FILE"
rm_file "$PASSWORD_FILE"

echo -e "\nOK\n"
