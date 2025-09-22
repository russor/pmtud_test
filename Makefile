.PHONY: reload

ERLANG_SRCS = $(wildcard *.erl)
ERLANG_OBJS = $(ERLANG_SRCS:%.erl=%.beam)
ERLANG_NAMES = $(ERLANG_SRCS:%.erl=%)

reload: $(ERLANG_OBJS)
	yaws --load $(ERLANG_NAMES)

%.beam: %.erl
	erlc -I /usr/local/lib/erlang/lib/yaws-2.2.0/include/ $<
