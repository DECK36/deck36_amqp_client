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
%% @doc Setup server.
%%
%% To see how to use this, see:
%% * start_link/1 and type start_opts()
%% * stop/1
%%
%% You should always properly shut down the setup using stop/1 or
%% you might end up with errors from amqp_client and tear down will
%% not take place.


-module(deck36_amqp_setup).
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("deck36_common/include/deck36_common.hrl").

%% ====================================================================
%% Types
%% ====================================================================
-export_type([start_opts/0]).
-type start_opts() :: [start_opt()].
-type start_opt() :: {connection, deck36_amqp_util:connection_def()}
		  		   | {queue, deck36_amqp_util:queue_def()}
				   | {exchange, deck36_amqp_util:exchange_def()}
				   | {binding, deck36_amqp_util:binding_def()}
				   | {teardown_on_stop, [teardown_opt()]}.
-type teardown_opt() :: all
					  | bindings
					  | queues
					  | exchanges
					  | deck36_amqp_util:definition().


%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/1,
		 stop/1,
		 info/1,
		 declare/2,
		 delete/2]).

%% start_link/1
%% ====================================================================
%% @doc Start unnamed, linked setup server.
%%
%% Will declare entities to the broker according to given options.
%% See type start_opt() or test/ct/config/ct.config.template for further
%% information.
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
%% @doc Stop server
%%
%% Will tear down entities it has declared according to the 
%% teardown_on_stop start option. See README.md for further information.
-spec stop(pid()) -> ok.
%% ====================================================================
stop(Ref) ->
	gen_server:call(Ref, stop).


%% info/1
%% ====================================================================
%% @doc Get information about setup identified by Ref
-spec info(pid()) -> term().
%% ====================================================================
info(Ref) ->
	gen_server:call(Ref, info).


%% declare/2
%% ====================================================================
%% @doc Declare queues, exchanges or bindings dynamically.
%%
%% Will be torn down on stop according to teardown_on_stop option
-spec declare(server_ref(), Def) -> ok when
	Def :: deck36_amqp_util:definition()
		 | [deck36_amqp_util:definition()].
%% ====================================================================
declare(Ref, Defs) when is_list(Defs) ->
	gen_server:call(Ref, {declare, [deck36_amqp_util:declaration(D) || D <- Defs]});
declare(Ref, Def) ->
	declare(Ref, [Def]).


%% delete/2
%% ====================================================================
%% @doc Delete queue, exchange or binding.
%%
%% Definitions will only be deleted if the setup declared this unless
%% they are given in form of a delete declaration. 
-spec delete(server_ref(), Defs) -> ok when
	Defs :: Def
		  | [Def],
	Def :: deck36_amqp_util:definition()
		 | deck36_amqp_util:delete_definition().
%% ====================================================================
delete(Ref, Defs) when is_list(Defs) ->
	F = fun(D) ->
				case deck36_amqp_util:is_deletion(D) of
					true -> D;
					false -> deck36_amqp_util:declaration(D)
				end
		end,
	gen_server:call(Ref, {delete, [F(Def) || Def <- Defs]});
delete(Ref, Def) ->
	delete(Ref, [Def]).


%% ====================================================================
%% Behavioural functions 
%% ====================================================================
-record(state, { conn, declarations = [], opts = []}).

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
	Conn = deck36_amqp_connection:new(?GV(connection, Opts)),
	setup(#state{opts = Opts, conn = Conn}).


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
handle_call(stop, _From, S) ->
	{stop, normal, ok, S};
handle_call(info, _From, S) ->
	{reply, do_info(S), S};
handle_call({declare, Declarations}, _From, S) ->
	{R, S1} = do_declare(Declarations, S),
	{reply, R, S1};
handle_call({delete, Declarations}, _From, S) ->
	{R, S1} = do_delete(Declarations, S),
	{reply, R, S1};
handle_call(_Request, _From, State) ->
    {reply, ok, State}.


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
	shutdown(teardown(State)),
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

%% setup/1
%% ====================================================================
%% @doc Setup environment
-spec setup(#state{}) -> {ok, #state{}}.
%% ====================================================================
setup(#state{conn=Conn, opts=Opts}=S) ->
	%% Declare entities in order queues, exchanges, bindings
	Declarations = lists:flatten([
								  [deck36_amqp_util:queue(Q) || Q <- ?GA(queue, Opts)],
								  [deck36_amqp_util:exchange(E) || E <- ?GA(exchange, Opts)],
								  [deck36_amqp_util:binding(B) || B <- ?GA(binding, Opts)]
								 ]),
	ok = deck36_amqp_connection:open_declare_close(Conn, Declarations),
	{ok, S#state{
				 declarations = lists:reverse(Declarations), % store in reversed order, so new declarations can simply be prepended and teardown order stays intact
				 opts = Opts}}.




%% shutdown/1
%% ====================================================================
%% @doc Shutdown channel and conneciton
-spec shutdown(#state{}) -> {ok, #state{}}.
%% ====================================================================
shutdown(#state{conn=undefined}=S) ->
	{ok, S};
shutdown(#state{conn=Conn}=S) ->
	{ok, S#state{conn = deck36_amqp_connection:ensure_closed(Conn)}}.


%% teardown/1
%% ====================================================================
%% @doc Tear down all entities that are marked to be torn down.
-spec teardown(#state{}) -> #state{}.
%% ====================================================================
teardown(#state{declarations = Decs, conn = Conn, opts = Opts}=S) ->
	TdOpts = ?GV(teardown_on_stop, Opts, []),
	TdRules = lists:flatten([td_rule(TdOpt) || TdOpt <- TdOpts]),
	Explicit = [deck36_amqp_util:declaration(E) || {T,_}=E <- TdOpts,
												   T == queue orelse
													   T == exchange orelse
													   T == binding],
	{Td, Rem} = split_td_rem_list(Decs, TdRules, Explicit),
	deck36_amqp_connection:open_call_close(
	  Conn,
	  [teardown_declare(D) || D <- Td]),
	S#state{declarations = Rem}.


%% split_td_rem_list/5
%% ====================================================================
%% @doc Worker function for split_teardown_remaining/2
-spec split_td_rem_list([Declaration], Rules, Explicit) -> Result when
	Declaration :: deck36_amqp_util:declaration(),
	Rules :: [atom()],
	Explicit :: [deck36_amqp_util:declaration()],
	Result :: {Teardown, Remaining},
	Teardown :: [deck36_amqp_util:declaration()],
	Remaining :: [deck36_amqp_util:declaration()].
%% ====================================================================
split_td_rem_list(Decs, Rules, Explicit) ->
	lists:partition(
	  fun(D) -> should_td(D, Rules) orelse lists:member(D, Explicit) end,
	  Decs).


%% td_rule/1
%% ====================================================================
%% @doc Get internal teardown rules from given config value
-spec td_rule(term()) -> [atom()].
%% ====================================================================
td_rule(all) ->						[q, e, b];
td_rule(queues) ->					[q];
td_rule(exchanges) ->				[e];
td_rule(bindings) ->				[b];
td_rule(_) ->						[].


-define(IM(E,L), lists:member(E,L)).
%% should_td/2
%% ====================================================================
%% @doc Determine if entity should be torn down according to rules
-spec should_td({Type, Declaration}, Rules) -> boolean() when
	Type :: static
		  | dynamic,
	Declaration :: deck36_amqp_util:declaration(),
	Rules :: [atom()].
%% ====================================================================
should_td(#'queue.declare'{}, R) ->		?IM(q, R);
should_td(#'exchange.declare'{}, R) ->	?IM(e, R);
should_td(#'queue.bind'{}, R)	->		?IM(b, R);
should_td(_, _) ->						false.


%% teardown_declare/1
%% ====================================================================
%% @doc Get teardown declaration according to given setup declaration
%% or teardown declaration
-spec teardown_declare(SetupDeclaration) -> deck36_amqp_util:deletion() when
	SetupDeclaration :: deck36_amqp_util:declaration()
					  | deck36_amqp_util:deletion_def().
%% ====================================================================
teardown_declare(X) ->
	deck36_amqp_util:deletion(X).


%% do_info/1
%% ====================================================================
%% @doc info/1 worker function
-spec do_info(#state{}) -> [{atom(), term()}].
%% ====================================================================
do_info(#state{declarations=D, opts=O}) ->
	[{opts, O},
	 {declarations, D}].


%% do_declare/2
%% ====================================================================
%% @doc Worker function for declare/2.
%%
%% Declares a list of entities unless any of these is already declared by this setup.
%% @todo Better error handling. E.g. if after N declarations an error occurs the first N should be saved as declared
-spec do_declare([deck36_amqp_util:declaration()], #state{}) -> {ok, #state{}}.
%% ====================================================================
do_declare(Decs, #state{declarations=SDecs, conn=Conn}=S) ->
	case [Dec || Dec <- Decs, lists:member(Dec, SDecs)] of
		[] -> ok;
		L -> erlang:error(lists:flatten(io_lib:format("Already declared: ~p", [L])))
	end,
	ok = deck36_amqp_connection:open_declare_close(Conn, Decs),
	{ok, S#state{declarations = lists:reverse(Decs) ++ SDecs}}.


%% do_delete/2
%% ====================================================================
%% @doc Worker function for delete/2.
%%
%% @todo Better error handling. E.g. if after N deletions an error occurs the first N should be saved as deleted
-spec do_delete([deck36_amqp_util:deletion_def()], #state{}) -> {ok, #state{}}.
%% ====================================================================
do_delete(Defs, #state{declarations=SDecs, conn=Conn}=S) ->
	SDelDecs = [{deck36_amqp_util:deletion(SDec), SDec} || SDec <- SDecs],
	DecsDels = [prepare_deletion(D, SDelDecs) || D <- Defs],
	ok = deck36_amqp_connection:open_declare_close(Conn, [Del || {_, Del} <- DecsDels]),
	Removed = [Dec || {Dec, _} <- DecsDels],
	NewDecs = [Dec || Dec <- SDecs, not lists:member(Dec, Removed)],
	{ok, S#state{declarations = NewDecs}}.


%% prepare_deletion/3
%% ====================================================================
%% @doc Prepare deletion for do_delete/2.
-spec prepare_deletion(Def, StateDelDecs) -> {Dec, Del} when
	Def :: deck36_amqp_util:defintion(),
	StateDelDecs :: [{deck36_amqp_util:deletion(), deck36_amqp_util:declaration()}],
	Dec :: deck36_amqp_util:declaration(),
	Del :: deck36_amqp_util:deletion().
%% ====================================================================
prepare_deletion(D, SDelDecs) ->
	case deck36_amqp_util:is_deletion(D) of
		true -> {?GV(D, SDelDecs), D};
		false ->
			case lists:keymember(D, 2, SDelDecs) of
				true -> {D, deck36_amqp_util:deletion(D)};
				false -> erlang:error(lists:flatten(io_lib:format("Not declared: ~p", [D])))
			end
	end.
