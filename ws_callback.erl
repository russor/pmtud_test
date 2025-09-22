%% from yaws basic_echo_callback_extended

-module(ws_callback).

-include("yaws_api.hrl").

%% Export for websocket callbacks
-export([init/1, terminate/2, handle_open/2, handle_message/2, handle_info/2]).
-export([tcp_info/1, set_max_seg/2]).
-export([out/1]).

out(A) ->
	Host = (A#arg.headers)#headers.host,
	OriginHost = case yaws_api:parse_url(yaws_api:get_header(A#arg.headers, "origin")) of
		U when is_record(U, url) -> U#url.host;
		_ -> "example.org"
	end,
	AllowedOriginHost = case Host of
		"ipv4." ++ OriginHost -> OriginHost;
		"ipv6." ++ OriginHost -> OriginHost;
		_ -> Host
	end,
	{websocket, ws_callback, [
		{origin, "http://" ++ AllowedOriginHost}
	]}.

-record(state, {wsstate, has_timestamps}).

init([_Arg, _Params]) ->
    {ok, #state{}}.

handle_open(WSState, #state{}) ->
    Sock = WSState#ws_state.sock,
    TcpInfo = tcp_info(Sock),
    HasTS = ((maps:get(options, TcpInfo) band 1) == 1),
    {ok, #state{wsstate = WSState, has_timestamps = HasTS}}.


send_probe(WSState, MaxSeg, Mss, Offset) ->
    Probe = case payload_size(Mss - Offset) of
    	{0, N} -> yaws_api:websocket_send(WSState, {binary, <<>>}), N;
    	N -> N
    end,
    Bin = binary:copy(<<"X">>, Probe - 6),
    yaws_api:websocket_send(WSState, {binary, <<1, Offset, MaxSeg:16, Mss:16, Bin/binary>>}).

payload_size(N) when N =< 127 -> N - 2;
payload_size(N) when N =< 129 -> {0, N - 4};
payload_size(N) -> N - 4.

handle_message({binary, <<1, Probe:16>>}, State = #state{wsstate = WSState, has_timestamps = HasTS}) ->
    MaxSeg = get_max_seg(WSState#ws_state.sock),
    Offset = case HasTS of
    	true -> 12;
    	false -> 0
    end,
    send_probe(WSState, MaxSeg, Probe, Offset),
    {noreply, State};

handle_message({close, Status, Reason}, _) ->
    io:format("Close connection: ~p - ~p~n", [Status, Reason]),
    {close, Status}.


handle_info(timeout, State) ->
    io:format("process timed out~n", []),
    {reply, {text, <<"Anybody Else ?">>}, State}.

terminate(Reason, State) ->
    io:format("terminate ~p: ~p (state:~p)~n", [self(), Reason, State]),
    ok.

get_max_seg(Sock) ->
    {ok, [{raw, _, _, <<Size:32/native>>}]} = inet:getopts(Sock,[{raw,6,2,4}]),
    Size.

set_max_seg(Sock, Size) ->
    ok = inet:setopts(Sock,[{raw,6,2,<<Size:32/native>>}]).

tcp_info(Sock) -> 
    {ok,[{raw,_,_,Info}]} = inet:getopts(Sock,[{raw,6,32,(2 + 31 + 26) * 8 }]),
    % options translated from FreeBSD 14.0 /usr/include/netinet/tcp.h struct tcp_info
    <<
        State:8/native,             %/* TCP FSM state. */
        __ca_state:8/native,
        __retransmits:8/native,
        __probes:8/native,
        __backoff:8/native,
        Options:8/native,           %/* Options enabled on conn. */
                Snd_wscale:4,       %/* RFC1323 send shift value. */
                Rcv_wscale:4,       %/* RFC1323 recv shift value. */
        _:8,			    % align to 32-bit

        Rto:32/native,              % /* Retransmission timeout (usec). */
        __ato:32/native,
        Snd_mss:32/native,          % /* Max segment size for send. */
        Rcv_mss:32/native,          % /* Max segment size for receive. */

        __unacked:32/native,
        __sacked:32/native,
        __lost:32/native,
        __retrans:32/native,
        __fackets:32/native,

        %/* Times; measurements in usecs. */
        __last_data_sent:32/native,
        __last_ack_sent:32/native,   %/* Also unimpl. on Linux? */
        Last_data_recv:32/native,    %/* Time since last recv data. */
        __last_ack_recv:32/native,

        %/* Metrics; variable units. */
        __pmtu:32/native,
        __rcv_ssthresh:32/native,
        Rtt:32/native,               %/* Smoothed RTT in usecs. */
        Rttvar:32/native,            %/* RTT variance in usecs. */
        Snd_ssthresh:32/native,      %/* Slow start threshold. */
        Snd_cwnd:32/native,          %/* Send congestion window. */
        __advmss:32/native,
        __reordering:32/native,

        __rcv_rtt:32/native,
        Rcv_space:32/native,         %/* Advertised recv window. */

        %/* FreeBSD extensions to tcp_info. */
        Snd_wnd:32/native,           %/* Advertised send window. */
        __snd_bwnd:32/native,          %/* No longer used. */
        Snd_nxt:32/native,           %/* Next egress seqno */
        Rcv_nxt:32/native,           %/* Next ingress seqno */
        Toe_tid:32/native,           %/* HWTID for TOE endpoints */
        Snd_rexmitpack:32/native,    %/* Retransmitted packets */
        Rcv_ooopack:32/native,       %/* Out-of-order packets */
        Snd_zerowin:32/native,       %/* Zero-sized windows sent */

        %/* fields added later and padding */
        _Rest/binary
    >> = Info,
    #{state => State, options => Options, snd_wscale => Snd_wscale, rcv_wscale => Rcv_wscale,
      rto => Rto, snd_mss => Snd_mss, rcv_mss => Rcv_mss, last_data_recv => Last_data_recv,
      rtt => Rtt, rttvar => Rttvar, snd_ssthresh => Snd_ssthresh, snd_cwnd => Snd_cwnd,
      rcv_space => Rcv_space, snd_wnd => Snd_wnd, snd_nxt => Snd_nxt, rcv_nxt => Rcv_nxt,
      toe_tid => Toe_tid,  snd_rexmitpack => Snd_rexmitpack, rcv_oopack => Rcv_ooopack,
      snd_zerowin => Snd_zerowin}.
    
    