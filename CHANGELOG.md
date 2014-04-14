0.3.4
------
New: Travis support added
Refactorings to make tests more stable

0.3.3
------
Moved meck dependency to deck36_common. Waiting for rebar to support test-deps / dev-deps. 

0.3.2
------
Improved MacOSX compatibility in bash scripts.

0.3.1
------
Bugfix: deck36_amqp_setup_sup:start_link/2 now using started process instead of singleton process
Bugfix: deck36_amqp_producer_sup:start_link/2 now using started process instead of singleton process
Bugfix: deck36_amqp_consumer_sup:start_link/2 now using started process instead of singleton process

0.3.0
------
New: MacOS X support for helper scripts
New: deck36_amqp_consumer_sup can now be used as non-singleton variant.
New: deck36_amqp_setup_sup can now be used as non-singleton variant.
New: deck36_amqp_producer_sup can now be used as non-singleton variant.

Interface change: deck36_amqp_consumer_sup:start_link/0 removed. Use start_link(singleton). See module for further information. 
Interface change: deck36_amqp_setup_sup:start_link/0 removed. Use start_link(singleton). See module for further information. 
Interface change: deck36_amqp_producer_sup:start_link/0 removed. Use start_link(singleton). See module for further information. 

