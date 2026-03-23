-module(goods_http).

-export([start_link/0]).

-include_lib("kernel/include/logger.hrl").
-include("goods.hrl").

-define(DEFAULT_PORT, 5432).
-define(MIN_SIZE_TO_COMPRESS, 512).
-define(MAX_URL_LENGTH, 800).
-define(ERROR_JSON(Msg), list_to_binary(["{\"error\": \"", Msg, "\"}"])).

-record(state, {    
}).

start_link() ->
    Port = application:get_env(goods_server_app, port, ?DEFAULT_PORT),
    ?LOG_INFO("starting server on port ~p~n", [Port]),

	misultin:start_link([
        {name, goods_http},
        {port, Port},
        {get_url_max_size, ?MAX_URL_LENGTH},
        {loop, fun(Req) -> handle_http_safe(Req, #state{}) end}
    ]).

-spec handle_http_safe(term(), #state{}) -> term().
handle_http_safe(Req, State = #state{}) ->
	try
		handle_http(Req, State)
    catch Error ->
        ?LOG_INFO("exception ~p; request ~p ~p", [Error, Req, misultin_req:parse_qs(Req)]),
        misultin_req:respond(503, [], "unknown error", Req)
	end.

-spec handle_http(term(), #state{}) -> term().
handle_http(Req, State) ->
    Method = misultin_req:get(method, Req), 
	case Method of
		'GET' ->
            case misultin_req:resource([lowercase, urldecode], Req) of
                ["assembled-products"] ->
                    ?LOG_INFO("assembled-products request"),
                    process_assembled_products(Req, State);
                _ ->
                    misultin_req:respond(400, [], ?ERROR_JSON("unknown request"), Req)
            end;
		'POST' ->
			case misultin_req:resource([lowercase, urldecode], Req) of
                ["set-time"] ->
                    ?LOG_INFO("set-time request"),
                    process_set_time(Req, State);
                _ ->
                    misultin_req:respond(400, [], ?ERROR_JSON("unknown request"), Req)
            end
	end.


-spec process_assembled_products(term(), #state{}) -> term().
process_assembled_products(Req, _State) ->
    Args = misultin_req:parse_qs(Req),
    StartDateText = case misultin_utility:get_key_value("start_date", Args) of
        undefined -> undefined;
        StartDateT -> StartDateT
    end,
    
    EndDateText = case misultin_utility:get_key_value("end_date", Args) of
        undefined -> undefined;
        EndDateT -> EndDateT
    end,
    
    IdText = case misultin_utility:get_key_value("id", Args) of
        undefined -> undefined;
        IdT -> IdT
    end,

    ?LOG_INFO("parametest StartDateText=~p, EndDateText=~p, Id=~p", [StartDateText, EndDateText,IdText]),
    
    case check_date_values(StartDateText, EndDateText) of
        false ->
            misultin_req:respond(400, [], ?ERROR_JSON("invalid parameters"), Req);
        _ ->
            Id = list_to_int_if_need(IdText),
            Result = goods_db:get(#goods_search_options{
                start_date = StartDateText,
                end_date   = EndDateText,
                id = Id
            }),
            ?LOG_INFO("Result ~p~n", [Result]),
            case Result of
                {error, _} ->
                    misultin_req:respond(503, [], ?ERROR_JSON("internal_error"), Req);
                Data ->
                    Body = jsx:encode([record_to_map(R) || R <- Data]),
                    misultin_req:ok([], Body, Req)
            end
    end.

-spec record_to_map(#goods_entry{}) -> list().
record_to_map(#goods_entry{time = T, id = I, price = P}) ->
    [{time, T}, {id, I}, {price, P}].


-spec process_set_time(term(), #state{}) -> term().
process_set_time(Req, _State) ->
    Body = misultin_req:get(body, Req),
    ?LOG_INFO("set-time request with body: ~p", [Body]),
    goods_requester:set_timeout(binary_to_integer(Body)),
    misultin_req:ok(["timeout set"], Req).

check_date_values(undefined, undefined) ->
    true;
check_date_values(undefined, _EndDate) ->
    false;
check_date_values(_StartDate, undefined) ->
    false;
check_date_values(_StartDate, _EndDate) ->
    true.

list_to_int_if_need(Id) when is_integer(Id) ->
    Id;
list_to_int_if_need(Id) ->
    try list_to_integer(Id) of
        IdInt ->
            IdInt
    catch
        error:_ ->
            undefined
    end.