-module(goods_db).
-behaviour(gen_server).

-include("goods.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include_lib("kernel/include/logger.hrl").

-export([start_link/0, put/1, get/1]).
-export([init/1, handle_call/3, handle_cast/2, terminate/2, code_change/3]).


start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec put([goods_entry()]) -> ok | {error, any()}.
put(Entries) ->
    gen_server:cast(?MODULE, {put, Entries}).

-spec get(goods_search_options()) -> {ok, [goods_entry()]} | {error, any()}.
get(Options) ->
    gen_server:call(?MODULE, {get, Options}).


init([]) ->
    ok = mnesia:start(),
    ?LOG_INFO("init mnesia db", []),
    mnesia:delete_table(goods_entry),
    %% Инициализация таблицы Mnesia
    mnesia:create_table(goods_entry, [
        {attributes, record_info(fields, goods_entry)},
        {type, bag} %% Используем bag, так как ID могут повторяться для разных временных меток
    ]),
    ok = mnesia:wait_for_tables([goods_entry], 1000),
    {ok, #{}}.

handle_call({get, Opts}, _From, State) ->
    SDate = Opts#goods_search_options.start_date,
    EDate = Opts#goods_search_options.end_date,
    TargetId = Opts#goods_search_options.id,
    ?LOG_INFO("geting data, SDate=~p, EDate=~p, TargetId=~p", [SDate, EDate, TargetId]),

    MS = ets:fun2ms(fun(E = #goods_entry{time = T, id = I}) 
        when (TargetId =:= undefined orelse I =:= TargetId) andalso
             (SDate =:= undefined orelse T >= SDate) andalso
             (EDate =:= undefined orelse T =< EDate) -> 
        E 
    end),
    {atomic, Entries} = mnesia:transaction(fun() -> mnesia:select(goods_entry, MS) end),
    {reply, Entries, State};

handle_call(Msg, _From, State) ->
    ?LOG_INFO("unhandled call ~p", [Msg]),
    {noreply, State}.


handle_cast({put, Entries}, State) ->
    write_data(Entries),
    {noreply, State};

handle_cast(Msg, State) ->
    ?LOG_INFO("unhandled cast ~p", [Msg]),
    {noreply, State}.

terminate(_Reason, _State) ->
    mnesia:stop(),
	terminated.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

write_data([]) ->
    ok;
write_data([Entry | Next]) ->
    F = fun() -> mnesia:write(Entry) end,
    mnesia:transaction(F),
    write_data(Next).