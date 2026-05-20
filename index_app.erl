-module (index_app).

-include ("yaws_api.hrl").
-export([out/1]).


out(A = #arg{server_path = "/"}) ->
	% reduce maximum segment size, so we can send the webpage even if
	% the client sent mss is too big
	ws_callback:set_max_seg(A#arg.clisock, 536),
	
	Filename = filename:append(filename:dirname(code:which(?MODULE)), "websocket.html"),

	case file:read_file(Filename) of
		{ok, Bin} -> {html, Bin};
		_ -> yaws_outmod:out404(A)
	end;
out(A = #arg{server_path = "/.well-known/acme-challenge/" ++ Token}) when Token /= []->
	case lists:all(fun is_base64url/1, Token) of
		true ->
			Filename= filename:append(filename:dirname(code:which(?MODULE)), "thumbprint.txt"),
			case file:read_file(Filename) of
				{ok, Bin} -> {content, "text/plain", [Token, ".", Bin]};
				_ -> yaws_outmod:out404(A)
			end;
		false -> yaws_outmod:out404(A)
	end;
out(A) -> yaws_outmod:out404(A).

is_base64url(C) when C >= $A, C =< $Z -> true;
is_base64url(C) when C >= $a, C =< $z -> true;
is_base64url(C) when C >= $0, C =< $9 -> true;
is_base64url($-) -> true;
is_base64url($_) -> true;
is_base64url(_) -> false.
