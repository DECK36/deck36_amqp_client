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
%% @doc Simple processor, which calls callback functions on delivery.
%%
%% Primarily used by deck36_amqp_consumer_container.
%%
%% Implements behaviour amqp_gen_consumer.
%%
%% init/1 expects a proplist containing:
%%
%% ```{acknowledge, all | ok | error}''' - optional (default: all)  
%% Messages will be acknowledged according to this setting.
%% all -> acknowledge all messages
%% ok -> acknowledge only if callback succeeded
%% error -> acknowledge only if callback returned an error
%% explicit -> acknowledge only if callback returned ```{ok, ack}'''.
%%             This means you have to acknowledge the message yourself in your
%%             error callback in case of an error.
%%
%% ```{deliver_cb, CbFun}''' - mandatory
%% CbFun must be a fun/1 and will be called upon delivery with #amqp_msg{} as only argument.
%% It must return one of
%% * ok - success, acknowledge according to acknowledge mode
%% * {ok, ack} - success, acknowledge even if acknowledge mode is set to error
%% * {ok, requeue} - success, don't acknowledge (but requeue) even if acknowledge mode is set to ok or all
%% * {error, Reason} - failure, don't acknowledge unless acknowledge mode is set to all or error. If dont_requeue_on_error is set, your error handler will have to take care of the message. 
%%
%% ```{error_cb, CbFun}''' - optional
%% CbFun must be a fun/1 and will be called when deliver_cb returned {error, term()}.
%% The argument is a tuple of {Reason, Deliver, Msg, Channel} with
%% * Reason :: term() - whatever your deliver_cb returned as reason
%% * Deliver :: #'basic.deliver'{} - so your error_cb can still acknowledge the message. Keep in mind, that depending on your settings the message might already have been acknowledged.
%% * Msg :: #amqp_msg{} - the initial message
%% * Channel :: pid() - the AMQP channel pid 

-module(deck36_amqp_consumer).
-behaviour(amqp_gen_consumer).
-export([init/1,
		 handle_consume/3,
		 handle_consume_ok/3,
		 handle_cancel/2,
		 handle_cancel_ok/3,
		 handle_deliver/3,
		 handle_info/2,
		 handle_call/3,
		 terminate/2]).

-export([is_valid_opts/1]).

-include_lib("amqp_client/include/amqp_gen_consumer_spec.hrl").
-include_lib("deck36_common/include/deck36_macros.hrl").
-include_lib("deck36_common/include/deck36_types.hrl").

%% ====================================================================
%% Types
%% ====================================================================
-export_type([start_opt/0]).
-type start_opt() :: {deliver_cb, cb_def()}
				   | {error_cb, cb_def()}
				   | {acknowledge_mode, acknowledge_mode()}
				   | dont_requeue_on_error
				   | {handle_mode, non_blocking | blocking}.
-type cb_def() :: {module(), function()}
				| {module(), function(), [any()]}
				| fun().
-type acknowledge_mode() :: all
						  | ok
						  | error
						  | explicit.


%% ====================================================================
%% API functions
%% ====================================================================
is_valid_opts(Opts) ->
	is_valid_deliver_cb_opt(?GV(deliver_cb, Opts)) andalso
		is_valid_error_cb_opt(?GV(error_cb, Opts)) andalso
		is_valid_acknowledge_mode_opt(?GV(acknowledge_mode, Opts)) andalso
		is_valid_handle_mode_opt(?GV(handle_mode, Opts)).


%% ====================================================================
%% Behavioural functions 
%% ====================================================================
-record(state, {deliver_cb, channel, error_cb, acknowledge_mode, requeue_on_error = true, handle_mode = non_blocking}).

%% init/1
%% ====================================================================
%% @doc amqp_gen_consumer:init/1
%%
%% This callback is invoked by the channel, when it starts
%% up. Use it to initialize the state of the consumer. In case of
%% an error, return {stop, Reason} or ignore.
%% ====================================================================
init([Opts]) ->
	ErrorCb = case ?GV(error_cb, Opts) of
				  undefined -> fun(_X) -> ok end;
				  ErrorDef -> get_cb(ErrorDef)
			  end,
	{ok, #state{
				deliver_cb = get_cb(?GV(deliver_cb, Opts)),
				error_cb = ErrorCb,
				acknowledge_mode = ?GV(acknowledge_mode, Opts, all),
				handle_mode = ?GV(handle_mode, Opts, non_blocking),
				requeue_on_error = not proplists:get_bool(dont_requeue_on_error, Opts)
			   }}.


%% handle_consume/3
%% ====================================================================
%% @doc amqp_gen_consumer:handle_consume/3
%%
%% This callback is invoked by the channel before a basic.consume
%% is sent to the server.
%% ====================================================================
handle_consume(#'basic.consume'{}=_Consume, _Sender, State) ->
	{ok, State}.


%% handle_consume_ok/3
%% ====================================================================
%% @doc amqp_gen_consumer:handle_consume_ok/3
%%
%% This callback is invoked by the channel every time a basic.consume_ok
%% is received from the server. Consume is the original method sent out
%% to the server - it can be used to associate the call with the response.
%% ====================================================================
handle_consume_ok(#'basic.consume_ok'{}=_ConsumeOk, #'basic.consume'{}=_Consume, State) ->
	{ok, State}.


%% handle_cancel/2
%% ====================================================================
%% @doc amqp_gen_consumer:handle_cancel/2
%%
%% This callback is invoked by the channel every time a basic.cancel
%% is received from the server.
%% ====================================================================
handle_cancel(#'basic.cancel'{}=_Cancel, State) ->
	{ok, State}.


%% handle_cancel_ok/3
%% ====================================================================
%% @doc amqp_gen_consumer:handle_cancel_ok/3
%%
%% This callback is invoked by the channel every time a basic.cancel_ok
%% is received from the server.
%% ====================================================================
handle_cancel_ok(#'basic.cancel_ok'{}=_CancelOk, #'basic.cancel'{}=_Cancel, State) ->
	{ok, State}.


%% handle_deliver/3
%% ====================================================================
%% @doc amqp_gen_consumer:handle_deliver/3
%%
%% This callback is invoked by the channel every time a basic.deliver
%% is received from the server.
%% ====================================================================
handle_deliver(#'basic.deliver'{} = Deliver,
			   #amqp_msg{} = Msg,
			   #state{deliver_cb = Cb,
					  error_cb = ErrorCb,
					  channel = Ch,
					  acknowledge_mode = AckMode,
					  handle_mode = HMode,
					  requeue_on_error = ROE}=State) ->
	case HMode of
		blocking ->
			do_handle_deliver(Deliver, Msg, Cb, ErrorCb, Ch, AckMode, ROE);
		non_blocking ->
			proc_lib:spawn(fun() ->
								   do_handle_deliver(Deliver, Msg, Cb, ErrorCb, Ch, AckMode, ROE)
						   end)
	end,
	{ok, State}.


%% handle_info/2
%% ====================================================================
%% @doc amqp_gen_consumer:handle_info/2
%%
%% This callback is invoked the consumer process receives a message.
%% ====================================================================
handle_info(_Info, State) ->
    {ok, State}.


%% handle_call/3
%% ====================================================================
%% @doc amqp_gen_consumer:handle_call/3
%%
%% This callback is invoked by the channel when calling amqp_channel:call_consumer/2.
%%
%% Reply is the term that amqp_channel:call_consumer/2 will return.
%%
%% If the callback returns {noreply, _}, then the caller to
%% amqp_channel:call_consumer/2 and the channel remain blocked until
%% gen_server2:reply/2 is used with the provided From as the first argument.
%% ====================================================================
handle_call({set_channel, Channel}, _From, S) ->
	{reply, ok, S#state{channel = Channel}};
handle_call(_Msg, _From, State) ->
	{reply, ok, State}.


%% terminate/2
%% ====================================================================
%% @doc amqp_gen_consumer:terminate/2
%%
%% This callback is invoked by the channel after it has shut down and
%% just before its process exits.
%% ====================================================================
terminate(_Reason, _State) ->
    ok.


%% ====================================================================
%% Internal functions
%% ====================================================================

%% is_valid_deliver_cb_opt/1
%% ====================================================================
%% @doc Determine if given value is a valid deliver_cb option
-spec is_valid_deliver_cb_opt(term()) -> boolean(). 
%% ====================================================================
is_valid_deliver_cb_opt(O) ->
	is_valid_cb_opt(O).


%% is_valid_error_cb_opt/1
%% ====================================================================
%% @doc Determine if given value is a valid error_cb option
-spec is_valid_error_cb_opt(term()) -> boolean().
%% ====================================================================
is_valid_error_cb_opt(undefined) ->
	true;
is_valid_error_cb_opt(O) ->
	is_valid_cb_opt(O).


%% is_valid_cb_opt/1
%% ====================================================================
%% @doc Determine if given value is a valid callback option
-spec is_valid_cb_opt(term()) -> boolean().
%% ====================================================================
is_valid_cb_opt({Mod, Fun}) ->
	is_valid_cb_opt({Mod, Fun, []});
is_valid_cb_opt({Mod, Fun, Args}) when is_atom(Mod), is_atom(Fun), is_list(Args) ->
	true;
is_valid_cb_opt(Fun) -> 
	is_function(Fun, 1).


%% is_valid_acknowledge_mode_opt/1
%% ====================================================================
%% @doc Determine if given value is a valid acknowledge_mode option
-spec is_valid_acknowledge_mode_opt(term()) -> boolean().
%% ====================================================================
is_valid_acknowledge_mode_opt(all) -> true;
is_valid_acknowledge_mode_opt(error) -> true;
is_valid_acknowledge_mode_opt(ok) -> true;
is_valid_acknowledge_mode_opt(explicit) -> true;
is_valid_acknowledge_mode_opt(undefined) -> true;
is_valid_acknowledge_mode_opt(_) -> false.


%% is_valid handle_mode_opt/1
%% ====================================================================
%% @doc Determine if given value is a valid handle_mode option
-spec is_valid_handle_mode_opt(term()) -> boolean().
%% ====================================================================
is_valid_handle_mode_opt(blocking) -> true;
is_valid_handle_mode_opt(non_blocking) -> true;
is_valid_handle_mode_opt(undefined) -> true;
is_valid_handle_mode_opt(_) -> false.


%% get_cb/1
%% ====================================================================
%% @doc Get callback fun from given Definition
-spec get_cb(Definition) -> fun() when
	Definition :: {Module, Function}
				| {Module, Function, Args}
				| fun(),
	Module :: module(),
	Function :: atom(),
	Args :: list().
%% ====================================================================
get_cb(Definition) ->
	case Definition of
		{M, F} -> fun(X) -> apply(M, F, [X]) end;
		{M, F, A} -> fun(X) -> apply(M, F, [X | A]) end;
		F when is_function(F, 1) -> F
	end.


%% do_handle_deliver/6
%% ====================================================================
%% @doc handle_deliver/3 worker function
%%
%% - Execute Cb(Msg)
%% - Execute ErrorCb({Reason, Deliver, Msg, Ch}) if Cb failed
%% - Maybe acknowledge Deliver according to AckMode
-spec do_handle_deliver(#'basic.deliver'{}, #amqp_msg{}, Cb, ErrorCb, Ch, AckMode, RequeueOnError) -> ok when
	Cb :: fun(),
	ErrorCb :: fun(),
	Ch :: pid(),
	AckMode :: acknowledge_mode(),
	RequeueOnError :: boolean().
%% ====================================================================
do_handle_deliver(#'basic.deliver'{delivery_tag=Tag}=Deliver,
				  #amqp_msg{}=Msg,
				  Cb, ErrorCb, Ch, AckMode, RequeueOnError) -> 
	R = case cb(Cb,Msg) of
			  {error, Reason} ->
				  error_cb(ErrorCb, {Reason, Deliver, Msg, Ch}),
				  error;
			  X -> X
		  end,
	ack_if(shall_ack(AckMode, R), Ch, Tag, RequeueOnError),
	ok.


%% shall_ack/2
%% ====================================================================
%% @doc Decide if delivery should by acknowledged
-spec shall_ack(AckMode, Result) -> boolean() when
	AckMode :: all | ok | error,
	Result :: ok | {ok, ack} | {ok, requeue} | error.
%% ====================================================================
shall_ack(_, {ok, requeue}) ->	false;
shall_ack(all, _) ->			true;
shall_ack(ok, ok) ->			true;
shall_ack(_, {ok, ack}) ->		true;
shall_ack(ok, error) ->			false;
shall_ack(error, ok) ->			false;
shall_ack(error, error) ->		true;
shall_ack(explicit, _) ->		false.


%% cb/2
%% ====================================================================
%% @doc Try callback and either return result or caught Error as {error, Error}
-spec cb(Cb :: fun(), Arg :: term()) -> term() | {error, term()}.  
%% ====================================================================
cb(Cb, Arg) ->
	try
		Cb(Arg)
	catch
		error:Reason -> {error, Reason};
		Class:Reason -> {error, {Class, Reason}}
	end.


%% error_cb/2
%% ====================================================================
%% @doc Try error callback
%%
%% Log error if error callback failed.
-spec error_cb(Cb :: fun(), Arg :: term()) -> term().
%% ====================================================================
error_cb(Cb, Arg) ->
	try
		Cb(Arg)
	catch
		error:Reason ->
			error_logger:error_report({?MODULE, handle_deliver, error_cb, Reason});
		Class:Reason ->
			error_logger:error_report({?MODULE, handle_deliver, error_cb, {Class, Reason}})
	end.


%% ack_if/3
%% ====================================================================
%% @doc Naybe acknowledge message
-spec ack_if(Ack :: boolean(), Ch :: pid(), Tag :: term(), RequeueOnError :: boolean()) -> ok.
%% ====================================================================
ack_if(true, Ch, Tag, _) ->		amqp_channel:cast(Ch, #'basic.ack'{delivery_tag=Tag});
ack_if(false, Ch, Tag, true) ->	amqp_channel:cast(Ch, #'basic.nack'{delivery_tag=Tag, requeue=true});
ack_if(false, _, _, false) ->	ok.

