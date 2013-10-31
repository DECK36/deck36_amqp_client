%% ====================================================================
%%
%% Copyright (c) DECK36 GmbH & Co. KG, Valentinskamp 18, 20354 Hamburg/Germany and individual contributors.
%% All rights reserved.
%% 
%% Redistribution and use in source and binary forms, with or without modification,
%% are permitted provided that the following conditions are met:
%% 
%%     1. Redistributions of source code must retain the above copyright notice,
%%        this list of conditions and the following disclaimer.
%% 
%%     2. Redistributions in binary form must reproduce the above copyright
%%        notice, this list of conditions and the following disclaimer in the
%%        documentation and/or other materials provided with the distribution.
%% 
%%     3. Neither the name of DECK36 GmbH & Co. KG nor the names of its contributors may be used
%%        to endorse or promote products derived from this software without
%%        specific prior written permission.
%% 
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
%% ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
%% WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
%% DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
%% ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
%% (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
%% LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
%% ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
%% (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
%% SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
%%
%% ====================================================================
%%
%% @author Bjoern Kortuemm (@uuid0) <bjoern.kortuemm@deck36.de>
%% @doc Util module providing types and converters.
%%
%% See functions for further information.


-module(deck36_amqp_util).

-include_lib("amqp_client/include/amqp_client.hrl").

%% ====================================================================
%% Types
%% ====================================================================
-export_type([queue_opt/0, queue_def/0, queue_declare/0,
			  queue_delete_def/0, queue_delete/0,
			  exchange_opt/0, exchange_def/0, exchange_declare/0,
			  exchange_delete_def/0, exchange_delete/0,
			  binding_opt/0, binding_def/0, binding_declare/0,
			  binding_delete_def/0, binding_delete/0,
			  definition/0, declaration/0, deletion/0]).
-type queue_def() :: queue_declare()
				   | {queue, [queue_opt()]} 
				   | [queue_opt()].
-type queue_declare() :: #'queue.declare'{}.
-type queue_opt() :: {queue, binary()}
				   | {durable, boolean()}
				   | {arguments, [any()]}.
-type queue_delete_def() :: queue_delete()
						  | queue_def().
-type queue_delete() :: #'queue.delete'{}.

-type exchange_def() :: #'exchange.declare'{}
					  | {exchange, [exchange_opt()]}
					  | [exchange_opt()].
-type exchange_opt() :: {exchange, binary()}
					  | {durable, boolean()}
					  | {type, atom()}
					  | {arguments, [any()]}.
-type exchange_declare() :: #'exchange.declare'{}.
-type exchange_delete_def() :: exchange_delete()
							 | exchange_def().
-type exchange_delete() :: #'exchange.delete'{}.

-type binding_def() :: #'queue.bind'{}
					 | {binding, [binding_opt()]}
					 | [binding_opt()].
-type binding_opt() :: {queue, binary()}
					 | {exchange, binary()}
					 | {routing_key, binary()}.
-type binding_declare() :: #'queue.bind'{}.
-type binding_delete_def() :: binding_delete()
							| binding_def().
-type binding_delete() :: #'queue.unbind'{}.

-type definition() :: queue_def()
					| exchange_def()
					| binding_def().
-type declaration() :: queue_declare()
					 | exchange_declare()
					 | binding_declare().
-type deletion() :: queue_delete()
				  | exchange_delete()
				  | binding_delete().

%% ====================================================================
%% API functions
%% ====================================================================
-export([queue/1,
		 is_queue/1,
		 is_queue_def/1,
		 exchange/1,
		 is_exchange/1,
		 is_exchange_def/1,
		 binding/1,
		 is_binding/1,
		 is_binding_def/1,
		 declaration/1,
		 is_definition/1,
		 is_declaration/1]).
-export([queue_delete/1,
		 is_queue_delete/1,
		 is_queue_delete_def/1,
		 exchange_delete/1,
		 is_exchange_delete/1,
		 is_exchange_delete_def/1,
		 binding_delete/1,
		 is_binding_delete/1,
		 is_binding_delete_def/1,
		 deletion/1,
		 is_deletion/1,
		 is_deletion_def/1]).
-export([amqp_msg/1]).

-define(GV(K,L), proplists:get_value(K,L)).
-define(GV(K,L,D), proplists:get_value(K,L,D)).



%% queue/1
%% ====================================================================
%% @doc Get queue declaratin to be used with amqp_client
-spec queue(queue_def()) -> queue_declare().
%% ====================================================================
queue(#'queue.declare'{}=Q) ->
	Q;
queue({queue, O}) ->
	queue(O);
queue(Opts) when is_list(Opts) ->
	#'queue.declare'{ durable = DD, arguments = DA } = #'queue.declare'{},
	#'queue.declare'{
					 queue = ?GV(queue, Opts),
					 durable = ?GV(durable, Opts, DD),
					 arguments = ?GV(arguments, Opts, DA)}.


%% is_queue/1
%% ====================================================================
%% @doc Determine if given value is a valid queue declaration.
%%
%% Currently only checks the structure of the given value.
%% @todo validate options
-spec is_queue(term()) -> boolean().
%% ====================================================================
is_queue(#'queue.declare'{}) ->	true;
is_queue(_) ->					false.


%% is_queue_def/1
%% ====================================================================
%% @doc Determine if given value is a valid queue definition.
%%
%% Currently only checks the structure of the given value.
%% @todo validate options
-spec is_queue_def(term()) -> boolean().
%% ====================================================================
is_queue_def(#'queue.declare'{}) ->	true;
is_queue_def(O) when is_list(O) ->	erlang:is_binary(?GV(queue, O));
is_queue_def(_) ->					false.


%% exchange/1
%% ====================================================================
%% @doc Get exchange declaration to be used with amqp_client
-spec exchange(exchange_def()) -> exchange_declare().
%% ====================================================================
exchange(#'exchange.declare'{}=E) ->
	E;
exchange({exchange, O}) ->
	exchange(O);
exchange(Opts) when is_list(Opts) ->
	#'exchange.declare'{ durable = DD, type = DT, arguments = DA } = #'exchange.declare'{},
	#'exchange.declare'{
						exchange = ?GV(exchange, Opts),
						durable = ?GV(durable, Opts, DD),
						type = ?GV(type, Opts, DT),
						arguments = ?GV(arguments, Opts, DA)}.


%% is_exchange/1
%% ====================================================================
%% @doc Determine if given value is a valid exchange declaration.
%%
%% Currently only checks the structure of the given value.
%% @todo validate options
-spec is_exchange(term()) -> boolean().
%% ====================================================================
is_exchange(#'exchange.declare'{}) ->	true;
is_exchange(_) ->						false.


%% is_exchange_def/1
%% ====================================================================
%% @doc Determine if given value is a valid exchange definition.
%%
%% Currently only checks the structure of the given value.
%% @todo validate options
-spec is_exchange_def(term()) -> boolean().
%% ====================================================================
is_exchange_def(#'exchange.declare'{}) ->	true;
is_exchange_def(O) when is_list(O) ->		erlang:is_binary(?GV(exchange, O));
is_exchange_def(_) ->						false.


%% binding/1
%% ====================================================================
%% @doc Get binding declaration to be used with amqp_client
-spec binding(binding_def()) -> binding_declare().
%% ====================================================================
binding(#'queue.bind'{}=B) ->
	B;
binding({binding, O}) ->
	binding(O);
binding(Opts) when is_list(Opts)->
	#'queue.bind'{
				  queue = ?GV(queue, Opts),
				  exchange = ?GV(exchange, Opts),
				  routing_key = ?GV(routing_key, Opts, <<>>)}.


%% is_binding/1
%% ====================================================================
%% @doc Determine if given value is a valid binding declaration.
%%
%% Currently only checks the structure of the given value.
%% @todo validate options
-spec is_binding(term()) -> boolean().
%% ====================================================================
is_binding(#'queue.bind'{}) ->		true;
is_binding(_) ->					false.


%% is_binding_def/1
%% ====================================================================
%% @doc Determine if given value is a valid binding definition.
%%
%% Currently only checks the structure of the given value.
%% @todo validate options
-spec is_binding_def(term()) -> boolean().
%% ====================================================================
is_binding_def(#'queue.bind'{}) ->		true;
is_binding_def(O) when is_list(O) ->	erlang:is_binary(?GV(queue, O)) andalso
										erlang:is_binary(?GV(exchange, O));
is_binding_def(_) ->					false.


%% declaration/1
%% ====================================================================
%% @doc Get declaration (queue, exchange or binding)
-spec declaration(queue_def() | exchange_def() | binding_def()) -> declaration().
%% ====================================================================
declaration(#'queue.declare'{}=Q) ->	Q;
declaration({queue, Q}) ->				queue(Q);
declaration(#'exchange.declare'{}=E) ->	E;
declaration({exchange, E}) ->			exchange(E);
declaration(#'queue.bind'{}=B) ->		B;
declaration({binding, B}) ->			binding(B).


%% is_declaration/1
%% ====================================================================
%% @doc Determine if given value is a valid declaration.
%%
%% Currently only checks the structure of the given value.
%% @todo validate options
-spec is_declaration(term()) -> boolean().
%% ====================================================================
is_declaration(#'queue.declare'{}) ->		true;
is_declaration(#'exchange.declare'{}) ->	true;
is_declaration(#'queue.bind'{}) ->			true;
is_declaration(_) ->						false.


%% is_definition/1
%% ====================================================================
%% @doc Determine if given value is a valid definition.
%%
%% Currently only checks the structure of the given value.
%% @todo validate options
-spec is_definition(term()) -> boolean().
%% ====================================================================
is_definition(#'queue.declare'{}) ->	true;
is_definition({queue, Q}) ->			is_queue_def(Q);
is_definition(#'exchange.declare'{}) ->	true;
is_definition({exchange, E}) ->			is_exchange_def(E);
is_definition(#'queue.bind'{}) ->		true;
is_definition({binding, B}) ->			is_binding_def(B);
is_definition(_) ->						false.


%% queue_delete/1
%% ====================================================================
%% @doc Get queue deletion declaration.
-spec queue_delete(queue_delete_def()) -> queue_delete().
%% ====================================================================
queue_delete(#'queue.delete'{}=Q) ->
	Q;
queue_delete(#'queue.declare'{queue = Q}) ->
	#'queue.delete'{queue = Q};
queue_delete(O) ->
	queue_delete(queue(O)).


%% is_queue_delete/1
%% ====================================================================
%% @doc Determine if given value is a valid queue delete declaration.
%%
%% Currently only checks the structure of the given value.
%% @todo validate options
-spec is_queue_delete(term()) -> boolean().
%% ====================================================================
is_queue_delete(#'queue.delete'{}) ->	true;
is_queue_delete(_) ->					false.


%% is_queue_delete_def/1
%% ====================================================================
%% @doc Determine if given value is a valid queue delete definition.
%%
%% Currently only checks the structure of the given value.
%% @todo validate options
-spec is_queue_delete_def(term()) -> boolean().
%% ====================================================================
is_queue_delete_def(#'queue.delete'{}) ->	true;
is_queue_delete_def(O) ->					is_queue_def(O).


%% exchange_delete/1
%% ====================================================================
%% @doc Get exchange deletion declaration.
-spec exchange_delete(exchange_delete_def()) -> exchange_delete().
%% ====================================================================
exchange_delete(#'exchange.delete'{}=E) ->
	E;
exchange_delete(#'exchange.declare'{exchange = E}) ->
	#'exchange.delete'{exchange = E};
exchange_delete(O) ->
	exchange_delete(exchange(O)).


%% is_exchange_delete/1
%% ====================================================================
%% @doc Determine if given value is a valid exchange delete declaration.
%%
%% Currently only checks the structure of the given value.
%% @todo validate options
-spec is_exchange_delete(term()) -> boolean().
%% ====================================================================
is_exchange_delete(#'exchange.delete'{}) ->	true;
is_exchange_delete(_) ->					false.


%% is_exchange_delete_def/1
%% ====================================================================
%% @doc Determine if given value is a valid exchange delete definition.
%%
%% Currently only checks the structure of the given value.
%% @todo validate options
-spec is_exchange_delete_def(term()) -> boolean().
%% ====================================================================
is_exchange_delete_def(#'exchange.delete'{}) ->	true;
is_exchange_delete_def(O) ->					is_exchange_def(O).


%% binding_delete/1
%% ====================================================================
%% @doc Get binding deletion declaration.
-spec binding_delete(binding_delete_def()) -> binding_delete().
%% ====================================================================
binding_delete(#'queue.unbind'{}=D) ->
	D;
binding_delete(#'queue.bind'{queue = Q, exchange = E, routing_key = R, arguments = A}) ->
	#'queue.unbind'{exchange = E, queue = Q, routing_key = R, arguments = A};
binding_delete(O) ->
	binding_delete(binding(O)).


%% is_binding_delete/1
%% ====================================================================
%% @doc Determine if given value is a valid binding delete declaration.
%%
%% Currently only checks the structure of the given value.
%% @todo validate options
-spec is_binding_delete(term()) -> boolean().
%% ====================================================================
is_binding_delete(#'queue.unbind'{}) ->	true;
is_binding_delete(_) ->					false.


%% is_binding_delete_def/1
%% ====================================================================
%% @doc Determine if given value is a valid binding delete definition.
%%
%% Currently only checks the structure of the given value.
%% @todo validate options
-spec is_binding_delete_def(term()) -> boolean().
%% ====================================================================
is_binding_delete_def(#'queue.unbind'{}) ->	true;
is_binding_delete_def(O) ->					is_binding_def(O).


%% deletion/1
%% ====================================================================
%% @doc Get delete declaration (queue, exchange or binding)
-spec deletion(queue_delete_def() | exchange_delete_def() | binding_delete_def()) -> deletion().
%% ====================================================================
deletion(#'queue.delete'{}=Q) ->		Q;
deletion(#'queue.declare'{}=Q) ->		queue_delete(Q);
deletion({queue, Q}) ->					queue_delete(Q);
deletion(#'exchange.delete'{}=E) ->		E;
deletion(#'exchange.declare'{}=E) ->	exchange_delete(E);
deletion({exchange, E}) ->				exchange_delete(E);
deletion(#'queue.unbind'{}=D) ->		D;
deletion(#'queue.bind'{}=B) ->			binding_delete(B);
deletion({binding, B}) ->				binding_delete(B).


%% is_deletion/1
%% ====================================================================
%% @doc Determine if given value is a valid deletion.
%%
%% Currently only checks the structure of the given value.
%% @todo validate options
-spec is_deletion(term()) -> boolean().
%% ====================================================================
is_deletion(#'queue.delete'{}) ->		true;
is_deletion(#'exchange.delete'{}) ->	true;
is_deletion(#'queue.unbind'{}) ->		true;
is_deletion(_) ->						false.


%% is_deletion_def/1
%% ====================================================================
%% @doc Determine if given value is a valid deletion definition.
%%
%% Currently only checks the structure of the given value.
%% @todo validate options
-spec is_deletion_def(term()) -> boolean().
%% ====================================================================
is_deletion_def(#'queue.delete'{}) ->		true;
is_deletion_def(#'queue.declare'{}) ->		true;
is_deletion_def({queue, Q}) ->				is_queue_delete_def(Q);
is_deletion_def(#'exchange.delete'{}) ->	true;
is_deletion_def(#'exchange.declare'{}) ->	true;
is_deletion_def({exchange, E}) ->			is_exchange_delete_def(E);
is_deletion_def(#'queue.unbind'{}) ->		true;
is_deletion_def(#'queue.bind'{}) ->			true;
is_deletion_def({binding, B}) ->			is_binding_delete_def(B);
is_deletion_def(_) ->						false.

%% amqp_msg/1
%% ====================================================================
%% @doc Get amqp_msg{} with Payload
-spec amqp_msg(Payload :: binary() | list()) -> #amqp_msg{}.
%% ====================================================================
amqp_msg(Payload) when is_binary(Payload) ->
	#amqp_msg{payload = Payload};
amqp_msg(Payload) when is_list(Payload) ->
	amqp_msg(erlang:list_to_binary(Payload));
amqp_msg(#amqp_msg{}=M) ->
	M.




