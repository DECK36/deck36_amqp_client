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
%% @doc Unit test for deck36_amqp_consumer_sup.

-module(deck36_amqp_consumer_sup_tests).

%% ====================================================================
%% API functions
%% ====================================================================
-export([]).

-include_lib("eunit/include/eunit.hrl").
-include_lib("deck36_common/include/deck36_common.hrl").

-define(MOD, deck36_amqp_consumer_sup).

%% ====================================================================
%% Tests for interface functions
%% ====================================================================

%% Test singleton
%% ====================================================================
singleton_test() ->
	mock_deck36_amqp_consumer_container(),
	% Fail
	Self = self(),
	proc_lib:spawn(fun() -> R1 = ?MOD:start_link(singleton, [[fail], [fail]]), Self ! R1 end),
	R2 = receive
			 X -> X
		 after 100 -> {error, timeout}
		 end,
	?assertMatch({error, {consumers_failed, [{error, {P1, [fail], failtest}}, {error, {P1, [fail], failtest}}]}} when is_pid(P1), R2),
	?assertEqual(ok, deck36_test_util:wait_for_stop(?MOD, 20)),
	% Success
	R3 = ?MOD:start_link(singleton, [[], []]),
	?assertMatch({ok, P} when is_pid(P), R3),
	{ok, Pid} = R3,
	?assertEqual(Pid, whereis(?MOD)),
	deck36_test_util:unmock(deck36_amqp_consumer_container).


%% Test start_link/1 (unnamed)
%% ====================================================================
start_link_1_unnamed_test_() ->
	?_assertMatch({ok, P} when is_pid(P),
				  ?MOD:start_link(unnamed)).


%% Test start_link/1 (named)
%% ====================================================================
start_link_1_named_test() ->
	R = ?MOD:start_link(consumer_test_1_name),
	?assertMatch({ok, P} when is_pid(P), R),
	{ok, Pid} = R,
	?assertEqual(Pid, whereis(consumer_test_1_name)).


%% Test start_link/2
%% ====================================================================
start_link_2_test_() ->
	test_mocked(
	  fun(_) ->
			  [
			   {"unnamed ok", fun test_start_link_2_unnamed_ok/0},
			   {"named ok", fun test_start_link_2_named_ok/0},
			   {"named failures", fun test_start_link_2_named_failures/0}
			  ]
	  end).

test_start_link_2_singleton_ok() ->	 
	R = ?MOD:start_link(singleton, [[], [], []]),
	?assertMatch({ok, P} when is_pid(P), R),
	{ok, Pid} = R,
	?assertEqual(Pid, whereis(?MOD)),
	?MOD:stop().

test_start_link_2_unnamed_ok() ->
	?assertMatch({ok, P} when is_pid(P),
				 ?MOD:start_link(unnamed, [[], [], []])).

test_start_link_2_named_ok() ->
	R = ?MOD:start_link(consumer_test_2_name, [[], [], []]),
	?assertMatch({ok, P} when is_pid(P), R),
	{ok, Pid} = R,
	?assertEqual(Pid, whereis(consumer_test_2_name)).

test_start_link_2_named_failures() ->
	Self = self(),
	proc_lib:spawn(fun() -> R1 = ?MOD:start_link(consumer_test_3_name, [[], [fail], [fail]]), Self ! R1 end),
	Result = receive
				 X -> X
			 after 100 -> {error, timeout}
			 end,
	?assertMatch({error, {consumers_failed, [{error, {P1, [fail], failtest}}, {error, {P1, [fail], failtest}}]}} when is_pid(P1), Result),
	?assertEqual(ok, deck36_test_util:wait_for_stop(consumer_test_3_name, 20)).


%% Test start_consumer/2, start_consumers/2
%% ====================================================================
start_consumer_consumers_2_test_() ->
	test_mocked(
	  fun(Ref) ->
			  [
			   {"one ok", ?_assertMatch({ok, P} when is_pid(P), ?MOD:start_consumer(Ref, []))},
			   {"one fail", ?_assertEqual({error, failtest}, ?MOD:start_consumer(Ref, [fail]))},
			   {"many ok", ?_assertMatch([{ok, P1},{ok, P2}] when is_pid(P1) andalso is_pid(P2),
 										 ?MOD:start_consumers(Ref, [[],[]]))},
 			   {"many fail", ?_assertMatch([{ok, P3},{error, {P4, [fail], failtest}}] when is_pid(P3) andalso is_pid(P4),
 										   ?MOD:start_consumers(Ref, [[], [fail]]))}
 			  ]
	  end,
	  fun() ->
			  {ok, Ref} = ?MOD:start_link(unnamed),
			  Ref
	  end).
			   

%% Test which_consumers/1
%% ====================================================================
which_consumers_test_() ->
	test_mocked(
	  fun(Ref) ->
			  R = ?MOD:start_consumers(Ref, [[], []]),
			  Pids = ?MOD:which_consumers(Ref),
			  [
			   {"Start ok", ?_assertMatch([{ok, P1}, {ok, P2}] when is_pid(P1) andalso is_pid(P2), R)},
			   {"Which", fun() -> [{ok, P3}, {ok, P4}] = R,
								  ?assert(lists:member(P3, Pids)),
								  ?assert(lists:member(P4, Pids))
						 end}
			  ]
	  end,
	  fun() ->
			  {ok, Ref} = ?MOD:start_link(unnamed),
			  Ref
	  end).


%% Test which_consumers/1
%% ====================================================================
stop_consumers_test_() ->
	test_mocked(
	  fun(Ref) ->
			  R = ?MOD:start_consumers(Ref, [[], []]),
			  ?MOD:stop_consumers(Ref),
			  [
			   {"Start ok", ?_assertMatch([{ok, P1}, {ok, P2}] when is_pid(P1) andalso is_pid(P2), R)},
			   {"Stopped", fun() -> [{ok, P3}, {ok, P4}] = R,
									?assertEqual(ok, deck36_test_util:wait_for_stop(P3, 20)),
									?assertEqual(ok, deck36_test_util:wait_for_stop(P4, 20))
						   end}
			  ]
	  end,
	  fun() ->
			  {ok, Ref} = ?MOD:start_link(unnamed),
			  Ref
	  end).


%% ====================================================================
%% Internal functions
%% ====================================================================
test_mocked(TestFun, SetupFun, TearDownFun) ->
	{setup,
	 fun() ->
			 mock_deck36_amqp_consumer_container(),
			 SetupFun()
	 end,
	 fun(X) ->
			 TearDownFun(X),
			 deck36_test_util:unmock(deck36_amqp_consumer_container)
	 end,
	 TestFun}.
	
test_mocked(TestFun, SetupFun) ->
	test_mocked(TestFun, SetupFun, fun(_) -> ok end).
	
test_mocked(TestFun) ->
	test_mocked(TestFun, fun() -> ok end).

	
mock_deck36_amqp_consumer_container() ->
	ok = meck:new(deck36_amqp_consumer_container, []),
	ok = meck:expect(deck36_amqp_consumer_container, start_link,
					 fun([fail]) ->
							 {error, failtest};
						(_) -> Pid = proc_lib:spawn(fun() ->
															receive
																_ -> ok
															end
													end),
							   {ok, Pid}
					 end),
	ok = meck:expect(deck36_amqp_consumer_container, stop,
					 fun(Pid) -> Pid ! stop, ok end),
	ok.

