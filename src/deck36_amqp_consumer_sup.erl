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
%% @doc Supervisor for consumers.


-module(deck36_amqp_consumer_sup).
-behaviour(supervisor).
-export([init/1]).

-include_lib("deck36_common/include/deck36_common.hrl").

%% ====================================================================
%% Types
%% ====================================================================
-export_type([consumer_def/0]).
-type consumer_def() :: [deck36_amqp_consumer:start_opt()].
-type start_ret() :: {error, reason()}
				   | {ok, pid()}.

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/1, start_link/2,
		 start_consumers/1, start_consumers/2,
		 start_consumer/1, start_consumer/2,
		 stop_consumers/0, stop_consumers/1,
		 which_consumers/0, which_consumers/1]).

-define(SERVER, ?MODULE).

%% start_link/1
%% ====================================================================
%% @doc Start linked, (named, unnamed or singleton) supervisor
-spec start_link(singleton | unnamed | atom()) -> start_ret().
%% ====================================================================
start_link(singleton) ->
	supervisor:start_link({local, ?SERVER}, ?MODULE, []);
start_link(unnamed) ->
	supervisor:start_link(?MODULE, []);
start_link(Ref) when is_atom(Ref) ->
	supervisor:start_link({local, Ref}, ?MODULE, []).


%% start_link/2
%% ====================================================================
%% @doc Start linked, (named, unnamed or singleton) supervisor with consumers
-spec start_link(singleton | unnamed | atom(), [consumer_def()]) -> start_ret().
%% ====================================================================
start_link(Ref, Consumers) ->
	{ok, Pid} = start_link(Ref),
	Started = start_consumers(Pid, Consumers),
	case lists:filter(fun({ok, _}) -> false; (_) -> true end, Started) of
		[] ->
			{ok, Pid};
		Failed ->
			stop_consumers(Pid),
			exit(Pid, kill),
			{error, {consumers_failed, Failed}}
	end.


%% start_consumers/1
%% ====================================================================
%% @doc Start consumers by singleton supervisor
-spec start_consumers([consumer_def()]) -> [start_ret()].
%% ====================================================================
start_consumers(Consumers) ->
	start_consumers(?SERVER, Consumers).


%% start_consumers/2
%% ====================================================================
%% @doc Start consumers by supervisor identified by Ref
-spec start_consumers(server_ref(), [consumer_def()]) -> [start_ret()].
%% ====================================================================
start_consumers(Ref, Consumers) ->
	[case start_consumer(Ref, Consumer) of
		 {ok, Pid} -> {ok, Pid};
		 {error, Reason} -> {error, {Ref, Consumer, Reason}}
	 end || Consumer <- Consumers].


%% start_consumer/1
%% ====================================================================
%% @doc Start consumer (transient) by singleton server
-spec start_consumer(consumer_def()) -> start_ret().
%% ====================================================================
start_consumer(Opts) ->
	start_consumer(?SERVER, Opts).


%% start_consumer/2
%% ====================================================================
%% @doc Start consumer (transient) by supervisor identified by Ref
-spec start_consumer(server_ref(), consumer_def()) -> start_ret().
%% ====================================================================
start_consumer(Ref, Opts) ->
	case supervisor:start_child(Ref, [Opts]) of
		{error, Reason} ->
			{error, Reason};
		{ok, Child, _} ->
			{ok, Child};
		X ->
			X
	end.


%% stop_consumers/0
%% ====================================================================
%% @doc Stop all consumers of singleton supervisor
-spec stop_consumers() -> ok.
%% ====================================================================
stop_consumers() ->
	stop_consumers(?SERVER).


%% stop_consumers/1
%% ====================================================================
%% @doc Stop all consumers of supervisor identified by Ref
-spec stop_consumers(Ref :: server_ref()) -> ok.
%% ====================================================================
stop_consumers(Ref) ->
	lists:foreach(fun(Pid) ->
						  deck36_amqp_consumer_container:stop(Pid)
				  end,
				  which_consumers(Ref)).


%% which_consumers/0
%% ====================================================================
%% @doc Get list of running consumers from singleton supervisor
-spec which_consumers() -> [pid()].
%% ====================================================================
which_consumers() ->
	which_consumers(?SERVER).


%% which_consumers/1
%% ====================================================================
%% @doc Get list of running consumers from supervisor identified by Ref
-spec which_consumers(Ref :: server_ref()) -> [pid()].
%% ====================================================================
which_consumers(Ref) ->
	[Pid || {_, Pid, _, _} <- supervisor:which_children(Ref)].


%% ====================================================================
%% Behavioural functions 
%% ====================================================================

%% init/1
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/supervisor.html#Module:init-1">supervisor:init/1</a>
-spec init(Args :: term()) -> Result when
	Result :: {ok, {SupervisionPolicy, [ChildSpec]}} | ignore,
	SupervisionPolicy :: {RestartStrategy, MaxR :: non_neg_integer(), MaxT :: pos_integer()},
	RestartStrategy :: one_for_all
					 | one_for_one
					 | rest_for_one
					 | simple_one_for_one,
	ChildSpec :: {Id :: term(), StartFunc, RestartPolicy, Type :: worker | supervisor, Modules},
	StartFunc :: {M :: module(), F :: atom(), A :: [term()] | undefined},
	RestartPolicy :: permanent
				   | transient
				   | temporary,
	Modules :: [module()] | dynamic.
%% ====================================================================
init([]) ->
	Child = {deck36_amqp_consumer, {deck36_amqp_consumer_container, start_link, []},
			 transient, 5000, worker, [deck36_amqp_consumer_container]},
    {ok,{{simple_one_for_one,2,10}, [Child]}}.

%% ====================================================================
%% Internal functions
%% ====================================================================


