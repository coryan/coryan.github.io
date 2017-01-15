---
layout: post
title: Falsehoods Programmers Believe about Statistics and Benchmarks
date: 2017-02-01 01:00
draft: true
---

1. You do not need statistics, just review the code and it will be
   obvious if it is faster.
1. Okay, it might not be obvious, but a code review by experts is
   enough.
1. Just use a faster algorithm, if your $$O(...)$$ bound is better
   then you are fine.
1. If you **must** run a benchmark don't worry, no statistics are needed,
   computers are deterministic, just run the test once and report the
   result.
1. Ha ha, I was kidding, I know I need to run the test 10 times and
   take the average.
1. Of course 10 iterations is wrong.  You need to run 50.
1. Sigh... come on, you need to run at less 10,000,000.
1. What do you mean the average is wrong?  Have you not heard of the
   Law of Large Numbers?  And the Central Limit Theorem?
1. You are right, you also need to report the standard deviation,
   because then you know that all samples are within 3 sigmas from the
   average.
1. I know statistics, you just use Student's t-test and it tells you
   if the change is significant or not.

## About Averages

Of all the falsehoods programmers believe about statistics the blind
belief in [average](https://en.wikipedia.org/wiki/Average)
as a good statistic to represent the sample (or
estimate the distribution) is probably the most pernicious, and
deserve some attention.

There are at least two problems with averages, or as statisticians
call it, the
[sample mean](https://en.wikipedia.org/wiki/Mean)
for benchmarking software systems.
First, is not robust to outliers, with a
[breakdown point](https://en.wikipedia.org/wiki/Robust_statistics#Breakdown_point)
of 0%.
In plain English, you can make the average really large, by just
adding **one** sample with a very very large value.
This means that this statistic is one the the least robust statistics
out there.

And if you think that is not a problem.
Consider the following empirical distribution for one of the
measurements of one small program:

![Empirical Distribution Density for a Microbenchmark.
High peak at around 5,000, another peak at around 15,000, tail goes to
60,000.
](/public/2017-02-01-falsehoods-programmers-believe-about-benchmarks/empirical-density-uncontrolled.svg
 "Empirical Distribution of Microbenchmark Results when System
 Configuration is not Controlled.")

With such a distribution it is not unreasonable to expect outliers in
the data.  There is an order of magnitude difference between the
minimum and maximum in this case, your average can be moved
substantially by just a few points in the extreme.

You might be thinking, as engineers often do, that you can use another
kind of mean: the geometric mean, or the harmonic mean, or maybe
something like the median to avoid the lack of robustness in the
arithmetic mean.
Unfortunately there is a second, more subtle, problem.
All the statistics mentioned above are measures of
[central tendency](https://en.wikipedia.org/wiki/Central_tendency),
the notion that the distribution has a central or typical value that
all other values "cluster around".

Sadly, the distributions that we observe in practice for performance
measurements do not seem to exhibit such "tendency to cluster around a
central value",
the same distribution
above serves as an example, but other examples can be readily found,
see [[1]](http://www.slideshare.net/brendangregg/velocity-stoptheguessing2013).

There are good statistics that measure shifts in the
[location](https://en.wikipedia.org/wiki/Location_parameter) of your
data.
For example, one should consider the
[Hodges-Lehmann estimator](https://en.wikipedia.org/wiki/Hodges%E2%80%93Lehmann_estimator)
when using non-parametric statistics.

## About the Number of Samples

Suppose you have a system that you are benchmarking, and after careful
tuning you manage to keep the results between 100 and 200
microseconds when you run the test 10,000 times.
You make a change, run the test once and the new result in 105
microseconds.
Was your change worthless?  It is, after all, in the same range as
before.  Maybe you run the test 10 times, and now the results are
between 105 and 130 microseconds.  Is your test faster?  Or you were
simply lucky and if you run it a few more times it will start taking
longer?
How can you decide?

The answer is
[statistical power](https://en.wikipedia.org/wiki/Statistical_power),
this is a measure (a probability really) that the test will detect the
effect you want, assuming it is there.
Or if you prefer: how unlucky would I need to be to miss the good
news, assuming I actually improved performance.

The computation is not hard for something like the t-test.
Alas! You say, my distributions are not normal, just look at that
graph from the previous section, and t-test assumes a normal
distribution.
The answer is that there are good bounds on the sample size needed for
the corresponding Wilcoxon-Mann-Whitney non-parametric test.
This is a test similar in goals as the t-test, but that makes no
assumption about the underlying distributions: it is distribution
free, or non-parametric.
The rule of thumb is to simply add 15% more samples
[[1]](http://www.jerrydallal.com/LHSP/npar.htm),
but if you do not like to use your thumbs to keep rules, then you can
use bootstrapping to estimate the power.

### The Side Benefits of using Statistics

Suppose we decide to use a rigorous statistical approach just because
it is fun to learn new things.
Before we can even start, we will need to answer the following
questions:

* What exactly do we mean by "better performance"?
* How exactly is this "performance" to be measured?
* Is that a meaningful measurement to the application or business
  being supported by this system?
* Is the change we measured important enough for the application or is
  the effect so small that we can just ignore it?
* Under what conditions does the improvement work? Are there
  restrictions on the possible inputs?  Are those 
  restrictions acceptable for the application?

We believe the reader will want to know the answer to these questions
regardless of whether they intend to use any kind of formal
statistical approach to decide if performance has improved or is
different.


