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
    ?LOG_INFO("goods_requester Timeout=~p, Url=~p, ModName=~p", [Timeout,Url, ModName]),
    erlang:send_after(500, self(), get_data),
    {ok, #state{timeout = Timeout, url = Url, mod = ModName}}.

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


handle_info(get_data, State=#state{timeout = Timeout, url = Url, mod = ModName}) ->
    ?LOG_INFO("requesting data", []),    
    case httpc:request(get, {Url, []}, [], [{body_format, binary}]) of
        {ok, {_StatusLine, _Headers, Body}} ->
            Entries = convert_body(Body),
            ModName:put(Entries);
        {error, Reason} ->
            ?LOG_INFO("failed to get data, reason ~p", [Reason])
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


convert_body(Body) ->
    %?LOG_INFO("body = ~p", [Body]),
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