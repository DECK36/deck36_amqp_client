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
%% @doc Tests basic application functionality.
%%
%% application_startup 
%% 
%% consume_base
%% consume_error
%%
%% @todo Test blocking/non_blocking



-module(basic_SUITE).

%% ====================================================================
%% API functions
%% ====================================================================
-export([groups/0,
         all/0,
         init_per_group/2,
         end_per_group/2,
         init_per_testcase/2,
         end_per_testcase/2]).
-export([application_startup/1,
		 consume_base/1, consume_error/1, consume_suspend_resume/1]).
-export([handle_deliver/1, handle_error/1]).

-define(APP, deck36_amqp_client).
-define(ETS, ?MODULE).
-define(WAIT_TIME, 500).
-define(GV(K,L), proplists:get_value(K,L)).

-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("common_test/include/ct.hrl").

%% ====================================================================
%% Common Test Interface
%% ====================================================================
groups() ->
	[
	 {application, [], [application_startup]},
	 {consume, [sequence], [consume_base,
							consume_suspend_resume,
							consume_error]}
	].


all() ->
	[
	 {group, application},
	 {group, consume}
	].


init_per_group(_, Config) ->
	init_all(Config).


end_per_group(_, _Config) ->
	?APP:stop(),
	ok.


init_all(Config) ->
	?APP:start(),
	Config.


init_per_testcase(_, Config) ->
	?ETS = ets:new(?ETS, [named_table, public, set]),
	Config.


end_per_testcase(_, _Config) ->
	case ets:info(?ETS) of
		undefined -> ok;
		Info when is_list(Info) -> ets:delete(?ETS)
	end,
	ok.


%% ====================================================================
%% Tests
%% ====================================================================

%% ====================================================================
%% Test group application
%% ====================================================================
application_startup(_Config) ->
	Apps = application:which_applications(),
	case lists:keymember(?APP, 1, Apps) of
		true -> ok;
		false -> throw("Application not started")
	end,
	case deck36_amqp_client:which_consumers() of
		[] -> throw("No consumers running");
		_ -> ok
	end,
	case deck36_amqp_client:which_producers() of
		[] -> throw("No producers running");
		_ -> ok
	end,
	case deck36_amqp_client:which_setups() of
		[] -> throw("No setups running");
		_ -> ok
	end.

%% ====================================================================
%% Test group consume
%% ====================================================================

%% Produce message, which should be handled by handle_deliver
%% ====================================================================
consume_base(_Config) ->
	Expected = erlang:list_to_binary(
				 lists:flatten(io_lib:fwrite("~p", [erlang:now()]))),
	consume_reset_actual(),
	deck36_amqp_client:produce(Expected),
	timer:sleep(?WAIT_TIME),
	consume_process_results(Expected, 0).


%% Produce message, which should trigger an error handled by handle_error
%% ====================================================================
consume_error(_Config) ->
	Expected = <<"error triggered">>,
	consume_reset_actual(),
	deck36_amqp_client:produce(<<"trigger error">>),
	timer:sleep(?WAIT_TIME),
	consume_process_results(Expected, 2).


%% 1) Produce message, which should be handle by handle_deliver
%% 2) Suspend and produce a message, which should not be consumed
%% 3) Resume, which should consume the message from before
%% ====================================================================
consume_suspend_resume(_Config) ->
	[Consumer] = deck36_amqp_consumer_sup:which_consumers(),
	Expected = erlang:list_to_binary(
				 lists:flatten(io_lib:fwrite("~p", [erlang:now()]))),
	
	%% Normal consumption once more
	consume_reset_actual(),
	deck36_amqp_client:produce(Expected),
	timer:sleep(?WAIT_TIME),
	consume_process_results(Expected, 0),
	
	%% Suspend, produce, wait
	consume_reset_actual(),
	ok = deck36_amqp_consumer_container:suspend(Consumer),
	deck36_amqp_client:produce(Expected),
	timer:sleep(?WAIT_TIME),
	
	%% Assert
	[{errors_triggered, Triggered}] = ets:lookup(?ETS, errors_triggered),
	[{actual, Actual}] = ets:lookup(?ETS, actual),
	case Actual of
		<<>> -> ok;
		Expected ->
			ct:pal(error, "Expected no consumption~n", []),
			throw(error_consumed);
		X ->
			ct:pal(error, "Unexpected: ~p~n", [X]),
			throw(error_consumed)
	end,
	case Triggered of
		Y when Y > 0 ->
			ct:pal(error, "Error triggered"),
			throw(error_triggered);
		0 -> ok
	end,
	
	ok = deck36_amqp_consumer_container:resume(Consumer),
	timer:sleep(?WAIT_TIME),
	consume_process_results(Expected, 0).
	

%% Helper: Reset "actual" values
%% ====================================================================
consume_reset_actual() ->
	ets:insert(?ETS, {actual, <<>>}),
	ets:insert(?ETS, {errors_triggered, 0}).


%% Helper: Assert
%% ====================================================================
consume_process_results(Expected, ShouldTrigger) ->
	[{errors_triggered, Triggered}] = ets:lookup(?ETS, errors_triggered),
	[{actual, Actual}] = ets:lookup(?ETS, actual),
	case Actual of
		Expected -> ok;
		<<>> ->
			ct:pal(error, "No delivery after timeout of ~pms", [?WAIT_TIME]),
			throw(timeout);
		_ ->
			ct:pal(error, "Expected: ~p~nActual: ~p~n", [Expected, Actual]),
			throw(not_triggered)
	end,
	case Triggered of
		ShouldTrigger -> ok;
		X when X > 0 ->
			ct:pal(error, "Error triggered, but shouldn't have been"),
			throw(error_triggered);
		0 ->
			ct:pal(error, "Error not triggered, but should have been"),
			throw(error_not_triggered)
	end.

%% ====================================================================
%% Consumer Callbacks
%% ====================================================================
handle_deliver(#amqp_msg{payload=Payload}=Msg) ->
	ct:pal("handle_deliver: ~p~n", [Msg]),
	case Payload of
		<<"trigger error">> ->
			case ets:lookup(?ETS, errors_triggered) of
				[{errors_triggered, X}] when X > 0 ->
					%% received requeued <<"trigger error">> -> ok
					ets:update_counter(?ETS, errors_triggered, 1),
					ok;
				_ ->
					ets:insert(?ETS, {actual, <<"error triggered">>}),
					{error, triggered}
			end;
		X ->
			ets:insert(?ETS, {actual, X}),
			ok
	end.

handle_error(X) ->
	ets:update_counter(?ETS, errors_triggered, 1),
	ct:pal("handle_error: ~p~n", [X]).

%% ====================================================================
%% Internal functions
%% ====================================================================

