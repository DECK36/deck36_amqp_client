#!/bin/sh

err() { echo "$@" >&2; exit 1; }

BASEDIR=$(readlink -f "$(dirname $0)/..")
CONFIGDIR="$BASEDIR/config"
RMQCTL="sudo rabbitmqctl"

AMQP_TYPE=rabbitmq
while getopts t: opt; do
	case $opt in
		t)
			AMQP_TYPE=$OPTARG
			;;
	esac
done

echo ""

case $AMQP_TYPE in
	"rabbitmq")
		echo -n "Trying to sudo rabbitmqctl ... "
		if [ $($RMQCTL eval "ok." | head -n 1) != "ok" ]; then
			err "FAILED."
		fi
		echo "OK."
		;;
	"manual")
		;;
	*)
		err "Invalid AMQP type ($AMQP_TYPE)"
		;;
esac

CT_TEMPLATE_FILE="$CONFIGDIR/ct.config.template"
if [ ! -e "$CT_TEMPLATE_FILE" ]; then
	err "Template file missing. Expected file: $CT_TEMPLATE_FILE"
fi

INTERACTIVE_TEMPLATE_FILE="$CONFIGDIR/interactive.config.template"
if [ ! -e "$INTERACTIVE_TEMPLATE_FILE" ]; then
	err "Template file missing. Expected file: $INTERACTIVE_TEMPLATE_FILE"
fi

CT_CONFIG_FILE="$CONFIGDIR/ct.config"
INTERACTIVE_CONFIG_FILE="$CONFIGDIR/interactive.config"
PASSWORD_FILE="$CONFIGDIR/password.do_not_commit"
TYPE_FILE="$CONFIGDIR/type.do_not_commit"

$BASEDIR/bin/make_password.sh -f "$PASSWORD_FILE"
PASSWORD=$(cat "$PASSWORD_FILE")

echo "Building test configuration file"
cat $CT_TEMPLATE_FILE | sed "s/{{PASSWORD}}/$PASSWORD/" > $CT_CONFIG_FILE
if [ ! -e "$CT_CONFIG_FILE" ]; then
	err "Failed to save config file. Expected file: $CT_CONFIG_FILE"
fi
			
cat $INTERACTIVE_TEMPLATE_FILE | sed "s/{{PASSWORD}}/$PASSWORD/" > $INTERACTIVE_CONFIG_FILE
if [ ! -e "$INTERACTIVE_CONFIG_FILE" ]; then
	err "Failed to save config file. Expected file: $INTERACTIVE_CONFIG_FILE"
fi

echo ""

case $AMQP_TYPE in
	"manual")
		echo "Skipping configuration of AMQP broker"
		echo -n "manual" > $TYPE_FILE
		;;
	"rabbitmq")
		echo "Configuring rabbitmq broker" 
		$RMQCTL add_user deck36_amqp_client_test "$PASSWORD"
		$RMQCTL add_vhost deck36_amqp_client_test
		$RMQCTL set_permissions -p deck36_amqp_client_test deck36_amqp_client_test ".*" ".*" ".*"
		echo -n "rabbitmq" > $TYPE_FILE
		;;
esac

if [ ! -e "$TYPE_FILE" ]; then
	err "Failed to save type file. Expected file not written: $TYPE_FILE"
fi

echo "\nOK\n" 
