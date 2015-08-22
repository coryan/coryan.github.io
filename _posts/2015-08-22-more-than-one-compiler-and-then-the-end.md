---
layout: post
title: More than One Compiler and Then The End
date: 2015-08-22 17:00
---

At this point I have been able to configure Ubuntu 12.04 to compile my
small C++11 library, I have also been able to configure Travis to
automatically compile the library from the github source.
Travis allows you to configure more than one compiler, which sounds
fantastic from my perspective.  Unfortunately, why they allow you to
test your code against multiple versions of Python
([ref](http://docs.travis-ci.com/user/languages/python/)) they do not
([yet](https://github.com/travis-ci/travis-ci/issues/979))
allow you to easily configure multiple C++ compiler versions.

This is not too difficult in practice, you simply need to override the
`CXX` and `CC` environment variable settings to your liking.  In my
case I modified the compiler section in the `.travis.yml` file to look
like this:

<pre>
compiler:
  - clang
  - gcc
</pre>

Then I modified the `before_script` section to include:

<pre>
before_script:
  - uname -a
....
..
  - if [ "x$CC" == "xgcc" ]; then CXX=g++-4.9; CC=gcc-4.9; fi
  - if [ "x$CC" == "xclang" ]; then CXX=clang++-3.6; CC=clang-3.6; fi
  - export CC
  - export CXX  
</pre>

The full configuration file is [here](https://github.com/coryan/Skye/blob/1d1c6cdbb24ffd87bf0a0558bcf7038e08235d45/.travis.yml)

Future Changes
--------------

The solution described above for testing multiple compilers is not
very scalable.  It seems the state of the art is to use the new
container-based build infrastructure in Travis, and build a matrix of
configurations as described
[here](http://stackoverflow.com/questions/29312015/building-with-more-than-one-version-of-a-compiler),
or if you want an even more sophisticated example look at
[this one](https://github.com/ldionne/hana/blob/master/.travis.yml).

I will probably need such an approach when I start testing builds with
code coverage, without it, with optimizations and without them, with
different memory checking tools (ASAN, TSAN, etc).  But for the time
being I am satisfied that I can continue to code and have something
running the tests for me.

Taking Stock
------------

I started this series of posts to investigate if it was possible to
setup C++11 builds using any of the hosted continuous integration
solutions out there.  Though I did not show my attempts at using other
CI frameworks, all the ones I tried use Ubuntu 12.04 as their base
platform, so the first step was to install the necessary tools for
C++11 on said platform.
Once that problem is resolved, using Travis CI, which appears to be
the most popular product, proved relatively easy.
In a scale of 1-10 where 1 is booting Android and 10 is configuring
sendmail using the original `.cf` file, I rate this a 2.

The biggest feature I miss from Travis CI is some kind of report to
show what specific tests broke or were fixed in each change.  The are
no plans to implement such a feature
([ref](https://github.com/travis-ci/travis-ci/issues/239)).
This feature is so important that I may look into using a completely
different continuous integration solution,
such as [Circle CI](http://www.circleci.com)).



