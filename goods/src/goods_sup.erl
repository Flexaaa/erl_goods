-module(goods_sup).
-behaviour(supervisor).
 
-include_lib("kernel/include/logger.hrl").

-export([start_link/0]).
-export([init/1]).
 
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).
 
init([]) ->
    Server = #{id => goods_http,
                start => {goods_http, start_link, []},
                restart => temporary,
                shutdown => 1000,
                type => worker,
                modules => [goods_http]},
    
    Db     = #{id => goods_db,
                start => {goods_db, start_link, []},
                restart => temporary,
                shutdown => 1000,
                type => worker,
                modules => [goods_db]},
    
    Requester = #{id => goods_requester,
                start => {goods_requester, start_link, []},
                restart => temporary,
                shutdown => 1000,
                type => worker,
                modules => [goods_requester]},
    

    ?LOG_INFO("starting supervisor~n", []),
    {ok, {{one_for_one, 60, 3600}, [Server, Db, Requester]}}.
 