---
layout: post
title: Building with Travis CI
date: 2015-08-22 15:00
---

[Travis CI](http://www.travis-ci.com) is one of the hosted continuous
integration frameworks that offer C++ support
([ref](http://docs.travis-ci.com/user/languages/cpp/)).
Their instructions looked promising, and they are easy to follow.
Unfortunately their default setup does not work for C++11 libraries,
and this is where I learn that I needed to setup a C++11 development
environment on Ubuntu 12.04 first.


The Configuration File
----------------------

Travis follows the instructions on a simple `.travis.yml` file in the
top level directory of your project.  The instructions in the website
are comprehensive enough, but I think it is easier to follow if we
describe the contents of our Travis file section by section.

### Configure the Language and Compilers

First we tell Travis to use C++ and to compile on Linux.

<pre>
language: cpp

os:
  - linux
</pre>

Then we tell it what compilers to use.  This is a nice feature,
testing C++ with more than one compiler is a good way to avoid
portability problems, both to other platforms and to future updates in
the compiler.
We will initially configure just one compiler, just to make testing
easier, but we will want to setup additional compilers later:

<pre>
compiler:
  - clang
</pre>

### Setting Up the Development environment

We are going to use the the `before_install` section to install the
development environment.  The
[documentation](http://docs.travis-ci.com/user/customizing-the-build/#The-Build-Lifecycle)
explicitly recommends installing Ubuntu packages there.

The set of apt repositories and packages was described in the
[previous post](/2015/08/22/to-build-your-program-from-scratch-you-must-first-build-the-universe/),
here we simply reproduce those commands in the `.travis.yml` format:

<pre>
before_install:
  - sudo apt-get -qq -y install python-software-properties
  - sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
  - sudo add-apt-repository -y ppa:dns/gnu
  - sudo add-apt-repository -y ppa:boost-latest/ppa
  - sudo add-apt-repository -y "deb http://llvm.org/apt/precise/ llvm-toolchain-precise main"
  - sudo add-apt-repository -y "deb http://llvm.org/apt/precise/ llvm-toolchain-precise-3.6 main"
  - wget -O - http://llvm.org/apt/llvm-snapshot.gpg.key|sudo apt-key add -
  - sudo apt-get -qq update
  - sudo apt-get -qq -y install clang-3.6
  - sudo apt-get -qq -y install g++-4.9
  - sudo apt-get -qq -y install boost1.55
  - sudo apt-get -qq -y install autoconf automake autoconf-archive make
  - sudo apt-get -qq -y install git
</pre>

Logging the Configuration
-------------------------

As this program will run automatically, it is always useful to log
the critical dependency versions to make debugging easier.  We do this
just before running the configuration script:

<pre>
before_script:
  - uname -a
  - g++ --version || echo "no g++ found"
  - clang++ --version || echo "no clang++ found"
  - g++-4.9 --version || echo "no g++-4.9 found"
  - clang++-3.6 --version || echo "no clang++-3.6 found"
  - make --version || echo "no make found"
  - automake --version || echo "no automake found"
  - autoconf --version || echo "no autoconf found"
  - dpkg -s autoconf-archive || echo "no autoconf-archive found"
  - dpkg -s libboost-test1.55-dev || echo "no libboost-test1.55-dev found"
  - echo $CXX
  - echo $CC
  - CC=clang-3.6
  - export CC
  - CXX=clang++-3.6
  - export CXX  
</pre>

Compiling the Code
------------------

With all these preambles behind us, we can now compile the code:

<pre>
script:
  - ./bootstrap
  - echo CC=${CC?} CXX=${CXX?}
  - buildir=$(basename ${CC?})
  - mkdir ${buildir?} && cd ${buildir?}
  - ../configure --with-boost-libdir=/usr/lib/x86_64-linux-gnu
  - make
  - make check
</pre>

At the end of this process you should have a file that looks like
[this
one](https://github.com/coryan/Skye/blob/b69ddcb34296fb491b1e3ec23d8b30503d2943e4/.travis.yml).
Notice that this link points to an specific version, I am planning to
update the file, but not these instructions.

Sign-in To Travis
-----------------

I have been using `travis-ci.org` (notice the TLD) for these builds.
You may be using the version with commercial support at
`travis-ci.com`.  I used github to create a travis-ci.org account.
And then enabled builds for the github.com/coryan/Skye project.

Travis scanned my github account and discovered by repositories.  From
there, I selected the settings for the Skye project, and enabled
"Build only if .travis.yml is present", and "Build pushes", leaving
all other options to their defaults (disabled).  With apologies to any
visually impaired readers, this screenshot may help
[image](/public/travis-screenshot.png).

What is Next
------------

So far we successfully built with clang, but we want to build with g++
too.  That comes in the next installment of this series.
