---
layout: post
title: On Benchmarking, Part 2
date: 2017-01-08 04:00
---

> This is a long series of posts where I try to teach myself how to
> run rigorous, reproducible microbenchmarks on Linux.  You may
> want to start from the [first one](/2017/01/04/on-benchmarking-part-1/)
> and learn with me as I go along.
> I am certain to make mistakes, please write be back in
> [this bug](https://github.com/coryan/coryan.github.io/issues/1) when
> I do.

In my [previous post]({{page.previous.url}}) I discussed a class
(`array_based_order_book_side<>` a/k/a `abobs<>`)
which serves as a motivation to learn how to create really good
benchmarks.
Because testing the class inside a full program introduces too much
variation in the results,  it is too slow, and it is too cumbersome I
decided to go with a small purpose-built benchmark program.
In that post I pointed out ([[I5]][issue 5]) that any good description
of a benchmark must include how does the benchmark measures time, why
is that a good approach to measure time, and how does the benchmark
control for variables that affect the results, such as system load.
This poist is largely written to address those questions.

I will describe a small framework I built to write
benchmarks for 
[JayBeams](https://github.com/coryan/jaybeams/).
Mostly this was born with my frustration when not getting the same
results if one runs the same benchmark twice.
If I cannot reproduce the results myself, for the same code, on the
same server, what hope do I have of creating reproducible results for
others?
I need to get the environment where the benchmarks run under control
before I have any hope of embarking of a rigorous analysis of them.

It turns out you need to do a lot of fine tuning in the operating
system to get consistency out of your benchmarks, and you also
need to select your clock carefully.
I find this kind of fine tuning interesting in itself, so I am taking
the opportunity to talk about it.

Most folks call such small benchmarks a 
[microbenchmark](https://en.wiktionary.org/wiki/microbenchmark),
and I like the name because it makes a clear distinction from large
benchmarks as those for database systems (think TPC-E and its
cousins).
I plan to use that name hereafter.

## Anatomy of a Microbenchmark

Most microbenchmarks follow a similar pattern.
First, you setup the environment necessary to run whatever it is you
are testing.
This is similar to how you setup your mocks in a unit test, and in
fact you may setup mocks for your benchmark too.
In the case of our example (`abobs<>`) one wants to build a
synthetic list of operations before the system starts measuring the
performance of the class.
Building that list is expensive, and you certainly do not want to include
it the measurement of the class itself; in general,
microbenchmarks should not measure or report the time required
to setup their test environment.

Then, you run multiple iterations of the test and capture how long it
took to run each iteration.
How exactly you measure the time is a
complicated question, modern operating systems and programming
languages offer multiple different ways to measure time.
I will discuss which one I picked, and why, later in the post.
Sometimes you want to run a number of iterations at the beginning of
the benchmark, and discard the results from them.
The argument is usually that you are interested in the steady state of
the system, not what happens while the system is "warming up".
Whether that is sensible or not depends on the context, of course.

At the end most microbenchmarks report some kind of aggregate of the
results, typically the average time across all iterations.
Most microbenchmarks stop there, though rarely they include additional
[statistics](https://en.wikipedia.org/wiki/Statistic), such as the minimum,
maximum, standard deviation, or the median.

One of my frustrations is that I rarely see any justification for the
choice of statistics:
why is the mean the right statistic to consider in the
conditions observed during the benchmark?
How are you going to deal with outliers if you use the mean?
Why not median?
Does your data show any kind of 
[central tendency](https://en.wikipedia.org/wiki/Central_tendency)?
If not, then neither median nor mean are good ideas, so why report them?
Likewise, why is the standard deviation the right measurement of
[statistical dispersion](https://en.wikipedia.org/wiki/Statistical_dispersion)?
Is something like the
[interquartile range](https://en.wikipedia.org/wiki/Interquartile_range)
a better statistic of dispersion for your tests?

The other mistake that folks often make is to pick a number of
iterations because "it seems high enough".
There are good statistical techniques to decide how many iterations
are needed to draw valid conclusions, why not use them?

An even worse mistake is to not consider whether the effect observed
by your benchmark even makes sense: if you results indicate that
option A is better by less than one machine instruction per iteration
vs. option B, do you really think that is meaningful?
I think it is not, no matter how many statistical tests you have to
prove that it is true, it has barely measurable impact.
I want rigorous results, I do not want to join
["The Cult of Statistical Significance"](http://www.deirdremccloskey.com/docs/jsm.pdf).

## The JayBeams Microbenchmark Framework

In JayBeams microbenchmark
[framework](https://github.com/coryan/jaybeams/blob/eabc035fc23db078e7e6b6adbc26c08e762f37b3/jb/testing/microbenchmark.hpp)
the user just needs to provide a `fixture` template parameter.
The constructor of this fixture must setup the environment for the
microbenchmark.
The `fixture::run` member function must run the test.
The framework takes care of the rest:
it reads the configuration parameters for the
test from the command line, calls your constructor,
runs the desired number of warm up and test iterations,
captures the results, and finally reports all the data.

The time measurements for each iteration are captured in memory,
since you do not want to contaminate the performance of test with
additional I/O.
All the memory necessary to capture the results is allocated before
the test starts, because I do not want to contaminate the arena
either.

### Reporting the Results

I chose to make no assumptions in the JayBeams microbenchmark
framework as to what are good
statistics to report for a given microbenchmark.
The choice of statistic depends on the nature of the underlying
distribution, and the statistical tests that you are planning to use.
Worse, even if I knew the perfect statistics to use, there are some
complicated numerical and semi-numerical algorithms involved.
Such tasks are best left to specialized software, such as
[R](http://www.r-project.org), or if you are a Python fan,
[Pandas](http://pandas.pydata.org/).

In general, the JayBeams microbenchmark framework will dump all the
results to stdout, and expects you to give them to a script (I use R)
to perform the analysis there.
However, sometimes you just want quick results to guide the
modify-compile-test cycles.

The microbenchmark framework also outputs a summary of the results.
This summary includes: the number of
iterations, the minimum time, the maximum time, and the p25, p50, p75,
p90 and p99.9 percentiles of the time across all iterations.
BTW, I picked up p99.9 as a notation for "the
99.9th percentile", or the even worse "the 0.999 quantile of the
sample" in one of my jobs, not sure who invented it, and I think
it is not very standard, but it should be.
The choice of percentiles is based on the fact that most latency
measurements are skewed to the right (so we have more percentiles
above 90% than below 10%), but the choice is admittedly arbitrary.
The system intentionally omits the mean, because the distributions
rarely have any central tendency, which is what the mean intuitively
represent, and I fear folks would draw wrong conclusions if included.

### Clock selection

I mentioned that there are many clocks available in C++ on Linux, and
promised to tell you how I chose.
The JayBeams microbenchmark framework uses `std::chrono::steady_clock`, this
is a guaranteed monotonic clock, the resolution depends on your
hardware, but any modern x86 computer is likely to have an
[HPET](https://en.wikipedia.org/wiki/High_Precision_Event_Timer)
circuit with at least 100ns resolution.
The Linux kernel can also drive the time measurements using the
[TSC](https://en.wikipedia.org/wiki/Time_Stamp_Counter) register,
which has sub-nanosecond resolution (but many other problems).
In short, this is a good clock for a stopwatch (monotonic), and while
the resolution is not guaranteed to be sub-microseconds, it is likely
to be. That meets my requirements, but why not any of the alternatives?

`getrusage(2)`: this system call returns the resource utilization
  counters that the system tracks for every process (and in some
  systems each thread).
  The counters include cpu time, system time, page faults, context
  switches, and many others.
  Using CPU time instead of wall clock time is good,
  because the amount of CPU used should not change while the program is
  waiting to be scheduled.
  However, the precision of `getrusage` is too low for my purposes,
  traditionally it was updated 100 times a second, but even on modern
  Linux kernels the counters are only incremented around 1,000 times
  per second
  [[1]](http://ww2.cs.fsu.edu/~hines/present/timing_linux.pdf)
  [[2]](http://stackoverflow.com/questions/12392278/measure-time-in-linux-time-vs-clock-vs-getrusage-vs-clock-gettime-vs-gettimeof).
  So at best you get millisecond resolution,
  while the improvements I am trying to measure may be a few
  microseconds.
  This system call would introduce measurement errors many times
  larger than the effects I want to measure, and therefore it is not
  appropriate for my purposes.

`std::chrono::high_resolution_clock`: so C++ 11 introduced a number of
  different clocks, and this one has potentially higher-resolution
  clock than `std::chrono::steady_clock`.
  That is good, right?
  Unfortunately, `high_resolution_clock` is not guaranteed to be
  monotonic, it might go back in time, or some seconds may be shorter
  than others.
  I decided to check, maybe I was lucky and it was actually monotonic
  on my combination of operating system and compilers.
  No such luck, in all the Linux implementations I used this clock is
  based on
  `clock_gettime(CLOCK_REALTIME,...)`
  [[3]](https://github.com/gcc-mirror/gcc/blob/1cb6c2eb3b8361d850be8e8270c597270a1a7967/libstdc%2B%2B-v3/src/c%2B%2B11/chrono.cc),
  which is subject to changes in the system clock, such as ntp
  adjustments.
  So this one is rejected because it does not make for a good
  stopwatch.

`clock_gettime(2)`: is the underlying function used in the
  implementation of `std::chrono::steady_clock`.
  One could argue that using it directly would be more efficient,
  however the C++ classes around them add very little overhead, and
  offer a much superior interface.
  Candidly I would have written a wrapper to use this class, and the
  wrapper would have been worse than the one provided by the standard,
  so why bother?

`gettimeofday(2)` is a POSIX call with similar semantics to
  `clock_gettime(CLOCK_REALTIME, ...)`.
  Even the POSIX standard no longer recommends using it
  [[4]](http://pubs.opengroup.org/onlinepubs/9699919799/functions/gettimeofday.html),
  and recommends using `clock_gettime` instead.
  So this one is rejected because it is basically obsoleted, and it is
  also not monotonic, so not a good stopwatch.

`time(2)` only has second resolution, and it is not monotonic.
  Clearly not adequate for my purposes.
  
`rdtscp` / `rdtsc`: Okay, this is the one that all the low level
  programmers go after.
  It is a x86 instruction that essentially returns the number of
  ticks since the CPU started.
  You cannot ask for lower overhead than "single instruction", right?
  I have used this approach in the past, but you do need to calibrate the
  counter; it is never correct to just take the count and divided by
  the clock rate of your CPU.
  But there are a number of other
  [pitfalls](http://oliveryang.net/2015/09/pitfalls-of-TSC-usage/) too.
  Furthermore, `clock_gettime` is implemented using
  [vDSO](http://man7.org/linux/man-pages/man7/vdso.7.html),
  which greatly reduces the overhead of these system calls.
  My little
  [benchmark](https://github.com/coryan/jaybeams/blob/eabc035fc23db078e7e6b6adbc26c08e762f37b3/jb/bm_clocks.cpp),
  indicates that the difference between them is about 30ns (that is
  nanoseconds) on my workstation.
  In my opinion, its use is no longer justified on modern Linux
  systems; it carries a lot of extra complexity that you only need if you are
  measuring things in the nanosecond range.
  I may need it eventually, if I start measuring computations that
  take less than one microsecond, but until I do I think
  `std::chrono::steady_clock` is much easier to use.

### System Configuration

Running benchmarks on a typical Linux workstation or server can be
frustrating because the results vary so much.
Run the test once, it takes 20ms, run it again, it takes 50ms, run
it a third time it takes 25ms, again and you get 45ms.
Where is all this variation coming from?  And how can we control it?
I have found that you need to control at least the following to
get consistent results:
(1) the scheduling class for the process,
(2) the percentage of the CPU reserved for non real-time processes,
(3) the CPU frequency scaling governor in the system,
and (4) the overall system load.

I basically tested all different combinations of these parameters, and
I will remove the combinations that produce bad results until I
find the one (or few ones) that works well.
Well, when I say "all combinations" I do not mean that: there are 99
different real-time priorities, do I need to test all of them?
What I actually mean is:

**scheduling class**: I ran the microbenchmark in both the default
scheduling class (`SCHED_OTHER`), and at the maximum priority in the
real-time scheduling class (`SCHED_FIFO`).
If you want a detailed description of the scheduling classes and how
they work I recommend the man page:
[sched(7)](http://man7.org/linux/man-pages/man7/sched.7.html).

**non-real-time CPU reservation**: this one is not as well known, so a
brief intro, real-time tasks can starve the non real-time tasks if
they go haywire.  That might be Okay, but they can also starve the
interrupts, and that can be a "Bad Thing"[tm].
So by default the  Linux kernel is configured to reserve a percentage
of the CPU for non real-time workloads.
Most systems set this to 5%, but it can be changed by writing
into `/proc/sys/kernel/sched_rt_runtime_us`
[[5]](http://man7.org/linux/man-pages/man7/sched.7.html)).
For benchmarks this is awful, if your systems has more cores than the
benchmark is going to use, why not run with 0% reserved for the non
real-time tasks?
So I try with both a 0% and a 5% reservation for non real-time tasks
and see how this affects the predictability of the results when using
real-time scheduling (it should make no difference when running in the
default scheduling class, so I skipped that).

**CPU frequency scaling governor**: modern CPUs can change their
frequency dynamically to tradeoff power efficiency against
performance.  The system provides different *governors* that offer
distinct strategies to balance this tradeoff.
I ran the tests with both the `ondemand` CPU governor, which attempts
to increase the CPU frequency as soon as it is needed,
and with the `performance` CPU frequency governor which always runs
the CPU at the highest available frequency
[[6]](https://wiki.archlinux.org/index.php/CPU_frequency_scaling).

**system load**: we all know that performance results are affected by
external load, so to simulate the effect of a loaded vs. idle system I
ran the tests with the system basically idle (called 'unloaded' in the
graphs).  Then I repeated the benchmarks while I ran N processes, one
for each core, each of these processes tries to consume 100% of a core.

Finally, for all the
all possible combinations of the configuration parameters and load I
described above I run the microbenchmark four times.
I actually used `mbobs<>` in these benchmarks, but
the results apply regardless of what you are testing.
Let's look at the pretty graph:

![A series of boxplot graphs showing how the performance vary with
  scheduling parameters, load, and the system frequency scaling
  governor used.](/public/2017-01-08-on-benchmarking-part-2/microbenchmark-vs-scheduling-setup.boxplot.svg
 "Test Latency Results under Different Load, Scheduling Parameters,
  and CPU Frequency Scaling Governor.")

The first thing that jumps at you is the large number of outliers in
the default scheduling class when the the system is under load.
That is not a surprise, the poor benchmark is competing with the load
generator, and they are both the same priority.
We probably do not want to run benchmarks on loaded systems at the
default scheduling class, we kind of knew that, but now it is confirmed.

We can also eliminate the `ondemand` governor when using the real-time
scheduling class.
When there is no load in the system the results are quite variable
under this governor.
However it seems that it performs well when the system is loaded.
That is weird, right?
Well if you think about it, under high system load the `ondemand`
governor pushes the CPU frequency to its highest value because the
load generator is asking for the CPU all the time.
That actually improves the consistency of the results because when the
benchmark gets to run the CPU is already running as fast as possible.
In effect, running with the `ondemand` governor under high load is
equivalent to running under the `performance` governor under any load.

#### Before Going Further: Fix the Input

Okay, so the `ondemand` governor is a bad idea, and running in the
default scheduling class with high load is a bad idea too.
The following graph shows different results for the microbenchmark
when the system is always configured to use the `performance` CPU
frequency governor, and excluding the default scheduling class when
the system is under load:

![A series of boxplot graphs showing how the performance vary with
  the PRNG seed selection and system load.](/public/2017-01-08-on-benchmarking-part-2/microbenchmark-vs-seed.boxplot.svg
 "Microbenchmark Results under Different Load and PRNG seeds.")

I have broken down the times by the different inputs to the test.
Either with the same seed to the pseudo random number generator (PRNG)
used to create that synthetic sequence of operations we have
discussed, labeled *fixed*, or using
`/dev/urandom` to initialize the PRNG, labeled *urandom*, of course.
Obviously some of the different in execution time can be attributed to
the input, but there are noticeable differences even when the input is
always the same.

Notice that I do not recommend running the benchmarks for the
`abobs<>` with a fixed input.
We want the class to work more efficiently for a large class of
inputs, not simply for the one we happy to measure with.
We are fixing the input in this post in an effort to better tune our
operating system.

#### Effect of the System Load and Scheduling Limits

By now this has become a quest: how to configure the system and test
to get the most consistent results possible?
Let's look at the results again, but remove the `ondemand` governor,
and only used the same input in all tests:

![A series of boxplot graphs showing how the performance vary with
  system load and the real-time scheduling system-wide limits.](/public/2017-01-08-on-benchmarking-part-2/microbenchmark-vs-load.boxplot.svg
 "Microbenchmark Results under Different Load and Real-time Scheduling
  Limits.")

Okay, we knew from the beginning that running on a loaded system was a
bad idea.
We can control the outliers with suitable scheduling parameters, but
there is a lot more variation between the first and third quartiles
(those are the end of the boxes in these graphs btw) with load than
without it.

I still have not examined the effect, if any, of that
`/proc/sys/kernel/sched_rt_runtime_us` parameter:

![A series of boxplot graphs showing how the performance vary with
  system load and the real-time scheduling system-wide limits.](/public/2017-01-08-on-benchmarking-part-2/microbenchmark-vs-rtlimit.boxplot.svg
 "Microbenchmark Results and Real-time Scheduling Limits.")

The effects seem to be very small, but hard to see in the graph.
Time to use some number crunching, I chose the interquartile range
(IQR) because it is robust and non-parametric, it captures 50% of the data
no matter what the distribution or outliers are:

| Governor | Scheduling Class | Real-time Scheduling Limits | IQR |
| -------- | ---------------- | --------------------------- | ---:|
| ondemand |default | N/A | 148 |
| performance |default | N/A | 89 |
| performance | FIFO    | default (95%) | 40 |
| performance | FIFO    | unlimited     | 28 |

That is enough to convince me that there is a clear benefit to using
all the settings I have discussed above.
Just for fun, here is how bad those IQRs started, even if only
restricted to the same seed for all runs:

|   loaded |   seed |  scheduling |   governor | Interquartile Range |
| -------- | ------ | ----------- | ---------- | -------------------:|
| loaded | fixed |      default    | ondemand     | 602 |
| loaded | fixed |   rt:default    | ondemand     | 555 |
| loaded | fixed |      default | performance     | 540 |
| loaded | fixed |   rt:default | performance     | 500 |
| loaded | fixed | rt:unlimited | performance     | 492 |
| loaded | fixed | rt:unlimited    | ondemand     | 481 |

I believe the improvement is quite significant, I will show in a
future post that this is the difference between having to run a few
hundred iterations
of the test vs. tens of thousands of iterations to obtain enough
statistical power in the microbenchmark.

I should mention that all these pretty graphs and tables are
compelling, but do not have sufficient statistical rigor to draw
quantitative conclusions.
I feel comfortable  asserting that changing these system configuration
parameters has an effect on the consistency of the performance
results.
I cannot assert with any confidence what is the size of the effect, or
whether the results are statistically significant, or to what
population of tests they apply.
Those things are possible to do, but distract us from the objective of
describing benchmarks rigorously.

### Summary

The system configuration seems to have a very large effect on how
consistent are your benchmark results.
I recommend you run microbenchmarks on the `SCHED_FIFO` scheduling class,
at the highest available priority, on a lightly loaded system,
where the CPU frequency scaling governor has been set to
`performance`, and where the system has been configured to dedicate up
to 100% of the CPU to real-time tasks.

The microbenchmark framework automatically
set all these configuration parameters.
Well, at the moment I use a driver script to set the CPU frequency
scaling governor and to change the CPU reservation for non real-time
tasks.
I prefer to keep this in a separate script because otherwise one needs
superuser privileges to run the benchmark.
Setting the scheduling class and priority is fine,
you only need the right capabilities via
`/etc/security/limits.conf`.
The script is small and easier to inspect for security problems,
in fact, it just relies on sudo, so a simple grep finds all the
relevant lines.
If you do not like these settings, the framework can be configured to
not set them.
It can also be configured to either ignore errors when changing the
scheduling parameters (the default), or to raise an exception if
setting any of the scheduling parameters fails.

I think one should use `std::chrono::steady_clock` if you are running C++
microbenchmarks on Linux.  Using `rdtsc` is probably the only option
if you need to measure things in the *[100,1000]* nanoseconds range,
but there are many pitfalls and caveats, read about the online before
jumping into coding.

Even with all this effort to control the consistency of the benchmark
results, and even with a very simple, purely CPU bound test as used in
this post the results exhibit some variability.
These benchmarks live in a world where only rigorous statistics can
help you draw the right conclusions, or at least help you avoid the
wrong conclusions.

As I continue to learn how to run rigorous, reproducible
microbenchmarks in Linux I keep having to pick up more and more
statistical tools.
I would like to talk about them in my next post.

### Future Work

There are a few other things about locking down the system
configuration that I left out and should not go unmentioned.
Page faults can introduce latency in the benchmark, and
can be avoided by using the `mlockall(2)` system call.
I do not think these programs suffer too much from it, but changing
the framework to make this system call is not too hard and sounds like
fun.

Similar to real-time CPU scheduling, the Linux kernel offers
facilities to schedule I/O operations at different priorities via the
`ioprio_set(2)` system calls.
Since these microbenchmarks perform no I/O I am assuming this will not
matter, but possibly could.
I should extend the framework to make these calls, even if it is only
when some configuration flag is set.

I have not found any evidence that setting the CPU affinity for the
process (also known as pinning) helps in this case.
It might do so, but I have no pretty graph to support that.
It also wreaks havoc with non-maskable interrupts when the benchmark
runs at higher priority than the interrupt priority.

In some circles it is popular to create a container restricted to a
single core and move all system daemons to that core.
Then you run your system (or your microbenchmark) in any of the other
cores.
That probably would help, but it is so tedious to setup that I have
not bothered.

Linux 4.7 and higher include `schedutil` a CPU frequency scaling
governor based on information provided by the scheduler
[[7]](https://kernelnewbies.org/Linux_4.7).
Initial reports indicate that it performs almost as well as the
`performance` governor.
For our purposes the `performance` scheduler is a
better choice as we are willing to forgo the power efficiency of a
intelligent governor in favor of the predictability of our results.

My friend [Gonzalo](https://github.com/gonzus) points out that we
assume `std::chrono::steady_clock` has good enough resolution,
we should at least check if this is the case at runtime and warn if
necessary.
Unfortunately, there is no guarantee in C++ as to the resolution of
any of the clocks, nor is there an API to expose the expected
resolution of the clock in the language.
Unfortunately this means any check on resolution must be platform
specific.
On Linux the
[clock_getres(2)](http://man7.org/linux/man-pages/man2/clock_gettime.2.html) 
seems promising at first, but it turns out to always return 1ns for
all the "high-resolution" clocks, regardless of their actual
resolution.
I do not have, at the moment, a good idea on how to approach this
problem beyond relying on the documentation of the system.

## Notes

The data in this post was generated using a shell script,
available
[here](/public/2017-01-08-on-benchmarking-part-2/generate-data.sh),
it should be executed in a directory where you have compiled
[JayBeams](https://github.com/coryan/jaybeams).

Likewise, the graphs for this post were generated using a R script,
which is also
[available](/public/2017-01-08-on-benchmarking-part-2/create-graphs.R).

The detailed configuration of the server hardware and software used to
run these scripts is included in the comments of the 
[csv](/public/2017-01-08-on-benchmarking-part-2/data.csv) file that
accompanies this post.

## Updates

> I completely reworded this post, the first one read like a not very
> good paper.  Same content, just better tone I think.  I beg
> forgiveness from my readers, I am still trying to find a good style
> for blogs.

[issue 5]: /2017/01/04/on-benchmarking-part-1/#bad-no-benchmark-description
