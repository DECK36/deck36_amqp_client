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
%% @doc Consumer server.
%%
%% Start the consumer with start_link/1.
%% You have to provide a processor definition, which is a tuple of type
%% and start options. 
%%
%% You should always properly shut down the consumer using stop/1 or
%% you might end up with errors from amqp_client. 


-module(deck36_amqp_consumer_container).
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("deck36_common/include/deck36_common.hrl").

%% ====================================================================
%% Types
%% ====================================================================
-export_type([start_opts/0, start_opt/0]).
-type start_opts() :: [start_opt()].
-type start_opt() :: {connection, deck36_amqp_util:connection_def()}
				   | {queue, deck36_amqp_util:queue_def()}
				   | {processor, processor_def()}
				   | start_suspended.
-type processor_def() :: {callback, [deck36_amqp_callback_processor:start_opt()]}
					   | {module(), term()}.

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/1,
		 stop/1,
		 suspend/1,
		 resume/1,
		 is_consuming/1]).

%% start_link/1
%% ====================================================================
%% @doc start linked consumer
%%
%% Will connect, open channel, subscribe
-spec start_link(start_opts()) -> Result when
	Result :: {ok, pid()}
			| ignore
			| {error, Error},
	Error :: {already_started, pid()}
		   | term().
%% ====================================================================
start_link(Opts) ->
	gen_server:start_link(?MODULE, [Opts], []).


%% stop/1
%% ====================================================================
%% @doc stop consumer identified by Ref
-spec stop(Ref :: pid()) -> ok.
%% ====================================================================
stop(Ref) ->
	gen_server:call(Ref, stop).


%% suspend/1
%% ====================================================================
%% @doc Suspend consumption
%%
%% If consumption is already suspended it will still return ok.
-spec suspend(Ref :: pid()) -> ok.
%% ====================================================================
suspend(Ref) ->
	gen_server:call(Ref, suspend).


%% resume/1
%% ====================================================================
%% @doc Resume consumption
%%
%% If consumption is already running it will still return ok.
-spec resume(Ref :: pid()) -> ok.
%% ====================================================================
resume(Ref) ->
	gen_server:call(Ref, resume).


%% is_consuming/1
%% ====================================================================
%% @doc Return whether or not the consumer is consuming (not suspended).
-spec is_consuming(Ref :: pid()) -> boolean().
%% ====================================================================
is_consuming(Ref) ->
	gen_server:call(Ref, is_consuming).


%% ====================================================================
%% Behavioural functions 
%% ====================================================================
-record(state, {conn, queue, consumer_tag, consumer_def}).


%% init/1
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:init-1">gen_server:init/1</a>
-spec init(Args :: term()) -> Result when
	Result :: {ok, State}
			| {ok, State, Timeout}
			| {ok, State, hibernate}
			| {stop, Reason :: term()}
			| ignore,
	State :: term(),
	Timeout :: non_neg_integer() | infinity.
%% ====================================================================
init([Opts]) ->
	Consumer = get_amqp_gen_consumer_def(?GV(type, Opts)),
	Conn = deck36_amqp_connection:ensure_open(
			 deck36_amqp_connection:new(?GV(connection, Opts)),
			 Consumer),
	Queue = deck36_amqp_util:queue(?GV(queue, Opts)),
	Ch = deck36_amqp_connection:get_channel(Conn),
	ok = amqp_channel:call_consumer(Ch, {set_channel, Ch}),
	Tag = case proplists:get_bool(start_suspended, Opts) of
			  true -> undefined;
			  false ->
				  #'queue.declare_ok'{queue=Q} = amqp_channel:call(Ch, Queue),
				  #'basic.consume_ok'{consumer_tag = CTag} = amqp_channel:call(Ch, #'basic.consume'{queue=Q}),
				  CTag
		end,
	{ok, #state{
				conn = Conn,
				queue = Queue,
				consumer_def = Consumer,
				consumer_tag = Tag}}.


%% handle_call/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_call-3">gen_server:handle_call/3</a>
-spec handle_call(Request :: term(), From :: {pid(), Tag :: term()}, State :: term()) -> Result when
	Result :: {reply, Reply, NewState}
			| {reply, Reply, NewState, Timeout}
			| {reply, Reply, NewState, hibernate}
			| {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason, Reply, NewState}
			| {stop, Reason, NewState},
	Reply :: term(),
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity,
	Reason :: term().
%% ====================================================================
handle_call(suspend, _From, #state{consumer_tag = undefined}=S) ->
	{reply, ok, S};
handle_call(suspend, _From, #state{consumer_tag = Tag, conn = Conn}=S) ->
	#'basic.cancel_ok'{} = amqp_channel:call(deck36_amqp_connection:get_channel(Conn),
											 #'basic.cancel'{consumer_tag = Tag}),
	{reply, ok, S#state{consumer_tag = undefined}};

handle_call(resume, _From, #state{consumer_tag = undefined, conn = Conn, queue = Queue}=S) ->
	Ch = deck36_amqp_connection:get_channel(Conn), 
	#'queue.declare_ok'{queue=Q} = amqp_channel:call(Ch, Queue),
	#'basic.consume_ok'{consumer_tag = Tag} = amqp_channel:call(Ch, #'basic.consume'{queue=Q}),
	{reply, ok, S#state{consumer_tag = Tag}};
handle_call(resume, _From, S) ->
	{reply, ok, S};

handle_call(is_consuming, _From, #state{consumer_tag = Tag}=S) ->
	{reply, (Tag /= undefined), S};

handle_call(stop, _From, S) ->
	{stop, normal, ok, S};
handle_call(_Request, _From, State) ->
    {reply, {error, not_implemented}, State}.


%% handle_cast/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_cast-2">gen_server:handle_cast/2</a>
-spec handle_cast(Request :: term(), State :: term()) -> Result when
	Result :: {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason :: term(), NewState},
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity.
%% ====================================================================
handle_cast(_Msg, State) ->
    {noreply, State}.


%% handle_info/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_info-2">gen_server:handle_info/2</a>
-spec handle_info(Info :: timeout | term(), State :: term()) -> Result when
	Result :: {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason :: term(), NewState},
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity.
%% ====================================================================
handle_info(_Info, State) ->
    {noreply, State}.


%% terminate/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:terminate-2">gen_server:terminate/2</a>
-spec terminate(Reason, State :: term()) -> Any :: term() when
	Reason :: normal
			| shutdown
			| {shutdown, term()}
			| term().
%% ====================================================================
terminate(_Reason, State) ->
	shutdown(State),
    ok.


%% code_change/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:code_change-3">gen_server:code_change/3</a>
-spec code_change(OldVsn, State :: term(), Extra :: term()) -> Result when
	Result :: {ok, NewState :: term()} | {error, Reason :: term()},
	OldVsn :: Vsn | {down, Vsn},
	Vsn :: term().
%% ====================================================================
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%% ====================================================================
%% Internal functions
%% ====================================================================

%% shutdown/1
%% ====================================================================
%% @doc Shutdown consumer
-spec shutdown(#state{}) -> {ok, #state{}}.
%% ====================================================================
shutdown(#state{conn=Conn}=S) ->
	Conn2 = deck36_amqp_connection:ensure_closed(Conn),
	{ok, S#state{conn = Conn2}}.


%% get_amqp_gen_consumer_def/1
%% ====================================================================
%% @doc Get consumer definition to be used in amqp_connection:open_channel/2
-spec get_amqp_gen_consumer_def
		({callback, [any()]}) -> {deck36_amqp_consumer, [[any()]]};
		({gen_consumer, {module(), list() | term()}}) -> {module(), list()};  
		({gen_consumer, [Opt]}) -> {module(), list()} when
	Opt :: {module, module()}
		 | {args, list()}.
%% ====================================================================
get_amqp_gen_consumer_def({callback, Opts}) ->
	true = deck36_amqp_consumer:is_valid_opts(Opts),
	{deck36_amqp_consumer, [Opts]};
get_amqp_gen_consumer_def({gen_consumer, {Mod, Args}}) ->
	if
		is_list(Args) -> {Mod, Args};
		true -> {Mod, [Args]}
	end;
get_amqp_gen_consumer_def({gen_consumer, Opts}) ->
	Mod = ?GV(module, Opts),
	Args = ?GV(args, Opts),
	get_amqp_gen_consumer_def({gen_consumer, {Mod, Args}}).

