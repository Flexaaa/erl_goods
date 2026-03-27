-module(goods_http).
-behaviour(gen_server).

-export([start_link/0]).

-export([init/1, handle_cast/2, handle_call/3, handle_info/2, terminate/2]).
-export([init/2]).

-include_lib("kernel/include/logger.hrl").
-include("goods.hrl").

-define(DEFAULT_PORT, 5432).
-define(MAX_URL_LENGTH, 800).
-define(ERROR_JSON(Msg), list_to_binary(["{\"error\": \"", Msg, "\"}"])).

-record(state, {    
}).

start_link() ->
    gen_server:start({local, ?MODULE}, ?MODULE, [], []).

init(_Options) ->
    Port = application:get_env(goods_app, port, ?DEFAULT_PORT),
    ?LOG_INFO("starting server on port ~p~n", [Port]),

    Dispatch = cowboy_router:compile([
		{'_', [
            {"/assembled-products", goods_http, [{action, assembled_products}] },
            {"/set-time", goods_http, [{action, set_time}] }
        ]}
	]),

	{ok, _} = cowboy:start_clear(http, [{port, Port}], #{
		env => #{dispatch => Dispatch}
	}),

    {ok, #state{}}.

handle_cast(_Message, State) ->
    {noreply, State}.

handle_call({assembled_products, Req}, _From, #state{} = State) ->
    Data = process_assembled_products(Req, State),
    {reply, Data, State};

handle_call({set_time, Req}, _From, #state{} = State) ->
    Result = process_set_time(Req, State),
    {reply, Result, State};

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
    ?LOG_INFO("Handle request action ~p with method ~p",[Action, Method]),
    Req = case Method of
        <<"GET">> ->
            handle_get(Req0, Action);
        <<"POST">> ->
            handle_post(Req0, Action);
        _ ->
            ?LOG_INFO("unknown method",[]),
            cowboy_req:reply(404, Req0)
    end,
    {ok, Req, Opts}.

handle_get(Req, assembled_products) ->
    Data = gen_server:call(?MODULE, {assembled_products, Req}),
    ?LOG_INFO("assembled_products data ~p",[Data]),
    case Data of
        {error, Reason} ->
            cowboy_req:reply(400, #{}, Reason, Req);
        BinaryData ->
            cowboy_req:reply(200, #{}, BinaryData, Req)
    end;
handle_get(Req, _OtherAction) ->
    ?LOG_INFO("unknown get request",[]),
    cowboy_req:reply(404, #{}, <<"wrong_action">>, Req).

handle_post(Req, set_time) ->
    Result = gen_server:call(?MODULE, {set_time, Req}),
    ?LOG_INFO("set_time result ~p",[Result]),
    case Result of
        {error, Reason} ->
            cowboy_req:reply(400, #{}, Reason, Req);
        ok ->
            cowboy_req:reply(200, #{}, [], Req)
    end;
handle_post(Req, _OtherAction) ->
    ?LOG_INFO("unknown post request",[]),
    cowboy_req:reply(404, #{}, <<"wrong_action">>, Req).



-spec process_assembled_products(term(), #state{}) -> binary() | {error, term()}.
process_assembled_products(Req, _State) ->
    Args = cowboy_req:parse_qs(Req),

    StartDateText = proplists:get_value(<<"start_date">>, Args, undefined),
    EndDateText = proplists:get_value(<<"end_date">>, Args, undefined),
    IdText = proplists:get_value(<<"id">>, Args, undefined),

    ?LOG_INFO("parametest StartDateText=~p, EndDateText=~p, Id=~p", [StartDateText, EndDateText,IdText]),
    
    case check_date_values(StartDateText, EndDateText) of
        false ->
            {error, "invalid parameters"};
        _ ->
            Id = to_int_if_need(IdText),
            Result = goods_db:get(#goods_search_options{
                start_date = transform_date(StartDateText),
                end_date   = transform_date(EndDateText),
                id = Id
            }),
            ?LOG_INFO("Result ~p~n", [Result]),
            case Result of
                {error, _} ->
                    Result;
                Data ->
                    jsx:encode([record_to_map(R) || R <- Data])
            end
    end.

-spec record_to_map(#goods_entry{}) -> list().
record_to_map(#goods_entry{time = T, id = I, price = P}) ->
    [{time, T}, {id, I}, {price, P}].


-spec process_set_time(term(), #state{}) -> ok | {error, term()}.
process_set_time(Req, _State) ->
    case cowboy_req:read_body(Req) of
        {ok, Body, Req} ->        
            ?LOG_INFO("set-time request with body: ~p", [Body]),
            goods_requester:set_timeout(binary_to_integer(Body));
        _ ->
            {error, "failed to read body"}
    end.

check_date_values(undefined, undefined) ->
    true;
check_date_values(undefined, _EndDate) ->
    false;
check_date_values(_StartDate, undefined) ->
    false;
check_date_values(_StartDate, _EndDate) ->
    true.

transform_date(undefined) ->
    undefined;
transform_date(DateBin) ->
    <<DateBin/binary, "T00:00:00Z">>.

to_int_if_need(undefined) ->
    undefined;
to_int_if_need(Id) ->
    try binary_to_integer(Id) of
        IdInt ->
            IdInt
    catch
        error:_ ->
            undefined
    end.