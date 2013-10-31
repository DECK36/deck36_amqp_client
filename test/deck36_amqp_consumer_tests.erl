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
%% @doc Unit test for deck36_amqp_setup.


-module(deck36_amqp_consumer_tests).

%% ====================================================================
%% API functions
%% ====================================================================
-export([get_cb_f_1/1, get_cb_f_2/3]).

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
-record(state, {deliver_cb, channel, error_cb, acknowledge_mode,  requeue_on_error = true, handle_mode=non_blocking}).

%% Test is_valid_cb_opt/1
%% ====================================================================
is_valid_cb_opt_test_() ->
	F = fun deck36_amqp_consumer:is_valid_cb_opt/1,
	AT = fun(X) -> ?_assert(F(X)) end,
	ANT = fun(X) -> ?_assertNot(F(X)) end,
	[
	 {"+ {mod, fun}", AT({m, f})},
	 {"+ {mod, fun, args}", AT({m, f, [a,b]})},
	 {"+ fun", AT(fun(_X) -> ok end)},
	 {"- undefined", ANT(undefined)},
	 {"- {<<\"mod\">>, ...}", ANT({<<"m">>, f})},
	 {"- {\"mod\", ...}", ANT({"mod", f})},
	 {"- {integer, ...}", ANT({10, f})},
	 {"- {..., <<\"fun\">>}", ANT({m, <<"f">>})},
	 {"- {..., \"fun\"}", ANT({m, <<"f">>})},
	 {"- {..., integer}", ANT({m, 10})},
	 {"- {m, f, atom}", ANT({m, f, a})},
	 {"- {m, f, binary}", ANT({m, f, <<"a">>})},
	 {"- {m, f, integer}", ANT({m, f, 10})},
	 {"- fun/2", ANT(fun(_A,_B) -> ok end)}
	].


%% Test is_valid_deliver_cb_opt/1
%% ====================================================================
is_valid_deliver_cb_opt_test_() ->
	F = fun deck36_amqp_consumer:is_valid_deliver_cb_opt/1,
	AT = fun(X) -> ?_assert(F(X)) end,
	ANT = fun(X) -> ?_assertNot(F(X)) end,
	[
	 {"+ {mod, fun}", AT({m, f})},
	 {"+ {mod, fun, args}", AT({m, f, [a,b]})},
	 {"+ fun", AT(fun(_X) -> ok end)},
	 {"- undefined", ANT(undefined)},
	 {"- {<<\"mod\">>, ...}", ANT({<<"m">>, f})},
	 {"- {\"mod\", ...}", ANT({"mod", f})},
	 {"- {integer, ...}", ANT({10, f})},
	 {"- {..., <<\"fun\">>}", ANT({m, <<"f">>})},
	 {"- {..., \"fun\"}", ANT({m, <<"f">>})},
	 {"- {..., integer}", ANT({m, 10})},
	 {"- {m, f, atom}", ANT({m, f, a})},
	 {"- {m, f, binary}", ANT({m, f, <<"a">>})},
	 {"- {m, f, integer}", ANT({m, f, 10})},
	 {"- fun/2", ANT(fun(_A,_B) -> ok end)}
	].
	

%% Test is_valid_error_cb_opt/1
%% ====================================================================
is_valid_error_cb_opt_test_() ->
	F = fun deck36_amqp_consumer:is_valid_error_cb_opt/1,
	AT = fun(X) -> ?_assert(F(X)) end,
	ANT = fun(X) -> ?_assertNot(F(X)) end,
	[
	 {"+ {mod, fun}", AT({m, f})},
	 {"+ {mod, fun, args}", AT({m, f, [a,b]})},
	 {"+ fun", AT(fun(_X) -> ok end)},
	 {"+ undefined", AT(undefined)},
	 {"- {<<\"mod\">>, ...}", ANT({<<"m">>, f})},
	 {"- {\"mod\", ...}", ANT({"mod", f})},
	 {"- {integer, ...}", ANT({10, f})},
	 {"- {..., <<\"fun\">>}", ANT({m, <<"f">>})},
	 {"- {..., \"fun\"}", ANT({m, <<"f">>})},
	 {"- {..., integer}", ANT({m, 10})},
	 {"- {m, f, atom}", ANT({m, f, a})},
	 {"- {m, f, binary}", ANT({m, f, <<"a">>})},
	 {"- {m, f, integer}", ANT({m, f, 10})},
	 {"- fun/2", ANT(fun(_A,_B) -> ok end)}
	].


%% Test is_valid_acknowledge_mode_opt/1
%% ====================================================================
is_valid_acknowledge_mode_opt_test_() ->
	F = fun deck36_amqp_consumer:is_valid_acknowledge_mode_opt/1,
	AT = fun(X) -> ?_assert(F(X)) end,
	ANT = fun(X) -> ?_assertNot(F(X)) end,
	[
	 {"+ all", AT(all)},
	 {"+ error", AT(error)},
	 {"+ ok", AT(ok)},
	 {"+ undefined", AT(undefined)},
	 {"+ explicit", AT(explicit)},
	 {"- something", ANT(something)}
	].


%% Test is_valid_handle_mode_opt/1
%% ====================================================================
is_valid_handle_mode_opt_test_() ->
	F = fun deck36_amqp_consumer:is_valid_handle_mode_opt/1,
	AT = fun(X) -> ?_assert(F(X)) end,
	ANT = fun(X) -> ?_assertNot(F(X)) end,
	[
	 {"+ blocking", AT(blocking)},
	 {"+ non_blocking", AT(non_blocking)},
	 {"+ undefined", AT(undefined)},
	 {"- something", ANT(something)}
	].


%% Test get_cb/1
%% ====================================================================
get_cb_test_() ->
	F = fun(X) -> X end,
	T = fun(E, V, Fun) ->
				AFun = deck36_amqp_consumer:get_cb(Fun),
				?_assertEqual(E, AFun(V))
				end,
	[
	 {"fun", T(123, 123, F)},
	 {"mf", T(42, 42, {?MODULE, get_cb_f_1})},
	 {"mfa", T({a,b,c}, a, {?MODULE, get_cb_f_2, [b,c]})}
	].

get_cb_f_1(X) ->
	X.

get_cb_f_2(X, Y, Z) ->
	{X, Y, Z}.


%% Test shall_ack/2
%% ====================================================================
shall_ack_test_() ->
	T = [{all, error, true},
		 {all, ok, true},
		 {all, {ok, ack}, true},
		 {all, {ok, requeue}, false},
		 {ok, error, false},
		 {ok, ok, true},
		 {ok, {ok, ack}, true},
		 {ok, {ok, requeue}, false},
		 {error, error, true},
		 {error, ok, false},
		 {error, {ok, ack}, true},
		 {error, {ok, requeue}, false},
		 {explicit, error, false},
		 {explicit, ok, false},
		 {explicit, {ok, ack}, true},
		 {explicit, {ok, requeue}, false}],
	{"shall_ack_test_",
	 [
	  {lists:flatten(io_lib:format("~p", [Tx])),
	   ?_assertEqual(Ex,
					 deck36_amqp_consumer:shall_ack(Sx, Vx))}
	 || {Sx, Vx, Ex} = Tx <- T]}.
		 

%% Test cb/2
%% ====================================================================
cb_test_() ->
	F = fun(ok) -> ok;
		   (error) -> erlang:error(expected_error) end,
	T = fun(E, A) -> ?_assertEqual(E, deck36_amqp_consumer:cb(F,A)) end,
	[
	 {"OK", T(ok, ok)},
	 {"Error", T({error, expected_error}, error)}
	].


%% Test error_cb/2
%% ====================================================================
error_cb_test_() ->
	F = fun(ok) -> ok;
		   (error) -> erlang:error(expected_error) end,
	T = fun(E, A) -> ?_assertEqual(E, deck36_amqp_consumer:error_cb(F,A)) end,
	{setup,
	 fun() ->
			 mock_error_logger()
	 end,
	 fun(_) ->
			 unmock(error_logger)
	 end,
	 fun(_) ->
			 [
			  {"OK", T(ok, ok)},
			  {"Error", T({deck36_amqp_consumer, handle_deliver, error_cb, expected_error},
						  error)}
			 ]
	 end}.


%% Test ack_if/3
%% ====================================================================
ack_if_test_() ->
	test_mocked(
	  fun(_) ->
			  F = fun deck36_amqp_consumer:ack_if/4,
			  {"ack_if_test_",
			   [
				{"true", ?_assertEqual(mocked_channel_ok,
									   F(true, ch_mock, any, true))},
				{"false, requeue", ?_assertEqual(mocked_channel_nack_ok,
												 F(false, ch_mock, any, true))},
				{"false, dont requeue", ?_assertEqual(ok,
													  F(false, ch_mock, any, false))}
			   ]
			  }
	  end).


%% ====================================================================
%% Tests for API functions
%% ====================================================================

%% Test is_valid_opts/1
%% ====================================================================
%% "Further" testing is done in other is_valid_... tests 
is_valid_opts_test_() ->
	O = [{deliver_cb, {m, f}},
		 {error_cb, {m, f, [a,b]}},
		 {acknowledge_mode, all},
		 {handle_mode, blocking},
		 {some, value}],
	F = fun deck36_amqp_consumer:is_valid_opts/1,
	[
	 {"+ full", ?_assert(F(O))},
	 {"+ deliver_cb only", ?_assert(F([{deliver_cb, {m, f, [a,b]}}]))},
	 {"- empty", ?_assertNot(F([]))},
	 {"- deliver_cb missing", ?_assertNot(F(proplists:delete(deliver_cb, O)))}
	].


%% ====================================================================
%% Tests for behavioural functions
%% ====================================================================

%% Test init/1
%% ====================================================================
init_test_() ->
	O = [{deliver_cb, {m, f}},
		 {error_cb, {m, f, [a,b]}},
		 {acknowledge_mode, all},
		 {handle_mode, blocking},
		 {some, value}],
	?_assertMatch({ok, #state{}}, deck36_amqp_consumer:init([O])). 


%% Test handle_consume/3
%% ====================================================================
handle_consume_test_() ->
	?_assertMatch({ok, #state{}},
				  deck36_amqp_consumer:handle_consume(#'basic.consume'{}, any, #state{})).


%% Test handle_consume_ok/3
%% ====================================================================
handle_consume_ok_test_() ->
	?_assertMatch({ok, #state{}},
				  deck36_amqp_consumer:handle_consume_ok(#'basic.consume_ok'{},
														 #'basic.consume'{},
														 #state{})).


%% Test handle_cancel/2
%% ====================================================================
handle_cancel_test_() ->
	?_assertMatch({ok, #state{}},
				  deck36_amqp_consumer:handle_cancel(#'basic.cancel'{}, #state{})).


%% Test handle_cancel_ok/3
%% ====================================================================
handle_cancel_ok_test_() ->
	?_assertMatch({ok, #state{}},
				  deck36_amqp_consumer:handle_cancel_ok(#'basic.cancel_ok'{},
														 #'basic.cancel'{},
														 #state{})).


%% Test handle_deliver/3
%% ====================================================================
%% Mainly testing blocking and non_blocking modes here.
%% non_blocking mode should have a different pid while blocking mode
%% should have the same.
handle_deliver_test_() ->
	Self = self(),
	M = #amqp_msg{payload = <<"test">>},
	State = #state{
				   acknowledge_mode = explicit,
				   channel = undefined,
				   deliver_cb = fun(Msg) -> Self ! {self(), Msg}, ok end,
				   error_cb = fun(_) -> ok end,
				   handle_mode = blocking},
	F = fun(S) ->
				RHD = deck36_amqp_consumer:handle_deliver(#'basic.deliver'{}, M, S),
				RR = receive
						 X -> X
					 after
							 100 -> {error, timeout}
					 end,
				{RHD, RR}
		end,
	[
	 {"blocking",
	  fun() ->
			  {RHD, RR} = F(State),
			  ?assertMatch({ok, #state{}}, RHD),
			  ?assertMatch({Self, M}, RR)
	  end},
	 {"non-blocking",
	  fun() ->
			  {RHD, RR} = F(State#state{handle_mode = non_blocking}),
			  ?assertMatch({ok, #state{}}, RHD),
			  ?assertMatch({Pid, M} when Pid /= Self, RR)
	  end}
	].


%% Test handle_info/2
%% ====================================================================
handle_info_test_() ->
	?_assertMatch({ok, #state{}},
				  deck36_amqp_consumer:handle_info(any, #state{})).


%% Test handle_call/3
%% ====================================================================
handle_call_test_() ->
	F = fun deck36_amqp_consumer:handle_call/3,
	[
	 {"set_channel", ?_assertMatch(
	  {reply, ok, #state{channel = test_channel}},
	  F({set_channel, test_channel}, any, #state{}))},
	 {"anything", ?_assertMatch({reply, ok, #state{}}, F(any, any, #state{}))}
	].


%% Test terminate/2
%% ====================================================================
terminate_test_() ->
	?_assertEqual(ok, deck36_amqp_consumer:terminate(any, any)).


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
			 unmock(amqp_channel),
			 unmock(amqp_connection)
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
	ok = meck:expect(amqp_channel, cast,
					 fun(_, #'basic.ack'{}) -> mocked_channel_ok;
						(_, #'basic.nack'{}) -> mocked_channel_nack_ok
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

mock_error_logger() ->
	ok = meck:new(error_logger, [unstick, passthrough]),
	ok = meck:expect(error_logger, error_report, fun(R) -> R end),
	ok.


unmock(Mod) ->
	try
		meck:unload(Mod),
		code:ensure_loaded(Mod)
	catch
		error:{not_mocked,Mod} -> ok;
		error:Reason ->
			error_logger:error_report({?MODULE, unmock, Reason}),
			ok
	end.