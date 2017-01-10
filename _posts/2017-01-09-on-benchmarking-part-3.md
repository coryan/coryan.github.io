---
layout: post
title: On Benchmarking, Part 3
date: 2017-01-09 01:00
draft: true
---

<div style="text-align: right">
In God we trust; all others must bring data.<br>
- W. Edwards Deming<br><br>
</div>

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

## Falsehoods Programmers Believe About Benchmarking and Statistics

1. You do you need a benchmark, you can tell whether it is faster.
1. Okay, it might not be obvious, but a code review will catch any
   problems
1. Just use a faster algorithm, if your $$O(...)$$ bound is better
   then you are fine.
1. If you must run a test don't worry, no statistics are needed,
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

### A Word about Averages

Of all the falsehoods programmers believe about statistics the blind
belief in [average](https://en.wikipedia.org/wiki/Average)
as a good statistic to represent the sample (or
estimate the distribution) is probably the most pernicious, and
deserve some attention.

There are at least two problems with the
[sample mean](https://en.wikipedia.org/wiki/Mean)
for benchmarking systems.
First, is not robust to outliers, with a
[breakdown point](https://en.wikipedia.org/wiki/Robust_statistics#Breakdown_point)
of 0%.
In other words, it is about as not robust as it can possibly be.
Consider the following empirical distribution for one of the measurements in the previous post:

![Empirical Distribution Density for a Microbenchmark.
High peak at around 5,000, another peak at around 15,000, tail goes to
60,000.
](/public/2017-01-09-on-benchmarking-part-3/empirical-density-uncontrolled.svg
 "Empirical Distribution of Microbenchmark Results when System
 Configuration is not Controlled.")

With such a distribution it is not unreasonable to expect outliers in
the data.  There is an order of magnitude difference between the
minimum and maximum in this case.

The second problem is a more subtle one.  When presented with these
facts many engineers recall other alternatives to the arithmetic mean:
the median, the geometric, harmonic, or truncated means, etc.  Some of
which are indeed more robust than the mean.
What they often forget is that all those statistics are measures of
[central tendency](https://en.wikipedia.org/wiki/Central_tendency),
the notion that the distribution has a central or typical value that
all other values "cluster around".

Sadly, the distributions that we observe in practice for performance
measurements do not seem to exhibit such values, the same distribution
above serves as an example, but other examples can be readily found,
see [[1]](http://www.slideshare.net/brendangregg/velocity-stoptheguessing2013).

Engineers need to select statistics that are appropriate for the
distribution of the data they have.

### Another Word: about the Number of Samples

Picking the correct number of samples to take is not difficult,
even without making any assumptions about the underlying distribution
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

Notice that selecting very large number of iterations has a cost: the
benchmarks take longer to run, the development cycles get longer,
productivity suffers.
So as engineers we want to make our benchmarks powerful enough to draw
valid conclusions without often being wrong, but also efficient.

## Hypothesis Testing Setup

Hopefully the reader now agrees that the results obtained through
benchmarking, unless they dramatically change the performance of the
system, should be reviewed with at least a modicum of rigor.

We now continue with our example, a software engineer proposes a
change to `array_based_order_book_side<>`.
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

Yes.

Okay, we need to say more words.

Engineers love to say that they make data-driven decisions, so they
should find this approach compelling, though maybe daunting.
Having the necessary data also short-circuits fruitless debate.
But more importantly, writing down exactly what we mean by "better
performance", or when we think this applies can change the discussion
from "I do not like this change" to "I think this assumption is not
well justified".

### What do we do if have no data?

This is a difficult question, and one that is important to answer
because it frames the hypothesis testing procedure.
Implicitly, this question is asking "What will you do if the data is
inconclusive"?  And also: "If you answer 'proceed anyway'", then why
should we work hard to collect valid statistics?  Why waste the
effort?  We think the answer should be:

Changes that make the code more readable or easier to understand are
accepted, unless there is compelling evidence that they decrease
performance.
On the other hand, changes that bring no benefits in readability, or
that actually make the code more complex or difficult to understand
are rejected unless there is compelling evidence that they improve
performance.

That balances other engineering constraints, such as readability, with
the performance considerations.

### How do we define "better performance"?

Effectively our design of the microbenchmark is an implicit answer to
the question, but we state it explicitly:

> We define the performance of an instantiation of
> `array_based_order_book_side<T>` on a 
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
But what is the group of persons we are going to measure this over?
All humans?  All adult males?

In our context: what is the population of sequences over which we
measure the execution time?  Under what values of the template
parameter `T` are we going to measure performance?  And under what
system configurations.

We could propose to use all possible runs and any system conditions,
while there would be difficulty in sampling this population,
we reject it because it is not realistic.

First, we recall our
[measurements](https://github.com/coryan/jaybeams/issues/30)
of event depth, the main result of which is that the number of price
levels between the inside and operation changing the book has these
sample percentiles:

| NSamples | min | p25 | p50 | p75 | p90 | p99 | p99.9 | max |
| --------:| ---:| ---:| ---:| ---:| ---:| ---:| -----:| ---:|
| 489064030 | 0 | 0 | 1 | 6 | 14 | 203 | 2135 | 20009799 |

In fact, we designed `array_based_order_book_side<>` to take advantage
of this type of distribution.
We have already said (implicitly) that we believe any future measure
of event depth will be similar.
If we did not believe that we would not have written the code in the
first place.
Naturally we do not expect every day to be identical, so we define the
possible population of inputs $$I$$ as any sequence S
that whose percentiles are no more than 10% away from the previous
table.  That is, a sequence S with a p90 outside the range
$$[0.9 \times 203, 1.1 \times 203]$$ would not be considered valid.

Second, what template parameter `T` should we use in our inputs?
This is pretty obvious, but we should use both buy and sell sides of
the book in our tests, and we expect that about 1/2 of the sequences
are executed against the buy side, and the other half against the sell
side.

And finally, we expect `array_based_order_book_side<>` to be used as
part of a system that runs on dedicated servers, or at
least servers with enough dedicated resources to the application that
it is effectively isolated from the rest.
Likewise, since the server is dedicated to this application and its
performance is often critical to the business, we expect
the system administrator to configure the system to maximize the
predictability of the system operation.

Therefore we think the following is a more realistic statement about
the population of measurements:

> The population under consideration is runs of our benchmark with a
> sequence of operations S from the collection $$I$$ defined earlier.
> 50% of these runs are for buy order books, 50% are for sell order
> books.
> And the program always executes in the real-time scheduling class,
> at the maximum available priority, with no other sources of load in
> the server, with the `performance` CPU frequency scaling governor,
> and with no CPU reserved for non-real-time scheduling tasks.

Notice that this means the population includes sequences of all
different lengths.

At this point we realize we have made a mistake in the design of our
benchmarks.
The stream of operations selected for the test is initialized with
either a seed from `/dev/urandom`, or with a user-provided
configuration parameter.

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
