---
layout: post
title: On Benchmarking, Part 2
date: 2017-01-06 05:00
---

> This is an article in a long series, you may want to start from the
> [first article](/2017/01/04/on-benchmarking-part-1/) and read them
> in sequence.

In our [previous post]({{previous.post.url}}) we discussed the details
of the `array_base_order_book_side<>` template class, and outlined the
characteristics of a benchmark program for it.
We determined that testing an end-to-end program would be too slow,
cumbersome, and unpredictable to be usable.
Instead we settled on generating a pseudo-random sequence of
operations with similar characteristics to a production run.
We also discussed some of the tradeoffs of generating the sequence of
operations vs. capturing a sequence from real data.

In this post we will describe the benchmark in more detail,
and start some of the statistical analysis required to decide if
changes to the code are improving its performance or not.
I think the reader will agree that the component we are trying to
measure is relatively small (it is less than 500 lines of code),
and it is therefore appropriate to describe this work as a
[*microbenchmark*](https://en.wiktionary.org/wiki/microbenchmark).

## The Typical Approach to Microbenchmarks

Most microbenchmarks operate in a similar pattern.
First, the environment necessary to run the component under benchmark
is setup.
This may require mocking some of the interfaces that the component
interacts with.
Next, multiple iterations of the microbenchmark are executed,
the exact number often goes unreported and we almost never see a
principled discussion as to why a particular number of iterations is
captured.
Sometimes a number of initial iterations is discarded, arguing that
they represent a "warmup" period that the system needs to get to a
more stable operating regimen.

The duration of each iteration is treated as the measurement of
interest.
Developers have many choices to measure time,
and often neglect to mention exactly which mechanism they use,
and why they used one approach vs. another.

Often only an aggregate of the results is reported, and more often
than not, this is the (arithmetic) mean, without much thought 
as to whether it is the right statistic to capture.
Rarely other statistics, such as the standard deviation or some
percentiles are included in the report, but commonly without any
effort at interpretation.

## The JayBeams Microbenchmark Infrastructure

JayBeams provides a number of classes to make it easy to write
microbenchmarks.
The user provides a *fixture*, which encapsulates both the setup and
run steps of the test, and the framework takes care of preparing the
system to run the test, reading the configuration parameters for the
test, running the desired number of warmup and test iterations,
capturing the results, and finally reporting all the data.

### Setup and Iteration

The JayBeams microbenchmark framework requires the user to provide a
`Fixture` class.
The constructor of this class is required to
configure the environment to run the tests, including any mock objects
or other dependencies.
The constructor can receive a `size` argument describing the how large
of a test to run, for benchmarks that exercises algorithms with
varying sizes for their inputs.

The `run` member function in the class executes the test.  The
framework configuration determines how many times this function is
called during the warmup period (if any), and how many times it is
called during the measurement period.

The time measurements for each iteration is captured (in memory)
reporting after the microbenchmark is completed.
No output is produced by the framework while the test is running.
All the memory necessary to capture the results is allocated before
the test starts to avoid interfering with the arena used by the test.

### Clock selection

The microbenchmark framework uses `std::steady_clock` to measure the
duration of the tests.
Other alternatives were considered (and rejected), for the following
reasons:

`getrusage(2)`: Unix systems keep counters tracking cpu time, system
  time, and other performance characteristics of each process (or
  thread).  This system call allows the caller to query these counters.
  Using CPU time instead of wallclock time is advantageous
  because it should be less sensitive to scheduling effects.  The
  amount of CPU used should not change while the program waiting to be
  scheduled.
  However, the precision of `getrusage` is too low for our purposes,
  traditional it was updated 100 times a second, but even on modern
  Linux kernels the counters are only incremented around 1,000 times
  per second
  [[1]](http://ww2.cs.fsu.edu/~hines/present/timing_linux.pdf)
  [[2]](http://stackoverflow.com/questions/12392278/measure-time-in-linux-time-vs-clock-vs-getrusage-vs-clock-gettime-vs-gettimeof).
  Therefore, these counters have at best 1ms resolution.
  The improvements evaluate often differ by just a few microseconds or
  even a few nanoseconds, requiring very long test times to make the
  effects visible through this call.

`std::high_resolution_clock`: C++ offers a potentially
  higher-resolution clock than `std::steady_clock`.
  However, this
  clock is not guaranteed to be monotonic, making it inadequate for
  duration measurements, and in fact is implemented on
  top of `clock_gettime(CLOCK_REALTIME,...)` on Linux
  [[3]](https://github.com/gcc-mirror/gcc/blob/1cb6c2eb3b8361d850be8e8270c597270a1a7967/libstdc%2B%2B-v3/src/c%2B%2B11/chrono.cc),
  which is subject to changes in the system clock, such as ntp
  adjustments.

`clock_gettime(2)` is just as good, but offers a worse interface than
  `std::steady_clock`.

`gettimeofday(2)` is no longer recommended by POSIX
  [[4]](http://pubs.opengroup.org/onlinepubs/9699919799/functions/gettimeofday.html),
  `clock_gettime` is recommended instead which we are using.

`time(2)` only has second resolution, and it is not monotonic.
  
`rdtsc`: x86 CPUs keep a clock tick counter that can be used to
  measure time intervals with very minimal overhead: it can be read in
  a single instruction.
  I have used this approach in the past, but there are a number of
  [pitfalls](http://oliveryang.net/2015/09/pitfalls-of-TSC-usage/).
  Furthermore, it has been many years since `clock_gettime` is
  implemented using
  [vDSO](http://man7.org/linux/man-pages/man7/vdso.7.html),
  greatly reducing the overhead of these calls.
  Its use is no longer justified on modern Linux systems.

### System Configuration

Running a benchmark on a standard workstation can produce extremely
variable results.
For example, in the following graph we depict the results of running
the experiment first on an idle workstation, and then on the same
workstation but under load.

![A boxplot plot: the X axis is labeled 'Environment',
  showing four cases 'idle', 'loaded', 'rt', and 'rt-loaded'.
  The Y axis is labeled 'Iteration Latency (us)' and ranges from 0 to
  over 150,000.
  The 'loaded' case is the only one with outliers beyond 25,000 but it
  is hard to read where are the boxes because the graph is dominated
  by the outliers..](/public/2017-01-06-environment-vs-latency.boxplot.svg
 "Test Latency Results under Different Load and Scheduling.")

It is not our intention to examine the behavior of the test under
every combination of load and scheduling parameters.
We simply notice that without scheduling on the real-time class the
results are subject to variation produced by the load in the system.

We must design our experiments to minimize the impact of such load,
and for this reason the microbenchmark framework automatically runs
the job in the FIFO scheduling class, at the maximum scheduling
priority.
If the user does not have enough privileges the changes in the
scheduling parameters fail, but the program continues.
This behavior can be changed to terminate the program on a failure via
a configuration parameter.

The framework does not attempt to lock the pages of the program via
`mlockall(2)`, nor does it attempt to set the I/O scheduling priority
via `ioprio_set(2)`.
We believe that the systems under consideration are not subject to
substantial memory pressure or I/O load, and thus will not benefit
from the additional setting.

We have one surprising result to report.
In both the default and FIFO
scheduling classes the program seems to have better performance up to
the p75 level when the system is under load:

![A boxplot plot: the X axis is labeled 'Environment',
  showing four cases 'idle', 'loaded', 'rt', and 'rt-loaded'.
  The Y axis is labeled 'Iteration Latency (us)' and ranges from 5,000 to
  over 10,000.
  This is a zoomed version of the previous graph.
  We can how see that both 'loaded' and 'rt-loaded' have lower p75
  (around 6,000 us)
  than the minimum of 'idle' and 'rt'.for 'idle' (which are around
  7,000 microseconds).
  ](/public/2017-01-06-environment-vs-latency.boxplot.zoom.svg
 "Test Latency Results under Different Load and Scheduling -
  Restricted Y Range.")

This result is curious, but irrelevant to our purposes.  We just want
to ensure that the same results are produced from one run to the next,
to evaluate the impact of code changes.

### Reporting the Results

JayBeams microbenchmark is intended to operate in two modes:

When a developer is running quick tests to evaluate a change the
microbenchmark program simply results a summary of the results,
including the following statistics, including the minimum time,
maximum time, the number of iterations, and some key percentiles
(p25, p50, p75, p90, and p99.9).

When the developer is ready for a formal test a driver shell script
runs the benchmark and produces a full dump of every iteration measurement,
as well as capturing metadata for the benchmark, such as the compiler
version and options.  A second script performs any statistical
analysis of the data.
In future versions we plan to eliminate the need for a driver script,
but the separation of concerns between the script to run the
statistical analysis and the program under test we think is the right
one.
For the purposes of this discussion we simply note that a full output
of the results allows the analysis script to perform **any**
statistical test.  In particular, the analysis script for this
benchmark uses R, a powerful software environment for statistical
computing.

## Notes

The graphs in this post were generated using the following R
commands.  They are presented to illustrate the functioning of the
microbenchmark framework, and how it controls for environment
variables.
Though the graphs were generated using the framework and driver
scripts most of the features to control experiment were disabled,
these results should simply be considered exploratory data analysis.
The data from these results was recorded, but not used in any
subsequent phases of the analysis.

{% highlight r %}
require(ggplot2)
data.filename <- 'http://coryan.github.io/public/2017-01-06-bm_order_book.results.csv'

data <- read.csv(
    data.filename, header=FALSE, col.names=c('testcase', 'nanoseconds'),
    comment.char='#')
data$run <- factor('baseline')
data$microseconds <- data$nanoseconds / 1000.0

ggplot(data=data, aes(x=testcase, y=microseconds, color=testcase)) +
  geom_boxplot() +
  ylab("Iteration Latency (us)") +
  xlab("Environment") +
  theme(legend.position="none")
ggsave(filename="2017-01-06-environment-vs-latency.boxplot.svg",
       width=8.0, height=8.0/1.61)
ggsave(filename="2017-01-06-environment-vs-latency.boxplot.png",
       width=8.0, height=8.0/1.61)

ggplot(data=data, aes(x=testcase, y=microseconds, color=testcase)) +
  geom_boxplot() +
  ylab("Iteration Latency (us)") +
  ylim(5000, 10000) +
  xlab("Environment") +
  theme(legend.position="none")
ggsave(filename="2017-01-06-environment-vs-latency.boxplot.zoom.svg",
       width=8.0, height=8.0/1.61)
ggsave(filename="2017-01-06-environment-vs-latency.boxplot.zoom.png",
       width=8.0, height=8.0/1.61)

## Load data for 
runs.filename <- 'http://coryan.github.io/public/2017-01-06-bm_order_book.rtruns.csv'

runs <- read.csv(
    runs.filename, header=FALSE, col.names=c('run', 'nanoseconds'),
    comment.char='#')
runs$microseconds <- runs$nanoseconds / 1000.0

ggplot(data=runs, aes(x=run, y=microseconds, color=run)) +
  geom_boxplot() +
  ylab("Iteration Latency (us)") +
  xlab("Run Number") +
  theme(legend.position="none")

ggsave(filename="2017-01-06-latency.boxplot.svg",
       width=8.0, height=8.0/1.61)
ggsave(filename="2017-01-06-latency.boxplot.png",
       width=8.0, height=8.0/1.61)

{% endhighlight %}
