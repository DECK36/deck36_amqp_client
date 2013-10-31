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


-module(deck36_amqp_consumer_container_tests).

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
			   {queue, [{queue, <<"Q">>}]},
			   {type, {callback, [{deliver_cb, fun(_) -> ok end}]}}]).


%% ====================================================================
%% Tests for internal functions
%% ====================================================================
-record(state, {conn, queue, consumer_tag, consumer_def}).

%% Test shutdown/1
%% ====================================================================
shutdown_test_() ->
	{setup,
	 fun() ->
			 mock_deck36_amqp_connection()
	 end,
	 fun(_) ->
			 unmock(deck36_amqp_connection)
	 end,
	 fun(_) ->
			 ?_assertMatch({ok, #state{conn = mock_conn_closed}},
						   deck36_amqp_consumer_container:shutdown(#state{conn = mock_conn_open}))
	 end}.


%% Test gen_amqp_gen_consumer_def/1
%% ====================================================================
get_amqp_gen_consumer_def_test_() ->
	F = fun deck36_amqp_consumer_container:get_amqp_gen_consumer_def/1,
	[
	 {"callback",
	  ?_assertMatch({deck36_amqp_consumer, [_]}, F({callback, [{deliver_cb, {m,f}}]}))},
	 {"gen_consumer tuple args",
	  ?_assertEqual({m, [a,b]}, F({gen_consumer, {m, [a,b]}}))},
	 {"gen_consumer tuple arg",
	  ?_assertEqual({m, [a]}, F({gen_consumer, {m, a}}))},
	 {"gen_consumer list args",
	  ?_assertEqual({m, [a,b]}, F({gen_consumer, [{module, m}, {args, [a,b]}]}))},
	 {"gen_consumer list arg",
	  ?_assertEqual({m, [a]}, F({gen_consumer, [{module, m}, {args, a}]}))}
	].


%% Test handle_call/3
%% ====================================================================
handle_call_test_() ->
	F = fun deck36_amqp_consumer_container:handle_call/3,
	[
	 {"stop", ?_assertMatch({stop, normal, ok, #state{}},
							F(stop, any, #state{}))},
	 {"any", ?_assertMatch({reply, {error, not_implemented}, #state{}},
						   F(any, any, #state{}))}
	].
							

%% Test handle_cast/2
%% ====================================================================
handle_cast_test_() ->
	?_assertMatch({noreply, #state{}},
				  deck36_amqp_consumer_container:handle_cast(any, #state{})).


%% Test handle_info/2
%% ====================================================================
handle_info_test_() ->
	?_assertMatch({noreply, #state{}},
				  deck36_amqp_consumer_container:handle_info(any, #state{})).


%% Test terminate/2
%% ====================================================================
terminate_test_() ->
	{setup,
	 fun() ->
			 mock_deck36_amqp_connection()
	 end,
	 fun(_) ->
			 unmock(deck36_amqp_connection)
	 end,
	 fun(_) ->
			 ?_assertMatch(ok,
						   deck36_amqp_consumer_container:terminate(any,
																	#state{conn = mock_conn_open}))
	 end}.


%% Test code_change/3
%% ====================================================================
code_change_test_() ->
	?_assertMatch({ok, #state{}},
				  deck36_amqp_consumer_container:code_change(any, #state{}, any)).


%% ====================================================================
%% Tests for behavioural functions
%% ====================================================================

%% Test init/1
%% ====================================================================
init_test_() ->
	test_mocked(
	  fun(_) ->
			  ?_assertMatch({ok, #state{}}, deck36_amqp_consumer_container:init([?OPTS]))
	  end).


%% ====================================================================
%% Tests for interface functions
%% ====================================================================

%% Test start_link/1, stop/1
%% ====================================================================
start_stop_test() ->
	mock_amqp_channel(),
	mock_amqp_connection(),
	mock_deck36_amqp_connection(),
	R1 = deck36_amqp_consumer_container:start_link(?OPTS),
	?assertMatch({ok, Pid} when is_pid(Pid), R1),
	{ok, Ref} = R1,
	?assert(erlang:is_process_alive(Ref)),
	?assertEqual(ok, deck36_amqp_consumer_container:stop(Ref)),
	?assertNot(erlang:is_process_alive(Ref)),
	unmock(deck36_amqp_connection),
	unmock(amqp_connection),
	unmock(amqp_channel),
	ok.


%% Test suspend/1, resume/1
%% ====================================================================
suspend_resume_test() ->
	mock_amqp_channel(),
	mock_amqp_connection(),
	mock_deck36_amqp_connection(),
	Mod = deck36_amqp_consumer_container,
	{ok, Ref} = Mod:start_link(?OPTS),
	?assert(Mod:is_consuming(Ref)),
	?assertEqual(ok, Mod:suspend(Ref)),
	?assertNot(Mod:is_consuming(Ref)),
	?assertEqual(ok, Mod:resume(Ref)),
	?assert(Mod:is_consuming(Ref)),
	unmock(deck36_amqp_connection),
	unmock(amqp_connection),
	unmock(amqp_channel),
	ok.
	


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
			 unmock(deck36_amqp_connection),
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
						(_, #'queue.unbind'{}) ->		#'queue.unbind_ok'{};
						(_, #'basic.consume'{}) ->		#'basic.consume_ok'{consumer_tag = mock_tag};
						(_, #'basic.cancel'{consumer_tag = mock_tag}) ->
							 							#'basic.cancel_ok'{}
					 end),
	ok = meck:expect(amqp_channel, close,
					 fun(invalid) -> ok;
						(ch_mock) -> ok;
						(Pid) -> Pid ! stop, ok end),
	ok = meck:expect(amqp_channel, call_consumer,
					 fun(mock_ch, {set_channel, mock_ch}) -> ok end),
	ok.


mock_amqp_connection() ->
	ok = meck:new(amqp_connection, [passthrough]),
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
	ok = meck:expect(deck36_amqp_connection, ensure_closed,
					 fun(mock_conn_open) -> mock_conn_closed;
						(mock_conn_closed) -> mock_conn_closed
					 end),
	ok = meck:expect(deck36_amqp_connection, new,
					 fun(_) -> mock_conn_closed end),
	ok = meck:expect(deck36_amqp_connection, ensure_open,
					 fun(mock_conn_closed, _) -> mock_conn_open;
						(mock_conn_open, _) -> mock_conn_open
					 end),
	ok = meck:expect(deck36_amqp_connection, get_channel,
					 fun(mock_conn_open) -> mock_ch;
						(mock_conn_closed) -> undefined
					 end),
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