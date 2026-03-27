-module(mock_cowboy_server).
-behaviour(gen_server).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/logger.hrl").

-export([start_link/1, stop/0]).

-export([init/1, handle_cast/2, handle_call/3, handle_info/2, terminate/2]).
-export([init/2]).

-record(state, {
    data :: binary()
}).


start_link(Options) ->
    gen_server:start({local, ?MODULE}, ?MODULE, Options, []).

stop() ->
    gen_server:stop(?MODULE).

init(Options) ->
    Port = proplists:get_value(port, Options),
    Data = proplists:get_value(data, Options),
    ?debugFmt("starting server on port ~p data= ~p~n", [Port,Data]),

    Dispatch = cowboy_router:compile([
		{'_', [{"/data", mock_cowboy_server, [{action, data}] }]}
	]),
	{ok, _} = cowboy:start_clear(http, [{port, Port}], #{
		env => #{dispatch => Dispatch}
	}),

    State = #state{
        data = Data
    },
    {ok, State}.


handle_cast(_Message, State) ->
    {noreply, State}.

handle_call(data, _From, #state{data = Data} = State) ->
    {reply, Data, State};

handle_call(_Call, _From, State) ->
    {reply, unknown_method, State}.

handle_info(_Message, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    cowboy:stop_listener(?MODULE).


%%=============================================================================
%%  cowboy callbacks
%%-----------------------------------------------------------------------------

init(Req0, Opts) ->
    Method = cowboy_req:method(Req0),
    Action = proplists:get_value(action, Opts),
    ?debugFmt("Handle request action ~p with method ~p",[Action, Method]),
    Req = case Method of
        <<"GET">> ->
            handle(Req0, Action);
        _ ->
            ?debugFmt("unknown method",[]),
            cowboy_req:reply(404, Req0)
    end,
    {ok, Req, Opts}.

handle(Req, data) ->
    %{ok, Body, Req1} = cowboy_req:read_body(Req),
    %Params = cowboy_req:parse_qs(Req),
    Data = gen_server:call(?MODULE, data),
    ?debugFmt("Response data ~p",[Data]),
    cowboy_req:reply(200, #{}, Data, Req);

handle(Req, _OtherAction) ->
    ?debugFmt("unknown action",[]),
    cowboy_req:reply(404, #{}, <<"wrong_action">>, Req).

