---
layout: post
title: Configuration and Logging
date: 2015-08-23 13:00
---

Configuration and Logging are some of those things that all projects
must chose how to do.  Of the two, the least interesting to me was
logging.  I needed a solution, but I was not particularly interested
in implementing one.  I have done this in the past and I was unlikely
to learn anything new.
A good logging library will (amongst many other things) be able to
filter by severity at run-time,
and will also completely eliminate some severity levels at
compile-time (if desired).
It will help you identify the source of the messages, by filename and
line number for example, but also can include the process and thread
that generated the message.
It can send the log to multiple destinations.
It can timestamp the messages.
Of course, it uses the iostream interface to log the basic types and
take advantage of any user-defined streaming operators.
I have chosen
[Boost.Log](http://www.boost.org/doc/libs/release/libs/log/)
simply because I was already using Boost and seems to met most of the
requirements I can think of.

#### Configuration

Application configuration is a more difficult topic.  I wanted a
configuration framework that allowed:

* User-defined types as configuration options, e.g. time durations, or
kernel scheduling parameters.
* Recursively defined configuration options, that is, one can use a
configuration object inside another.
* The configuration objects have suitable default values, without
requiring custom coding of special classes.
* The default values can be defined at compile-time using `-D` options
to the compiler, so one can change the defaults on a different
platform, for example.
* One should be able to override one configuration parameter without
having to explicitly repeat the default values for the other
parameters.
* For tests and simple examples it should be possible to override
parameters in the code, without having to modify `argv` or something
similar.
* Because the configuration can get quite complex, one should be able
to read the configuration from files.
* The location of these files should be configurable using some kind
of environment variable.
* The library should look at a set of standard locations for the
configuration file, such as "/etc", and then "wherever the binary is
installed", and then "whatever the value of $FOO_HOME is".
* The values set by the configuration files can be overriden by
command-line arguments.

I defined a number of classes that achieve (I think) all these goals.
To parse the configuration files I used YAML, because it was easy to
hand craft configuration files, and I picked the `yaml-cpp` library
because it seemed easy enough to use.

#### Using jb::configuration

A full example of the configuration classes can be found in the
[examples/configuration.cpp](https://github.com/coryan/jaybeams/blob/master/examples/configuration.cpp)
file.

If the Doxygen documentation and the example is not enough, please
reach out to me through the
[mailing list](mailto:jaybeams-users@googlegroups.com).
I will be happy to write a longer document, but the
main motivation to commit this code soon was to get the continuous
integration and automatic documentation going.
