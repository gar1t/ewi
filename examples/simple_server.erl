-module(simple_server).

-behaviour(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {lsock, app}).

%%%===================================================================
%%% API
%%%===================================================================

start_link(Port, App) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [Port, App], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([Port]) ->
    {ok, LSock} = gen_tcp:listen(Port, [{packet, http},
                                        {active, false},
                                        {reuseaddr, true}]),
    {ok, #state{lsock=LSock, app=App}, 0}.

handle_call(_Request, _From, State) ->
    {noreply, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(timeout, #state{lsock=LSock, app=App}=State) ->
    {ok, Sock} = gen_tcp:accept(LSock),
    proc_lib:spawn(fun() -> handle_client(Sock, init_environ(), App) end),
    {noreply, State, 0}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

handle_client(Sock, App) ->
    Environ = recv_environ(Sock),
    handle_app_result(call_app(App, Environ), Sock).

recv_environ(Sock) ->
    handle_client_recv(client_recv(Sock), Sock, init_environ()).

init_environ() -> [].

client_recv(Sock) ->
    gen_tcp:recv(Sock, 0).

handle_client_recv({ok, {http_request, Method, {abs_path, Path}, ProtoVer}},
                   Sock, Environ) ->
    handle_client_recv(
      client_recv(Sock), Sock, add_request(Method, Path, ProtoVer, Environ));
handle_client_recv({ok, {http_header, _, Field, _, Value}},
                   Sock, Environ) ->
    handle_client(Sock, add_header(Field, Value, Environ));
handle_client_recv({ok, http_eoh}, Sock, Environ) ->
    handle_eoh(Sock, Environ);
handle_client_recv({ok, Packet}, Sock, Environ) ->
    io:format("Received ~p~n", [Packet]),
    handle_client(Sock, Environ);
handle_client_recv({error, Err}, Sock, _Environ) ->
    io:format("ERROR ~p~n", [Err]),
    gen_tcp:close(Sock).

add_request(Method, Path, ProtoVer, Environ) ->
    {ScriptName, PathInfo, QueryString} = parse_path(Path),
    ServerProtocol = server_protocol(ProtoVer),
    [{request_method, atom_to_list(Method)},
     {script_name, ScriptName},
     {path_info, PathInfo},
     {query_string, QueryString},
     {server_protocol, ServerProtocol}
     |Environ].

parse_path(Path) ->
    handle_path_parts(re:split(Path, "\\?", [{return, list}, {parts, 2}])).

handle_path_parts([Path]) ->
    {"", Path, ""};
handle_path_parts([Path, QueryString]) ->
    {"", Path, QueryString}.

server_protocol({Maj, Min}) ->
    "HTTP/" ++ integer_to_list(Maj) ++ "." ++ integer_to_list(Min).

add_header(Field, Value, Environ) ->
    [{http_header_name(Field), Value}|Environ].

http_header_name(Field) ->
    list_to_atom("http_" ++ field_str(Field)).

field_str(Field) ->
    string:to_lower(replace_dash(atom_to_list(Field))).

replace_dash(Str) ->
    re:replace(Str, "-", "_", [global, {return, list}]).

handle_eoh(Sock, Environ) ->
