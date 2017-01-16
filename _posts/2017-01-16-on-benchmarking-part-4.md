---
layout: post
title: On Benchmarking, Part 4
date: 2017-01-16 01:00
draft: true
---

{% assign ghsha = "f3a3907485c6834272c5c6e0369510cfd71c5d90" %}
{% capture ghver %}https://github.com/coryan/jaybeams/blob/{{ghsha}}{% endcapture %}

> This is a long series of posts where I try to teach myself how to
> run rigorous, reproducible microbenchmarks on Linux.  You may
> want to start from the [first one](/2017/01/04/on-benchmarking-part-1/)
> and learn with me as I go along.
> I am certain to make mistakes, please write be back in
> [this bug](https://github.com/coryan/coryan.github.io/issues/1) when
> I do.

In my [previous post]({{page.previous.url}}) I started to frame the
task of evaluating the difference between two bechmark results as a
statistical hypothesis testing problem.
I defined the minimum effect that would of interest, operationalized
the notion of "performance", and defined the population of interest
for the example we are using.

As I wrote down the population and problem statement it became
apparent that I had designed the benchmark improperly.
In this post we review an improved version of the benchmark, and do
some exploratory data analysis to prepare for our formal data capture.

## The New Benchmark

Modifying the benchmark created a bit of programming fun.
The code uses static polymorphism to represent buy vs. sell sides of
the book, and I wanted to randomly select one vs. the other.
With a [bit]({{ghver}}/jb/itch5/bm_order_book.cpp#L121) of 
[type erasure](https://en.wikipedia.org/wiki/Type_erasure) the task is
completed.

I also needed to modify the input data on each iteration,
that was easy to do, I just added `iteration_setup()` and
`iteration_teardown()` member functions to the benchmarking fixture.
With a little extra programming
[fun]({{ghver}}/jb/testing/microbenchmark.hpp#L37)
I modified the
microbenchmark framework to only call those functions if they are
present.

### Biases in the Data Collection

I paid more attention to the
[seeding]({{ghver}}/jb/itch5/bm_order_book.cpp#L488)
of my PRNG, because I do not want to introduce biases in the
sampling.
While this is a obvious improvement I think the benchmark is exposed
to other forms of bias which will be harder to measure or account for.
In particular, it is possible that the process used to generate
input data suffers from **exclusion**,
that is, I cannot guarantee that every possible input is reachable
through this procedure.

Nevertheless, the procedure exposes the code to more inputs than those
we could obtain through saved traces or manually crafted ones.

## Exploratory Analysis

To prepare for the formal analysis of our results we first collect a
modest number of samples to establish what model we can use, how many
samples will be needed, and to validate that the R code we write will
actually be able to complete the operations.

I used the microbenchmark to take $$20,000$$ samples for each of the
implementations (`map_based_order_book` and `array_based_order_book`).
The number of samples is somewhat arbitrary, but we will validate in a
second if it is high enough.
The first thing I want to look at is the distribution of the data,
just to get a sense of how it is shaped:

![Distribution of the Exploratory
Samples](/public/{{page.id}}/explore.density.svg
"Empirical Density Functions for the Exploratory Data")

The first observation is that the data does not look like any of the
distributions I am familiar with.
For reference, compare the curves against the graphs for a
[normal distribution](https://en.wikipedia.org/wiki/Normal_distribution),
or a
[log normal](https://en.wikipedia.org/wiki/Log-normal_distribution),
or a [exponential](https://en.wikipedia.org/wiki/Exponential_distribution).
None of them seem like good matches,
we can verify using these handy (but not very pretty) plots:

![Cullen and Frey graph for both map-based order book
 data](/public/{{page.id}}/explore.map.descdist.svg
 "Empirical Kurtosis and Skew vs. Best fit Values for Map-Based Order
 Book.")

![Cullen and Frey graph for both map-based order book
 data](/public/{{page.id}}/explore.array.descdist.svg
 "Empirical Kurtosis and Skew vs. Best fit Values for Array-Based
 Order Book.")

What these graphs are showing is how closely would the empirical
[skewness](https://en.wikipedia.org/wiki/Skewness)
and [kurtosis](https://en.wikipedia.org/wiki/Kurtosis)
would match a best-fit of the most
commonly used distributions for the data.
None of them are good matches,
if youare unconvinced, check the [Goodness of
Fit](#appendix-goodnes-of-fit) appendix for some math showing this.

All this means is that we need to dig deeper into the statistics
toolbox, and use
[*nonparametric*](https://en.wikipedia.org/wiki/Nonparametric_statistics)
(or if you prefer *distribution free*) methods.
The disadvantage of nonparametric methods is that they often require
more computation,
but computation is nearly free these days.
Their advantage is that one can operate with minimal assumptions about
the underlying distribution.
Yay!  I guess?

## Power Analysis

I would like now to determine how many samples I need to collect to
reliably detect the desired effect,
as the reader may recall, "effect" is the fancy statistics word for
"performance is actually better".

If our data followed the normal distribution this would be a nice
exercise in computation: you are going to use the
[Student's t-test](https://en.wikipedia.org/wiki/Student's_t-test)
and there are
good functions in any statistical package for power analysis of the
t-test.
Alas!  We already pointed out that we will need to use some kind of
nonparametric test, and the t-test is about as parametric as they
come.
There are good news, the canonical nonparametric test for hypothesis
testing is the
[Mann-Whitney U Test](https://en.wikipedia.org/wiki/Mann%E2%80%93Whitney_U_test).
There are results [[1]](http://www.jerrydallal.com/LHSP/npar.htm)
showing that this test is only 15% less powerful than the t-test.
So all we need to do is run the analysis for the t-test and add 15%
more samples.

Good news then.  The t-test power analysis requires just a few inputs:

**Significance Level:** this is conventionally set to 0.05, it is a
  measure of "how often do we want to claim success and be wrong".
  I am going to set it to 0.01, because why not?  The conventional
  value was adopted in fields where getting samples was expensive, in
  benchmarking data is cheap (more or less).

**Power:** this is conventionally set to 0.8, it is a measure of "how
  often do we want to dismiss the effect for lack of evidence, when
  the effect is real".  I am going to set it to 0.95, because why not?
  
**Effect:** what is the minimum effect we want to measure, we decided
    that already, one cycle per member function call.
    In this case we are using a 3.0Ghz computer, so the cycle is
    1us/3000, and we are running tests with 20,000 function calls, so
    any effect larger than 6.6us is interesting.

**Standard Deviation:** this is what you think, an estimate of the
  *population* standard deviation.

Of these, the standard deviation is the only one I need to get from
the data.
I can use the sample standard deviation:

| Book Type | StdDev (Sample) |
| --------- | ---------------:|
|     array |        862 |
|       map |       1172 |

And I can use that as an estimate of the population standard
deviation, right?
In principle yes, the sample standard deviation converges to the
population standard deviation.  But how big is the error?

In the [Estimating Standard
Deviation](#appendix-estimate-standard-deviation) appendix we use
bootstrapping to compute confidence intervals for the standard
deviation.
Because the sample size gets higher with larger standard deviations we
use the upper values for the confidence intervals, yielding:

| Book Type | StdDev Estimate |
| --------- | ---------------:|
|     array |   873           |
|       map |  1185           |

### A Note about Equal Variance

Some of the readers may have notice that the data does not have equal
variance, or in the language of statistics it is not *homosketasdic*
(if you prefer, it is *hetero*skedastic).
Other than being great words to use at parties, what does it mean or
matter?
Many statistical methods, for example linear regression, assume that
the variance is constant, and "Bad Things"[tm] happen to you if you
try to use these methods with data that does not meet that assumption.
One advantage of using non-parametric methods is that they do not care
about the homoskedasticiy of your data.

Why is that data this way?  My intuition is: despite all our efforts,
the operating system still introduced variability in your time
measurements.
For example, interrupts steal cycles from your microbenchmark to
perform background tasks in the system.
The impact of these measurement artifacts is larger (in absolute
terms) the longer your benchmark iteration runs.
That is, if your benchmark takes a few microseconds to run each
iteration it is unlikely that any iteration suffers more than 1 or 2
interrupts.
In contrast, if your bench takes a few seconds to run each iteration
you are probably going to see the full gamut of interrupts in the
system.

## Power Analysis

I have finally finished all the preliminaries and can do some power
analysis to determine how many samples will be necessary.
I ran the analysis using some simple R script:

{% highlight r %}
## These constants are valid for my environment,
## change as needed / wanted ...
clock.ghz <- 3
test.iterations <- 20000
## ... this is the minimum effect size that we
## are interested in, anything larger is great,
## smaller is too small to care ...
min.delta <- 1.0 / (clock.ghz * 1000.0) * test.iterations
min.delta

## ... these constants are based on the
## discussion in the post ...
desired.delta <- min.delta
desired.significance <- 0.01
desired.power <- 0.95
nonparametric.extra.cost <- 1.15

## ... the power object has several
## interesting bits, so store it ...
required.power <- power.t.test(
    delta=desired.delta, sd=estimated.sd,
    sig.level=desired.significance, power=desired.power)

## ... I like multiples of 1000 because
## they are easier to type and say ...
required.nsamples <-
    1000 * ceiling(nonparametric.extra.cost *
                   required.power$n / 1000)
required.nsamples
{% endhighlight %}

{% highlight rout %}
[1] 1295000
{% endhighlight %}

Ouch, that is a whopping number of iterations to run.
What is happening here?
The effect I want to measure is extremely small (6.6us), while the
standard deviation is almost $$200$$ times larger.

It is possible to perform such an analysis, but really overkill in
this case.
I am willing to accept any effect of 6.6us as real, that means that
any effect of 50us is also acceptable to me,
and we have reason to believe the effect might be larger than that.
The risk here is that I might reject some performance improvements for
lack of evidence, but if that is the case I can run the test with a
larger sample.
So changing the parameters a bit I get:

{% highlight r %}
## ... re-run power analysis ...
required.power <- power.t.test(
    delta=desired.delta, sd=estimated.sd,
    sig.level=desired.significance, power=desired.power)
required.nsamples <-
    1000 * ceiling(nonparametric.extra.cost *
                   required.power$n / 1000)
required.nsamples
{% endhighlight %}

{% highlight rout %}
[1] 24000
{% endhighlight %}

### A Note about Testing with a Single Input

If the execution time did not depend on the nature of the input,
for example if the algorithm or data structure I was measuring was
something like "add all the numbers in this vector", then our standard
deviations would only depend on the system configuration.

We have seen that the results can be far more deterministic.
We did not compute the standard deviation in the
[relevant post](/2017/01/08/on-benchmarking-part2/), but you can load
the data from that post and compute it yourself, it is just $$56.3$$
microseconds.

## Future Work

There are some results [[1]](http://www.pcg-random.org/) that indicate
the Mersenne-Twister generator does not pass all statistical tests for
randomness.
We should modify the microbenchmark framework to use better RNG, such
as [PCG](http://www.pcg-random.org/) and/or
[Random123](https://github.com/DEShawResearch/Random123-Boost).

I have made no attempts to test the statistical properties of the
Mersenne-Twister generator as initialized from my code.
This seems redundant, the previous results show that it will fail some
tests, but it is the best family from those available in C++11.

## Appendix Goodness of Fit

Though the Cullen and Frey graphs shown above are appealing,
I wanted a more quantitative approach to decide if the distributions
were good fits or not.
We reproduce here the analysis for the two distributions that are
harder to discount just based on the Culley and Frey graphs.

### LogNormal for the Array Based case

The
[lognormal distribution](https://en.wikipedia.org/wiki/Log-normal_distribution)
is a distribution of a random variable
whose logarithm is normally distributed.
The density functions in the Wikipedia article show that it can fit a
number of right skewed shapes, which is not too part from what we
observe in the case of the array based order book.

The procedure to test the fit is relatively straightforward, first
find the fit for the lognormal distribution using the existing data:

{% highlight r %}
a.data <- subset(data, book_type == 'array')
a.fit <- fitdist(a.data$microseconds, distr="lnorm")
plot(a.fit)
{% endhighlight %}

![](/public/{{page.id}}/array.fit.lognormal.svg
"Samples of Array Based Order Book Fitted Against Lognormal Distribution.")

Then you run the Kolmogorov-Smirnov test with the null being that the
sample was extracted from a distribution:

{% highlight r %}
a.ks <- ks.test(x=a.data$microseconds, y="plnorm", a.fit$estimate)
a.ks
{% endhighlight %}

{% highlight rout %}
	One-sample Kolmogorov-Smirnov test

data:  a.data$microseconds
D = 0.99995, p-value < 2.2e-16
alternative hypothesis: two-sided
{% endhighlight %}

We did not establish a significance level, but it does not matter, we
can reject the null hypothesis (that the sample was drawn from the
given distribution) at the $$0.1%$$ level (or even more strict).
The Q-Q plot in the graph also shows that the tail of the
distributions is substantially different.

### What about the Beta Distribution?

The
[beta distribution](https://en.wikipedia.org/wiki/Beta_distribution)
would be a strange choice for this data,
it only makes sense on the $$[0,1]$$ interval, and our data has a
different domain.
We could, of course, scale down the data:

{% highlight r %}
m.data <- subset(data, book_type == 'map')
m.data$seconds <- m.data$microseconds / 1000000
a.data$seconds <- a.data$microseconds / 1000000
{% endhighlight %}

{% highlight r %}
m.beta.fit <- fitdist(
    m.data$seconds, distr="beta", start=beta.start(m.data$seconds))
plot(m.beta.fit)
{% endhighlight %}

![](/public/{{page.id}}/map.fit.beta.svg
"Samples of Map Based Order Book Fitted Against Beta Distribution.")

The graph clearly shows that this is a poor fit, and the KS-test
confirms it:

{% highlight r %}
m.beta.ks <- ks.test(x=m.data$seconds, y="beta", m.beta.fit$estimate)
m.beta.ks
{% endhighlight %}

{% highlight rout %}
	One-sample Kolmogorov-Smirnov test

data:  m.data$seconds
D = 965.77, p-value < 2.2e-16
alternative hypothesis: two-sided
{% endhighlight %}

The results for the array-based samples is similar:

![](/public/{{page.id}}/array.fit.beta.svg
"Samples of Array Based Order Book Fitted Against Beta Distribution.")

Instead of searching for more and more exotic distributions to test
against I decided to go the distribution-free route.

## Appendix Estimate Standard Deviation

[Bootstrapping](https://en.wikipedia.org/wiki/Bootstrapping_(statistics))
is the practice of estimating properties of an estimator (in our case
the standard deviation) by resampling the data.

[R](https://www.r-project.org/) provides a package for bootstrapping,
we simply take advantage of it to produce the estimates.
We reproduce here the bootstrap histograms, and
[Q-Q plots](https://en.wikipedia.org/wiki/Q%E2%80%93Q_plot),
they show the standard deviation estimator largely follow
a normal distribution, and one can use the more economical procedures
to estimate the confidence interval:

| Book Type | Normal Method | Basic Method | Percentile Method |
| --------- | ------------- | ------------ | ----------------- |
| Map       | (1159, 1185)  |  (1160, 1185)|   (1159, 1184) |
| Array     | (851, 873)  |  (851, 873)|   (851, 873) |

Therefore we use **1185** as our estimate of the standard deviation.

![](/public/{{page.id}}/bootstrap.map.sd.svg
 "Bootstrap Histogram and Q-Q Plot for Standard Deviation Estimator
  for Map-Based Order Book.")

![](/public/{{page.id}}/bootstrap.map.sd.svg
 "Bootstrap Histogram and Q-Q Plot for Standard Deviation Estimator
  for Array-Based Order Book.")


## Notes

The data for this post was generated using the
[driver script]({{ghver}}/jb/itch5/bm_order_book_generate.sh)
for the order book benchmark.
With the [{{ghsha}}]({{ghver}}) version of JayBeams.
The [script](public{{page.id}}/generate-graphs.R) used to generate
the graphs is found in the same web site as this post, as well as the
[data](public{{page.id}}/data.csv) used here.
Metadata about the tests, including platform details can be found in
comments embedded with the data file.
The highlights of that metadata is reproduced here:

* CPU: AMD A8-3870 CPU @ 3.0Ghz
* Memory: 16GiB DDR3 @ 1333 Mhz, 0.8ns in 4 DIMMs.
* Operating System: Fedora 23, 4.8.13-100.fc23.x86_64
* C Library: glibc 2.22
* C++ Library: libstdc++-5.3.1-6.fc23.x86_64
* Compiler: gcc 5.3.1 20160406
* Compiler Options: -O3 -ffast-math -Wall -Wno-deprecated-declarations

