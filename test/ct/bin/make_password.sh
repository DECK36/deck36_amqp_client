#!/bin/bash

NUM_CHARS=80
FILENAME='.password'
CHARSET='a-zA-Z0-9-_@#%^:='
while getopts f:c:n: OPTION
do
	case $OPTION in
		f)
			FILENAME="$OPTARG"
			;;
		n)
			NUM_CHARS="$OPTARG"
			;;
		c)
			CHARSET="$OPTARG"
			;;
	esac
done

if [ "${OSTYPE:0:6}" = "darwin" ]; then
	LC_CTYPE=C tr -dc $CHARSET < /dev/urandom | head -c $NUM_CHARS > $FILENAME
else
	tr -dc $CHARSET < /dev/urandom | head -c $NUM_CHARS > $FILENAME
fi


