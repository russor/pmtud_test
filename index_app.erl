-module (index_app).

-include ("yaws_api.hrl").
-export([out/1]).


out(A = #arg{server_path = "/"}) -> 
	ws_callback:set_max_seg(A#arg.clisock, 536),
	
	case file:read_file("websocket.html") of
		{ok, Bin} -> {html, Bin};
		_ -> yaws_outmod:out404(A)
	end;
out(A) -> yaws_outmod:out404(A).
