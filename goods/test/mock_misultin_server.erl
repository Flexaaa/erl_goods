-module(mock_misultin_server).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/logger.hrl").

-export([start_link/1]).

-record(state, {
    data :: binary()
}).

start_link(Options) ->
    Port = proplists:get_value(port, Options),
    Data = proplists:get_value(data, Options),
    ?debugFmt("starting server on port ~p data= ~p~n", [Port,Data]),

	misultin:start_link([
        {name, mock_misultin_server},
        {port, Port},
        {loop, fun(Req) -> handle_http_safe(Req, #state{data = Data}) end}
    ]).

-spec handle_http_safe(term(), #state{}) -> term().
handle_http_safe(Req, State) ->
	try
		handle_http(Req, State)
    catch Error ->
        ?debugFmt("exception ~p; request ~p ~p", [Error, Req, misultin_req:parse_qs(Req)]),
        misultin_req:respond(503, [], "unknown error", Req)
	end.

-spec handle_http(term(), #state{}) -> term().
handle_http(Req, #state{data = Data}) ->
    case misultin_req:resource([lowercase, urldecode], Req) of
        ["data"] ->
            ?debugFmt("Sending data ~p",[Data]),
            misultin_req:ok([], Data, Req);
        Resource ->
            ?debugFmt("Unknown resource = ~p", [Resource]),
            misultin_req:respond(400, [], ["unknown request"], Req)
    end.
