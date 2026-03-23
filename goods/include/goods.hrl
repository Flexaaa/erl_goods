-ifndef(GOODS_HRL).
-define(GOODS_HRL, true).

-record(goods_entry, {
    time  :: binary(),
    id    :: integer(),
    price :: float()
}).

-record(goods_search_options, {
    start_date :: undefined | string(),
    end_date   :: undefined | string(),
    id         :: undefined | string()
}).

-type goods_search_options() :: #goods_search_options{}.
-type goods_entry()          :: #goods_entry{}.

-endif.
