---
layout: post
title: Computing the Inside and Per Symbol Statistics
date: 2015-09-14 05:00
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
the tool is unimaginatibly called "itch5inside".  It outputs the
inside changes as an ASCII file (which can be compressed on the
fly), so we can use it later as a sample input into our analysis.
Optionally, it also outputs to stdout the per-symbol statistics.
I have made the statistics available
[on this very blog](/public/NASDAQ-ITCH.csv)
in case you want to analyse them.

In this post we will just make some observations about the expected
message rates.
First we load the data, you can set public.dir to
'https://coryan.github.io/public' to download the data directly from
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


{% highlight r %}
ggplot(data=symbols, aes(x=NSamples)) + geom_density() +
  theme(legend.position="bottom") +
  scale_x_log10() +
  ylab("Number of Symbols") +
  xlab("Total Event Count")
{% endhighlight %}

{% highlight r %}
NSamples <- sort(unique(symbols$NSamples), decreasing=TRUE)
ggplot(x=NSamples, binwidth=(range[2] - range[1])/100)
+ geom_histogram(binwidth=1) +
  theme(legend.position="bottom") +
  ylab("Number of Symbols") +
  xlab("Total Event Count")
{% endhighlight %}


{% highlight r %}
fit <- fitdistr(symbols$NSamples, densfun="exponential")
{% endhighlight %}

We pick the Top50 symbols by the total number of inside changes for
the day, and plot the results:
{% highlight r %}
top50.raw <- raw[head(order(raw$NSamples, decreasing=TRUE), n=50),]
ggplot(data=top50.raw, aes(x=NSamples, y=p999RatePerMSec)) +
  geom_text(aes(label=Name), angle=45, color="blue", size=2.5) +
  geom_point(alpha=0.5) +
  theme(legend.position="bottom") +
  ylab("Events/msec @ p99.9") +
  xlab("Total Event Count")
{% endhighlight %}

![A scatter plot.  The X axis is labeled 'Total Event Count' and varies from 0 to 200,000,000.  The Y axis is labeled 'Events/msec @ p99.9' and varies from 0 to 250.  All the points but one are clustered around the origin, the only extreme is labeled '__aggregate__'.](/public/top50.raw.svg "Per millisecond message rates at the 99.9 percentile.")

This graph shows that the aggregate message rate is much higher than
any per-symbol rate.  Yes, the distribution of total messages per
symbol is 
A brief apology for the p99.99 notation, we used this shorthand in a
previous job for "the 99.99-th percentile", and got used to it.

{% highlight r %}
symbols <- subset(raw, Name != '__aggregate__')
top50 <- symbols[head(order(symbols$NSamples, decreasing=TRUE), n=50),]
ggplot(data=top50, aes(x=NSamples, y=p999RatePerMSec)) +
  geom_text(aes(label=Name), angle=45, color="blue", size=2.5) +
  geom_point(alpha=0.5) +
  theme(legend.position="bottom") +
  ylab("Events/msec @ p99.9") +
  xlab("Total Event Count")
{% endhighlight %}



