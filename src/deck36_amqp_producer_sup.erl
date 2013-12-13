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
%% @doc Supervisor for producers.


-module(deck36_amqp_producer_sup).
-behaviour(supervisor).
-export([init/1]).

-include_lib("deck36_common/include/deck36_common.hrl").

%% ====================================================================
%% Types
%% ====================================================================
-export_type([producer_def/0]).
-type producer_def() :: [deck36_amqp_producer:start_opt()].
-type start_ret() :: {error, reason()}
				   | {ok, pid()}.

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/1, start_link/2,
		 start_producer/1, start_producer/2,
		 start_producers/1, start_producers/2,
		 stop_producers/0, stop_producers/1,
		 which_producers/0, which_producers/1]).
-define(SERVER, ?MODULE).

%% start_link/1
%% ====================================================================
%% @doc Start linked, (named, unnamed or singleton) supervisor
-spec start_link(singleton | unnamed | atom()) -> supervisor:startlink_ret().
%% ====================================================================
start_link(singleton) ->
	supervisor:start_link({local, ?SERVER}, ?MODULE, []);
start_link(unnamed) ->
	supervisor:start_link(?MODULE, []);
start_link(Ref) when is_atom(Ref) ->
	supervisor:start_link({local, Ref}, ?MODULE, []).


%% start_link/2
%% ====================================================================
%% @doc Start singleton supervisor and all Producers
-spec start_link(singleton | unnamed | atom(), [producer_def()]) -> start_ret().
%% ====================================================================
start_link(Ref, Producers) ->
	{ok, Pid} = start_link(Ref),
	Started = start_producers(Pid, Producers),
	case lists:filter(fun({ok, _}) -> false; (_) -> true end, Started) of
		[] ->
			{ok, Pid};
		Failed ->
			stop_producers(Pid),
			exit(Pid, kill),
			{error, {producers_failed, Failed}}
	end.


%% start_producers/1
%% ====================================================================
%% @doc Start producers by singleton supervisor
-spec start_producers([producer_def()]) -> [start_ret()].
%% ====================================================================
start_producers(Producers) ->
	start_producers(?SERVER, Producers).


%% start_producers/2
%% ====================================================================
%% @doc Start producers by supervisor identified by Ref
-spec start_producers(server_ref(), [producer_def()]) -> [start_ret()].
%% ====================================================================
start_producers(Ref, Producers) ->
	[case start_producer(Ref, Producer) of
		 {ok, Pid} -> {ok, Pid};
		 {error, Reason} -> {error, {Ref, Producer, Reason}}
	 end || Producer <- Producers].


%% start_producer/1
%% ====================================================================
%% @doc Start producer (transient) by singleton server
-spec start_producer([deck36_amqp_producer:start_opt()]) -> start_ret().
%% ====================================================================
start_producer(Opts) ->
	start_producer(?SERVER, Opts).


%% start_producer/2
%% ====================================================================
%% @doc Start producer (transient) by supervisor identified by Ref
-spec start_producer(server_ref(), [deck36_amqp_producer:start_opt()]) -> start_ret().
%% ====================================================================
start_producer(Ref, Opts) ->
	case supervisor:start_child(Ref, [Opts]) of
		{error, Reason} ->
			{error, Reason};
		{ok, Child, _} ->
			{ok, Child};
		X ->
			X
	end.


%% stop_producers/0
%% ====================================================================
%% @doc Stop all producers of singleton supervisor
-spec stop_producers() -> ok.
%% ====================================================================
stop_producers() ->
	stop_producers(?SERVER).


%% stop_producers/1
%% ====================================================================
%% @doc Stop all producers of supervisor identified by Ref
-spec stop_producers(server_ref()) -> ok.
%% ====================================================================
stop_producers(Ref) ->
	lists:foreach(fun(Pid) ->
						  deck36_amqp_producer:stop(Pid)
				  end,
				  which_producers(Ref)).


%% which_producers/0
%% ====================================================================
%% @doc Get list of running producers from singleton supervisor
-spec which_producers() -> [pid()].
%% ====================================================================
which_producers() ->
	which_producers(?SERVER).


%% which_producers/1
%% ====================================================================
%% @doc Get list of running producers from supervisor identified by Ref
-spec which_producers(server_ref()) -> [pid()].
%% ====================================================================
which_producers(Ref) ->
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
	Child = {deck36_amqp_producer, {deck36_amqp_producer, start_link, []},
			 transient, 2000, worker, [deck36_amqp_producer]},
    {ok,{{simple_one_for_one,2,10}, [Child]}}.

%% ====================================================================
%% Internal functions
%% ====================================================================


