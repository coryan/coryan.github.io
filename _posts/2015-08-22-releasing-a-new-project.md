---
layout: post
title: Releasing a New Project
date: 2015-08-22 23:00
---

I am releasing another project under the
[Apache License](http://www.apache.org/licenses/LICENSE-2.0).
Instead of just dumping all the code in one go, I will try to release
it in manageable chunks accompanied by a post explaining the ideas
behind them.
This will also make it easier to keep a strong build infrastructure,
such as continuous integration, automatically generated documentation,
and code coverage reports.
Finally it gives me a chance to reorganize some of the code.  It was
not particularly horrible, but it is always easier the second time.

### Motivation

**TL;DR;** The author wants to learn how to program on GPUs.

The problem this library tries to solve is how to measure the delay
between two market data feeds.
The problem is most common in the US equity markets, but I have good
reason that it is interesting in US options, and it might be
interested in other markets too.
The problem appears because many market participants use the
[consolidated feeds](https://en.wikipedia.org/wiki/National_market_system_plan),
which are often significantly slower than the direct feeds from the
exchanges.
There is very little trading opportunities created by measuring the
exact delay between the consolidated and direct feeds, it is enough to
know that the consolidated feeds are slower to open trading
opportunities.
But measuring the delay can help one determine how long or big those
opportunities are.  Furthermore, exchanges release new feeds all the
time, and comparing their latency is critical to the business that
depend on timely market data.

In addition, the performance of the software that captures, normalizes
and distributes these market feeds must be tested in every release.
Regressions can be expensive.  Benchmarks and simulated measurements
are often not enough, the characteristics of a production feed are
hard to reproduce in a lab, so we must have a mechanism to measure the
performance in production.

All this would not be so challenging if the message streams were
identical in both the direct and consolidated feeds.  But they are
not, the direct feeds often contain more information.
For example, a direct feed often describes the interest for all price
levels, while the consolidated feeds often only indicate the interest
at the best available price, i.e., the highest price for the buy
interest, and the lowest price for the sell interest.

And to further confuse matters, there is rarely a reliable identifier
that can be used to correlate messages on the consolidated feed
against the messages in the direct feed.

The approach that we attempt on this library is to treat the market
feeds as basic timeseries, and then perform time-delay estimation
using the [cross
correlation](https://en.wikipedia.org/wiki/Cross-correlation) of the
paired timeseries.

Cross-correlation (and time-delay estimation) are expensive operations
if performed naively.
A naive cross-relation is a $$O(n^2)$$ algorithm, fortunately, one can
use Fast-Fourier-Transform (FFT) to implement the algorithm in
$$O(n\log(n))$$.
In addition, both FFTs and the time-delay estimation algorithms can be
implemented efficiently on modern GPUs, to further speed up the
computation.

Though the primary motivation is the analysis of market data feeds, I
believe this technique is applicable any time the same timeseries is
measured in two different ways.  For example, CPU utilization, page
hit rates, server crash counts, etc.

### First Commit

That said, we need to start coding something.  So I created a
repository in github.com (with some basic defaults), and then submitted
the `autoconf` and `automake` [boilerplate](https://github.com/coryan/jaybeams/commit/9d4c2490c185e775cee65bf78fc25251e935c5f0).
