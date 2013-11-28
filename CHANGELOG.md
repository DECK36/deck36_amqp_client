0.3.0

New: MacOS X support for helper scripts
New: deck36_amqp_consumer_sup can now be used as non-singleton variant.
New: deck36_amqp_setup_sup can now be used as non-singleton variant.
New: deck36_amqp_producer_sup can now be used as non-singleton variant.

Interface change: deck36_amqp_consumer_sup:start_link/0 removed. Use start_link(singleton). See module for further information. 
Interface change: deck36_amqp_setup_sup:start_link/0 removed. Use start_link(singleton). See module for further information. 
Interface change: deck36_amqp_producer_sup:start_link/0 removed. Use start_link(singleton). See module for further information. 

