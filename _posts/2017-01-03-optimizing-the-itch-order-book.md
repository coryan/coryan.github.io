---
layout: post
title: Optimizing the ITCH Order Books
date: 2017-01-03 01:00
---

It has been a while since I posted something, laziness and not having
anything interesting to report.  Well, maybe a lot of negative
reports, which are interesting and should be published, but see above
about laziness.

Recently my friend [Gabriel](https://github.com/GFariasR/)
implemented a really cool optimization on the ITCH-5.0 order book I
had implemented, which I thought should be documented somewhere.
His work inspired me to look further into
benchmarking and how to decide if a code change has actually improved
anything.

But first let's start with Gabriel's work.  Two observations, first
prices are discrete, they only show in penny increments (1/100 of a
penny for prices below $1.00, but still discrete).
The second, and more critical, observation is that most market feed
updates happen close to the inside.
Gabriel and myself wrote a
[program](https://github.com/coryan/jaybeams/blob/master/tools/itch5eventdepth.cpp)
to confirm this,
here are the results, as percentiles of the event depth:

| NSamples | min | p25 | p50 | p75 | p90 | p99 | p99.9 | p99.99 | max |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 489064030 | 0 | 0 | 1 | 6 | 14 | 203 | 2135 | 15489331 | 20009799 |

One should expect, therefore, that 99% of the events affect a price no
more than 203 levels from the inside.
How can one use that?  Well, building a book is basically
keeping a map (it needs to be sorted, so hashes typically do not
work), between prices and quantities.
Since prices are basically discrete values, one starts thinking of
vectors, or arrays, or many circular buffers indexed by price levels.

Since most of the changes are close to the inside, what if we kept an
array with the quantities, with the inside somewhere close to the
center of the array?
Most updates would happen in a few elements of this array, and
indexing arrays is fast!
Furthermore, even as the price moves, the change will be "slow", only
affecting a few price levels at a time.

Unfortunately we cannot keep **all** the prices in an array, the
arrays would need to be too large in some cases.
We could explore options to keep everything in arrays, for example,
one could grow the arrays dynamically and only a few will be very
large.
But a more robust approach is to just use a map for anything that does
not fit the array.

Naturally prices change during the day, and sometimes the price
changes will be so large that the range in the array is no longer
usable.
That is Okay, as long as that happens rarely enough the overall
performance will be better.

Our benchmarks show that this optimization works extremely well in
practice.
With real data the array based order book can process its events
significantly faster than the map-based book, the total CPU time
decreases from 199.5 seconds to 187.50 seconds.  But more
interestingly, processing latencies per event are decreased up to the
p99 level (times in nanoseconds):

| Book Type | min | p10 | p25 | p50 | p75 | p90 | p99 | p99.9 | p99.99 | max | N
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Map       | 193 | 345 | 421 | 680 | 1173 | 1769 | 2457 | 3599 | 13491 | 65673473 | 17560405 |
| Array     | 193 | 288 | 332 | 517 | 886  | 1328 | 2093 | 5807 | 12657 | 63389010 | 17560405 |

More interestingly, using a synthetic benchmark we can see that the
difference is very obvious:

![A boxplot plot: the X axis is labeled 'Book Type', showing 'array'
 and 'map' labels for two boxplots.  The Y axis is labeled 'Iteration
 Latency'.  The array boxplot shows much lower values from p0 to p75.
 Both boxplots have numerous
 outliers.](/public/2017-01-03-array_vs_map.boxplot.svg
 "Iteration Latencies for Array and Map Based Order Books.")

Finally a teaser: the array book type shows more variability, still
faster than map, but more difference between quartiles.
We use the less familiar (but more visually pleasing) violin plot to
break down the data by book side as well as book type.  There
is nothing remarkable for the 'map' book type, but why are latencies
so different for different side of the book in the 'array' case?
The answer to that and other questions in a future post.

![A violin plot: the X axis is labeled 'Book Type', showing 'array'
 and 'map' labels, each label has two plots, distinguished by color,
 one for 'buy' and another for 'sell'.
 The Y axis is labeled
 'Iteration Latency'.
 Each book type has two violin plots, the ones for The array boxplot shows much lower values from p0 to p75.
 Both boxplots have numerous
 outliers.](/public/2017-01-03-array_vs_map.violin.svg
 "Iteration Latencies for Array and Map Based Order Books.")


### Notes

The script used to generate the plots is shown below.  The data is
available for download, and committed to my github
[repository](http://github.com/coryan/jaybeams/).  This data was
generated with an specific
[version](https://github.com/coryan/jaybeams/tree/487e8ffb7e89614581b4639d22a416495b47f55b)
of the
[benchmark](https://github.com/coryan/jaybeams/blob/487e8ffb7e89614581b4639d22a416495b47f55b/jb/itch5/bm_order_book.cpp),
on a Google Compute Engine (GCE) virtual machine (2 vCPUs, 13GiB RAM,
Ubuntu 16.04 image), additional configuration information is captured
in the CSV file.
System configuration beyond the base image is captured in the
[Dockerfile](https://github.com/coryan/jaybeams/blob/487e8ffb7e89614581b4639d22a416495b47f55b/docker/dev/ubuntu16.04/Dockerfile).

{% highlight r %}
require(ggplot2)
baseline.file <- 'http://coryan.github.io/public/2017-01-03-bm_order_book.baseline.csv'
data <- read.csv(
    baseline.file, header=FALSE, col.names=c('testcase', 'nanoseconds'),
    comment.char='#')
data$run <- factor('baseline')
data$microseconds <- data$nanoseconds / 1000.0
data$booktype <- factor(sapply(
    data$testcase,
    function(x) strsplit(as.character(x), split=':')[[1]][1]))
data$side <- factor(sapply(
    data$testcase,
    function(x) strsplit(as.character(x), split=':')[[1]][2]))

ggplot(data=data, aes(x=booktype, y=microseconds)) +
  geom_boxplot(color="blue") +
  ylab("Iteration Latency (us)") +
  xlab("Book Type") +
  theme(legend.position="bottom")
ggsave(filename="2017-01-03-array_vs_map.boxplot.svg",
       width=8.0, height=8.0/1.61)
ggsave(filename="2017-01-03-array_vs_map.boxplot.png",
       width=8.0, height=8.0/1.61)

ggplot(data=data, aes(x=booktype, y=microseconds, color=side)) +
  geom_violin() +
  ylab("Iteration Latency (us)") +
  xlab("Book Type") +
  theme(legend.position="bottom")
ggsave(filename="2017-01-03-array_vs_map.violin.svg",
       width=8.0, height=8.0/1.61)
ggsave(filename="2017-01-03-array_vs_map.violine.png",
       width=8.0, height=8.0/1.61)

{% endhighlight %}

