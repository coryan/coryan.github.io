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

So, after some unsuccessful web searches I created a few more
installation steps:

<pre>
before_install:
# ... lots of stuff skipped see git repo for details ...
  - wget -q http://ftpmirror.gnu.org/autoconf-archive/autoconf-archive-2015.02.24.tar.xz
  - tar -xf autoconf-archive-2015.02.24.tar.xz
  - (cd autoconf-archive-2015.02.24 && ./configure --prefix=/usr && make && sudo make install)
  - sudo apt-get -qq -y install cmake
  - wget -q https://github.com/jbeder/yaml-cpp/archive/release-0.5.1.tar.gz
  - tar -xf release-0.5.1.tar.gz
  - (cd yaml-cpp-release-0.5.1 && mkdir build && cd build && cmake -DCMAKE_INSTALL_PREFIX=/usr .. && make && make test && sudo make install)
  - wget -q https://github.com/coryan/Skye/releases/download/v0.2/skye-0.2.tar.gz
  - tar -xf skye-0.2.tar.gz
  - (cd skye-0.2 && CXX=g++-4.9 CC=gcc-4.9 ./configure --with-boost-libdir=/usr/lib/x86_64-linux-gnu/ && make check && sudo make install)
</pre>

The full gory details can be found in the
[repository](https://github.com/coryan/jaybeams/blob/671a37374d80b93d55063880e063c5bb4009625a/.travis.yml).

The sheer complexity of the installation process is making it more and
more tempting to try some kind of container-based solution.  Simply
pull the container and compile.
Potentially it can get developers going faster too:
install this container and develop in that environment.  On the other
hand, users may want to install editors, IDEs, debuggers and other
tools that would not be in the container, so a lot of customization is
unavoidable.

At this point I just cringe at the number of steps `before_install`
and keep going.
