deck36_amqp_client
================

deck36_amqp_client - the DECK36 AMQP Client - provides some helpers on top of amqp_client / rabbitmq-erlang-client by rabbitMQ.

The main goals of this application are:
* Taking away some work for common, simple use cases
* Providing an easy way to configure producers, consumers, exchanges, queues and bindings with a configuration file

deck36_amqp_client is not supposed to be
* a replacement for amqp_client / rabbitmq-erlang-client
* an abstraction from AMQP

Feedback, ideas, issues, contributions are very welcome.

See LICENSE

Terms
------

Apart from the usual terms used in AMQP context (see [rabbitmq tutorials](http://www.rabbitmq.com/getstarted.html)) there is one additional concept I'd like to mention.

### Setup

Setups can be used to declare exchanges, queue and bindings according to a configuration list (e.g. from the application config).
Depending on the configuration of 'teardown_on_stop' the setup will tear down all/some/none of the declarations it has made automatically.
Examples:
* *{teardown_on_stop, [all]}* - Will tear down all declarations it has made
* *{teardown_on_stop, [bindings]}* - Will tear down all bindings, but not exchanges or queues
* *{teardown_on_stop, [{queue, [{queue, <<"abc">>}]}]}* - Will only tear down the queue <<"abc">>
* *{teardown_on_stop, [bindings, {exchange, [{exchange, <<"abc">>}]}]}* - Will tear down all bindings and the exchange <<"abc">>

You can have several "setups". Each element of the List in {setups, List} in your configuration will result in one deck36_amqp_setup server.
This comes in handy if you want to configure different brokers or with different teardown policies, e.g. for dynamic declarations w/ a 'all' policy.

See *deck36_amqp_setup* for further information.

Usage
------

### Static configuration

deck36_amqp_client uses [OTP application configuration](http://www.erlang.org/doc/design_principles/applications.html#id74282).

Use the [erl](http://www.erlang.org/doc/man/erl.html) option "-config <config file>" or [application:set_env/3](http://www.erlang.org/doc/apps/kernel/application.html#set_env-3) before starting the application (application:config_change/3 hasn't been implemented yet).

See test/ct/config/ct.config.template an example.

### Start

You can start deck36_amqp_client by calling *deck36_amqp_client:start/0* as OTP application.

You can also embed *deck36_amqp_consumer_sup*, *deck36_amqp_producer_sup* and/or *deck36_amqp_setup_sup* into your own supervision tree. See *deck36_amqp_consumer_sup:start_link/0,1*, *deck36_amqp_producer_sup:start_link/0,1* and *deck36_amqp_setup_sup:start_link/0,1*.

And last but not least you can start and use *deck36_amqp_producer*, *deck36_amqp_consumer* and *deck36_amqp_setup* directly.

### Starting / stopping consumers / producers

If you want to auto-start consumers/producers/setups on application startup, just put their definitions into the config. See test/ct/onfig/ct.config.template.

To dynamically start consumers/producers/setups use *deck36_amqp_client:start_consumer/1* / *deck36_amqp_client:start_producer/1* / *deck36_amqp_client:start_setup/1*.

You can stop a consumer with *deck36_amqp_client:stop_consumer/1* / *deck36_amqp_client:stop_producer/1* / *deck36_amqp_client:stop_setup/1*.

### The deck36_amqp_consumer and its container

deck36_amqp_consumer is a amqp_gen_consumer, which simply calls a callback function each time it receives a message and uses the result of that delivery callback function to determine if the message should be acknowledged:
- ok -> The message will be acknowledged if the acknowledge setting is set to 'all' or 'ok' 
- {ok, ack} -> The message will be acknowledged
- {ok, leave} -> The message will not be acknowledged
- {error, Reason} -> If you have specified an error_cb (see below) it will be called and the message will be acknowledged if the acknowledge setting is set to 'all' or 'error'
The delivery callback - mandatory opt {deliver_cb, fun()} can be specified in three ways:
- {Module, Function}, where Function has to accept exactly one parameter (the #amqp_msg{}).
- {Module, Function, Args}, where Function has to accept exactly size(Args)+1 parameters. The #amqp_msg{} will be prepended to the Args.
- fun/1, where the fun accepts exactly one parameter (the #amqp_msg{}).

The error callback - optional opt {error_cb, fun/1} - is called whenever delivery_cb returns {error, Reason}. It has to accept exactly one parameter, which will be a 4-tuple of {Reason, #'basic.deliver'{}, #amqp_msg{}, ChannelPid}.

You can use the error_cb for example to write a log entry or send the message to another exchange/queue. If you have set the acknowledge setting to 'ok' you can also use the error_cb to acknowledge the message by yourself.

The deck36_amqp_consumer_container is used to hold the links to the connection and channel for supervision). Besides the deck36_amqp_consumer it can also contain other amqp_gen_consumer implementations.

### Tests

You need a running rabbitmq-server on 127.0.0.1:5672 for the full tests (make full-tests or make full). If you don't have a broker, you can only run the unit tests (make unit-tests).

Before first test run, execute the following setup script. A rabbitmq user and vhost will be created. The user will get permissions to the newly created vhost. The password will be random, so you don't accidently expose your rabbitmq server with guest/guest or whatever. 
> test/ct/bin/setup_test_env.sh

Note: This script will use sudo for rabbitmqctl. If you don't want that, use option "-t manual"

To run the actual tests use:
> make full-tests

If you want to tear down the test environment execute:
> test/ct/bin/teardown_test_env.sh

Note: This script will use sudo for rabbitmqctl if setup_test_env.sh was used with type "rabbitmq", which is the default. 

If you want to create the configurations yourself copy ct.config.template to ct.config and interactive.config.template to interactive.config and set {{PASSWORD}} plus all changes you'd like to make.
 
You can also run "test/ct/bin/setup_test_env.sh -t manual" (not as su) to just create the configurations. You must afterwards configure your broker accordingly. teardown_test_env.sh will then only remove the config files.


Dependencies
-------------
Resolved by rebar.

* [amqp_client](https://github.com/jbrisbin/amqp_client)
* [deck36_common](https://github.com/DECK36/deck36_common)
* [meck](https://github.com/eproxus/meck)

ToDos
------
- better shutdown procedure (stop consumption, make sure all workers finished, shutdown)
- make consumer_sup, producer_sup, setup_sup available on non-singleton variant
- connection aliases
- smarter waiting / parallelization of tests
- deletion in setup ("delete queue X and declare queue X again")
- as always: more tests (units, tear down, custom modules in consumer)
- full example.config
- integration test
