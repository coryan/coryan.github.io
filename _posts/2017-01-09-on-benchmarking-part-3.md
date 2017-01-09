---
layout: post
title: On Benchmarking, Part 3
date: 2017-01-09 01:00
---

> This is an post in a long series, you may want to start from the
> [first article](/2017/01/04/on-benchmarking-part-1/) and read them
> in sequence.

In our [previous post]({{page.previous.url}}) we discussed the
JayBeams microbenchmark framework and how to configure a system to
produce consistent results when benchmarking a CPU-bound component
like `array_based_order_book_side<>`.

In this post we consider how to approach the problem of making sound
decisions about whether changes to a software component have actually
improved performance or not.
We will use `array_based_order_book_side<>` as an example, but the
lessons translate well to any other benchmark.

## Before the Statistics

Why do we need a formal statistical approach to make these decisions?
What is the point?
Isn't it obvious when the code is faster?
Just examine it and have it reviewed by a few experts, they can tell
you.
Or even if it is not obvious: computers are deterministic, right?
Just run the performance test once, if it is better than before then
your new version is better and you accept it.
Or even if the computer is not fully deterministic because the
operating system or whatever, just run the test 10 times, average the
results and if the average is better then we can accept the results.

The previous paragraph lists some of the common misconceptions that
software engineers have about performance testing.
In fact, I am certain I have a few of my own that I have not
discovered yet.  Let's examine these questions in turn debunk the
myths surrounding them.

### Performance is not Obvious

While there are conditions under which rigorous testing is not
necessary, humans are terrible at predicting the impact of changes in
complex systems.
Even the most pessimistic of engineers will take very little
convincing to accept a change that replaces a $O(N^2)$ algorithm
with a $O(N\ln(N))$ algorithmd.
On the other hand,  even the most optimistic of engineers will write a
simple test to verify that no mistake was introduced which incorrectly 
applies or implements the more efficient algorithm and renders it even
less efficient.

We are not advocating that rigorous testing is necessary for all
changes, only that in many conditions it is the the only way to avoid
errors or endless debate.

However, the rigor required to apply statistics to our problem is
still useful.
For example, we will need to answer the following questions
before we can apply any kind of statistical test:

* What exactly do we mean by "better performance"?
* How exactly is this "performance" to be measured?
* Is that a meaningful measurement to the application or business
  being supported by this system?
* Is the change we measured important enough for the application or is
  the effect so small as to not matter?
* Under what conditions does the improvement work? Are there
  restrictions on the possible inputs?  Are those 
  restrictions acceptable for the application?

The reader hopefully agrees that those questions are important to
answer regardless of the need for statistical rigor.
Furthermore, the previous objections are not consistent with what we
have already learned about microbenchmarks in practice, as we
discuss below.

### Your Computer may not be Deterministic Enough

As we discussed in the [previous]({{page.previous.url}}) post,
obtaining consistent measurements of performance, even for a simple
component is very difficult.

In the extreme case, without controlling the process and system
configuration one may obtain a distribution like the ones shown in the
next figure:

![Empirical Distribution Density for a Microbenchmark.
High peak at around 5,000, another peak at around 15,000, tail goes to
60,000.
](/public/2017-01-09-on-benchmarking-part-3/empirical-density-uncontrolled.svg
 "Empirical Distribution of Microbenchmark Results when System
 Configuration is not Controlled.")

Contrast with the results when the environment is controlled effectively:

![Empirical Distribution Density for a Microbenchmark.
High peak at around 5,000, with the tail going to around 7,000.
](/public/2017-01-09-on-benchmarking-part-3/empirical-density-controlled.svg
 "Empirical Distribution of Microbenchmark Results when System
 Configuration is Controlled.")

The results are far more consistent, with the interquartile range (IQR)
improving from 899 to 28 microseconds (a factor of 30), and the
maximum decreasing by a factor of 8:

| Environment | Min | p25 | Median | Mean | p75 | Max |
| ----------- | ----:| ---:| ------:| ----:| ---:| ---:|
| Not Controlled | 4798 | 5453 | 5889 | 8368 | 6528 | 59550 |
| Controlled | 5255 | 5302 | 5316 | 5325 | 5330 | 6876 |

Whether the reader wants to attribute the variation in the more
controlled environment to inherent measurement errors, or to
the need to control the execution environment even further is a matter
for further research.
In either case, the results of measuring the same test function
multiple times should not be expected to be identical.
Modern computer systems are simply too complex to be modeled as a
completely deterministic system when it comes to performance
measurements.

Having said this, clear algorithmic improvements often change the
results so dramatically that no further analysis is required.
The reader probably has examples of changes that resulted in code
executing many times faster than before.
Unfortunately not all improvements are so clear.
As an thought experiment, consider a system whose performance results
vary by 1,500 microseconds (such as ours), and an improvement that
changes the median by approximately 100 microseconds.
How can we decide if that result should be attributed to luck,
or to actual changes in the performance.
After all 100 microseconds is well within the range we have already
observed.

Many engineers will argue that it is unlikely that we get that lucky
over "enough" runs, maybe once, maybe twice, but 10 times in a row?
100 times in a row?  That can only be explained by the brilliance of
their code improvements.
That only begs the question.
We are assuming that 100 or 1,000 runs is enough to eliminate "luck"
as a factor, what evidence do we have to draw that conclusion?

Even if 1,000 feels extremely unlikely, do we really need to run 1,000
tests?  There is a cost to waiting for that many tests to complete,
maybe we can finish much faster, and increase developer productivity,
if we only needed 200 tests, or 150 of them.

### The Average is not Always the Right Measure

Often engineers will recommend using the
[average](https://en.wikipedia.org/wiki/Average),
of the data to compensate for the observed variation in the results.
They ignore (or do not recall), that the
[sample mean](https://en.wikipedia.org/wiki/Mean) is not robust to
outliers, with a
[breakdown point](https://en.wikipedia.org/wiki/Robust_statistics#Breakdown_point)
of 0%.
But as shown already, it is not unreasonable to expect outliers in our
benchmarks.  The data often varies by as much as an order of magnitude.

When presented with these facts many engineers recall other
alternatives to the arithmetic mean: the median, the geometric,
harmonic, or truncated means, etc.
What they often forget is that all those statistics are measures of
[central tendency](https://en.wikipedia.org/wiki/Central_tendency),
the notion that the distribution has a central or typical value that
all other values "cluster around".

Sadly, the distributions that we observe in practice for performance
measurements do not seem to exhibit such values, in addition to the
examples we have shown, we refer the reader to
[[1]](http://www.slideshare.net/brendangregg/velocity-stoptheguessing2013).

Therefore, we need to decide study the distribution of our data before
deciding what statistics make sense to report.

### Principled Approaches to Picking the Number of Samples

As we already discussed, selecting the right number of samples should
not be done arbitrarily.
Fortunately, there are well established techniques to compute the
correct number of samples to capture.

Even without making any assumptions about the underlying distribution
we can compute the
[statistical power](https://en.wikipedia.org/wiki/Statistical_power) 
of our tests, and recommend a number of iterations that achieves the
desired power.

This is a simple computation assuming we have already made high level
decisions about how often we are willing to be wrong: both how often
we reject a code modification that actually improves (or more
generally changes) the 
performance of the system.
As well as how often we fail to reject code changes that actually made
no difference to the performance of the system.

The rate of the first type of problem (called a type I error in
statistics) is called the significance level, and it is conventionally
set to 5%.
The rate of the second type of problem (called a type II error in
statistics) is called the power of the test, and is conventionally set
to 80%.
There are no reasons for 5% and 80% other than convention, and we do
not see any reason to follow this conventions if it does not make
sense for the needs of the software system in question.

## Hypothesis Testing

Hopefully the reader now agrees that the results obtained through
benchmarking, unless they dramatically change the performance of the
system, make it necessary to apply at least a
modicum of rigor when we decide if a software change really improves
the performance of a system.

Continuing with our example, a software engineer proposes a change to
`array_based_order_book_side<>`.
They claim that the changes "improve performance" or simply "make the
class faster".
Either our software engineer is very disciplined and doubts their own
claims or maybe another team member (a peer, a supervisor) doubts the
claims of improved performance.
We would like an objective procedure to evaluate the claims of the
change author, and make a decision as to whether we want to accept the
change or not.

The reader will recognize this as a classical problem in
[statistical hypothesis testing](https://en.wikipedia.org/wiki/Statistical_hypothesis_testing).
The reader may also recall that before jumping into an rote execution
of a statistical test procedure we should clearly specify how we model
our system, what population we are sampling from, what is the accepted
level of error, and what assumptions are we making about our data, our
distributions, etc.

### What do we need to Decide? And Why?

In our case, the decision that requires statistical hypothesis testing
is whether the code change should be accepted into the system or not.
We need to make these decisions correctly because high
performance is one of the desired characteristics of our system, of
which the component being changed is a critical piece.
If we make this decision incorrectly our system will grow increasingly
slower over time, maybe requiring more computational resources than
needed, or maybe reaching a point where the system is too slow to be
useful.

### Is a Data Driven Approach to Decision Making Necessary?

As we have established, yes.  We cannot rely in our intuition or in a
simple pass/fail performance test to make the decision.  There are too
many source of variation for the latter, and too much complexity for
the former.
We also find data-driven approaches are compelling for most software
engineers, and short-circuit difficult or fruitless debate.

### What do we do if have no data?

This is a difficult question, and one that is important to answer
because it frames the hypothesis testing procedure.
Implicitly, this question is asking "What will you do if the data is
inconclusive"?  And also: "If you answer 'proceed anyway'", then why
should we work hard to collect valid statistics?

The answer we propose is:
changes that make the code more readable or easier to understand are
accepted, unless there is compelling evidence that they decrease
performance.
On the other hand, changes that bring no benefits in readability, or
that actually make the code more complex or difficult to understand
are rejected unless there is compelling evidence that they improve
performance.

### How do we define "better performance"?

Effectively our design of the microbenchmark is an implicit answer to
the question, but we state it explicitly:

> We define the performance of `array_based_order_book_side<>` on a
> given stream of operations S as the total time required to
> initialize an instance of the class and process all the operations
> in S.

Notice that this is not the only way to operationalize performance.
An alternative might read:

> We define the performance of `array_based_order_book_side<>` on a
> given stream of operations S as the 0.999 quantile of the time taken
> by the component to execute each one the operations in S.

We prefer the former definition (for the moment) because it neatly
avoids the problem of trying to measure events that take only a few
cycles to execute.

### The Population

Essentially we have defined the variable that we are going to measure,
analogous to deciding exactly how are are going to measure the weight
of a person.
We have not described over what population we are going
to measure this variable.
What is the population of runs over which we measure the execution
time?  What inputs are considered for our analysis?  Do we consider
inputs of different lengths?

We could propose to use all possible runs any system conditions,
there would be difficulty in sampling this population,
but it would be the most applicable population if the program was
expected to run under the regular scheduling class on shared servers
used by many applications.
We do not think such configuration is realistic, though
it makes the least number of assumptions.  We expect that software
systems like an order book to operate on dedicated servers, or at
least servers with enough dedicated resources in the server for the
book to be isolated from other applications.
Likewise, since the server is dedicated to this application and its
performance is so critical to the overall application, we expect
the system administrator to configure the system to maximize the
predictability of the system operation.
Therefore we think the following is a more realistic statement about
the population of measurements:

Therefore we limit the environmental conditions,
we assume the program running this application will be running in the
real-time scheduling class.
We assume the server to use the `performance` CPU frequency
scaling governor.
We assume no other significant sources of load in the system.
We assume the server will be configured without reservations for the
non-real-time tasks, i.e., all of the CPU can be used for real-time
tasks.

However, the environmental conditions are not the only thing that will
affect the performance of the class.
Obviously the longer the sequence of operations that we measure the
class against, the longer it will take to execute.
But also the statistical properties of the inputs will affect the
performance.
As we discussed in the
[first article](/2017/01/04/on-benchmarking-part-1) of the series the
`array_based_order_book_side<>` template class is designed to take
advantage of the typical characteristics of the input.
It would be unreasonable to test the performance of this class against
inputs that will never (or hardly ever) appear in a production
environment.
We would expect the class to function *correctly* with such an input,
we just do no expect it to be particularly fast if the input is
designed to hit the worst case each time.

We recall our
[measurements](https://github.com/coryan/jaybeams/issues/30)
of event depth, the main result of which is that the number of price
levels between the inside and operation changing the book has these
sample percentiles:

| NSamples | min | p25 | p50 | p75 | p90 | p99 | p99.9 | max |
| --------:| ---:| ---:| ---:| ---:| ---:| ---:| -----:| ---:|
| 489064030 | 0 | 0 | 1 | 6 | 14 | 203 | 2135 | 20009799 |

Then we define the possible population of inputs $$I$$ as any sequence S
that whose percentiles are no more than 10% away from the previous
table.  That is, a sequence S with a p90 outside the range
$$[0.9 \times 203, 1.1 \times 203]$$ would not be considered valid.

To be explicit then we define our population as:

> The population under consideration is runs of our benchmark with a
> sequence of operations S from the collection $$I$$.
> As long as
> the program is executing in the real-time scheduling class, at the
> maximum available priority, with no other sources of load, with the
> `performance` CPU frequency scaling governor, and with no CPU
> reserved for non-real-time scheduling tasks.

Notice that this means the population includes sequences of all
different lengths, and 

### Minimum Size of the Effect

An often neglected topic is whether the measured effect was relevant
to the application, for a full treatment see
[[2]](http://www.deirdremccloskey.com/docs/jsm.pdf).
It is of no interest to us if we measure a statistically significant
improvement in performance, but the measurement is lower than say the
theoretical minimum time to execute a single instruction.
Such a result would clearly be nonsense, and whether statistically
significant or not is no matter.

For the purposes of our analysis, we decide that the effect must be at
least a single cycle in the execution of a `add_order` or
`remove_order` operation.
Let's call $$cycle_{period}$$ the duration of the cycle in seconds.
Because the operations we measure have N operati
Because we execute N operations in our
measurements (with N to be determined later as we set the minimum
power), the minimum effect becomes $$ N * cycle_{period} $$.
