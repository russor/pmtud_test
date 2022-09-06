-module (size_app).
-include("yaws_api.hrl").


-export ([out/1]).

out(#arg{clisock = Sock}) ->
	{ok, [{_, Size}]} = inet:getstat(Sock, [recv_oct]),
	TcpInfo = ws_callback:tcp_info(Sock),
	ReportedSize = case (maps:get(options, TcpInfo) band 1) == 1 of
		true -> Size + 12;
		false -> Size
	end,

	[{header, {connection, "close"}},
	 %{header, {"access-control-allow-origin", "http://ruka.org"}},
	 {content, "application/json", io_lib:format("{\"size\":~p}", [ReportedSize])}
	].
