---
title: Forced to Compile from Scratch
layout: post
date: 2015-08-23 17:00
---

I ran out of luck locating pre-built binaries for my dependencies.
First, the `autoconf-archive` packages that I can locate for Ubuntu
12.04 do not have good support for Boost.Log, which I need.
Second, there are no packages for `yaml-cpp`, which I use to parse
(duh) YAML files, and I also need.
And last, but this was expected, JayBeams depends on Skye.

None of these packages are really big, so I simply resigned myself to
compile them from source and installing them.  But that will be a drag
if I want to use the Travis CI functionality for build matrices.

As I write this Travis CI is dutifully compiling the code.  The first
build was "successful", but I purposefully set it up to just install
all the dependencies and then run `./configure`.  No sense in getting
more errors when I expect things to fail.
