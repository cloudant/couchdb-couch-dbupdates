-module(couch_dbupdates).

-export([
    handle_dbupdates/3,
    handle_event/3
]).


handle_dbupdates(Fun, Acc, Options) ->
    NotifierPid = db_update_notifier(),
    try
        loop(Fun, Acc, Options)
    after
        couch_event:stop_listener(NotifierPid)
    end.


handle_event(DbName, Event, Parent) ->
    Parent ! {Event, DbName},
    {ok, Parent}.


loop(Fun, Acc, Options) ->
    [{timeout, Timeout}, {heartbeat, Heartbeat}] = Options,
    receive
        {db_updated, Event} ->
            case Fun(Event, Acc) of
                {ok, Acc1} ->
                    loop(Fun, Acc1, Options);
                stop ->
                    Fun(stop, Acc)

            end
    after Timeout ->
        case Heartbeat of
            true ->
                case Fun(heartbeat, Acc) of
                {ok, Acc1} ->
                    loop(Fun, Acc1, Options);
                stop ->
                    Fun(stop, Acc)

                end;
            _ ->
                Fun(stop, Acc)
        end
    end.

db_update_notifier() ->
    {ok, Pid} = couch_event:link_listener(?MODULE, handle_event, self(), []),
    Pid.
