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
%% @doc AMQP producer.
%%
%% In order to see how to use this, see:
%% * start_link/1 and type start_opt()
%% * send/1, send/2
%%
%% You should always properly shut down the producer using stop/1 or
%% you might end up with errors from amqp_client. 


-module(deck36_amqp_producer).
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("deck36_common/include/deck36_common.hrl").

%% ====================================================================
%% Types
%% ====================================================================
-export_type([start_opt/0, server_ref/0, msg/0]).
-type start_opt() :: {server_ref, server_ref_opt()}
				   | {connection, deck36_amqp_util:connection_def()}
				   | {publish, [publish_opt()]}
				   | {delivery_mode, delivery_mode()}.
-type server_ref_opt() :: undefined
						| singleton
						| server_ref().
-type publish_opt() :: {exchange, binary()}
					 | {queue, binary()}
					 | {routing_key, binary()}.
-type delivery_mode() :: persistent
					   | non_persistent
					   | undefined.
-type msg() :: #amqp_msg{}
			 | binary().


%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/1,
		 stop/0, stop/1,
		 send/1, send/2,
		 send_sync/1, send_sync/2,
		 delivery_mode/1]).

-define(SERVER, ?MODULE).

%% start_link/1
%% ====================================================================
%% @doc Start deck36_amqp_producer
%%
%% Use option {server_ref, Ref} to register the producer:
%% - undefined -> don't register (default)
%% - singleton -> register as locally default server
%% - {global, Ref} -> register globally
%% - Ref -> register locally
-spec start_link([start_opt()]) -> Result when
	Result :: {ok, pid()}
			| ignore
			| {error, Error},
	Error :: {already_started, pid()}
		   | term().
%% ====================================================================
start_link(Opts) ->
	case proplists:get_value(server_ref, Opts) of
		undefined -> gen_server:start_link(?MODULE, [Opts], []);
		singleton -> gen_server:start_link({local, ?SERVER}, ?MODULE, [Opts], []);
		Ref -> gen_server:start_link({local, Ref}, ?MODULE, [Opts], [])
	end.


%% stop/0
%% ====================================================================
%% @doc Stop singleton producer
-spec stop() -> ok.
%% ====================================================================
stop() ->
	stop(?SERVER).


%% stop/1
%% ====================================================================
%% @doc Stop producer identified by Ref
-spec stop(server_ref()) -> ok.
%% ====================================================================
stop(Ref) ->
	gen_server:call(Ref, stop).


%% send/1
%% ====================================================================
%% @doc Send message via the singleton producer
%%
%% Returns ok even if the connection is somehow closed. If you want to
%% be sure the message reached the channel, use send_sync/1.
-spec send(Msg :: #amqp_msg{} | binary()) -> ok.
%% ====================================================================
send(Msg) ->
	send(?SERVER, Msg).


%% send/2
%% ====================================================================
%% @doc Send message via producer identified by Ref
%%
%% Returns ok even if the connection is somehow closed. If you want to
%% be sure the message reached the channel, use send_sync/2.
-spec send(Ref :: server_ref(), Msg :: #amqp_msg{} | binary()) -> ok.
%% ====================================================================
send(Ref, #amqp_msg{}=Msg) ->
	gen_server:cast(Ref, {send, Msg});
send(Ref, Payload) when is_binary(Payload) ->
	send(Ref, #amqp_msg{payload=Payload}).


%% send_sync/1
%% ====================================================================
%% @doc Send message via the singleton producer synchronously.
%%
%% If you don't want to block your process use send/1. 
-spec send_sync(Msg :: #amqp_msg{} | binary()) -> ok.
%% ====================================================================
send_sync(Msg) ->
	send_sync(?SERVER, Msg).


%% send_sync/1
%% ====================================================================
%% @doc Send message via producer identified by Ref synchronously.
%%
%% If you don't want to block your process use send/1. 
-spec send_sync(Ref :: server_ref(), Msg :: #amqp_msg{} | binary()) -> ok.
%% ====================================================================
send_sync(Ref, #amqp_msg{}=Msg) ->
	gen_server:call(Ref, {send, Msg});
send_sync(Ref, Payload) when is_binary(Payload) ->
	send_sync(Ref, #amqp_msg{payload=Payload}).


%% delivery_mode/1
%% ====================================================================
%% @doc Get internal delivery_mode representation
-spec delivery_mode(undefined | non_persistent | persistent | default) -> term().
%% ====================================================================
delivery_mode(undefined) ->	undefined;
delivery_mode(default) -> 1;
delivery_mode(non_persistent) -> 1;
delivery_mode(persistent) -> 2.


%% ====================================================================
%% Behavioural functions 
%% ====================================================================
-record(state, { conn, publish, delivery_mode }).

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
	Conn = deck36_amqp_connection:ensure_open(
			 deck36_amqp_connection:new(?GV(connection, Opts))),
	{ok, #state{
				conn = Conn,
				publish = get_publish(?GV(publish, Opts)),
				delivery_mode = delivery_mode(?GV(delivery_mode, Opts))
			   }}.


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
handle_call({send, Msg}, From, S) ->
	proc_lib:spawn(fun() ->
						   gen_server:reply(From, do_send(Msg, S, sync))
				   end),
	{noreply, S};
handle_call(stop, _From, S) ->
	{stop, normal, ok, S};
handle_call(_Request, _From, State) ->
    {reply, invalid_call, State}.


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
handle_cast({send, Msg}, State) ->
	do_send(Msg, State, async),
	{noreply, State};
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
terminate(_Reason, #state{conn = Conn}) ->
	deck36_amqp_connection:ensure_closed(Conn),
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

%% get_publish/1
%% ====================================================================
%% @doc Get publish from options
-spec get_publish(Opts :: list()) -> #'basic.publish'{}.
%% ====================================================================
get_publish(Opts) ->
	case ?GV(exchange, Opts) of
		undefined ->
			QO = ?GV(queue, Opts),
			Queue = deck36_amqp_util:queue(
					  case is_binary(QO) of
						  true -> [{queue, QO}];
						  false -> QO
					  end),
			#'basic.publish'{ exchange = <<>>, routing_key = Queue#'queue.declare'.queue};
		ExO ->
			RoutingKey = ?GV(routing_key, Opts, <<>>),
			Exchange = deck36_amqp_util:exchange(
						 case is_binary(ExO) of
						   true -> [{exchange, ExO}];
						   false -> ExO
						 end),
			#'basic.publish'{exchange = Exchange#'exchange.declare'.exchange,
							 routing_key = RoutingKey}
	end.


%% do_send/2
%% ====================================================================
%% @doc Send message to broker
-spec do_send(#amqp_msg{}, #state{}, sync | async) -> ok.
%% ====================================================================
do_send(#amqp_msg{props = MP} = Msg,
		#state{publish = Publish,
			   conn = Conn,
			   delivery_mode = SDM},
		Mode) ->
	M = if
			MP#'P_basic'.delivery_mode =:= undefined ->
				Msg#amqp_msg{props = MP#'P_basic'{delivery_mode = SDM}};
			true -> Msg
		end,
	case Mode of
		async ->
			amqp_channel:cast(deck36_amqp_connection:get_channel(Conn), Publish, M);
		sync -> 
			amqp_channel:call(deck36_amqp_connection:get_channel(Conn), Publish, M)
	end.

