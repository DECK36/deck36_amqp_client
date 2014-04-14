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

-module(deck36_amqp_connection).

-include_lib("deck36_common/include/deck36_common.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

%% ====================================================================
%% Types
%% ====================================================================
-export_type([def/0, opt/0, params/0]).
-type def() :: params()
			 | [opt()].
-type opt() :: {host, string()}
			 | {port, pos_integer()}
			 | {virtual_host, binary()}
			 | {username, binary()}
			 | {password, binary()}.
-type params() :: #amqp_params_network{}
				| #amqp_params_direct{}.


%% ====================================================================
%% API functions
%% ====================================================================
-export([params/1,
		 new/1,
		 get_channel/1,
		 get_connection/1,
		 get_params/1,
		 ensure_open/1,
		 ensure_open/2,
		 ensure_closed/1,
		 is_open/1,
		 open_apply_close/2,
		 open_call_close/2,
		 open_declare_close/2,
		 declare/2]).

-record(state, {params, conn, ch}).

%% params/1
%% ====================================================================
%% @doc Get connection params to be used with amqp_client
-spec params(def()) -> params().
%% ====================================================================
params(#amqp_params_network{}=AP) ->
	AP;
params(#amqp_params_direct{}=AP) ->
	AP;
params(Opts) when is_list(Opts) ->
	#amqp_params_network{
						 host = host(?GV(host, Opts)),
						 port = deck36_inet:port_number(?GV(port, Opts)),
						 virtual_host = bin(?GV(virtual_host, Opts)),
						 username = bin(?GV(username, Opts)),
						 password = bin(?GV(password, Opts))}.


%% new/1
%% ====================================================================
%% @doc New connection structure
-spec new(def()) -> #state{}.
%% ====================================================================
new(Def) ->
	#state{params = params(Def), conn = undefined, ch = undefined}.


%% get_channel/1
%% ====================================================================
%% @doc Get channel pid from connection structure
-spec get_channel(#state{}) -> pid() | undefined.
%% ====================================================================
get_channel(#state{ch = Ch}) ->
	Ch.


%% get_connection/1
%% ====================================================================
%% @doc Get connection pid from connection structure
-spec get_connection(#state{}) -> pid() | undefined.
%% ====================================================================
get_connection(#state{conn = Conn}) ->
	Conn.


%% get_params/1
%% ====================================================================
%% @doc Get AMQP connectin params from connection structure
-spec get_params(#state{}) -> deck36_amqp_util:connection_params().
%% ====================================================================
get_params(#state{params = Params}) ->
	Params.


%% ensure_open/1
%% ====================================================================
%% @doc Ensure connection and channel are open
-spec ensure_open(#state{}) -> #state{}.
%% ====================================================================
ensure_open(S) ->
	ensure_open(S, undefined).


%% ensure_open/2
%% ====================================================================
%% @doc Ensure connection and channel are open /w consumer
-spec ensure_open(#state{}, {module(), Args :: [any()]}) -> #state{}.
%% ====================================================================
ensure_open(#state{conn = undefined, ch = undefined, params = Params}=Connection, Consumer) ->
	{ok, Conn} = amqp_connection:start(Params),
	erlang:link(Conn),
	ensure_open(Connection#state{conn = Conn}, Consumer);
ensure_open(#state{conn = undefined, ch = Ch}=Connection, Consumer) ->
	erlang:unlink(Ch),
	amqp_channel:close(Ch),
	ensure_open(Connection#state{ch = undefined}, Consumer);
ensure_open(#state{ch = undefined, conn = Conn}=Connection, Consumer) ->
	case open_channel(Conn, Consumer) of
		{ok, Ch} ->
			erlang:link(Ch),
			ensure_open(Connection#state{ch = Ch});
		{error, Reason} ->
			erlang:unlink(Conn),
			amqp_connection:close(Conn),
			erlang:error("Failed to open channel: ~p", [Reason])
	end;
ensure_open(Connection, _Consumer) ->
	Connection.

%% ensure_closed/1
%% ====================================================================
%% @doc Ensure connection and channel are closed
-spec ensure_closed(#state{}) -> #state{}.
%% ====================================================================
ensure_closed(#state{ch = undefined, conn = undefined}=Connection) ->
	Connection;
ensure_closed(#state{conn = Conn, ch = undefined}=Connection) ->
	erlang:unlink(Conn),
	amqp_connection:close(Conn),
	ensure_closed(Connection#state{conn = undefined});
ensure_closed(#state{ch = Ch}=Connection) ->
	erlang:unlink(Ch),
	amqp_channel:close(Ch),
	ensure_closed(Connection#state{ch = undefined}).


%% is_open/1
%% ====================================================================
%% @doc Determine if connection and channel are open
-spec is_open(#state{}) -> boolean().
%% ====================================================================
is_open(#state{ch = Ch, conn = Conn}) ->
	((Ch /= undefined) and (Conn /= undefined)) andalso
		erlang:is_process_alive(Ch) andalso
		erlang:is_process_alive(Conn).


%% open_apply_close/2
%% ====================================================================
%% @doc Open conn/channel, apply Fun, close channel/conn
-spec open_apply_close(#state{}, function()) -> term().
%% ====================================================================
open_apply_close(Connection, Fun) when is_function(Fun, 1) ->
	#state{ch=Ch}=C1 = ensure_open(Connection), 
	try
		Fun(Ch)
	after
		ensure_closed(C1)
	end.


%% open_call_close/2
%% ====================================================================
%% @doc Open conn/channel, make call, close channel/conn
-spec open_call_close(#state{}, Declarations) -> [term()] when
	Declarations :: [deck36_amqp_util:declaration()]
				  | deck36_amqp_util:declaration().
%% ====================================================================
open_call_close(Connection, Declarations) when is_list(Declarations) ->
	#state{ch=Ch}=C1 = ensure_open(Connection),
	try
		[amqp_channel:call(Ch, D) || D <- Declarations]
	after
		ensure_closed(C1)
	end;
open_call_close(Connection, Declaration) ->
	#state{ch=Ch}=C1 = ensure_open(Connection),
	try
		amqp_channel:call(Ch, Declaration)
	after
		ensure_closed(C1)
	end.


%% open_declare_close/2
%% ====================================================================
%% @doc Open conn/channel, make declaration call w/ check, close channel/conn
-spec open_declare_close(#state{}, Declarations) -> ok when
	Declarations :: [deck36_amqp_util:declaration()]
				  | deck36_amqp_util:declaration().
%% ====================================================================
open_declare_close(Connection, Declarations) when is_list(Declarations) ->
	#state{ch=Ch}=C1 = ensure_open(Connection),
	try
		lists:foreach(fun(D) -> declare(Ch, D) end, Declarations),
		ok
	after
		ensure_closed(C1)
	end;
open_declare_close(Connection, Declaration) ->
	#state{ch=Ch}=C1 = ensure_open(Connection),
	try
		declare(Ch, Declaration),
		ok
	after
		ensure_closed(C1)
	end.


%% declare/2
%% ====================================================================
%% @doc Make the declaration call to channel Ch
-spec declare(Ch :: pid(), deck36_amqp_util:declaration()) -> ok.
%% ====================================================================
declare(Ch, #'queue.declare'{}=D) ->
	#'queue.declare_ok'{} = amqp_channel:call(Ch, D),
	ok;
declare(Ch, #'exchange.declare'{}=D) ->
	#'exchange.declare_ok'{} = amqp_channel:call(Ch, D),
	ok;
declare(Ch, #'queue.bind'{}=D) ->
	#'queue.bind_ok'{} = amqp_channel:call(Ch, D),
	ok;
declare(Ch, #'queue.delete'{}=D) ->
	#'queue.delete_ok'{} = amqp_channel:call(Ch, D),
	ok;
declare(Ch, #'exchange.delete'{}=D) ->
	#'exchange.delete_ok'{} = amqp_channel:call(Ch, D),
	ok;
declare(Ch, #'queue.unbind'{}=D) ->
	#'queue.unbind_ok'{} = amqp_channel:call(Ch, D),
	ok.
	

%% ====================================================================
%% Internal functions
%% ====================================================================

%% host/1
%% ====================================================================
%% @doc Return a valid host string to be used in #amqp_params_network{}
-spec host(list() | binary() | tuple()) -> string().
%% ====================================================================
host(Host) when is_list(Host) ->
	case io_lib:printable_list(Host) of
		true -> Host;
		false -> erlang:error(einval)
	end;
host(Host) when is_binary(Host) ->
	host(erlang:binary_to_list(Host));
host(Host) when is_tuple(Host) ->
	case deck36_inet:ntoa(Host) of
		{error, einval} -> erlang:error(einval);
		String -> String
	end.


%% bin/1
%% ====================================================================
%% @doc Return binary from binary or list
-spec bin(binary() | list()) -> binary().
%% ====================================================================
bin(Bin) when is_binary(Bin) ->
	Bin;
bin(List) when is_list(List) ->
	erlang:list_to_binary(List).


%% open_channel/2
%% ====================================================================
%% @doc Open channel with or without consumer
-spec open_channel(Conn :: pid(), Consumer) -> Result when
	Consumer :: undefined
			  | {module(), [any()]},
	Result :: {ok, pid()}
			| {error, reason()}.
%% ====================================================================
open_channel(Conn, undefined) ->
	amqp_connection:open_channel(Conn);
open_channel(Conn, Cons) ->
	amqp_connection:open_channel(Conn, Cons).

