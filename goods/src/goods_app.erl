-module(goods_app).

-behaviour(application).

-include_lib("kernel/include/logger.hrl").

-export([start/2, 
			stop/1]).

start(_Type, _Args) ->
    goods_sup:start_link().
	
stop(State) ->
	?LOG_INFO("stop goods ~p",[State]),
	ok.
