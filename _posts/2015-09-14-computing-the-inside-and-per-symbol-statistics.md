---
layout: post
title: Computing the Inside and Per Symbol Statistics
date: 2015-09-14 02:00
---

I have been silent for a while as I was having fun writing code.  I
finally implemented a simple (and hopelessly slow) book builder for
the ITCH-5.0 feed.  With it we can estimate the event rate for
changes to the inside, as opposed to all the changes in the book
that do not affect the best bid and offer.

This data is interesting as we try to design our library for time
delay estimation because it is the number of changes at the inside
that will (or may) trigger new delay computations.  We are also
interested in breaking down the statistics per symbol, because have
to perform time delay analysis for only a subset of the symbols in
the feed and it is trivial to parallelize the problem across
different symbols in different servers.

The code is already available on
[github.com](https://github.com/coryan/jaybeams)
the tool called `itch5inside`, clearly I lack imagination.
It outputs the
inside changes as an ASCII file (which can be compressed on the
fly), so we can use it later as a sample input into our analysis.
Optionally, it also outputs to stdout the per-symbol statistics.
I have made the statistics available
[on this very blog](/public/NASDAQ-ITCH.csv)
in case you want to analyze them.

In this post we will just make some observations about the expected
message rates.
First we load the data, you can set `public.dir` to
`https://coryan.github.io/public` and download the data directly from
the Internet, and then create a separate data set that does not
include the aggregate statistics.
{% highlight r %}
raw <- read.csv(paste0(public.dir, '/NASDAQ-ITCH.csv'))
symbols <- subset(raw, Name != '__aggregate__')
{% endhighlight %}

It is a more or less well-known fact that some symbols are much more
active than others, for example, if we plot a histogram of number of
events at the inside and number of symbols with that many messages
we get:
{% highlight r %}
require(ggplot2)
range <- range(symbols$NSamples)
bw <- (range[2] - range[1]) / 300
ggplot(data=symbols, aes(x=NSamples)) + geom_histogram(binwidth=bw) +
  theme(legend.position="bottom") +
  ylab("Number of Symbols") +
  xlab("Total Event Count")
{% endhighlight %}

![A histogram plot.  The X axis is labeled 'Total Event Count' and varies from 0 to almost 3,000,000.  The Y axis is labeled 'Number of Symbols' and varies from 0 to 5000.  The highest values are at the beginning, and the values drop in a seemingly exponential curve.](/public/nsamples.linear.svg "Symbol count per total message count.")

That graph appears exponential at first sight, but one can easily be
fooled, this is what goodness of fit tests where invented for:
{% highlight r %}
require(MASS)
fit <- fitdistr(symbols$NSamples, "geometric")
ref <- rgeom(length(symbols$NSamples), prob=fit$estimate)
control <- abs(rnorm(length(symbols$NSamples)))
chisq.test(symbols$NSamples, p = ref/sum(ref))
{% endhighlight %}

{% highlight rout %}

	Chi-squared test for given probabilities

data:  symbols$NSamples
X-squared = 6330400000, df = 8171, p-value < 2.2e-16

Warning message:
In chisq.test(symbols$NSamples, p = ref/sum(ref)) :
  Chi-squared approximation may be incorrect
{% endhighlight %}

That p-value is extremely low, we cannot reject the Null
Hypothesis, the `symbol$NSamples` values do not come from the
geometric distribution that best fits the data.
Also notice that your values might be different, in fact, they
should be different as the reference data was generated at random.
We can also visualize the distributions in log scale to make the
mismatch more apparent:
{% highlight r %}
df.ref <- data.frame(count=log(ref, 10))
df.ref$variable <- 'Reference'
df.actual <- data.frame(count=log(symbols$NSamples, 10))
df.actual$variable <- 'Actual'
df <- rbind(df.ref, df.actual)
ggplot(data=df, aes(x=count, fill=variable)) +
  geom_histogram(alpha=0.5) +
  scale_fill_brewer(palette="Set1") +
  theme(legend.position="bottom") +
  ylab("Number of Symbols") +
  xlab("Total Event Count")
{% endhighlight %}

![Two overlapping histograms. The X axis is labeled 'Total Event Count' and varies from 0 to 6.  The Y axis is labeled 'Number of Symbols' and varies from 0 to 2,000.  The histogram labeled 'Reference' has a much higher peak than the
histogram labeled 'Actual'.](/public/nsamples.log10.svg "Compare actual distribution against best 'Geometric' fit.")

Clearly not the same distribution, but using math to verify this
makes me feel better.
In any case, whether the distribution is geometric or not does not
matter much, clearly there is a small subset of the securities that
have much higher message rates than others.
We want to find out if any security has such high rates as to make
them unusable, or very challenging.

The `itch5inside` collects per-symbol message rates, actually it
collects message rates at different timescales (second, millisecond
and microsecond), as well as the distribution of processing times to
build the book, and the distribution of time in between messages 
(which I call "inter-arrival time", because I cannot think of a
cooler name).
Well, the tool does not exactly report the distributions, it reports
key quantiles, such as the minimum, the first quartile, and the 90th
percentile.
The actual quantiles vary per metric, but for our immediate purposes
maybe we can get the p99.9 of the event rate at the millisecond
timescale.
A brief apology for the p99.9 notation, we used this shorthand in a
previous job for "the 99.9-th percentile", and got used to it.

Let's plot the p99.9 events/msec rate against the total number of
messages per second:
{% highlight r %}
ggplot(data=raw, aes(x=NSamples, y=p999RatePerMSec)) +
  geom_point(alpha=0.5) +
  theme(legend.position="bottom") +
  ylab("Events/msec @ p99.9") +
  xlab("Total Event Count")
{% endhighlight %}

![A scatter plot.  The X axis is labeled 'Total Event Count' and varies from 0 to 200,000,000.  The Y axis is labeled 'Events/msec @ p99.9' and varies from 0 to 250.  All the points but one are clustered around the origin.](/public/all.rate.svg "Per millisecond message rates at the 99.9 percentile.")

There is a clear outlier, argh, the `itch5inside` tool also reports
the metrics aggregated across all symbols, that must be the
problem:

{% highlight r %}
top5.raw <- raw[head(order(raw$NSamples, decreasing=TRUE), n=5),]
top5.raw[,c('Name', 'NSamples')]
{% endhighlight %}
{% highlight rout %}
          Name  NSamples
8173 __aggregate__ 206622013
6045           QQQ   2604819
7814           VXX   2589224
6840           SPY   2457820
3981           IWM   1638988
{% endhighlight %}

Of course it was, let's just plot the symbols without the aggregate
metrics:
{% highlight r %}
ggplot(data=symbols, aes(x=NSamples, y=p999RatePerMSec)) +
  geom_point(alpha=0.5) +
  theme(legend.position="bottom") +
  ylab("Events/msec @ p99.9") +
  xlab("Total Event Count")
{% endhighlight %}

![A scatter plot.  The X axis is labeled 'Total Event Count' and varies from 0 to around 2,500,000.  The Y axis is labeled 'Events/msec @ p99.9' and varies from 0 to 10.  All the points but one are clustered around the origin.](/public/symbols.rate.svg "Per millisecond message rates at the 99.9 percentile.")

Finally it would be nice to know what the top symbols are, so we
filter the top50 and plot them against this data:
{% highlight r %}
top50 <- symbols[head(order(symbols$NSamples, decreasing=TRUE), n=50),]
ggplot(data=symbols, aes(x=NSamples, y=p999RatePerMSec)) +
  geom_point(alpha=0.5, size=1) +
  geom_text(data=top50, aes(x=NSamples, y=p999RatePerMSec, label=Name),
            angle=45, color="DarkRed", size=2.8) +
  theme(legend.position="bottom") +
  ylab("Events/msec @ p99.9") +
  xlab("Total Event Count")
{% endhighlight %}

![A scatter plot.  The X axis is labeled 'Total Event Count' and varies from 0 to 2,500,000.  The Y axis is labeled 'Events/msec @ p99.9' and varies from 0 to 10.  The top points are labeled VXX, SPY, QQQ, .](/public/symbols.labeled.rate.svg "Per millisecond message rates at the 99.9 percentile.")

## What Does this Mean?

We have established that inside changes are far more manageable, we
probably need to track less than the top 50 symbols and those do not
seem to see more than 10 messages in a millisecond very often.
We still need to be fairly efficient, in those peak milliseconds we
might have as little as 100 microseconds to process a single event.

## What Next?

I did write a FFTW time delay estimator and benchmarked it, the
results are recorded in the github
[issue](https://github.com/coryan/jaybeams/issues/7).
On my
(somewhat old) workstations it takes 27 microseconds to analyze a
sequence of 2,048 points, which I think would be the minimum for
market data feeds.  Considering that we need to analyze 4 signals
per symbol (bid and offer, price and size for each), and we only
have a 100 microsecond budget per symbol (see above), we find
ourselves without any headroom, even if we did not have to
analyze 20 or more symbols at a time to monitor all the different
channels that some market feeds use.

So we need to continue exploring GPUs as a solution to the problem,
I recently ran across [VexCL](https://github.com/ddemidov/vexcl),
which may save me a lot of tricky writing of code.
VexCL uses template expressions to create complex kernels and
optimize the computations at a high level.
I think my future involves benchmarking this library against some
pretty raw OpenCL pipelines to see how those template expressions do
in this case.
