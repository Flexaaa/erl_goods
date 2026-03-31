-module(goods_requester).
-behaviour(gen_server).

-include_lib("kernel/include/logger.hrl").
-include("goods.hrl").

-define(DEFAULT_TIMEOUT, 30000).
-define(DEFAULT_URL, "https://dummyjson.com/products").

-export([start_link/0, set_timeout/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {
    timeout          :: integer(),
    url              :: string(),
    mod              :: module(),
    partial          :: boolean(),  % true - and receiving will be by small chunks
    chunk_size       :: integer(),  % if partial true sets number of requested elements is single request
    tref = undefined :: undefined | reference()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

set_timeout(Timeout) ->
    gen_server:call(?MODULE, {set_timeout, Timeout}).

init([]) ->
    Timeout = application:get_env(goods_app, timeout, ?DEFAULT_TIMEOUT),
    Url = application:get_env(goods_app, url, ?DEFAULT_URL),
    ModName = application:get_env(goods_app, module, goods_db),
    Partial = application:get_env(goods_app, partial, false),
    ChunkSize = application:get_env(goods_app, chunk_size, 10),
    ?LOG_INFO("goods_requester Timeout=~p, Url=~p, ModName=~p, Partial =~p, ChunkSize=~p", [Timeout, Url, ModName, Partial, ChunkSize]),
    erlang:send_after(500, self(), get_data),
    {ok, #state{timeout = Timeout, url = Url, mod = ModName, partial = Partial, chunk_size = ChunkSize}}.

handle_call({set_timeout, Timeout}, _From, State=#state{tref = TRef}) ->
    ?LOG_INFO("setting timeout ~p", [Timeout]),
    stop_timer(TRef),
    erlang:send_after(0, self(), get_data),
    {reply, [], State#state{timeout = Timeout}};

handle_call(Msg, _From, State) ->
    ?LOG_INFO("unhandled call ~p", [Msg]),
    {reply, [], State}.


handle_cast(Msg, State) ->
    ?LOG_INFO("unhandled cast ~p", [Msg]),
    {noreply, State}.


handle_info(get_data, State=#state{timeout = Timeout, url = Url, mod = ModName, partial = Partial, chunk_size = ChunkSize}) ->
    ?LOG_INFO("requesting data, URL =~p", [Url]),
    OutHeaders = [{"User-Agent", "erl"}],
    HTTPOptions = [{ssl, [{verify, verify_none}]}, {timeout, 3000}],
    Options = [
    {body_format, binary}, 
    {socket_opts, [
            inet, 
            {recbuf, 65536},
            {sndbuf, 65536},
            {nodelay, true}
        ]}
    ],
    Data = case Partial of
        false ->
            case httpc:request(get, {Url, OutHeaders}, HTTPOptions, Options) of
                 {ok, {_StatusLine, _Headers, Body}} ->
                    ?LOG_INFO("data received", []),
                    convert_body(Body);
                {error, Reason} ->
                    ?LOG_INFO("failed to get data, reason ~p", [Reason]),
                    {error, Reason}
            end;
        true ->
            fetch_recursive(Url, OutHeaders, HTTPOptions, Options, ChunkSize, 0, 3, [])
    end,

    case Data of
        {error, Reason1} ->
            ?LOG_INFO("failed to get data, reason ~p", [Reason1]);
        _ ->
            ModName:put(Data)
    end,
    TRef = erlang:send_after(Timeout, self(), get_data),
    {noreply, State#state{tref = TRef}};

handle_info(Msg, State) ->
    ?LOG_INFO("unhandled info ~p", [Msg]),
    {noreply, State}.

terminate(_Reason, _State=#state{tref = TRef}) ->
    stop_timer(TRef),
	terminated.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

fetch_recursive(Url, OutHeaders, HTTPOptions, Options, Limit, Skip, Attempts, Acc) ->
    UrlWithParams = lists:flatten(io_lib:format(Url ++ "?limit=~p&skip=~p", [Limit, Skip])),
    ?LOG_INFO("Requesting ~p ", [UrlWithParams]),
    case httpc:request(get, {UrlWithParams, OutHeaders}, HTTPOptions, Options) of
        {ok, {{_, 200, _}, _, Body}} ->
            case convert_body(Body) of
                [] -> 
                    ?LOG_INFO("Готово!~n"),
                    lists:reverse(Acc); % Конец данных
                Products ->
                    ?LOG_INFO("получено ~p объектов~n", [length(Products)]),
                    % Рекурсивно запрашиваем следующую порцию
                    fetch_recursive(Url, OutHeaders, HTTPOptions, Options, Limit, Skip + Limit, Attempts, Products ++ Acc)
            end;
        {error, Reason} ->
            case Attempts of
                0 ->
                    {error, Reason};
                _ ->
                    timer:sleep(1000),
                    ?LOG_INFO("Retrying, attempts ~p", [Attempts - 1]),
                    fetch_recursive(Url, OutHeaders, HTTPOptions, Options, Limit, Skip, Attempts - 1, Acc)
            end
    end.

convert_body(Body) ->
    %?LOG_INFO("body = ~s", [Body]),
    %?LOG_INFO("Decode = ~p", [jsx:decode(Body, [{return_maps, true}])]),
    #{<<"products">> := Products} = jsx:decode(Body, [{return_maps, true}]),
    Now = list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second), [{offset, "Z"}])),

    [ #goods_entry{
        time = Now,
        id = maps:get(<<"id">>, P),
        price = ensure_float(maps:get(<<"price">>, P))
      } || P <- Products ].

% Вспомогательная функция, так как JSON может вернуть integer вместо float (например, 10 вместо 10.0)
ensure_float(V) when is_integer(V) -> V * 1.0;
ensure_float(V) -> V.

stop_timer(undefined) ->
    ok;
stop_timer(TRef) ->
    erlang:cancel_timer(TRef).