    Author: Garrett Smith <g(at)rre(dot)tt>
    Status: Draft
    Type: Standards Track EEP
    Created: DD-Mmm-2012
    Post-History:
    Replaces:
****
EEP NN: Erlang Web Interface
----


Abstract
========

This document specifies a proposed standard interface between web
servers and Erlang web applications or frameworks.

It borrows heavily from [PEP 333][] and [PEP 444][].


Rationale
=========

The Erlang ecosystem has produced a number of web related applications
and frameworks such as Yaws, Mochiweb, Cowboy, and core Erlang's
inets. However, these packages are largely incompatible with one
another in terms of...

TODO

Goals
=====

As stated in [PEP 333][], a specification must be implemented for
there to be any effect. It is therefore imperative that EWI be as
simple as possible for developers to support -- in servers,
application frameworks, and middleware -- without comprimising
essential web application features.

EWI must not require particular software libraries outside Erlang's
kernal and stdlib applications. Like CGI and WSGI, EWI is a protocol
that can be implemented using standard langauge data types and
conventions.

It should be possible for current Erlang web applications and frameworks
to adopt EWI with minimal effort.

EWI should support pipelining of web requests, enabling varieties of
web related middleware.

EWI must not use experimental or otherwise unsupported Erlang langauge
features. This includes parameterized modules.

EWI should follow Erlang's [Programming Rules and Conventions][].

This specification does not address software deployment and configuration.

Overview
========

EWI represents the fundamental request/response mechanism of HTTP
using an Erlang function of arity 1. As with WSGI, this mechanism is
called an *application*.

A EWI application may be implement as any of the following:

- An Erlang function of arity 1
- A module/function tuple refercing an exported function of arity 1

Here's a simple EWI application:

```
simple_app(Environ) ->
    Status = "200 OK",
    Headers = [{"Content-Type", "text/plain"}],
    Body = "Hello world!\n",
    {Body, Status, Headers}.
```

TODO: This follows WSGI exactly. It feel counter intuitive to return
body first. This feels more natural:

```
simple_app(Environ) ->
    Status = "200 OK",
    Headers = [{"Content-Type", "text/plain"}],
    Body = "Hello world!\n",
    {Status, Headers, Body}.
```

TODO: Being Erlang, this is an odd interface. I'd expect something
more along these lines:

```
simple_app(Environ) ->
    Status = "200 OK",
    Headers = [{"Content-Type", "text/plain"}],
    Body = "Hello world!\n",
    {ok, {Status, Headers, Body}}.
```

TODO: Examples of a server and middleware. We could write a simple
wrapper around an http enabled Erlang socket. Middleware could be a
profiler that wraps an application call.


Details
=======

TODO: What Erlang data type is Environ? IMO this must be a
proplist. Performance might enter into this, but hopefully proplists
fair well for smallish lists. Would a proplist provide the advantage
of letting middleware modify the Environ non-destructively? E.g. [{foo,
"v2}|[{foo, "v1"}]] will yield "v2" using proplists:get_value(foo,
Environ) but the original value "v1" is still available if anyone's
interested. Is this just a sneaky benefit of proplists?

TODO: Needs to explicitly address web sockets, async handlers, comet
(long polling), chunking -- and any other hard issue.

TODO: Do servers need to maintain application state? I don't think so,
but this could severely limit the capabilities of an app. State could
be a second arg to this call, mimicking the APIs of gen_server and
gen_event. But then what's the scope of app state? Is it per process?
Certainly per "app". But is it obvious what an app wants? This feels
like too much responsibility for the server -- rather the app should
deal with state out of band.

TODO: How to communicate errors? Do we need tagged responses? How does
a server handle {error, Err}? If there's no other meaningful response,
we could get by with the tuple {Status, Headers, Body}.

TODO: We need to be precise about lists vs binaries and encoding
issues. I suspect this will be to simply support iolists and let
application providers handle all encoding issues.

TODO: In WSGI, Body is an iterable, which can come in very handle for
lazily generated bodies. We'll need something comparable. I don't know
what the convention in Erlang is for this, though it could be simply
that body is a tuple of {fun(Arg) -> {continue, Body, Arg1} | stop,
Arg0} that is called iteratively by the server to generate body
content.

TODO: Note on buffering. Do we want to tie iterations with flushing
response bytes to clients? I think so -- that'd be the reason to use
an iteration response.

TODO: If we use functions to iterate, we don't need to provide a
convention for body "close" operations as per WSGI. The return of stop
is where resource cleanup would occur.

TODO: WSGI provides an error output stream (for logging) -- do we need
this? Need to see how Python apps use this. If there's collaboration
-- e.g. support for decorated logging, maybe. But Erlang has its own
pluggable error logging facility (for good or bad) that I'd think
might be the place to start. That said, consolidated logging for EWI
apps might be a must have for any sensible ecosystem.

Environ
-------

TODO: I think representing CGI vars as standard Erlang atoms (prop
names) is probably the right thing. E.g.

```
[{request_method, string()},
 {script_name, string()},
 {path_info, string()},
 {query_string, string()},
 {server_name, string()},
 {server_port, integer()},
 {server_protocol, string()},
 {content_type, string()},
 {content_length, integer()},
 {http_XXX, string()}]
```

Alternatively (but I think oddly):

```
[{'REQUEST_METHOD', string()},
 {'SCRIPT_NAME', string()},
 {'PATH_INFO', string()},
 ...]
```

TODO: What about environment variables? If we're maintaining close
ties with CGI, os:getenv() might be in the list. (Of course, an app is
free to call os:getenv() directly, so I don't know if it makes sense
to maintain this convention. But in that spirit, Environ might then
look like this:

```
[{"REQUEST_METHOD", string()},
 {"SCRIPT_NAME", string()},
 {"PATH_INFO", string()},
 ...]
```

TODO: We also need to expose EWI specific vars as per wsgi.xxx
vars. These might be prefixed as ewi_xxx, as with the http vars.

Request Body Input Stream
-------------------------

TODO: I think we can get away with Erlang's [IO Device][] as the value
for the body input stream. This could be read using io module
functions.

Response Status
---------------

TODO: Reference RFC 2616 and summarize with bullets

Response Headers
----------------

TODO: Reference RFC 2616 and summarize with bullets

Response Body
-------------

TODO: Either an iolist, or a fun(Arg0) -> {continue, iolist(), Arg1} |
stop.


References
==========

[PEP 333]: http://www.python.org/dev/peps/pep-0333/
    "Python Web Server Gateway Interface v1.0"

[PEP 333]: http://www.python.org/dev/peps/pep-0333/
    "Python Web3 Interface"

[Programming Rules and Conventions]: http://www.erlang.se/doc/programming_rules.shtml
    "Programming Rules and Conventions"

[IO Device]: http://erlang.org/doc/man/io.html#type-device
    "Erlang's IO Device"

Copyright
=========

This document has been placed in the public domain.



[EmacsVar]: <> "Local Variables:"
[EmacsVar]: <> "mode: indented-text"
[EmacsVar]: <> "indent-tabs-mode: nil"
[EmacsVar]: <> "sentence-end-double-space: t"
[EmacsVar]: <> "fill-column: 70"
[EmacsVar]: <> "coding: utf-8"
[EmacsVar]: <> "End:"
