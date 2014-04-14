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


-module(deck36_amqp_connection_tests).

%% ====================================================================
%% API functions
%% ====================================================================
-export([]).

-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("deck36_common/include/deck36_common.hrl").

-define(OPTS, [{host, "1.2.3.4"},
			   {port, "1234"},
			   {virtual_host, <<"/">>},
			   {username, <<"u">>},
			   {password, <<"p">>}]).


%% ====================================================================
%% Tests for internal functions
%% ====================================================================

%% Test host/1
%% ====================================================================
host_test_() ->
	T = fun deck36_amqp_connection:host/1,
	[
	 {"List OK", ?_assertEqual("host", T("host"))},
	 {"List Error (non-printable)", ?_assertError(einval, T([a,b]))}
	].


%% Test bin/1
%% ====================================================================
bin_test_() ->
	T = fun(E, X) -> ?_assertEqual(E, deck36_amqp_connection:bin(X)) end,
	[
	 {"Bin", T(<<"a">>, <<"a">>)},
	 {"List", T(<<"b">>, "b")}
	].


%% Test open_channel/2
%% ====================================================================
open_channel_test_() ->
	T = fun(Conn, Cons) ->
				?_assertMatch({ok, Pid} when is_pid(Pid),
							  deck36_amqp_connection:open_channel(Conn, Cons))
		end,
	test_mocked(
		fun({Conn, _Ch}) ->
			[
			 {"w/o consumer", T(Conn, undefined)},
			 {"w/ consumer", T(Conn, a_consumer)}
			]
		end).

%% ====================================================================
%% Tests
%% ====================================================================
-record(state, { params, conn, ch }).


%% Test params/1
%% ====================================================================
params_test_() ->
	E = #amqp_params_network{
							 host = "1.2.3.4",
							 port = 1234,
							 virtual_host = <<"/">>,
							 username = <<"u">>,
							 password = <<"p">>},
	T = fun(Exp, X) -> ?_assertMatch(Exp, deck36_amqp_connection:params(X)) end,
	[
	 {"Identity Network", T(E, E)},
	 {"Identity Direct", T(#amqp_params_direct{}, #amqp_params_direct{})},
	 {"Opts", T(E, ?OPTS)}
	].
	



%% Test new/1
%% ====================================================================
new_test_() ->
	P = deck36_amqp_connection:params(?OPTS),
	?_assertMatch(#state{params = P, conn = undefined, ch = undefined},
				  deck36_amqp_connection:new(?OPTS)).


%% Test get_channel/1
%% ====================================================================
getters_test_() ->
	P = deck36_amqp_connection:params(?OPTS),
	C = deck36_amqp_connection:new(?OPTS),
	[
	 {"get_channel/1 undef", ?_assertEqual(undefined, deck36_amqp_connection:get_channel(C))},
	 {"get_channel/1 mock", ?_assertEqual(ch_mock, deck36_amqp_connection:get_channel(C#state{ch = ch_mock}))},
	 {"get_connection/1 undef", ?_assertEqual(undefined, deck36_amqp_connection:get_connection(C))},
	 {"get_connection/1 mock", ?_assertEqual(conn_mock, deck36_amqp_connection:get_connection(C#state{conn = conn_mock}))},
	 {"get_params/1", ?_assertEqual(P, deck36_amqp_connection:get_params(C))}
	].


%% Test ensure_open/1
%% ====================================================================
ensure_open_test_() ->
	test_mocked(
	 fun({Conn, Ch}) ->
			 S = deck36_amqp_connection:new(?OPTS),
			 [
			  {Nx, ?_assertMatch(#state{conn=ConnPid,ch=ChPid} when is_pid(ConnPid) and is_pid(ChPid),
								 deck36_amqp_connection:ensure_open(Sx))}
			 || {Nx, Sx} <- [{"conn=undef, ch=undef", S},
%							 {"conn=undef, ch=invalid", S#state{ch = invalid}},
							 {"conn=mock, ch=undef", S#state{conn = Conn}},
							 {"conn=mock, ch=mock", S#state{conn = Conn, ch = Ch}}]]
	 end).


%% Test ensure_closed/1
%% ====================================================================
ensure_closed_test_() ->
	test_mocked(
	  fun({Conn, Ch}) ->
			  S = #state{conn = undefined, ch = undefined},
			  [
			   {Nx, ?_assertMatch(#state{conn=undefined, ch=undefined},
								  deck36_amqp_connection:ensure_closed(Sx))}
			   || {Nx, Sx} <- [{"conn=undef, ch=undef", S},
							   {"conn=mock, ch=undef", S#state{conn = Conn}},
							   {"conn=undefined, ch=mock", S#state{ch = Ch}},
							   {"conn=mock, ch=mock", S#state{ch = Ch, conn = Conn}}]]
	  end).


%% Test is_open/1
%% ====================================================================
is_open_test_() ->
	{setup,
	 fun() ->
			 {erlang:spawn(fun() -> receive _ -> ok end end),
			  erlang:spawn(fun() -> receive _ -> ok end end),
			  erlang:spawn(fun() -> ok end)}
	 end,
	 fun({Conn, Ch, _}) ->
			 Conn ! stop,
			 Ch ! stop
	 end,
	 fun({Conn, Ch, Dead}) ->
			 F = fun deck36_amqp_connection:is_open/1,
			 [
			  {"+ OK", ?_assert(F(#state{ch = Ch, conn = Conn}))}, 
			  {"- Ch undefined", ?_assertNot(F(#state{ch = undefined, conn = Conn}))}, 
			  {"- Conn undefined", ?_assertNot(F(#state{ch = Ch, conn = undefined}))}, 
			  {"- Ch dead", ?_assertNot(F(#state{ch = Dead, conn = Conn}))}, 
			  {"- Conn dead", ?_assertNot(F(#state{ch = Ch, conn = Dead}))},
  			  {"- Ch & Conn dead", ?_assertNot(F(#state{ch = Dead, conn = Dead}))}
			 ]
	 end}.
 

%% Test declare/2
%% ====================================================================
declare_test_() ->
	T = fun(X) -> deck36_amqp_connection:declare(ch_mock, X) end,
	test_mocked(
	  fun(_) ->
			[
			 {"Queue", ?_assertEqual(ok, T(#'queue.declare'{}))},
			 {"Exchange", ?_assertEqual(ok, T(#'exchange.declare'{}))},
			 {"Binding", ?_assertEqual(ok, T(#'queue.bind'{}))},
			 {"Queue delete", ?_assertEqual(ok, T(#'queue.delete'{}))},
			 {"Exchange delete", ?_assertEqual(ok, T(#'exchange.delete'{}))},
			 {"Binding delete", ?_assertEqual(ok, T(#'queue.unbind'{}))},
			 {"Invalid", ?_assertError(function_clause, T(invalid))}
			]
	  end).


%% Test open_apply_close/2
%% ====================================================================
open_apply_close_test_() ->
	T = fun deck36_amqp_connection:open_apply_close/2,
	test_mocked(
	  fun(_) ->
			  S = deck36_amqp_connection:new(?OPTS),
			  [
			   {"OK", ?_assertEqual(expected, T(S, fun(_Ch) -> expected end))},
			   {"Exception", ?_assertException(error, oh_no,
											   T(S, fun(_Ch) -> erlang:error(oh_no) end))}
			  ]
	  end).
			  
							
%% Test open_call_close/2
%% ====================================================================
open_call_close_test_() ->
	T = fun deck36_amqp_connection:open_call_close/2,
	test_mocked(
	  fun(_) ->
			  S = deck36_amqp_connection:new(?OPTS),
			  [
			   {"OK One", ?_assertEqual(#'queue.declare_ok'{}, T(S, #'queue.declare'{}))},
			   {"OK Many", ?_assertEqual([#'queue.declare_ok'{}, #'queue.declare_ok'{}],
										 T(S, [#'queue.declare'{}, #'queue.declare'{}]))},
			   {"Exception", ?_assertException(error, function_clause, T(S, invalid))}
			  ]
	  end).


%% Test open_declare_close/2
%% ====================================================================
open_declare_close_test_() ->
	T = fun deck36_amqp_connection:open_declare_close/2,
	test_mocked(
	  fun(_) ->
			  S = deck36_amqp_connection:new(?OPTS),
			  [
			   {"OK One", ?_assertEqual(ok, T(S, #'queue.declare'{}))},
			   {"OK Many", ?_assertEqual(ok, T(S, [#'queue.declare'{},
												   #'exchange.declare'{}]))},
			   {"Exception", ?_assertException(error, function_clause, T(S, invalid))}
			  ]
	  end).


%% ====================================================================
%% Internal functions
%% ====================================================================
test_mocked(Fun) ->
	{setup,
	 fun() ->
			 mock_amqp_connection(),
			 mock_amqp_channel(),
			 {erlang:spawn(fun() -> receive _ -> ok end end),
			  erlang:spawn(fun() -> receive _ -> ok end end)}
	 end,
	 fun({Conn, Ch}) ->
			 Conn ! stop,
			 Ch ! stop,
			 deck36_test_util:unmock(amqp_channel),
			 deck36_test_util:unmock(amqp_connection)
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
					 fun(Pid) when is_pid(Pid) -> {ok, erlang:spawn(fun() -> receive _ -> ok end end)};
						(_) -> {error, einval}
					 end),
	ok = meck:expect(amqp_connection, open_channel,
					 fun(Pid, _Consumer) when is_pid(Pid) -> {ok, erlang:spawn(fun() -> receive _ -> ok end end)};
						(_, _) -> {error, einval}
					 end),
	ok = meck:expect(amqp_connection, close,
					 fun(Pid) when is_pid(Pid) -> Pid ! stop, ok;
						(_) -> ok end),
	ok.

