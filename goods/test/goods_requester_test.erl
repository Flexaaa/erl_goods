-module(goods_requester_test).

-include_lib("eunit/include/eunit.hrl").
-include_lib("goods.hrl").
-include_lib("kernel/include/logger.hrl").

-export([put/1]).

-define(TEST_DATA, <<"{\"products\": [{
            \"id\": 1,
            \"title\": \"Essence Mascara Lash Princess\",
            \"category\": \"beauty\",
            \"price\": 9.99,
            \"tags\": [
                \"beauty\",
                \"mascara\"
            ]
        },
        {
            \"id\": 2,
            \"title\": \"Eyeshadow Palette with Mirror\",
            \"category\": \"beauty\",
            \"price\": 19.99,
            \"tags\": [
                \"beauty\",
                \"eyeshadow\"
            ]
        }
    ]
}">>).

-spec put([goods_entry()]) -> ok | {error, any()}.
put(Entries) ->
    {ok, Pid} = application:get_env(goods_requester_test, notify_pid),
    %?debugFmt("Entries = ~p", [Entries]),
    Pid ! {test_data, Entries}.


get_data_test()->
    %application:ensure_all_started(gproc),
    ok = application:ensure_started(inets),
    application:ensure_all_started(cowboy),
    TestPid = self(),
    application:set_env(goods_requester_test, notify_pid, TestPid),

    MockHttpPort = 5555,
    {ok,MockPid} = mock_cowboy_server:start_link([{port, MockHttpPort}, {data, ?TEST_DATA}]),
    %{ok,MockPid} = mock_misultin_server:start_link([{port, MockHttpPort}, {data, ?TEST_DATA}]),
    application:get_env(goods_app, timeout, 1000),
    application:set_env(goods_app, url, "http://localhost:" ++ integer_to_list(MockHttpPort) ++ "/data"),
    application:set_env(goods_app, module, goods_requester_test),
    {ok,RequesterPid} = goods_requester:start_link(),

    receive
        {test_data, Recv} -> 
            %?debugFmt("Received = ~p", [Recv]),
            NowStr = list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second), [{offset, "Z"}])),
            ExpectedGoods = [#goods_entry{
                time = NowStr,
                id = 1,
                price = 9.99
            },
            #goods_entry{
                time = NowStr,
                id = 2,
                price = 19.99
            }],

            ?assertEqual(ExpectedGoods, lists:sort(Recv))
    after 1000 -> 
        ?assert(false) 
    end,

    gen_server:stop(RequesterPid),
    gen_server:stop(MockPid),

    ok.
