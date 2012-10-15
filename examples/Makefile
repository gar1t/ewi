ERL_SOURCES := $(wildcard *.erl)
ERL_OBJECTS := $(ERL_SOURCES:%.erl=%.beam)

%.beam: %.erl
	erlc $<

compile:  $(ERL_OBJECTS)
