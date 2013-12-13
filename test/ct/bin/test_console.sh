#!/bin/bash
BASEDIR="$(dirname $0)/../../"
NODE="-sname deck36_amqp_client_test"

cd $BASEDIR/test/ct/helpers
erlc -I $BASEDIR/deps *.erl

cd $BASEDIR

erl $NODE -config $BASEDIR/test/ct/config/interactive.config -pa $BASEDIR/deps/*/ebin $BASEDIR/ebin $BASEDIR/src/*/*/deps/*/ebin $BASEDIR/src/*/*/ebin $BASEDIR/itest/helpers -s deck36_amqp_client start
