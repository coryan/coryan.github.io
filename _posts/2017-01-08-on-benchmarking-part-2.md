---
layout: post
title: On Benchmarking, Part 2
date: 2017-01-08 05:00
---

> This is an article in a long series, you may want to start from the
> [first article](/2017/01/04/on-benchmarking-part-1/) and read them
> in sequence.

In our [previous post]({{previous.post.url}}) we discussed the
`array_base_order_book_side<>` template class in detail,
and outlined how
we plan to benchmark different versions of it.
We determined that testing an end-to-end program would be too slow,
too cumbersome, and too unpredictable to be usable.
After discussing the tradeoffs between using recorded vs. synthetic
inputs for benchmarking this class, we settled on synthetic inputs.
We recall that the inputs in this case take the form of sequences of
operations that must be processed by the class under test.

In this post we will describe the benchmarking framework used in
[JayBeams](https://github.com/coryan/jaybeams/),
and how to control the execution environment to obtain consistent
results in any benchmark of CPU bound components.
In general, the class of benchmarks we are describing are referred to
as
[microbenchmark](https://en.wiktionary.org/wiki/microbenchmark), and
we will use this term from now on.

## The Typical Structure of Microbenchmark

Most microbenchmarks follow a similar pattern.
First, the environment necessary to run the component under test
is setup.
This may require mocking some of the interfaces that the component
interacts with, but potentially could be tested against real
components too.

Next, multiple iterations of the test are executed, and the elapsed or
CPU time of the each iteration is recorded.
Sometimes a number of initial iterations is discarded, arguing that
they represent a "warm up" period that the system needs before it can
get to a stable operating regimen.

While modern systems provide many mechanisms to measure time,
microbenchmarks often neglect to mention exactly which mechanism they used,
and to document why what that mechanism chosen in the first place.

Often only an aggregate of the results is reported,
for example, the arithmetic mean of the measurements.
More rarely other statistics, such as the maximum, some quantiles, or
the standard deviation are also reported.

Rarely do we see any justification to the choice of statistics:
why is the mean the right statistic to consider in the
conditions observed during the benchmark?  Why not median?
Does it even make sense to consider a measure of
[central tendency](https://en.wikipedia.org/wiki/Central_tendency),
or should we consider another type of
[location parameter](https://en.wikipedia.org/wiki/Location_parameter)?
Why is the standard deviation the right measurement of
[statistical dispersion](https://en.wikipedia.org/wiki/Statistical_dispersion)?
Is the interquartile range a better statistic under our conditions?

Even worse, very few reports include any kind of power analysis: was
the number of iterations high enough to draw a stastically significant
conclusion?
And more importantly: was the effect observed sufficiently interesting
to merit any reporting?  Or is this a case of statistically
significant but meaningless [change](https://xkcd.com/1252/)?

The (very) interesting statistical questions will be the matter of a
future post.
In the following sections we will describe the framework used in
JayBeams, and hopefully address all the deficiencies raised in the
previous paragraphs.

## The JayBeams Microbenchmark Infrastructure

JayBeams provides a number of classes to make it easy to write
microbenchmarks.
The user provides a *fixture*, which encapsulates both the setup and
run steps of the test.  The framework takes care of preparing the
system to run the test, reading the configuration parameters for the
test, running the desired number of warm up and test iterations,
capturing the results, and finally reporting all the data.

### The Fixture class

The constructor of this class is required to
configure the environment to run the tests, including any mock objects
or other dependencies.
The constructor can receive a `size` argument describing the how large
of a test to run, for benchmarks that exercises algorithms with

The `Fixture::run()` member function executes the test.
The framework configuration determines how many times this function is
called during the warm up period (if any), and how many times it is
called during the measurement period.

The time measurements for each iteration are captured in memory,
with all reporting deferred until after the microbenchmark is completed.
In fact, no output is produced by the framework while the test is running.
And all the memory necessary to capture the results is allocated before
the test starts to avoid interfering with any allocations performed by
the component under test.

### Clock selection

The microbenchmark framework uses `std::steady_clock` to measure the
duration of the tests.
Other alternatives were considered (and rejected), as described below:

`getrusage(2)`: this system call returns the resource utilization
  counters that the system tracks for every process (and in some
  systems each thread).
  The counters include cpu time, system time, page faults, context
  switches, and many others.
  Using CPU time instead of wall clock time is advantageous
  because it should be less sensitive to scheduling effects.  The
  amount of CPU used should not change while the program waiting to be
  scheduled.
  However, the precision of `getrusage` is too low for our purposes,
  traditionally it was updated 100 times a second, but even on modern
  Linux kernels the counters are only incremented around 1,000 times
  per second
  [[1]](http://ww2.cs.fsu.edu/~hines/present/timing_linux.pdf)
  [[2]](http://stackoverflow.com/questions/12392278/measure-time-in-linux-time-vs-clock-vs-getrusage-vs-clock-gettime-vs-gettimeof).
  Therefore, these counters have at best millisecond resolution,
  while the improvements we need to evaluate often differ by just a
  few microseconds or even a few nanoseconds.
  Using these function would introduce measurement errors many times
  larger than the effects we want to measure, and therefore it is not
  appropriate for our purposes.

`std::high_resolution_clock`: C++ offers a potentially
  higher-resolution clock than `std::steady_clock`.
  However, this
  clock is not guaranteed to be monotonic, making it inadequate for
  duration measurements.
  On Linux, the implementation uses
  `clock_gettime(CLOCK_REALTIME,...)`
  [[3]](https://github.com/gcc-mirror/gcc/blob/1cb6c2eb3b8361d850be8e8270c597270a1a7967/libstdc%2B%2B-v3/src/c%2B%2B11/chrono.cc),
  which is subject to changes in the system clock, such as ntp
  adjustments.

`clock_gettime(2)`: is the underlying function used in the
  implementation of `std::steady_clock`.
  One could argue that using it directly would be more efficient,
  however the C++ classes around them add very little overhead, and
  offer a much superior,
  we see no reason to sacrifice the improved abstractions for marginal
  (or no) improvement.

`gettimeofday(2)` is a POSIX call with similar semantics to
  `clock_gettime(CLOCK_REALTIME, ...)`.
  However, POSIX no longer recommendeds this call
  [[4]](http://pubs.opengroup.org/onlinepubs/9699919799/functions/gettimeofday.html),
  and recommends using `clock_gettime` instead.

`time(2)` only has second resolution, and it is not monotonic.
  Clearly not adequate for our purposes.
  
`rdtsc`: is a x86 instruction that essentially returns the number of
  ticks since the CPU started.
  It can be used to measure time intervals with very minimal overhead
  (a single instruction to capture the timestamp!).
  We have used this approach in the past, but there are a number of
  [pitfalls](http://oliveryang.net/2015/09/pitfalls-of-TSC-usage/).
  Furthermore, `clock_gettime` is implemented using
  [vDSO](http://man7.org/linux/man-pages/man7/vdso.7.html),
  which greatly reduces the overhead of these system calls.
  In our opinion, its use is no longer justified on modern Linux systems.

### System Configuration

Running a benchmark on a Linux server or workstation can produce
extremely variable results depending on the system load, scheduling
parameters, and the frequency scaling governor among other system
configuration parameters.
We have identified (1) the scheduling class for the process,
(2) the percentage of the CPU reserved for non real-time processes,
(3) the CPU frequency scaling governor in the system,
and (4) the overall system load,
as the critical system and process configuration that must be
controlled to obtain consistent results.

First we describe these configuration parameters, and then we present
the results of our exploratory data analysis.

**scheduling class**: the scheduling class controls the algorithm used
by the kernel to schedule the tasks in the system.
We run the microbenchmark in the default scheduling class
(`SCHED_OTHER`), and at the maximum priority in the real-time
scheduling class (`SCHED_FIFO`) with the default system limits for
real-time tasks.
We refer the reader to
[sched(7)](http://man7.org/linux/man-pages/man7/sched.7.html)
for a detailed description of the different scheduling classes and
available priorities in Linux systems.

**non-real-time CPU reservation**: to avoid starving non-real-time
tasks the Linux kernel can be configured to reserve a percentage of
the CPU for them.
By default this value is set to 5%, but it can be changed by writing
into `/proc/sys/kernel/sched_rt_runtime_us` parameter
[[5]](http://man7.org/linux/man-pages/man7/sched.7.html)).
When the process is in the FIFO scheduling class we run it with the
default CPU reservation for non-real-time tasks and with unlimited CPU
for real-time tasks.

**CPU frequency scaling governor**: modern CPUs can change their
frequency dynamically to tradeoff power efficiency against
performance.  The system provides different *governors* that offer
distinct tradeoffs of performance vs. power efficiency.
We run the tests with both the `ondemand` CPU governor, which attempts
to increase the CPU frequency as soon as it is needed,
and with the `performance` CPU frequency governor which always runs
the CPU at the highest available frequency
[[6]](https://wiki.archlinux.org/index.php/CPU_frequency_scaling).

**system load**: to simulate the effect of a loaded vs. idle system we
run the system without any additional load, that is *unloaded*, and
with N processes, one for each core, each of which tries to consume
100% of a CPU.


Finally, we run run multiple iterations of the microbenchmark, under
all possible combinations of these conditions.  The results are
presented in the following graph:

![A series of boxplot graphs showing how the performance vary with
  scheduling parameters, load, and the system frequency scaling
  governor used.](/public/2017-01-08-on-benchmarking-part-2/microbenchmark-vs-scheduling-setup.boxplot.svg
 "Test Latency Results under Different Load, Scheduling Parameters,
  and CPU Frequency Scaling Governor.")

As we can see the results are extremely variable when the
default scheduling class is used and the system is under load.
The results in this scheduling class are more consistent when the
system is not under load.
We should continue to consider the default scheduling class when the
system is not under load, however.

While the results are more consistent under the real-time scheduling
class,
they are, somewhat surprisingly, very variable with the `ondemand`
governor under no system load.
This is explained because under high system load the `ondemand`
governor pushes the CPU frequency to its highest value, improving the
consistency (and actual latency) of the microbenchmark measurements.
In effect, running with the `ondemand` governor under high load is
equivalent to running under the `performance` governor under any load.
It is, again, preferable to use the `performance` governor when
running microbenchmarks because we want consistent results.

For these reason the microbenchmark framework automatically runs
the job in the FIFO scheduling class, at the maximum scheduling
priority.
If the user does not have enough privileges the changes in the
scheduling parameters fail, but the program continues.
The framework can be configured at run-time to terminate the program
on a failure to set the scheduling parameters,
or to not set the scheduling parameters in the first place.

Likewise, the driver scripts for any microbenchmarks in JayBeams
automatically set the CPU frequency scaling governor to `performance`
before running any benchmarks.

#### Effect of the Microbenchmark Inputs

We recall that the microbenchmark in question generates a sequence of
operations based on a PRNG.
Naturally, the component under test will take different time to
process different inputs,
and while we would be interested on making sure any
improvements to the component work for all inputs (or at least most
inputs), we propose to analyze the impact of other system
configuration parameters while the input remains fixed.

The following graph shows different results for the microbenchmark
when the system is always configured to use the `performance` CPU
frequency governor, and excluding the default scheduling class when
the system is under load.

![A series of boxplot graphs showing how the performance vary with
  the PRNG seed selection and system load.](/public/2017-01-08-on-benchmarking-part-2/microbenchmark-vs-seed.boxplot.svg
 "Microbenchmark Results under Different Load and PRNG seeds.")

As we can see, running with a fixed seed produces more consistent
results than letting the system pick a seed from `/dev/urandom`.
However, there are still large effects due to system load and
scheduling that we should control for.

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
not under heavy load, notice that the variation here is
significantly smaller than what we observed earlier when using the
default scheduling class.

Finally, we examine the effect of the real-time scheduling limits as
configured in `/proc/sys/kernel/sched_rt_runtime_us`:

![A series of boxplot graphs showing how the performance vary with
  system load and the real-time scheduling system-wide limits.](/public/2017-01-08-on-benchmarking-part-2/microbenchmark-vs-rtlimit.boxplot.svg
 "Microbenchmark Results and Real-time Scheduling Limits.")

The effects seem to be very small, but not trivial, the inter-quartile
range for this data is:

|Scheduling Class | Real-time Scheduling Limits | Inter-Quartile Range |
| --------------- | --------------------------- | --------------------:|
| default | N/A | 89 |
| FIFO    | default (95%) | 40 |
| FIFO    | unlimited     | 28 |

Therefore, we prefer to configure the system to real-time tasks to use
all the CPU during the execution of microbenchmarks.

### Reporting the Results

We now need to consider how the results of the measurements should be
reported.
The JayBeams microbenchmark framework makes no assumptions as to what
are good statistics to report for a given run of experiments.
The choice of statistic depends on the nature of the underlying
distribution, and producing correct results for all of them is a task
best left for specialized software, such as
[R](http://www.r-project.org), a powerful software environment for
statistical computing.
On the other hand, before final results are ready for analysis the
developers may want to review preliminary results quickly to guide
their modify-compile-test cycles.

To satisfy these demands the JayBeams microbenchmark framework can
operate in two modes:

When a developer is running quick tests to evaluate a change,
the microbenchmark program outputs a summary of the results.
This summary includes the following statistics: the number of
iterations, the minimum time, the maximum time, and the p25, p50, p75,
p90 and p99.9 percentiles.
The choice of percentiles is based on the fact that most latency
measurements are skewed to the right (so we have more percentiles
above 90% than below 10%), but the choice is admittedly arbitrary.
The system intentionally omits the mean, because the distributions
rarely have any central tendency, which is what the mean intuitively
represent.
We believe most users would be tempted to draw incorrect conclusions
if this statistic was included.

When the developer is ready for a formal test they execute a driver
script which runs the benchmark with a controlled system configuration,
and produces a full dump of every iteration measurement.
The driver also captures metadata for the benchmark, such as the
compiler version, library versions, and compilation options.
A second script, typically written in R, performs any statistical
analysis of the data.

The need for a separate driver is less than ideal,
however, there are no APIs to configure some of the system
parameters identified above (such as the CPU frequency scaling
governor, or the non-real-time scheduling CPU reservation), which
would require running the program as a privileged user to change
them.
A script can request temporary privilege escalation via `sudo(8)`,
which is a more accepted practice than running your benchmarks as the
superuser.
We are waiting to gain more experience with the framework before
deciding if running them with elevated privileges is the right
solution after all.

On the other hand, the separation of concerns between the script to
run the statistical analysis and the program under test we think is
the right one.
Systems like R, offer far more flexibility and a richer set of
statistics than we can dream to offer in our code.

### Summary of Recommendations for the System Configuration

Microbenchmarks should be executed on a lightly loaded system,
where the CPU frequency scaling governor has been set to
`performance`, and where the system has been configured to dedicate up
to 100% of the CPU to real-time tasks.
The program performing the tests should be running on the `SCHED_FIFO`
scheduling class, at the highest priority available.

Even under such conditions it is crucial that the program runs with
exactly the same inputs in each iteration of the test,
and one should expect some variation in the results from run to run.

We note that because there is variation in the results any change that
allegedly improves the performance should be evaluated using some
statistical test.
The nature of the test will depend on the distribution of the
performance measurement results, in particular, the
[Student's t-test](https://en.wikipedia.org/wiki/Student%27s_t-test)
assumes a normal distribution on the underlying data.

Likewise, the number of measurements required to produce statistically
valid results increases with the variability of the test.
Our efforts to control the execution environment and produce more
consistent results lowers the number of iterations required to produce
valid results.

However, a developer wishing to draw conclusions about the improvement
of their systems should perform
[power analysis](https://en.wikipedia.org/wiki/Statistical_power)
to determine what is the minimum number of iterations required.

### Future Work

Page faults can introduce additional latency in program execution, and
can be avoided by using the `mlockall(2)` system call.
Similar to real-time CPU scheduling, the Linux kernel offers
facilities to schedule I/O operations at different priorities via the
`ioprio_set(2)` system calls.
The JayBeams microbenchmark framework does not take advantage of
either of these mechanisms.
We believe that the components under consideration are not subject to
substantial memory pressure or I/O load, and thus will not benefit
from the additional settings.
This could be changed in the future as more components need to be
benchmarked with different requirements.

Linux 4.7 and higher include `schedutil` a CPU frequency scaling
governor based on information provided by the scheduler
[[7]](https://kernelnewbies.org/Linux_4.7).
Initial reports indicate that it performs almost as well as the
`performance` governor.
For our purposes the `performance` scheduler is a
better choice as we are willing to forgo the power efficiency of a
intelligent governor in favor of the predictability of our results.

## Notes

The data in this post was generated using a shell script,
available
[here](/public/2017-01-08-on-benchmarking-part-2/generate-data.sh),
it should be executed in a directory where you have compiled
[JayBeams](https://github.com/coryan/jaybeams).

Likewise, the graphs for this post were generated using a R script,
which is also
[available](/public/2017-01-08-on-benchmarking-part-2/create-graphs.R).

Though the data and graphs were generated using the JayBeams
microbenchmark for `map_based_order_book_side<>` the results are not
based on the specifics of this test, and are applicable to any
CPU-bound, single-threaded microbenchmark.
The data from these results was recorded, but not used in any
subsequent phases of the analysis of `map_based_order_book_side<>` or
`array_based_order_book_side<>`.

The detailed configuration of the server hardware and software used to
generate run these scripts is included in the comments of the 
[csv](/public/2017-01-08-on-benchmarking-part-2/data.csv) file that
accompanies this post.

