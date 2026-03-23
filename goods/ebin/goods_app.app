%% -*- erlang -*-
{application, goods_app, [
    {description, "goods app"},
    {vsn, "0.0.0.1"},
    {registered, []},
    {applications, [kernel, stdlib]},
    {mod, {goods_app, []}},
    {env, [
        {port, 5432},
        {users, [
            {<<"user">>, <<"password">>}
        ]}
    ]}
]}.
