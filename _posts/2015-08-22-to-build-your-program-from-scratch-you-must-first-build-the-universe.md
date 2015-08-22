---
title: To Build Your Program From Scratch First you must Build the Universe
layout: post
date: 2015-08-22 13:00
---

Given that most hosted continuous integration solutions are based on
Ubuntu 12.04 I started by testing my small C++11
[library](http://github.com/coryan/Skye) in that environment.
Of course not, I started by trying to build directly in one of the
hosted solutions and failed miserably.
This was entirely my fault, of course, once the coffee kicked in and I
started thinking more clearly I prepped a virtual machine to test my
library there.

I will not go into the details of building virtual machines and
running them, I am sure you can find information on the web about it.
I run Fedora 21 on my workstation, and for these purposes I find
[virt-manager](http://virt-manager.org), a point-and-click interface
perfectly acceptable.

Create your Baseline VM
-----------------------

First you must download the Ubuntu 12.04 install CD, I easily found
this online at:

[http://releases.ubuntu.com/12.04/](http://releases.ubuntu.com/12.04/)

Because I am planning to use this VM just to verify my builds, and not
to use it as a primary development platform I used the server ISO:

[http://releases.ubuntu.com/12.04/ubuntu-12.04.5-server-amd64.iso](http://releases.ubuntu.com/12.04/ubuntu-12.04.5-server-amd64.iso)

Once you download the ISO, move it to wherever you keep the images and
ISO for your virtual machines.  Then create the VM, a chose a fairly
small machine, 1 CPU, 2 GiB of RAM, 32GiB of disk space.  One can
chance those if needed, so better to start small.

Then simply boot the VM and let the installer do its job, you probably
want to enable SSH so you do not need to login through the console.
Last time I used a Debian-based system (such as Ubuntu), was around
2001.  I recall the packaging system getting wedged routinely, but now
it is 2015, so the packaging system gets wedged sometimes.  Sigh.  In my
case, the default installation, selecting *only* SSH server as an
option left the server unable to update some packages.  A quick web
search found this series of incantations to fix it:

       sudo apt-get clean
       sudo find /var/lib/apt/lists -type f | xargs sudo rm
       sudo apt-get update
       sudo apt-get dist-upgrade

Install the Development Tools
-----------------------------

Because I am likely to restart the rest of the process numerous times,
I took a snapshot and cloned this VM at this point.  The biggest question
I had was how to get recent versions of the development tools
installed.  Ubuntu 12.04 was released in 2012, when the support for
C++11 was fairly immature.  Luckily, an army of volunteers have
created /backports/ of all sorts of packages to the platform.  You
just need to find their packages.  More web searches and you discover
the rich collection of /Personal Package Archives/ (PPA) for Ubuntu.

In my case these included:

* **ppa:ubuntu-toolchain-r/test**: the GNU toolchain, including g++ and gcc.
* **ppa:dns/gnu**: a host of GNU tools, include autoconf and automake.
* **ppa:boost-latest/ppa**: recent (though not necessarily the latest) version of the boost libraries.

The clang and llvm packages can be downloaded from
[http://llvm.org/apt/](http://llvm.org/apt/), and they list what
repositories are needed for each version of Ubuntu.

I find the whole idea of downloading a pre-built binary
from an unknown party and running it is mildly terrifying.
I would much rather use the packages built by a
well-known source, or build them from source as a second choice.
But neither
approach is realistic for these purposes.
The binaries for Ubuntu 12.04 are simply too old for my purposes.
Upgrading the hosted VMs where I would like to run the builds is not
possible (we will revisit this later as we setup containers).
And building from source will take too long and would be wasteful on the
hosted environment.  I could create my own PPA, but that solves the
problem for me and nobody else.  And ultimately I am running these
packages on a throwaway virtual machine.


Having found all the packages we need to simply configure our
sacrificial VM:

<pre>
# Install a tool to easily add PPAs and other sources:
sudo apt-get -qq -y install python-software-properties
sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
sudo add-apt-repository -y ppa:dns/gnu
sudo add-apt-repository -y ppa:boost-latest/ppa
sudo add-apt-repository -y "deb http://llvm.org/apt/precise/ llvm-toolchain-precise main"
sudo add-apt-repository -y "deb http://llvm.org/apt/precise/ llvm-toolchain-precise-3.6 main"
# ... add the public key used by llvm.org ...
wget -O - http://llvm.org/apt/llvm-snapshot.gpg.key|sudo apt-key add -
</pre>

Once the package sources are configured, we are ready to download the list
of packages and their dependencies:

<pre>
sudo apt-get -qq update
sudo apt-get -qq -y install clang-3.6
sudo apt-get -qq -y install g++-4.9
sudo apt-get -qq -y install boost1.55
sudo apt-get -qq -y install autoconf automake autoconf-archive make
sudo apt-get -qq -y install git
</pre>

After 30 years of coding, I am paranoid, I want to know what really
got installed:

<pre>
$ g++-4.9 --version
g++-4.9 (Ubuntu 4.9.2-0ubuntu1~12.04) 4.9.2
Copyright (C) 2014 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
</pre>

<pre>
$ clang++-3.6 --version
Ubuntu clang version 3.6.2-svn240577-1~exp1 (branches/release_36) (based on LLVM 3.6.2)
Target: x86_64-pc-linux-gnu
Thread model: posix
</pre>

<pre>
$ ld --version
GNU ld (GNU Binutils for Ubuntu) 2.23.1
Copyright 2012 Free Software Foundation, Inc.
This program is free software; you may redistribute it under the terms of
the GNU General Public License version 3 or (at your option) a later version.
This program has absolutely no warranty.
</pre>

<pre>
$ make --version
GNU Make 3.81
Copyright (C) 2006  Free Software Foundation, Inc.
This is free software; see the source for copying conditions.
There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

This program built for x86_64-pc-linux-gnu
</pre>

<pre>
$ automake --version
automake (GNU automake) 1.14
Copyright (C) 2013 Free Software Foundation, Inc.
License GPLv2+: GNU GPL version 2 or later <http://gnu.org/licenses/gpl-2.0.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Tom Tromey <tromey@redhat.com>
       and Alexandre Duret-Lutz <adl@gnu.org>.
</pre>

<pre>
$ autoconf --version
autoconf (GNU Autoconf) 2.69
Copyright (C) 2012 Free Software Foundation, Inc.
License GPLv3+/Autoconf: GNU GPL version 3 or later
<http://gnu.org/licenses/gpl.html>, <http://gnu.org/licenses/exceptions.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by David J. MacKenzie and Akim Demaille.
</pre>

<pre>
$ dpkg -s autoconf-archive | grep ^Version
Version: 20130406-0gnu1~12.04
</pre>

Okay, seems like we are ready to go.

Download the Source and Compile
-------------------------------

Now that the development tools are here, download the source code for
our C++11 library and compile it:

<pre>
git clone https://github.com/coryan/Skye
cd Skye
./bootstrap
mkdir clang ; cd clang
CXX=clang++-3.6 CC=clang-3.6 ../configure --with-boost-libdir=/usr/lib/x86_64-linux-gnu
make check
</pre>

Success!  Let's try with gcc:

<pre>
cd ..
mkdir gcc ; cd gcc
CXX=g++-4.9 CC=gcc-4.9 ../configure --with-boost-libdir=/usr/lib/x86_64-linux-gnu
make check
</pre>

Success again!


What is next?
-------------

Now that we have reproduceable builds for this library on Ubuntu
12.04 we can attempt a build using some of the existing hosted
continuous integration environments.  Stay tuned for the next post.
