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
%% @doc Supervisor for setups.


-module(deck36_amqp_setup_sup).
-behaviour(supervisor).
-export([init/1]).

-include_lib("deck36_common/include/deck36_common.hrl").

%% ====================================================================
%% Types
%% ====================================================================
-export_type([setup_def/0]).
-type setup_def() :: [deck36_amqp_setup:start_opt()].
-type start_ret() :: {error, reason()}
				   | {ok, pid()}.


%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/1, start_link/2,
		 start_setups/1, start_setups/2,
		 start_setup/1, start_setup/2,
		 stop_setups/0, stop_setups/1,
		 which_setups/0, which_setups/1]).
-define(SERVER, ?MODULE).

%% start_link/1
%% ====================================================================
%% @doc Start linked, (named, unnamed or singleton) supervisor
-spec start_link(singleton | atom()) -> {ok, pid()}.
%% ====================================================================
start_link(singleton) ->
	supervisor:start_link({local, ?SERVER}, ?MODULE, []);
start_link(unnamed) ->
	supervisor:start_link(?MODULE, []);
start_link(Ref) ->
	supervisor:start_link({local, Ref}, ?MODULE, []).


%% start_link/2
%% ====================================================================
%% @doc Start linked, (named, unnamed or singleton) supervisor with setups
-spec start_link(singleton | unnamed | atom(), [setup_def()]) -> {ok, pid()}.
%% ====================================================================
start_link(Ref, Setups) ->
	{ok, Pid} = start_link(Ref),
	lists:foreach(fun(S) ->
						  ?MODULE:start_setup(S)
				  end, Setups),
	{ok, Pid}.


%% start_setups/1
%% ====================================================================
%% @doc Start setups by singleton supervisor
-spec start_setups([setup_def()]) -> [start_ret()].
%% ====================================================================
start_setups(Setups) ->
	start_setups(?SERVER, Setups).


%% start_setups/2
%% ====================================================================
%% @doc Start setups by supervisor identified by Ref
-spec start_setups(server_ref(), [setup_def()]) -> [start_ret()].
%% ====================================================================
start_setups(Ref, Setups) ->
	[start_setup(Ref, Setup) || Setup <- Setups].


%% start_setup/1
%% ====================================================================
%% @doc Start setup (transient) by singleton supervisor
-spec start_setup(setup_def()) -> [start_ret()].
%% ====================================================================
start_setup(Opts) ->
	start_setup(?SERVER, Opts).


%% start_setup/2
%% ====================================================================
%% @doc Start setup (transient) by supervisor identified by Ref
-spec start_setup(server_ref(), setup_def()) -> [start_ret()].
%% ====================================================================
start_setup(Ref, Opts) ->
	case supervisor:start_child(Ref, [Opts]) of
		{error, Reason} ->
			error_logger:error_report({?MODULE, start_setup, {Opts, Reason}}),
			{error, Reason};
		{ok, Child, _} ->
			{ok, Child};
		X ->
			X
	end.


%% stop_setups/0
%% ====================================================================
%% @doc Stop all setups of singleton supervisor
-spec stop_setups() -> ok.
%% ====================================================================
stop_setups() ->
	stop_setups(?SERVER).


%% stop_setups/1
%% ====================================================================
%% @doc Stop all setups of supervisor identified by Ref
-spec stop_setups(server_ref()) -> ok.
%% ====================================================================
stop_setups(Ref) ->
	lists:foreach(fun(Pid) ->
						  deck36_amqp_setup:stop(Pid)
				  end,
				  which_setups(Ref)).


%% which_setups/0
%% ====================================================================
%% @doc Get list of running setups from singleton supervisor
-spec which_setups() -> [pid()].
%% ====================================================================
which_setups() ->
	which_setups(?SERVER).


%% which_setups/1
%% ====================================================================
%% @doc Get list of running setups from supervisor identified by Ref
-spec which_setups(server_ref()) -> [pid()].
%% ====================================================================
which_setups(Ref) ->
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
	Child = {deck36_amqp_setup, {deck36_amqp_setup, start_link, []},
			 transient, 2000, worker, [deck36_amqp_setup]},
    {ok,{{ simple_one_for_one,2,10}, [Child]}}.

%% ====================================================================
%% Internal functions
%% ====================================================================


