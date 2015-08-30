---
layout: post
title: Where I Try to Justify the Complexity I am About to Introduce
date: 2015-08-30 17:00
---

Before we start worrying about computing cross-correlations in GPUs we
would like to have a well-tested version using the CPU.  It is much
easier to debug these, and they serve as reference data when testing
the GPU version.

I chose the [FFTW](http://www.fftw.org) library because it is freely
available and it is well-known and highly regarded FFT
implementation.  It is a C library, which requires us to write some
wrappers to avoid common programming errors.

My goal is to implement a simple example showing how to estimate the
delay between two simple signals, something like this would be close
to ideal:

{% highlight c++ %}
std::size_t nsamples = ...;
std::size_t actual_delay = ...;
jb::fftw::delay_estimator estimator = ...;
auto signal_a = create_test_signal(nsamples);
auto signal_b = delay_signal(a, actual_delay);

double estimated_delay = estimator.handle(signal_a, signal_b);
// assert std::abs(estimade_delay - actual_delay) < something_small
{% endhighlight %}

We want the estimator to be some kind of class because there is need
to keep state.  For example, most FFT libraries store "execution
plans" for the transforms.  Likewise, we anticipate (or know, because
I have prototyped this) that an
OpenCL-based estimator would need to keep buffers to pass data to the
GPU, the computational kernels that will be sent to the GPU, and many
other data structures.

Finally, we expect that real-time estimators will combine the
estimates obtained by analyzing across multiple securities and/or
across different attributes -- bid vs. offer for example -- of the
same security.

We also expect that an estimator may have multiple different compute
units at its disposal.  For example, my workstation at home has 3
distint GPU devices: two discrete video cards and an
[APU](https://en.wikipedia.org/wiki/AMD_Accelerated_Processing_Unit)
which combines a CPU and GPU into the same die.
Such configuration may be uncommon, but it is common to have multiple
cores in the same server, and it would be desirable to schedule some
of the FFT transforms in different cores to increase the processing
throughput.

## You Are Not Going To Need It

Despite the challenge throughput numbers in a market feed we have not
yet definitely concluded that this level of complexity is necessary.
FFT after all stands for "*Fast* Fourier Transform", why worry about
GPUs, multicore programming, etc.?

I think I need to gather two pieces of information to demonstrate this
complexity is required.
First, we have established the throughput requirements for a feed such
as ITCH-5.0, but that feed includes *all* changes in the Nasdaq book,
across all symbols and across all price levels.
One can reasonably argue that the throughput requirements for a single
security (or a small number of securities) would be sufficiently low
to estimate the time delay in real-time.
And even if that does not reduce the throughput enough, the inside
prices and quantities provide some more relief.

Alas!  Experience shows that most changes do occur in the inside
quantities.
And, while the number of messages in a single security is hardly ever
as high as the messages in all securities, some securities have
message rates several orders of magnitude higher than others.
This wide variation in message rates can be used to our advantage, as
we can select securities that are not so active as to slow down our
system, but active enough to provide a constant signal to the delay
estimator.

Furthermore, experience shows that typical latencies for the
consolidated feeds vary between one and eight milliseconds.
To secure a long enough baseline for the delay estimator we will need
at least 16 milliseconds of data.
We need to determine the right value for our sampling rate.
Higher sampling rates should produce more accurate results, but
increase the computational costs.

For example, if we chose to take one sample per microsecond each FFTs
would require at least $$16384 * \log_2(16384) = 229376$$ operations.
A cross correlation requires at least three FFTs, so we are looking at
a lower bound of 680,000 operations.
Assuming your server or workstation can handle 3 billion operations
per second, *and* that we can use all these operations, the time delay
estimation would require something in the order of 229
microseconds.
That could easily prove too expensive if we want to read just 1% of
the ITCH-5.0 market feed.

None of these figures are to be taken as extremely accurate
predictions of performance.  They just illustrate that the problem is
not trivial and will require significant complexity to manage the
computations efficiently.

## What is Next?

We need to implement four different programs or components:
(1) we need a way to compute the inside for the ITCH-5.0 feed
([issue #8](https://github.com/coryan/jaybeams/issues/8)),
(2) we need a way to compute per-symbol throughput statistics of just
the inside changes
([issue #9](https://github.com/coryan/jaybeams/issues/8)),
(3) we need to prototype the time delay estimation based on
cross-correlations and using the GPU
and (4) we need to prototype the time delay estimation based on
([issue #10](https://github.com/coryan/jaybeams/issues/10)),
cross-correlations and the FFTW library
([issue #7](https://github.com/coryan/jaybeams/issues/7)).

I have decided to start with the last one, because I have been doing
too much market data processing lately and too much posting latety.



