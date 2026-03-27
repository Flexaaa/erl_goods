-ifndef(GOODS_HRL).
-define(GOODS_HRL, true).

-record(goods_entry, {
    time  :: binary(),
    id    :: integer(),
    price :: float()
}).

-record(goods_search_options, {
    start_date :: undefined | binary(),
    end_date   :: undefined | binary(),
    id         :: undefined | integer()
}).

-type goods_search_options() :: #goods_search_options{}.
-type goods_entry()          :: #goods_entry{}.

-endif.
