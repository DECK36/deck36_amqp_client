%% ====================================================================
%%
%% Copyright (c) DECK36 GmbH & Co. KG, Burchardstraße 21, 20095 Hamburg/Germany and individual contributors.
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
%% @doc Unit test for deck36_amqp_setup.


-module(deck36_amqp_producer_tests).

%% ====================================================================
%% API functions
%% ====================================================================

-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("deck36_common/include/deck36_common.hrl").

-define(OPTS, [{connection, [{host, "1.2.3.4"},
							 {port, "1234"},
							 {virtual_host, <<"/">>},
							 {username, <<"">>},
							 {password, <<"">>}]},
			   {publish, [{exchange, <<"E">>}]}]).


%% ====================================================================
%% Tests for internal functions
%% ====================================================================
-record(state, { conn, publish, delivery_mode }).

%% Test get_publish/2
%% ====================================================================
get_publish_test_() ->
	T = fun(E, O) -> ?_assertMatch(E, deck36_amqp_producer:get_publish(O)) end,
	[
	 {"Queue", T(#'basic.publish'{exchange = <<>>, routing_key = <<"Q">>},
				 [{queue, [{queue, <<"Q">>}]}])},
	 {"Queue binary", T(#'basic.publish'{exchange = <<>>, routing_key = <<"Q">>},
						[{queue, <<"Q">>}])},
	 {"Exchange", T(#'basic.publish'{exchange = <<"E">>, routing_key = <<>>},
					[{exchange, [{exchange, <<"E">>}]}])},
	 {"Exchange binary", T(#'basic.publish'{exchange = <<"E">>, routing_key = <<>>},
						   [{exchange, <<"E">>}])},
	 {"Exchange w/ routing key", T(#'basic.publish'{exchange = <<"E">>, routing_key = <<"R">>},
								   [{exchange, [{exchange, <<"E">>}]}, {routing_key, <<"R">>}])},
	 {"Exchange binary w/ routing key", T(#'basic.publish'{exchange = <<"E">>, routing_key = <<"R">>},
										  [{exchange, <<"E">>}, {routing_key, <<"R">>}])}
	].


%% Test do_send/2
%% ====================================================================
do_send_test_() ->
	test_mocked(
	  fun(_) ->
			  Msg = #amqp_msg{props = #'P_basic'{delivery_mode = 1}, payload = <<"P">>},
			  Conn = deck36_amqp_connection:ensure_open(deck36_amqp_connection:new([])),
			  Publish = deck36_amqp_producer:get_publish([{queue, [{queue, <<"Q">>}]}]),
			  State = #state{ publish = Publish, conn = Conn, delivery_mode = 2},
			  T = fun(E, M, Mode) -> ?_assertMatch(E, deck36_amqp_producer:do_send(M, State, Mode)) end,
			  [
			   {"async w/ delivery_mode", T({mock_ch_ok, <<"P">>, 1}, Msg, async)},
			   {"async w/o delivery_mode", T({mock_ch_ok, <<"P">>, 2},
											 Msg#amqp_msg{props = #'P_basic'{delivery_mode = undefined}},
											 async)},
			   {"sync w/ delivery_mode", T({mock_ch_ok, <<"P">>, 1}, Msg, sync)},
			   {"sync w/o delivery_mode", T({mock_ch_ok, <<"P">>, 2},
											Msg#amqp_msg{props = #'P_basic'{delivery_mode = undefined}},
											sync)}
			  ]
	  end).


%% ====================================================================
%% Tests for behavioural functions
%% ====================================================================

%% Test init/1
%% ====================================================================
init_test_() ->
	test_mocked(
	  fun(_) ->
			  F = fun(X) -> deck36_amqp_producer:init([X]) end,
			  Es = #state{conn = mock_conn_open,
						  publish = #'basic.publish'{ exchange = <<"E">>, routing_key = <<>> },
						  delivery_mode = undefined}, 
			  [
			   {"Default delivery mode", ?_assertEqual({ok, Es}, F(?OPTS))},
			   {"Persistent delivery mode",
				?_assertEqual({ok, Es#state{delivery_mode = 2}},
							  F([{delivery_mode, persistent} | ?OPTS]))},
			   {"Error no publish", ?_assertError(function_clause, F([{connection, [dummy]}]))},
			   {"Error no connection", ?_assertError(function_clause, F([]))}
			  ]
	  end).


%% Test handle_call/3
%% ====================================================================
handle_call_test_() ->
	test_mocked(
	  fun(_) ->
			  S = #state{
						 conn = mock_conn_open,
						 publish = deck36_amqp_producer:get_publish([{exchange, <<"E">>}])},
%			  M = #amqp_msg{payload = <<"any">>},
			  F = fun deck36_amqp_producer:handle_call/3,
			  [
			   {"Stop", ?_assertEqual({stop, normal, ok, S}, F(stop, any, S))},
%%			   {"Send w/ open connection", ?_assertEqual({noreply, S}, F({send, M}, any, S))},
%% Not testing this here -> tested via send_sync_1_test_, send_sync_2_test_
			   {"Invalid", ?_assertEqual({reply, invalid_call, S}, F(any, any, S))}
			  ]
	  end).


%% Test handle_cast/2
%% ====================================================================
handle_cast_test_() ->
	F = fun deck36_amqp_producer:handle_cast/2,
	test_mocked(
	  fun(_) ->
			  S = #state{
						 conn = mock_conn_open,
						 publish = deck36_amqp_producer:get_publish([{exchange, <<"E">>}])},
			  M = #amqp_msg{payload = <<"any">>},
			  [
			   {"Send w/ open connection",
				?_assertEqual({noreply, S}, F({send, M}, S))},
			   {"Error send w/ closed connection",
				?_assertEqual({noreply, S#state{conn = mock_conn_closed}},
							  F({send, M}, S#state{conn = mock_conn_closed}))},
			   {"Any", ?_assertEqual({noreply, S}, F(any, S))}
			  ]
	  end).


%% Test handle_info/2
%% ====================================================================
handle_info_test_() ->
	?_assertEqual({noreply, #state{}}, deck36_amqp_producer:handle_info(any, #state{})).


%% Test terminate/2
%% ====================================================================
terminate_test_() ->
	test_mocked(
	  fun(_) ->
			  ?_assertEqual(ok, deck36_amqp_producer:terminate(any, #state{conn = mock_conn_open}))
	  end).


%% Test code_change/3
%% ====================================================================
code_change_test_() ->
	?_assertEqual({ok, #state{}}, deck36_amqp_producer:code_change(any, #state{}, any)).


%% ====================================================================
%% Tests for interface functions
%% ====================================================================

%% Test start_link/1, stop/2 unnamed
%% ====================================================================
start_stop_unnamed_test() ->
	mock_deck36_amqp_connection(),
	R1 = deck36_amqp_producer:start_link(?OPTS),
	?assertMatch({ok, Pid} when is_pid(Pid), R1),
	{ok, Pid} = R1,
	?assert(is_process_alive(Pid)),
	?assertEqual(ok, deck36_amqp_producer:stop(Pid)),
	?assertEqual(ok, deck36_test_util:wait_for_stop(Pid, 20)),
	deck36_test_util:unmock(deck36_amqp_connection).


%% Test start_link/1, stop/2 named
%% ====================================================================
start_stop_named_test() ->
	mock_deck36_amqp_connection(),
	R1 = deck36_amqp_producer:start_link([{server_ref, start_stop_named_test}|?OPTS]),
	?assertMatch({ok, Pid} when is_pid(Pid), R1),
	Pid = whereis(start_stop_named_test),
	?assert(is_process_alive(Pid)),
	?assertEqual(ok, deck36_amqp_producer:stop(start_stop_named_test)),
	?assertEqual(ok, deck36_test_util:wait_for_stop(Pid, 20)),
	deck36_test_util:unmock(deck36_amqp_connection).


%% Test start_link/1, stop/1 singleton
%% ====================================================================
start_stop_singleton_test() ->
	ServerName = deck36_amqp_producer,
	mock_deck36_amqp_connection(),
	R1 = deck36_amqp_producer:start_link([{server_ref, singleton}|?OPTS]),
	?assertMatch({ok, Pid} when is_pid(Pid), R1),
	Pid = whereis(ServerName),
	?assert(is_process_alive(Pid)),
	?assertEqual(ok, deck36_amqp_producer:stop()),
	?assertEqual(ok, deck36_test_util:wait_for_stop(Pid, 20)),
	deck36_test_util:unmock(deck36_amqp_connection).


%% Test send/1
%% ====================================================================
send_1_test_() ->
	{setup,
	 fun() ->
			 mock_amqp_channel(),
			 mock_deck36_amqp_connection(),
			 {ok, _}  = deck36_amqp_producer:start_link([{server_ref, singleton}|?OPTS])
	 end,
	 fun(_) ->
			 deck36_amqp_producer:stop(),
			 deck36_test_util:unmock(deck36_amqp_connection),
			 deck36_test_util:unmock(amqp_channel)
	 end,
	 fun(_) ->
			 [
			  {"Binary", ?_assertEqual(ok, deck36_amqp_producer:send(<<"test">>))},
			  {"AMQP msg", ?_assertEqual(ok, deck36_amqp_producer:send(#amqp_msg{payload = <<"test">>}))}
			 ]
	 end}.
	

%% Test send/2
%% ====================================================================
send_2_test() ->
	{setup,
	 fun() ->
			 mock_amqp_channel(),
			 mock_deck36_amqp_connection(),
			 {ok, Pid}  = deck36_amqp_producer:start_link(?OPTS),
			 Pid
	 end,
	 fun(Pid) ->
			 deck36_amqp_producer:stop(Pid),
			 deck36_test_util:unmock(deck36_amqp_connection),
			 deck36_test_util:unmock(amqp_channel)
	 end,
	 fun(Pid) ->
			 [
			  {"Binary", ?_assertEqual(ok, deck36_amqp_producer:send(Pid, <<"test">>))},
			  {"AMQP msg", ?_assertEqual(ok, deck36_amqp_producer:send(Pid, #amqp_msg{payload = <<"test">>}))}
			 ]
	 end}.


%% Test send_sync/1
%% ====================================================================
send_sync_1_test_() ->
	{setup,
	 fun() ->
			 mock_amqp_channel(),
			 mock_deck36_amqp_connection(),
			 {ok, _}  = deck36_amqp_producer:start_link([{server_ref, singleton}|?OPTS])
	 end,
	 fun(_) ->
			 deck36_amqp_producer:stop(),
			 deck36_test_util:unmock(deck36_amqp_connection),
			 deck36_test_util:unmock(amqp_channel)
	 end,
	 fun(_) ->
			 [
			  {"Binary", ?_assertEqual({mock_ch_ok, <<"test">>, undefined},
									   deck36_amqp_producer:send_sync(<<"test">>))},
			  {"AMQP msg", ?_assertEqual({mock_ch_ok, <<"test">>, undefined},
										 deck36_amqp_producer:send_sync(#amqp_msg{payload = <<"test">>}))}
			 ]
	 end}.


%% Test send_sync/2
%% ====================================================================
send_sync_2_test() ->
	{setup,
	 fun() ->
			 mock_amqp_channel(),
			 mock_deck36_amqp_connection(),
			 {ok, Pid}  = deck36_amqp_producer:start_link(?OPTS),
			 Pid
	 end,
	 fun(Pid) ->
			 deck36_amqp_producer:stop(Pid),
			 deck36_test_util:unmock(deck36_amqp_connection),
			 deck36_test_util:unmock(amqp_channel)
	 end,
	 fun(Pid) ->
			 [
			  {"Binary", ?_assertEqual({mock_ch_ok, <<"test">>, undefined},
									   deck36_amqp_producer:send_sync(Pid, <<"test">>))},
			  {"AMQP msg", ?_assertEqual({mock_ch_ok, <<"test">>, undefined},
										 deck36_amqp_producer:send_sync(Pid, #amqp_msg{payload = <<"test">>}))}
			 ]
	 end}.


%% Test delivery_mode/1
%% ====================================================================
delivery_mode_test_() ->
	T = fun(E, X) -> ?_assertEqual(E, deck36_amqp_producer:delivery_mode(X)) end,
	[
	 {"undefined", T(undefined, undefined)},
	 {"default", T(1, default)},
	 {"non_persistent", T(1, non_persistent)},
	 {"persistent", T(2, persistent)}
	].


%% ====================================================================
%% Internal functions
%% ====================================================================
test_mocked(Fun) ->
	{setup,
	 fun() ->
			 mock_amqp_channel(),
			 mock_amqp_connection(),
			 mock_deck36_amqp_connection()
	 end,
	 fun(_) ->
			 deck36_test_util:unmock(deck36_amqp_connection),
			 deck36_test_util:unmock(amqp_channel),
			 deck36_test_util:unmock(amqp_connection)
	 end,
	 Fun}.


mock_amqp_channel() ->
	ok = meck:new(amqp_channel, []),
	ok = meck:expect(amqp_channel, call,
					 fun(mock_ch, #'queue.declare'{}) ->	#'queue.declare_ok'{};
						(mock_ch, #'exchange.declare'{}) ->	#'exchange.declare_ok'{};
						(mock_ch, #'queue.bind'{}) ->		#'queue.bind_ok'{};
						(mock_ch, #'queue.delete'{}) ->		#'queue.delete_ok'{};
						(mock_ch, #'exchange.delete'{}) ->	#'exchange.delete_ok'{};
						(mock_ch, #'queue.unbind'{}) ->		#'queue.unbind_ok'{}
					 end),
	ok = meck:expect(amqp_channel, call,
					 fun(mock_ch, #'basic.publish'{}, #amqp_msg{props=Pr, payload=P}) ->
							 #'P_basic'{delivery_mode=D}=Pr,
							 {mock_ch_ok, P, D}
					 end),
	ok = meck:expect(amqp_channel, cast,
					 fun(_, #'basic.publish'{}, #amqp_msg{props=Pr, payload=P}) ->
							 #'P_basic'{delivery_mode=D}=Pr,
							 {mock_ch_ok, P, D}
					 end),
	ok = meck:expect(amqp_channel, close,
					 fun(invalid) -> ok;
						(mock_ch) -> ok;
						(Pid) -> Pid ! stop, ok end),
	ok.


mock_amqp_connection() ->
	ok = meck:new(amqp_connection, []),
	ok = meck:expect(amqp_connection, start,
					 fun(#amqp_params_network{}) -> {ok, proc_lib:spawn(fun() -> receive _ -> ok end end)};
						(#amqp_params_direct{}) -> {ok, proc_lib:spawn(fun() -> receive _ -> ok end end)};
						(_) -> {error, einval}
					 end),
	ok = meck:expect(amqp_connection, open_channel,
					 fun(Pid) when is_pid(Pid) ->
							 {ok, proc_lib:spawn(fun() -> receive _ -> ok end end)};
						(_) -> {error, einval}
					 end),
	ok = meck:expect(amqp_connection, close,
					 fun(Pid) when is_pid(Pid) -> Pid ! stop, ok;
						(_) -> ok end),
	ok.


mock_deck36_amqp_connection() ->
	ok = meck:new(deck36_amqp_connection, []),
	ok = meck:expect(deck36_amqp_connection, ensure_closed,
					 fun(mock_conn_open) -> mock_conn_closed;
						(mock_conn_closed) -> mock_conn_closed
					 end),
	ok = meck:expect(deck36_amqp_connection, new,
					 fun(_) -> mock_conn_closed end),
	ok = meck:expect(deck36_amqp_connection, ensure_open,
					 fun(mock_conn_closed) -> mock_conn_open;
						(mock_conn_open) -> mock_conn_open
					 end),
	ok = meck:expect(deck36_amqp_connection, get_channel,
					 fun(mock_conn_open) -> mock_ch;
						(mock_conn_closed) -> undefined
					 end),
	ok.

