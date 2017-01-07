---
layout: post
title: On Benchmarking, Part 2
date: 2017-01-08 05:00
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
operations with similar characteristics to a production run,
and benchmark the performance of the class on that sequence.
We also discussed some of the tradeoffs of generating the sequence of
operations vs. capturing a sequence from real data.

In this post we will describe the benchmark in more detail,
and how to control the execution environment to obtain consistent results.
I think the reader will agree that the component we are trying to
measure is relatively small (it is less than 500 lines of code),
and it is therefore appropriate to describe this work as a
[*microbenchmark*](https://en.wiktionary.org/wiki/microbenchmark).

## The Typical Structure of Microbenchmark

Most microbenchmarks operate in a similar pattern.
First, the environment necessary to run the component under benchmark
is setup.
This may require mocking some of the interfaces that the component
interacts with, and otherwise initializing the test harness.
Next, multiple iterations of the test are executed,
the exact number of iterations should depend on the required power of
the statistical test we plan to use, but sadly it often goes unreported
and we almost never see a principled discussion as to why a particular
number of iterations is captured.
Sometimes a number of initial iterations is discarded, arguing that
they represent a "warm up" period that the system needs to get to a
more stable operating regimen.

The duration of each iteration is treated as the measurement of
interest.
Modern systems provide many mechanisms to have many choices to measure time,
but often neglect to mention exactly which mechanism they use,
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
run steps of the test.  The framework takes care of preparing the
system to run the test, reading the configuration parameters for the
test, running the desired number of warm up and test iterations,
capturing the results, and finally reporting all the data.

### Setup and Iteration

As mentioned, the JayBeams microbenchmark framework requires the user
to provide a `Fixture` class.
The constructor of this class is required to
configure the environment to run the tests, including any mock objects
or other dependencies.
The constructor can receive a `size` argument describing the how large
of a test to run, for benchmarks that exercises algorithms with
varying sizes for their inputs.

The `Fixture::run()` member function executes the test.
The
framework configuration determines how many times this function is
called during the warm up period (if any), and how many times it is
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
  Using CPU time instead of wall clock time is advantageous
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

`clock_gettime(2)` could have been used.  However, `std::steady_clock`
  is an efficient wrapper around it, with a better interface, we saw
  no reason to sacrifice the improved abstractions for marginal (or
  no) improvement.

`gettimeofday(2)` is POSIX call with similar semantics to
  `clock_gettime(CLOCK_REALTIME, ...)`.
  However, POSIX no longer recommendeds this call by POSIX
  [[4]](http://pubs.opengroup.org/onlinepubs/9699919799/functions/gettimeofday.html),
  and recommends using `clock_gettime` instead.

`time(2)` only has second resolution, and it is not monotonic.
  Clearly not adequate for our purposes.
  
`rdtsc`: is a x86 instruction that essentially returns the number of
  ticks since the CPU started.
  It can be used to measure time intervals with very minimal overhead.
  I have used this approach in the past, but there are a number of
  [pitfalls](http://oliveryang.net/2015/09/pitfalls-of-TSC-usage/).
  Furthermore, it has been many years since `clock_gettime` is
  implemented using
  [vDSO](http://man7.org/linux/man-pages/man7/vdso.7.html),
  greatly reducing the overhead of these calls.
  In my opinion, its use is no longer justified on modern Linux systems.

### System Configuration

Running a benchmark on a Linux server or workstation can produce
extremely variable results depending on the system load, scheduling
parameters, and the frequency scaling governor.
The following graph depicts the results of running one microbenchmark
under all the different variations of:

**scheduling class**: we run the microbenchmark in the default
scheduling class (`SCHED_OTHER`), the real-time scheduling class
(`SCHED_FIFO`) with the default system limits for real-time tasks
(i.e. 95% of the cycles for real-time tasks, as configured in the
`/proc/sys/kernel/sched_rt_runtime_us` parameter: 
[[5]](http://man7.org/linux/man-pages/man7/sched.7.html)), and with no
limitations on the cycles allocated for real-time tasks.

**cpu frequency governor**: we run the microbenchmark with either the
`ondemand` CPU governor or with the `performance` CPU frequency
governor.  While the `performance` CPU governor always keeps the CPU
at the highest possible frequency, the `ondemand` governor is scales
the CPU frequency only if there is demand from the system
[[6]](https://wiki.archlinux.org/index.php/CPU_frequency_scaling).

**system load**: to simulate the effect of a loaded vs. idle system we
run one process for each core that consumes all CPU resources.

We run multiple iterations of the test under all possible combinations
of these conditions.  The results are presented in the following graph:

![A series of boxplot graphs showing how the performance vary with
  scheduling parameters, load, and the system frequency scaling
  governor used.](/public/2017-01-08-on-benchmarking-part-2/microbenchmark-vs-scheduling-setup.boxplot.svg
 "Test Latency Results under Different Load, Scheduling Parameters,
  and CPU Frequency Scaling Governor.")

As we can see the results are extremely variable when the
default scheduling class is used.
Even though the inter-quartile range is relatively low when the system
is not under load the tests still have a high number of outliers.

The results are more consistent under the real-time scheduling class,
but are somewhat surprisingly, more variable with the `ondemand` CPU
frequency governor under no system load.
This is explained because under high system load the `ondemand`
governor pushes the CPU frequency to its highest value, benefiting the
consistency (and actual latency) of the microbenchmark measurements.
The `performance` CPU frequency governor has the same effect, without
the need to introduce any additional load.

Based on these results we recommend that all microbenchmarks under
Linux are executed in the real-time scheduling class, and if possible
the CPU frequency governor should be set to `performance` before the
microbenchmark is executed.

For this reason the microbenchmark framework automatically runs
the job in the FIFO scheduling class, at the maximum scheduling
priority.
If the user does not have enough privileges the changes in the
scheduling parameters fail, but the program continues.
The framework can be configured at run-time to terminate the program
on a failure to set the scheduling parameters,
or to not set the scheduling parameters in the first place.

#### Effect of the Microbenchmark Inputs

We recall that the microbenchmark in question generates a sequence of
operations based on a PRNG.
Naturally, the component under test will perform differently with
different inputs, and while we would be interested on making sure any
improvements to the component work for all inputs (or at least most
inputs), let's fix the input and analyze the impact of other system
configuration parameters.

The following graph shows different results for the microbenchmark
when the system is always configured to use the `performance` CPU
frequency governor, and when the system always runs under the
real-time scheduling class.

![A series of boxplot graphs showing how the performance vary with
  the PRNG seed selection and system load.](/public/2017-01-08-on-benchmarking-part-2/microbenchmark-vs-seed.boxplot.svg
 "Microbenchmark Results under Different Load and PRNG seeds.")

#### Effect of the System Load and Scheduling Limits

The previous graph shows that different seed parameters can result in
different performance for the test.
To complete our analysis of the system configuration more suitable for
testing, we fix the seed and look at the effects of the system load
and real-time scheduling limits:

![A series of boxplot graphs showing how the performance vary with
  system load and the real-time scheduling system-wide limits.](/public/2017-01-08-on-benchmarking-part-2/microbenchmark-vs-load.boxplot.svg
 "Microbenchmark Results under Different Load and Real-time Scheduling
  Limits.")

As one would expect, the system produces more consistent results when
the system is not under heavy load, notice that the variation here is
significantly smaller than what we observed earlier when using the
default scheduling class.
Real-time scheduling minimizes the impact of system load, but does not
eliminate it.

Finally, we examine the effect of the real-time scheduling limits as
configured in `/proc/sys/kernel/sched_rt_runtime_us`:

![A series of boxplot graphs showing how the performance vary with
  system load and the real-time scheduling system-wide limits.](/public/2017-01-08-on-benchmarking-part-2/microbenchmark-vs-rtlimit.boxplot.svg
 "Microbenchmark Results and Real-time Scheduling Limits.")

The effects seem to be very small, but not trivial, the inter-quartile
range for this data is:

| Real-time Scheduling Limits | Inter-Quartile Range |
| ---- | ---:|
| default (95%) | 56 |
| unlimited     | 20 |

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

### Summary of Recommendations for the System Configuration

Microbenchmarks should be executed on a lightly loaded system,
where the CPU frequency scaling governor has been set to
`performance`, and where the system has been configured to dedicate up
to 100% of the CPU to real-time tasks.
The program performing the tests should be running on the `SCHED_FIFO`
scheduling class, at the highest priority available.

Even under such conditions it is crucial that the program runs with
exactly the same inputs in each tests, and one should expect some
variation in the results from run to run.

We note that because there is variation in the results any change that
allegedly improves the performance should be evaluated using some
statistical test.
The nature of the test will depend on the distribution of the
performance measurement results.
The number of measurements required to produce statistically valid
results increases with the variability of the test, so all the effort
to control the system configuration is, in effect, effort to reduce
the complexity and cost of the tests.

### Future Work

The framework does not attempt to lock the pages of the program via
`mlockall(2)`, nor does it attempt to set the I/O scheduling priority
via `ioprio_set(2)`.
We believe that the systems under consideration are not subject to
substantial memory pressure or I/O load, and thus will not benefit
from the additional setting.

## Notes

The data in this post was generated using a shell script,
available
[here](/public/2017-01-06-benchmarking-part-2/generate-data.sh),
it should be executed in a directory where you have compiled
[JayBeams](https://github.com/coryan/jaybeams).

Likewise, the graphs for this post were generated using a R script,
which is also
[available](/public/2017-01-06-benchmarking-part-2/create-graphs.R).

Though the data and graphs were generated using the JayBeams
microbenchmark for `map_based_order_book_side<>` the results are not
based on the specifics of this test, and are applicable to any
CPU-bound, single-threaded microbenchmark.
The data from these results was recorded, but not used in any
subsequent phases of the analysis of `map_based_order_book_side<>` or
`array_based_order_book_side<>`.

The detailed configuration of the server hardware and software used to
generate run these scripts is included in the comments of the 
[csv](/public/2017-01-06-benchmarking-part-2/data.csv) file that
accompanies this post.

