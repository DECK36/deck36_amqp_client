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


-module(deck36_amqp_setup_tests).

%% ====================================================================
%% API functions
%% ====================================================================
-export([]).

-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("deck36_common/include/deck36_common.hrl").

-define(OPTS, [{connection, [{host, "1.2.3.4"},
							 {port, "1234"},
							 {virtual_host, <<"/">>},
							 {username, <<"">>},
							 {password, <<"">>}]},
			   {teardown_on_stop, [all]}]).


%% ====================================================================
%% Tests for internal functions
%% ====================================================================
-record(state, { conn, declarations, opts }).

%% Test td_rule/1
%% ====================================================================
td_rule_test_() ->
	T = fun(X) -> deck36_amqp_setup:td_rule(X) end,
	Pos = fun(A, E) -> lists:all(fun(Ex) -> lists:member(Ex, A) end, E) end,
	Neg = fun(A, E) -> lists:any(fun(Ax) -> not lists:member(Ax, E) end, A) end,
	N = fun(PN, Test) -> lists:flatten(io_lib:format("~p - ~s", [Test, PN])) end,
	Tests = [
			 {all, [q, e, b]},
			 {queues, [q]},
			 {exchanges, [e]},
			 {bindings, [b]}
			],
	[
	 [{N("positive", Test), ?_assert(Pos(T(Test), Expected))},
	  {N("negative", Test), ?_assertNot(Neg(T(Test), Expected))}]
	|| {Test, Expected} <- Tests].


%% Test should_td/2
%% ====================================================================
should_td_test_() ->
	T = fun(X, R) -> deck36_amqp_setup:should_td(X, R) end,
	N = fun(PN, Test) -> N2 = hd(erlang:tuple_to_list(Test)),
						 lists:flatten(io_lib:format("~p, ~s", [N2, PN])) end,
	F = fun(X) -> lists:flatten(io_lib:format("~p", [X])) end,
	Tests = [
			 {#'queue.declare'{}, [[q], [q, e]], [[], [b], [e]]},
			 {#'exchange.declare'{}, [[e], [q, e]], [[], [q], [b]]},
			 {#'queue.bind'{}, [[b], [q, b]], [[], [q], [e]]}
			],
	{"should_td_test_",
	 [[{N("positive", Test), [{F(R), ?_assert(T(Test, R))} || R <- RP]},
	   {N("negative", Test), [{F(R), ?_assertNot(T(Test, R))} || R <- RN]}]
	  || {Test, RP, RN} <- Tests]}.


%% Test split_td_rem_list/5
%% ====================================================================
split_td_rem_list_test_() ->
	Q = #'queue.declare'{},
	E = #'exchange.declare'{},
	B = #'queue.bind'{},
	D = [Q, E, B],
	T = fun(R, Expl) -> deck36_amqp_setup:split_td_rem_list(D, R, Expl) end,
	{"split_td_rem_list_test_",
	 [
	  {"none", ?_assertEqual({[], [Q, E, B]}, T([], []))},   
	  {"explicit", ?_assertEqual({[Q], [E, B]}, T([], [Q]))},   
	  {"exchange static", ?_assertEqual({[E], [Q, B]}, T([e], []))},
	  {"static", ?_assertEqual({[Q, E], [B]}, T([e, q], []))},
	  {"all", ?_assertEqual({[Q, E, B], []}, T([e, q, b], []))}
	 ]}.   


%% @todo implement test for do_declare, do_delete

%% get_teardown_list_test_/0 helper function
%% ====================================================================
get_teardown_list_test_fun(RulesOpts, EL) ->
	D = [deck36_amqp_util:declaration(X)
		|| X <- [
				 {queue, [{queue, <<"gtl_q">>}]},
				 {exchange, [{exchange, <<"gtl_e">>}]},
				 {binding, [{exchange, <<"gtl_e">>}, {queue, <<"gtl_q">>}]}
				]],
	O = [{teardown_on_stop, [{queue, [{queue, <<"explicit">>}]} | RulesOpts]}],
	A = deck36_amqp_setup:split_teardown_remaining(O, D),
	?assertMatch({_,_}, A),
	{ATD, _ARem} = A,
	FP = fun(#'queue.declare'{queue = <<"explicit">>}) -> true;
			(_) -> false end,
	AssertAny = fun(true, P, L) -> ?_assert(lists:any(P, L));
				   (false, P, L) -> ?_assertNot(lists:any(P, L)) end,
	[
	 [{Nx, AssertAny(Ex, Px, ATD)} || {Nx, Ex, Px} <- EL],
	 {"explicit", AssertAny(true, FP, ATD)}
	].
	

%% Test setup/1
%% ====================================================================
setup_test_() ->
	D = [{queue, [{queue, <<"setup_queue">>}]},
		 {exchange, [{exchange, <<"setup_exchange">>}]},
		 {binding, [{exchange, <<"setup_e">>}, {queue, <<"setup_q">>}]}
		],
	Opts = ?OPTS ++ [{teardown_on_stop, [all]} | D],
	Conn = deck36_amqp_connection:new(?GV(connection, ?OPTS)),
	S = #state{opts = Opts, conn = Conn},
	test_mocked(
	  fun() ->
			  R = deck36_amqp_setup:setup(S),
			  [
			   {"opts", ?_assertMatch({ok, #state{opts = Opts}}, R)},
			   {"declarations", ?_assertMatch({ok, #state{declarations = AD}} when length(AD) == 3, R)}
			  ]
	  end).


%% Test shutdown/1
%% ====================================================================
shutdown_test_() ->
	test_mocked(
	  fun(_) ->
			  ?_assertMatch({ok, #state{}}, deck36_amqp_setup:shutdown(#state{}))
	  end).


%% Test teardown_declare/1
%% ====================================================================
teardown_declare_test() ->
	[ {Nx, ?_assertMatch(Ex, deck36_amqp_setup:teardown_declare(Dx))}
	|| {Nx, Ex, Dx} <- [{"queue",
						 #'queue.delete'{queue = <<"Q">>},
						 #'queue.declare'{queue = <<"Q">>}},
						{"queue identity",
						 #'queue.delete'{queue = <<"Q">>},
						 #'queue.delete'{queue = <<"Q">>}},
						{"exchange",
						 #'exchange.delete'{exchange = <<"E">>},
						 #'exchange.declare'{exchange = <<"E">>}},
						{"exchange identity",
						 #'exchange.delete'{exchange = <<"E">>},
						 #'exchange.delete'{exchange = <<"E">>}},
						{"binding",
						 #'queue.unbind'{queue = <<"Q">>, exchange = <<"E">>, routing_key = <<"R">>, arguments = <<"A">>},
						 #'queue.bind'{queue = <<"Q">>, exchange = <<"E">>, routing_key = <<"R">>, arguments = <<"A">>}},
						{"binding identity",
						 #'queue.unbind'{queue = <<"Q">>, exchange = <<"E">>, routing_key = <<"R">>, arguments = <<"A">>},
						 #'queue.unbind'{queue = <<"Q">>, exchange = <<"E">>, routing_key = <<"R">>, arguments = <<"A">>}}
					   ]].



%% Test teardown/1
%% ====================================================================
teardown_test_() ->
	{setup,
	 fun() ->
			 mock_deck36_amqp_connection()
	 end,
	 fun(_) ->
			 deck36_test_util:unmock(deck36_amqp_connection)
	 end,
	 fun(_) ->
			 S = #state{opts = [{teardown_on_stop, [queues]}],
						declarations = [#'queue.declare'{queue = <<"Q">>},
										#'exchange.declare'{exchange = <<"E">>}]},
			 R = deck36_amqp_setup:teardown(S),
			 ?_assertMatch(#state{declarations = [#'exchange.declare'{exchange = <<"E">>}]}, R)
	  end}.


%% Test do_info/1
%% ====================================================================
do_info_test_() ->
	A = deck36_amqp_setup:do_info(#state{declarations = test_decs, opts = test_opts}),
	[
	 {"opts", ?_assertEqual(test_opts, ?GV(opts, A))},
	 {"declarations", ?_assertEqual(test_decs, ?GV(declarations, A))}
	].


%% Test do_declare/2
%% ====================================================================
do_declare_test_() ->
	test_deck36_amqp_connection_mocked(
	  fun(_) ->
			  TDecs = [#'exchange.declare'{exchange = <<"E">>},
					   #'queue.bind'{exchange = <<"E">>, queue = <<"Q">>}],
			  SDecs = [#'queue.declare'{queue = <<"Q">>}],
			  S = #state{declarations = SDecs},
			  EDecs = [#'queue.bind'{exchange = <<"E">>, queue = <<"Q">>},
					   #'exchange.declare'{exchange = <<"E">>}
											  | SDecs], 
			  E = {ok, #state{declarations = EDecs}},
			  ?_assertEqual(E, deck36_amqp_setup:do_declare(TDecs, S))
	  end).


%% Test prepare_deletion/3
%% ====================================================================
prepare_deletion_test_() ->
	Del1 = #'exchange.delete'{exchange = <<"E">>},
	Del2 = #'queue.delete'{queue = <<"Q">>},
	Dec2 = #'queue.declare'{queue = <<"Q">>, durable = true},
	SDelDecs = [{Del2, Dec2}],
	F = fun(X) -> deck36_amqp_setup:prepare_deletion(X, SDelDecs) end,
	T = fun(E, X) -> ?_assertEqual(E, F(X)) end,
	[
	 {"Deletion not declared", T({undefined, Del1}, Del1)},
	 {"Deletion declared", T({Dec2, Del2}, Del2)},
	 {"Declaration declared", T({Dec2, Del2}, Dec2)},
	 {"Error declaration not declared",
	  ?_assertError(X when is_list(X), F(#'exchange.declare'{exchange = <<"E">>}))}
	].


%% Test do_delete/2
%% ====================================================================
do_delete_test_() ->
	test_deck36_amqp_connection_mocked(
	  fun(_) ->
			  EDecs = [#'exchange.declare'{exchange = <<"E">>}],
			  SDecs = [#'queue.declare'{queue = <<"Q">>} | EDecs],
			  S = #state{declarations = SDecs},
			  E1 = {ok, #state{declarations = EDecs}},
			  E2 = {ok, #state{declarations = SDecs}},
			  F = fun deck36_amqp_setup:do_delete/2,
			  [
			   {"Declaration",
				?_assertEqual(E1, F([#'queue.declare'{queue = <<"Q">>}], S))},
			   {"Deletion declare",
				?_assertEqual(E1, F([#'queue.delete'{queue = <<"Q">>}], S))},
			   {"Deletion not declared",
				?_assertEqual(E2, F([#'queue.unbind'{queue = <<"Q">>, exchange = <<"E">>}], S))},
			   {"Error",
				?_assertError(X when is_list(X), F([#'queue.declare'{queue = <<"Q1">>}], S))},
			   {"Multiple",
				?_assertEqual(E1, F([#'queue.declare'{queue = <<"Q">>}, #'exchange.delete'{exchange = <<"E2">>}], S))}
			  ]
	  end).


%% ====================================================================
%% Tests for interface functions
%% ====================================================================

%% Test start_link/1
%% ====================================================================
start_link_test() ->
	mock_amqp_channel(),
	mock_amqp_connection(),
	?assertMatch({ok, Pid} when is_pid(Pid), deck36_amqp_setup:start_link(?OPTS)),
	deck36_test_util:unmock(amqp_channel),
	deck36_test_util:unmock(amqp_connection).


%% Test stop/1
%% ====================================================================
stop_test() ->
	mock_amqp_channel(),
	mock_amqp_connection(),
	{ok, Pid} = deck36_amqp_setup:start_link(?OPTS),
	?assert(is_process_alive(Pid)),
	?assertEqual(ok, deck36_amqp_setup:stop(Pid)),
	?assertEqual(ok, deck36_test_util:wait_for_stop(Pid, 20)),
	deck36_test_util:unmock(amqp_channel),
	deck36_test_util:unmock(amqp_connection).


%% Test info/1
%% ====================================================================
info_test() ->
	mock_amqp_channel(),
	mock_amqp_connection(),
	{ok, Pid} = deck36_amqp_setup:start_link(?OPTS),
	Info = deck36_amqp_setup:info(Pid),
	?assert(is_list(Info)),
	deck36_amqp_setup:stop(Pid),
	deck36_test_util:unmock(amqp_channel),
	deck36_test_util:unmock(amqp_connection).


%% ====================================================================
%% Internal functions
%% ====================================================================
test_mocked(Fun) ->
	{setup,
	 fun() ->
			 mock_amqp_channel(),
			 mock_amqp_connection()
	 end,
	 fun(_) ->
			 deck36_test_util:unmock(amqp_channel),
			 deck36_test_util:unmock(amqp_connection)
	 end,
	 Fun}.


test_deck36_amqp_connection_mocked(Fun) ->
	{setup,
	 fun() ->
			 mock_deck36_amqp_connection()
	 end,
	 fun(_) ->
			 deck36_test_util:unmock(deck36_amqp_connection)
	 end,
	 Fun}.


mock_amqp_channel() ->
	ok = meck:new(amqp_channel, []),
	ok = meck:expect(amqp_channel, call,
					 fun(_, #'queue.declare'{}) ->		#'queue.declare_ok'{};
						(_, #'exchange.declare'{}) ->	#'exchange.declare_ok'{};
						(_, #'queue.bind'{}) ->			#'queue.bind_ok'{};
						(_, #'queue.delete'{}) ->		#'queue.delete_ok'{};
						(_, #'exchange.delete'{}) ->	#'exchange.delete_ok'{};
						(_, #'queue.unbind'{}) ->		#'queue.unbind_ok'{}
					 end),
	ok = meck:expect(amqp_channel, close,
					 fun(invalid) -> ok;
						(ch_mock) -> ok;
						(Pid) -> Pid ! stop, ok end),
	ok.


mock_amqp_connection() ->
	ok = meck:new(amqp_connection, []),
	ok = meck:expect(amqp_connection, start,
					 fun(#amqp_params_network{}) -> {ok, erlang:spawn(fun() -> receive _ -> ok end end)};
						(#amqp_params_direct{}) -> {ok, erlang:spawn(fun() -> receive _ -> ok end end)};
						(_) -> {error, einval}
					 end),
	ok = meck:expect(amqp_connection, open_channel,
					 fun(Pid) when is_pid(Pid) ->
							 {ok, erlang:spawn(fun() -> receive _ -> ok end end)};
						(_) -> {error, einval}
					 end),
	ok = meck:expect(amqp_connection, close,
					 fun(Pid) when is_pid(Pid) -> Pid ! stop, ok;
						(_) -> ok end),
	ok.


mock_deck36_amqp_connection() ->
	ok = meck:new(deck36_amqp_connection, []),
	ok = meck:expect(deck36_amqp_connection, open_call_close,
					 fun(_, L) -> true = lists:all(
										   fun(#'queue.delete'{}) -> true;
											  (#'exchange.delete'{}) -> true;
											  (#'queue.unbind'{}) -> true;
											  (_) -> false end, L)
					 end),
	ok = meck:expect(deck36_amqp_connection, open_declare_close,
					 fun(_, L) -> true = lists:all(
										   fun(#'queue.declare'{}) -> true;
											  (#'exchange.declare'{}) -> true;
											  (#'queue.bind'{}) -> true;
											  (#'queue.unbind'{}) -> true;
											  (#'queue.delete'{}) -> true;
											  (#'exchange.delete'{}) -> true;
											  (_) -> false end, L),
								  ok
					 end),
	ok.
	