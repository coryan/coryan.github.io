---
layout: post
title: Some Estimates for ITCH
date: 2015-08-29 18:00
---

As promised, I recently released a little program to estimate message
rates for the ITCH-5.0 data.  It took me a while because I wanted to
refactor some code, but it is now done and available in my
[github repository](http://github.com/coryan/jaybeams).

What makes market data processing fun is the extreme message rates you
have to deal with, for example, my estimates for ITCH-5.0 show that
you can expect 560,000 messages per second at peak.
Now, if data was nicely
distributed over a second that would leave you more than a microsecond
to process each message.  Not a lot, but manageable, however, nearly 1%
of the messages are generated just 297 nanoseconds after the previous
one, so you need to process the messages in sub 300 nanos or risk some
delays.

Even if you do not care about performance in the peak second (and you
should), 75% of the milliseconds contain over 1,000 messages, so you
must be able to *sustain* 1,000,000 messages per second.

Just 3 main memory accesses will make it hard to keep up with such a
feed ([ref](https://gist.github.com/jboner/2841832)).
A single memory allocation would probably ruin your day too
([ref](http://goog-perftools.sourceforge.net/doc/tcmalloc.html)).
If there were no other concerns, you would be writing most of this
code in assembly (or VHDL, as some people do).
Unfortunately, or fortunately depending on your perspective,
the requirements change quicker than
you can possibly develop assembly (or VHDL) code for such systems.
By the time your assembly code is done another feed has been created,
or there is a new version of the feed, or the feed handler needs to be
used in a different model of hardware, or another program wants to
have an embedded feed handler, or you want to reuse the code for
another purpose.

