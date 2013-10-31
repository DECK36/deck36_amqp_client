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
%% @doc Unit test for deck36_amqp_util.


-module(deck36_amqp_util_tests).

%% ====================================================================
%% API functions
%% ====================================================================
-export([]).

-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("eunit/include/eunit.hrl").


%% Test queue/1
%% ====================================================================
queue_test_() ->
	Queue = <<"queue">>,
	Durable = true,
	Args = [<<"some arg">>],
	Opts = [
			{queue, Queue},
			{durable, Durable},
			{arguments, Args} ],
	QD = #'queue.declare'{
						  queue = Queue,
						  durable = Durable,
						  arguments = Args},
	F = fun deck36_amqp_util:queue/1,
	[
	 {"Identity", ?_assertEqual(QD, F(QD))},
	 {"Opts", ?_assertEqual(QD, F(Opts))},
	 {"Opts - queue only", ?_assertEqual(#'queue.declare'{queue=Queue},
										 F([{queue, Queue}]))}
	].


%% Test is_queue/1
%% ====================================================================
is_queue_test_() ->
	F = fun deck36_amqp_util:is_queue/1,
	[
	 {"+ Record", ?_assert(F(#'queue.declare'{queue = <<"Q">>}))},
	 {"- Opts", ?_assertNot(F([{queue, <<"Q">>}, {durable, true}, {arguments, [<<"A">>]}]))},
	 {"- Empty list", ?_assertNot(F([]))},
	 {"- Exchange", ?_assertNot(F(#'exchange.declare'{}))},
	 {"- Binding", ?_assertNot(F(#'queue.bind'{}))}
	].
	 

%% Test is_queue_def/1
%% ====================================================================
is_queue_def_test_() ->
	F = fun deck36_amqp_util:is_queue_def/1,
	[
	 {"+ Record", ?_assert(F(#'queue.declare'{queue = <<"Q">>}))},
	 {"+ Opts - queue only", ?_assert(F([{queue, <<"Q">>}]))},
	 {"+ Opts", ?_assert(F([{queue, <<"Q">>}, {durable, true}, {arguments, [<<"A">>]}]))},
	 {"- Empty list", ?_assertNot(F([]))},
	 {"- Exchange", ?_assertNot(F(#'exchange.declare'{}))},
	 {"- Binding", ?_assertNot(F(#'queue.bind'{}))}
	].
	 

%% Test exchange/1
%% ====================================================================
exchange_test_() ->
	Exchange = <<"exchange">>,
	Durable = true,
	Type = <<"fanout">>,
	Arguments = [{<<"x-ha-policy">>, longstr, <<"all">>}],
	Opts = [
			{exchange, Exchange},
			{durable, Durable},
			{type, Type},
			{arguments, Arguments}],
	ED = #'exchange.declare'{
							 exchange = Exchange,
							 durable = Durable,
							 type = Type,
							 arguments = Arguments },
	F = fun deck36_amqp_util:exchange/1,
	[
	 {"Identity", ?_assertEqual(ED, F(ED))},
	 {"Opts", ?_assertEqual(ED, F(Opts))},
	 {"Opts - exchange only", ?_assertEqual(#'exchange.declare'{exchange=Exchange},
											F([{exchange, Exchange}]))}
	].


%% Test is_exchange/1
%% ====================================================================
is_exchange_test_() ->
	F = fun deck36_amqp_util:is_exchange/1,
	[
	 {"+ Record", ?_assert(F(#'exchange.declare'{exchange = <<"E">>}))},
	 {"- Opts", ?_assertNot(F([{exchange, <<"E">>}, {durable, true}, {arguments, [<<"A">>]}]))},
	 {"- Empty list", ?_assertNot(F([]))},
	 {"- Queue", ?_assertNot(F(#'queue.declare'{}))},
	 {"- Binding", ?_assertNot(F(#'queue.bind'{}))}
	].


%% Test is_exchange_def/1
%% ====================================================================
is_exchange_def_test_() ->
	F = fun deck36_amqp_util:is_exchange_def/1,
	[
	 {"+ Record", ?_assert(F(#'exchange.declare'{exchange = <<"E">>}))},
	 {"+ Opts - exchange only", ?_assert(F([{exchange, <<"E">>}]))},
	 {"+ Opts", ?_assert(F([{exchange, <<"E">>}, {durable, true}, {arguments, [<<"A">>]}]))},
	 {"- Empty list", ?_assertNot(F([]))},
	 {"- Queue", ?_assertNot(F(#'queue.declare'{}))},
	 {"- Binding", ?_assertNot(F(#'queue.bind'{}))}
	].


%% Test binding/1
%% ====================================================================
binding_test_() ->
	Exchange = <<"exchange">>,
	Queue = <<"queue">>,
	RoutingKey = <<"routing_key">>,
	Opts1 = [
			{exchange, Exchange},
			{queue, Queue}],
	Expected1 = #'queue.bind'{
							  exchange = Exchange,
							  queue = Queue,
							  routing_key = <<>>},
	Opts2 = [{routing_key, RoutingKey}|Opts1],
	Expected2 = Expected1#'queue.bind'{routing_key = RoutingKey},
	F = fun deck36_amqp_util:binding/1,
	[
	 {"Identity", ?_assertEqual(Expected1, F(Expected1))},
	 {"Opts", ?_assertEqual(Expected1, F(Opts1))},
	 {"Identity - routing key", ?_assertEqual(Expected2, F(Expected2))},
	 {"Opts - routing key", ?_assertEqual(Expected2, F(Opts2))}
	].


%% Test is_binding/1
%% ====================================================================
is_binding_test_() ->
	F = fun deck36_amqp_util:is_binding/1,
	[
	 {"+ Record", ?_assert(F(#'queue.bind'{queue = <<"Q">>, exchange = <<"E">>}))},
	 {"- Opts", ?_assertNot(F([{queue, <<"Q">>}, {exchange, <<"E">>}, {routing_key, <<"R">>}]))},
	 {"- Empty list", ?_assertNot(F([]))},
	 {"- Opts queue only", ?_assertNot(F([{queue, <<"Q">>}]))},
	 {"- Opts exchange only", ?_assertNot(F([{exchange, <<"E">>}]))},
	 {"- Exchange", ?_assertNot(F(#'exchange.declare'{}))},
	 {"- Queue", ?_assertNot(F(#'queue.declare'{}))}
	].


%% Test is_binding_def/1
%% ====================================================================
is_binding_def_test_() ->
	F = fun deck36_amqp_util:is_binding_def/1,
	[
	 {"+ Record", ?_assert(F(#'queue.bind'{queue = <<"Q">>, exchange = <<"E">>}))},
	 {"+ Opts", ?_assert(F([{queue, <<"Q">>}, {exchange, <<"E">>}, {routing_key, <<"R">>}]))},
	 {"+ Opts Q & E only", ?_assert(F([{queue, <<"Q">>}, {exchange, <<"E">>}]))},
	 {"- Empty list", ?_assertNot(F([]))},
	 {"- Opts queue only", ?_assertNot(F([{queue, <<"Q">>}]))},
	 {"- Opts exchange only", ?_assertNot(F([{exchange, <<"E">>}]))},
	 {"- Exchange", ?_assertNot(F(#'exchange.declare'{}))},
	 {"- Queue", ?_assertNot(F(#'queue.declare'{}))}
	].


%% Test declaration/1
%% ====================================================================
declaration_test_() ->
	Exchange = <<"exchange">>,
	Queue = <<"queue">>,
	RoutingKey = <<"routing_key">>,
	OQ = {queue, [{queue, Queue}]},
	EQ = #'queue.declare'{queue = Queue},
	OE = {exchange, [{exchange, Exchange}]},
	EE = #'exchange.declare'{exchange = Exchange},
	OB = {binding, [{exchange, Exchange},{queue, Queue},{routing_key, RoutingKey}]},
	EB = #'queue.bind'{
					   exchange = Exchange,
					   queue = Queue,
					   routing_key = RoutingKey},
	T = fun(E, X) -> ?_assertEqual(E, deck36_amqp_util:declaration(X)) end,
	[
	 {"Identity Queue", T(EQ, EQ)},
	 {"Identity Exchange", T(EE, EE)},
	 {"Identity Binding", T(EB, EB)},
	 {"Opts Queue", T(EQ, OQ)},
	 {"Opts Exchange", T(EE, OE)},
	 {"Opts Binding", T(EB, OB)}
	].


%% Test is_declaration/1
%% ====================================================================
is_declaration_test_() ->
	F = fun deck36_amqp_util:is_declaration/1,
	[
	 {"+ Queue record", ?_assert(F(#'queue.declare'{queue = <<"Q">>}))},
	 {"+ Exchange record", ?_assert(F(#'exchange.declare'{exchange = <<"E">>}))},
	 {"+ Binding record", ?_assert(F(#'queue.bind'{queue = <<"Q">>, exchange = <<"E">>}))},
	 {"- Queue opts", ?_assertNot(F({queue, [{queue, <<"Q">>}, {durable, true}, {arguments, [<<"A">>]}]}))},
	 {"- Exchange opts", ?_assertNot(F({exchange, [{exchange, <<"E">>}, {durable, true}, {arguments, [<<"A">>]}]}))},
	 {"- Binding opts", ?_assertNot(F({binding, [{queue, <<"Q">>}, {exchange, <<"E">>}, {routing_key, <<"R">>}]}))},
	 {"- Empty list", ?_assertNot(F([]))},
	 {"- Opts binding queue only", ?_assertNot(F({binding, [{queue, <<"Q">>}]}))},
	 {"- Opts binding exchange only", ?_assertNot(F({binding, [{exchange, <<"E">>}]}))}
	].


%% Test is_definition/1
%% ====================================================================
is_definition_test_() ->
	F = fun deck36_amqp_util:is_definition/1,
	[
	 {"+ Queue record", ?_assert(F(#'queue.declare'{queue = <<"Q">>}))},
	 {"+ Queue opts - queue only", ?_assert(F({queue, [{queue, <<"Q">>}]}))},
	 {"+ Queue opts", ?_assert(F({queue, [{queue, <<"Q">>}, {durable, true}, {arguments, [<<"A">>]}]}))},
	 {"+ Exchange record", ?_assert(F(#'exchange.declare'{exchange = <<"E">>}))},
	 {"+ Exchange opts", ?_assert(F({exchange, [{exchange, <<"E">>}, {durable, true}, {arguments, [<<"A">>]}]}))},
	 {"+ Exchange opts - exchange only", ?_assert(F({exchange, [{exchange, <<"E">>}]}))},
	 {"+ Binding record", ?_assert(F(#'queue.bind'{queue = <<"Q">>, exchange = <<"E">>}))},
	 {"+ Binding opts", ?_assert(F({binding, [{queue, <<"Q">>}, {exchange, <<"E">>}, {routing_key, <<"R">>}]}))},
	 {"+ Binding opts - Q & E only", ?_assert(F({binding, [{queue, <<"Q">>}, {exchange, <<"E">>}]}))},
	 {"- Empty list", ?_assertNot(F([]))},
	 {"- Opts binding queue only", ?_assertNot(F({binding, [{queue, <<"Q">>}]}))},
	 {"- Opts binding exchange only", ?_assertNot(F({binding, [{exchange, <<"E">>}]}))}
	].


%% Test queue_delete/1
%% ====================================================================
queue_delete_test_() ->
	Queue = <<"queue">>,
	Durable = true,
	Args = [<<"some arg">>],
	Opts = [
			{queue, Queue},
			{durable, Durable},
			{arguments, Args} ],
	QD = #'queue.declare'{
						  queue = Queue,
						  durable = Durable,
						  arguments = Args},
	F = fun deck36_amqp_util:queue_delete/1,
	E = #'queue.delete'{queue = Queue},
	[
	 {"Identity", ?_assertEqual(E, F(E))},
	 {"Queue record", ?_assertEqual(E, F(QD))},
	 {"Opts", ?_assertEqual(E, F(Opts))},
	 {"Opts - queue only", ?_assertEqual(E, F([{queue, Queue}]))}
	].


%% Test is_queue_delete/1
%% ====================================================================
is_queue_delete_test_() ->
	F = fun deck36_amqp_util:is_queue_delete/1,
	[
	 {"+ Record", ?_assert(F(#'queue.delete'{queue = <<"Q">>}))},
	 {"- Queue record", ?_assertNot(F(#'queue.declare'{queue = <<"Q">>}))},
	 {"- Opts", ?_assertNot(F([{queue, <<"Q">>}, {durable, true}, {arguments, [<<"A">>]}]))},
	 {"- Empty list", ?_assertNot(F([]))},
	 {"- Exchange", ?_assertNot(F(#'exchange.declare'{}))},
	 {"- Binding", ?_assertNot(F(#'queue.bind'{}))}
	].
	 

%% Test is_queue_delete_def/1
%% ====================================================================
is_queue_delete_def_test_() ->
	F = fun deck36_amqp_util:is_queue_delete_def/1,
	[
	 {"+ Record", ?_assert(F(#'queue.delete'{queue = <<"Q">>}))},
	 {"+ Queue record", ?_assert(F(#'queue.declare'{queue = <<"Q">>}))},
	 {"+ Opts - queue only", ?_assert(F([{queue, <<"Q">>}]))},
	 {"+ Opts", ?_assert(F([{queue, <<"Q">>}, {durable, true}, {arguments, [<<"A">>]}]))},
	 {"- Empty list", ?_assertNot(F([]))},
	 {"- Exchange", ?_assertNot(F(#'exchange.declare'{}))},
	 {"- Binding", ?_assertNot(F(#'queue.bind'{}))}
	].
	 

%% Test exchange_delete/1
%% ====================================================================
exchange__deletetest_() ->
	Exchange = <<"exchange">>,
	Durable = true,
	Type = <<"fanout">>,
	Arguments = [{<<"x-ha-policy">>, longstr, <<"all">>}],
	Opts = [
			{exchange, Exchange},
			{durable, Durable},
			{type, Type},
			{arguments, Arguments}],
	ED = #'exchange.declare'{
							 exchange = Exchange,
							 durable = Durable,
							 type = Type,
							 arguments = Arguments },
	E = #'exchange.delete'{exchange = Exchange},
	F = fun deck36_amqp_util:exchange_delete/1,
	[
	 {"Identity", ?_assertEqual(E, F(E))},
	 {"Exchange record", ?_assertEqual(E, F(ED))},
	 {"Opts", ?_assertEqual(E, F(Opts))},
	 {"Opts - exchange only", ?_assertEqual(#'exchange.declare'{exchange=Exchange},
											F([{exchange, Exchange}]))}
	].


%% Test is_exchange_delete/1
%% ====================================================================
is_exchange_delete_test_() ->
	F = fun deck36_amqp_util:is_exchange_delete/1,
	[
	 {"+ Record", ?_assert(F(#'exchange.delete'{exchange = <<"E">>}))},
	 {"- Exchange record", ?_assertNot(F(#'exchange.declare'{exchange = <<"E">>}))},
	 {"- Opts", ?_assertNot(F([{exchange, <<"E">>}, {durable, true}, {arguments, [<<"A">>]}]))},
	 {"- Empty list", ?_assertNot(F([]))},
	 {"- Queue", ?_assertNot(F(#'queue.declare'{}))},
	 {"- Binding", ?_assertNot(F(#'queue.bind'{}))}
	].


%% Test is_exchange_delete_def/1
%% ====================================================================
is_exchange_delete_def_test_() ->
	F = fun deck36_amqp_util:is_exchange_delete_def/1,
	[
	 {"+ Record", ?_assert(F(#'exchange.delete'{exchange = <<"E">>}))},
	 {"+ Exchange record", ?_assert(F(#'exchange.declare'{exchange = <<"E">>}))},
	 {"+ Opts - exchange only", ?_assert(F([{exchange, <<"E">>}]))},
	 {"+ Opts", ?_assert(F([{exchange, <<"E">>}, {durable, true}, {arguments, [<<"A">>]}]))},
	 {"- Empty list", ?_assertNot(F([]))},
	 {"- Queue", ?_assertNot(F(#'queue.declare'{}))},
	 {"- Binding", ?_assertNot(F(#'queue.bind'{}))}
	].


%% Test binding_delete/1
%% ====================================================================
binding_delete_test_() ->
	Exchange = <<"exchange">>,
	Queue = <<"queue">>,
	RoutingKey = <<"routing_key">>,
	Opts1 = [
			{exchange, Exchange},
			{queue, Queue}],
	Expected1 = #'queue.unbind'{
							  exchange = Exchange,
							  queue = Queue,
							  routing_key = <<>>},
	Opts2 = [{routing_key, RoutingKey}|Opts1],
	Expected2 = Expected1#'queue.unbind'{routing_key = RoutingKey},
	F = fun deck36_amqp_util:binding_delete/1,
	[
	 {"Identity", ?_assertEqual(Expected1, F(Expected1))},
	 {"Opts", ?_assertEqual(Expected1, F(Opts1))},
	 {"Identity - routing key", ?_assertEqual(Expected2, F(Expected2))},
	 {"Opts - routing key", ?_assertEqual(Expected2, F(Opts2))}
	].


%% Test is_binding_delete/1
%% ====================================================================
is_binding_delete_test_() ->
	F = fun deck36_amqp_util:is_binding_delete/1,
	[
	 {"+ Record", ?_assert(F(#'queue.unbind'{queue = <<"Q">>, exchange = <<"E">>}))},
	 {"- Binding record", ?_assertNot(F(#'queue.bind'{queue = <<"Q">>, exchange = <<"E">>}))},
	 {"- Opts", ?_assertNot(F([{queue, <<"Q">>}, {exchange, <<"E">>}, {routing_key, <<"R">>}]))},
	 {"- Empty list", ?_assertNot(F([]))},
	 {"- Opts queue only", ?_assertNot(F([{queue, <<"Q">>}]))},
	 {"- Opts exchange only", ?_assertNot(F([{exchange, <<"E">>}]))},
	 {"- Exchange", ?_assertNot(F(#'exchange.declare'{}))},
	 {"- Queue", ?_assertNot(F(#'queue.declare'{}))}
	].


%% Test is_binding_delete_def/1
%% ====================================================================
is_binding_delete_def_test_() ->
	F = fun deck36_amqp_util:is_binding_delete_def/1,
	[
	 {"+ Record", ?_assert(F(#'queue.unbind'{queue = <<"Q">>, exchange = <<"E">>}))},
	 {"+ Binding record", ?_assert(F(#'queue.bind'{queue = <<"Q">>, exchange = <<"E">>}))},
	 {"+ Opts", ?_assert(F([{queue, <<"Q">>}, {exchange, <<"E">>}, {routing_key, <<"R">>}]))},
	 {"+ Opts Q & E only", ?_assert(F([{queue, <<"Q">>}, {exchange, <<"E">>}]))},
	 {"- Empty list", ?_assertNot(F([]))},
	 {"- Opts queue only", ?_assertNot(F([{queue, <<"Q">>}]))},
	 {"- Opts exchange only", ?_assertNot(F([{exchange, <<"E">>}]))},
	 {"- Exchange", ?_assertNot(F(#'exchange.declare'{}))},
	 {"- Queue", ?_assertNot(F(#'queue.declare'{}))}
	].


%% Test deletion/1
%% ====================================================================
deletion_test_() ->
	Exchange = <<"exchange">>,
	Queue = <<"queue">>,
	RoutingKey = <<"routing_key">>,
	OQ = {queue, [{queue, Queue}]},
	DQ = #'queue.declare'{queue = Queue},
	EQ = #'queue.delete'{queue = Queue},
	OE = {exchange, [{exchange, Exchange}]},
	DE = #'exchange.declare'{exchange = Exchange},
	EE = #'exchange.delete'{exchange = Exchange},
	OB = {binding, [{exchange, Exchange},{queue, Queue},{routing_key, RoutingKey}]},
	DB = #'queue.bind'{
					   exchange = Exchange,
					   queue = Queue,
					   routing_key = RoutingKey},
	EB = #'queue.unbind'{
					   exchange = Exchange,
					   queue = Queue,
					   routing_key = RoutingKey},
	T = fun(E, X) -> ?_assertEqual(E, deck36_amqp_util:deletion(X)) end,
	[
	 {"Identity Queue", T(EQ, EQ)},
	 {"Identity Exchange", T(EE, EE)},
	 {"Identity Binding", T(EB, EB)},
	 {"Record Queue", T(EQ, DQ)},
	 {"Record Exchange", T(EE, DE)},
	 {"Record Binding", T(EB, DB)},
	 {"Opts Queue", T(EQ, OQ)},
	 {"Opts Exchange", T(EE, OE)},
	 {"Opts Binding", T(EB, OB)}
	].


%% Test is_deletion/1
%% ====================================================================
is_deletion_test_() ->
	F = fun deck36_amqp_util:is_deletion/1,
	[
	 {"+ Queue delete", ?_assert(F(#'queue.delete'{queue = <<"Q">>}))},
	 {"+ Exchange delete", ?_assert(F(#'exchange.delete'{exchange = <<"E">>}))},
	 {"+ Binding delete", ?_assert(F(#'queue.unbind'{queue = <<"Q">>, exchange = <<"E">>}))},
	 {"- Queue record", ?_assertNot(F(#'queue.declare'{queue = <<"Q">>}))},
	 {"- Exchange record", ?_assertNot(F(#'exchange.declare'{exchange = <<"E">>}))},
	 {"- Binding record", ?_assertNot(F(#'queue.bind'{queue = <<"Q">>, exchange = <<"E">>}))},
	 {"- Queue opts", ?_assertNot(F({queue, [{queue, <<"Q">>}, {durable, true}, {arguments, [<<"A">>]}]}))},
	 {"- Exchange opts", ?_assertNot(F({exchange, [{exchange, <<"E">>}, {durable, true}, {arguments, [<<"A">>]}]}))},
	 {"- Binding opts", ?_assertNot(F({binding, [{queue, <<"Q">>}, {exchange, <<"E">>}, {routing_key, <<"R">>}]}))},
	 {"- Empty list", ?_assertNot(F([]))},
	 {"- Opts binding queue only", ?_assertNot(F({binding, [{queue, <<"Q">>}]}))},
	 {"- Opts binding exchange only", ?_assertNot(F({binding, [{exchange, <<"E">>}]}))}
	].


%% Test is_deletion_def/1
%% ====================================================================
is_deletion_def_test_() ->
	F = fun deck36_amqp_util:is_deletion_def/1,
	[
	 {"+ Queue delete", ?_assert(F(#'queue.delete'{queue = <<"Q">>}))},
	 {"+ Exchange delete", ?_assert(F(#'exchange.delete'{exchange = <<"E">>}))},
	 {"+ Binding delete", ?_assert(F(#'queue.unbind'{queue = <<"Q">>, exchange = <<"E">>}))},
	 {"+ Queue record", ?_assert(F(#'queue.declare'{queue = <<"Q">>}))},
	 {"+ Queue opts - queue only", ?_assert(F({queue, [{queue, <<"Q">>}]}))},
	 {"+ Queue opts", ?_assert(F({queue, [{queue, <<"Q">>}, {durable, true}, {arguments, [<<"A">>]}]}))},
	 {"+ Exchange record", ?_assert(F(#'exchange.declare'{exchange = <<"E">>}))},
	 {"+ Exchange opts", ?_assert(F({exchange, [{exchange, <<"E">>}, {durable, true}, {arguments, [<<"A">>]}]}))},
	 {"+ Exchange opts - exchange only", ?_assert(F({exchange, [{exchange, <<"E">>}]}))},
	 {"+ Binding record", ?_assert(F(#'queue.bind'{queue = <<"Q">>, exchange = <<"E">>}))},
	 {"+ Binding opts", ?_assert(F({binding, [{queue, <<"Q">>}, {exchange, <<"E">>}, {routing_key, <<"R">>}]}))},
	 {"+ Binding opts - Q & E only", ?_assert(F({binding, [{queue, <<"Q">>}, {exchange, <<"E">>}]}))},
	 {"- Empty list", ?_assertNot(F([]))},
	 {"- Opts binding queue only", ?_assertNot(F({binding, [{queue, <<"Q">>}]}))},
	 {"- Opts binding exchange only", ?_assertNot(F({binding, [{exchange, <<"E">>}]}))}
	].


%% Test amqp_msg/1
%% ====================================================================
amqp_msg_test_() ->
	E = #amqp_msg{payload = <<"payload">>},
	A = fun(T) -> ?_assertEqual(E, deck36_amqp_util:amqp_msg(T)) end,
	[
	 {"Identity", A(E)},
	 {"Binary", A(<<"payload">>)},
	 {"List", A("payload")}
	].

%% ====================================================================
%% Internal functions
%% ====================================================================


