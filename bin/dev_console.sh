#!/bin/bash
BASEDIR="$(dirname $0)/.."
NODE="-sname dev"

cd $BASEDIR 

erl $NODE -pa $BASEDIR/deps/*/ebin $BASEDIR/ebin $BASEDIR/src/*/*/deps/*/ebin $BASEDIR/src/*/*/ebin -boot start_sasl -sasl_error_logger '{file, "log/dev_console.log"}'
