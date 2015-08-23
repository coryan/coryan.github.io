---
title: Automating Doxygen Documentation
layout: post
date: 2015-08-23 18:00
---

I think of continuous integration, unit testing, code reviews, design
documents, and *documentation* as practices that prevent or catch
common errors.
It is easy to see why that is the case for unit testing, you are
making sure the code works as you expect as soon as possible;
or with continuous integration: you are making sure that defects do
not go unnoticed for too long.

I believe (yes, this is one of those opinions I promised in the About
page),
that documentation is also a practice to prevent defects: it stops others
from using your code incorrectly.  It states, in words that humans can
read, how you expect the code to be used and what how should others
expect the code to behave.

Others have said this
[better](http://blog.codefx.org/techniques/documentation/comment-your-fucking-code/)
than I possibly could, but it is worth repeating:
yes, by all means make your interfaces so obvious that very little
documentation is needed;
yes, by all means use the type system so it
is hard to use the code incorrectly (but you can go too far on this);
and yes, by all means write unit tests that describe the expected
behaviors and uses of your code.
Do all those things and then document your code, state how it is to be
used, state what should happen when it is used.
Yes, maintaining the documentation is hard, just do it and shut up
will you?

This is why I am setting up automated generation of Doxygen
[documents](https://coryan.github.io/jaybeams).
Writing Doxygen comments does not absolve me of all
responsibilities, I still should write design documents of some sort,
and nice pages describing how the code should be used, and examples.
But it is a start, and it allows me to see when documentation is
missing.
