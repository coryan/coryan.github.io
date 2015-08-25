---
layout: post
title: Of Message Rates and Histograms
date: 2015-08-25 02:00
---

After pushing the code coverage to nearly 99% from the low 80's, I
have found exactly
[one bug](https://github.com/coryan/jaybeams/issues/2).
This was a known problem and a feature that I intentionally left
unimplemented.  Not a huge return on investment, but increasing code
coverage is satisfying for its own sake.

The next chunk of code to release deals with measuring expected
message rates.  To design the system I want to know (within an order
of magnitude) how many messages per second, per millisecond, and even
per microsecond to expect.  This is partially to satisfy my
curiosity, partially to illustrate the technical problems when
building real-time market data processing systems, and partly because
that defines the design envelope.

## Don't write code if you can just go an look it up online

Before we write any code, why not simply look up the numbers online?
They might not be accurate, but would help with the initial
estimation.
My search-fu may not be the best, but this information is hard to
find.  It is not exactly secret, exchanges publish it so their users
can provision their networks and software systems adequately.
But it is not on their front page either, they reserve that space for
information with more commercial value.

But some digging around can get you the basics.

#### BATS

For example, as of 2015-06-01 BATS
[informs](http://cdn.batstrading.com/resources/membership/BATS_Connectivity_Manual.pdf)
its users that they can expect 21,883 messages in the peak
millisecond for their BZX exchange.
BATS owns several exchanges, and the numbers can be as "low" as 15,000
messages for the peak millisecond.

To illustrate how bursty this data is: in the same publication BATS
notes that on the BYX exchange the peak minute may have the equivalent
of 50,000 messages/second, while the peak millisecond carries the
equivalent of 16,000,000 messages/second.

We will see later than the peak microsecond for some of these feeds
can carry 270 messages, and implied rate of 270,000,000
messages/second.  In other words, the bursts can be 3 orders of
magnitude higher than the average.  And they can be very high indeed.

#### NASDAQ

NASDAQ provides a
[report](http://www.nasdaqtrader.com/content/technicalsupport/specifications/dataproducts/bandwidthreport.xls)
recommending 160 Mbps of bandwidth for their ITCH-5.0 feed.
Since their messages sizes are around 40 bytes (see the
[spec](http://www.nasdaqtrader.com/content/technicalsupport/specifications/dataproducts/NQTVITCHSpecification.pdf)),
we can estimate that this feed peaks at 400,000 messages/second.
However, we can do much better: NASDAQ provides
[sample data](ftp://emi.nasdaq.com/ITCH/) so their
users can verify if their feed handlers are processing it correctly.
We will use this data, to generate some interesting stats, but that later!

## So What about Some Code?

I just pushed a few new classes to github to deal keep histograms,
that is, counts of events by bucket.  Shortly I will push additional
classes where the range of each bucket represents some observed
message rate.  With these two classes in place we can estimate the
min, max, mean, median, p90, p99 or any percentile of message rates we
are interested in.

Of course the histograms will also be useful to later compute
inter-arrival times, or latencies.

The `jb::histogram` class decomposes the problem of defining the
bucket ranges and computing several statistical estimators into two
separate classes.  The bucket ranges are defined by a strategy, and I
have implemented two simple ones:

* `jb::integer_range_binning`: simply defines one bucket for each
  integer value between some user-prescribed minimum and maximum.  In
  other words, it is about as simple as you can get.
* `jb::explicit_cuts_binning`: allows the user to define the exact
  points for each bucket.  Typically this is useful when you want to
  define buckets of variable size, such as
  [0,1,2,3,...,9,10,20,30...,100]

Users can define additional binning strategies as long as they conform
to the `jb::binning_strategy_concept` interface.  The `jb::histogram`
class enforces these requirements using compile-time assertions, which
(hopefully) provide better error messages than whatever the default
compiler does.

#### What is with the weird dates?

If you see a post with an strange date, it is because I am using UTC
to date them.  Sometimes I post late on US Eastern time, and that may
make it appear as if the post is from the future.
