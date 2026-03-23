-module(goods_db_test).

-include_lib("eunit/include/eunit.hrl").
-include_lib("goods.hrl").
-include_lib("kernel/include/logger.hrl").

empty_selector_test()->
    {ok,DbPid} = goods_db:start_link(),

    {{Y0, M0, D0}, {H0, Min0, S0}} = erlang:universaltime(),
    NowStr = list_to_binary(io_lib:format("~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0wZ", 
                                [Y0, M0, D0, H0, Min0, S0])),

    TwoDaysMoreStr = list_to_binary(io_lib:format("~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0wZ", 
                                [Y0, M0, D0+2, H0, Min0, S0])),

    Good0 = #goods_entry{
        time = NowStr,
        id = 1,
        price = 9.99
    },

    Good1 = #goods_entry{
        time = TwoDaysMoreStr,
        id = 1,
        price = 9.99
    },

    Good2 = #goods_entry{
        time = NowStr,
        id = 2,
        price = 19.99
    },
    
    %?debugFmt("Good0 = ~p", [Good0]),
    goods_db:put([Good0, Good1, Good2]),

    Data = goods_db:get(#goods_search_options{}),
    %?debugFmt("Data = ~p", [Data]),

    gen_server:stop(DbPid),

    ?assertEqual([Good0, Good2, Good1], lists:sort(Data)),
    ok.


use_selector_test()->
    {ok,DbPid} = goods_db:start_link(),

    {{Y0, M0, D0}, {H0, Min0, S0}} = erlang:universaltime(),
    NowStr = list_to_binary(io_lib:format("~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0wZ", 
                                [Y0, M0, D0, H0, Min0, S0])),

    OneDaysMoreStr = list_to_binary(io_lib:format("~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0wZ", 
                                [Y0, M0, D0+1, H0, Min0, S0])),
    TwoDaysMoreStr = list_to_binary(io_lib:format("~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0wZ", 
                                [Y0, M0, D0+2, H0, Min0, S0])),

    Good0 = #goods_entry{
        time = NowStr,
        id = 1,
        price = 9.99
    },

    Good1 = #goods_entry{
        time = TwoDaysMoreStr,
        id = 1,
        price = 9.99
    },

    Good2 = #goods_entry{
        time = NowStr,
        id = 2,
        price = 19.99
    },
    
    %?debugFmt("Good0 = ~p", [Good0]),
    goods_db:put([Good0, Good1, Good2]),
    SelectorDate = #goods_search_options{
        start_date = NowStr,
        end_date   = OneDaysMoreStr
    },
    SelectorId = #goods_search_options{
        id = 1
    },
    SelectorMixed = #goods_search_options{
        start_date = NowStr,
        end_date   = OneDaysMoreStr,
        id = 1
    },

    SelectedByDate = goods_db:get(SelectorDate),
    SelectedById = goods_db:get(SelectorId),
    SelectedByMix = goods_db:get(SelectorMixed),

    gen_server:stop(DbPid),

    ?assertEqual([Good0, Good2], lists:sort(SelectedByDate)),
    ?assertEqual([Good0, Good1], lists:sort(SelectedById)),
    ?assertEqual([Good0], lists:sort(SelectedByMix)),

    ok.
