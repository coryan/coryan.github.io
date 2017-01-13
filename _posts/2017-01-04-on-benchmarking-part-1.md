---
layout: post
title: On Benchmarking, Part 1
date: 2017-01-04 12:00
---

My [previous post](2017/01/03/optimizing-the-itch-order-book/)
included a performance comparison between two implementations of a
data structure.
I have done this type of comparison many times, and have grown
increasingly uncomfortable with the lack of scientific and statistical
rigor we use in our field (I mean software engineering, or computer
science, or computer engineering, or any other name you prefer)
when reporting such results.

Allow me to criticize my own post to illustrate what I mean.
The post reported on the results of benchmarking two implementations
of a data structure.

**I1:**<a name="bad-no-context"></a> I did not provide a context: what
domain those this problem arise in? Why is this data structure
interesting at all?

**I2:**<a name="bad-no-problem-description"></a> I did not provide a
description of the problem the data structure is trying to solve.
Maybe there is a much better solution that I am not aware of, one of
the readers may point this potential solution to me, and all
the analysis is a waste of time.

**I3:**<a name="bad-efficiency-not-justified"></a> I did not provide any
justification for why the data structure efficiency would be of
interest to anybody.

**I4:**<a name="bad-no-data-structure-description"></a> I did not include a
description of the data structure.  With such a description the reader
can understand why is it likely that the data structure will perform
better. Better yet, they can identify the weakness in the data
structure, and evaluate if the analysis considers those weaknesses.

I assumed that a reader of this blog, where I largely write about
[JayBeams](http://github.com/coryan/jaybeams),
should be familiar with these topics, but that is
not necessarily the case.
The gentle reader may land on this post as the result of a search, or
because a friend recommends a link.
In any case, it would have to be a very persistent reader if they were
to find the actual *version* of the JayBeams project used to prepare
the post, and that information was nowhere to be found either.

Furthermore, and this is less forgivable, my post did not answer any
of these other questions:

**I5:**<a name="bad-no-benchmark-description"></a> How exactly is the
benchmark constructed?
How does it measure time?
Why is that a good choice for time measurement?
What external variables impact the results, such as system load,
impact the results and how did I control for them?

**I6:**<a name="bad-no-minimum-effect-size"></a> What exactly is the
definition of success and do the results meet that definition? Or in
the language of statistics:
Was the effect interesting or too small to matter?

**I7:**<a name="bad-faster-not-operationalized"></a>What exactly do I mean
by "faster", or "better performance", or "more efficient"?  How is
that operationalized?

**I8:**<a name="bad-no-population-definition"></a> At least I was
explicit in declaring that I only expected the
`array_based_order_book_side<>` to the faster for the inputs that one
sees in a normal feed, but that it was worse with suitable constructed
inputs.  However, this leaves other questions unanswered:
How do you characterize those inputs for which it is expected to be
faster?
Even from the brief description, it sounds there is a very large
space of such inputs.  Why do I think the results apply
for most of the acceptable inputs if you only tested with a few?
How many inputs would you need to sample to be confident in the results?

**I9:**<a name="bad-no-power-analysis"></a> How unlucky would I have to
be to miss the effect if it is there?  Or if you prefer: how likely
is it that we will detect the effect if it is there?  In the
language of statistics:
Did the test have enough statistical power to measure what I
wanted to measure?
Is that number of iterations (a/k/a samples) high enough?
For that matter, how many iterations of the test did I ran? 

**I10:**<a name="bad-no-statistical-significance"></a> How confident
am I that the results cannot be explained by luck alone?  Or in the
language of statistics: Was the result statistically significant?
A what level?

**I11:**<a name="bad-median-not-justified"></a> I reported the median
latency (and a number of other percentiles): 
why are those statistics relevant or appropriate for this problem?

**I12:**<a name="bad-not-reproducible"></a> How could anybody reproduce
these tests?
What was the hardware and software platform used for it?
What version of JayBeams did I use for the test?
What version of the compiler, libraries, kernel, etc. did I use?

If those questions are of no interest to you, then this is not the
series of posts that you want to read.
If you think those questions are important, or peak your interest,
or you think they may be applicable to similar benchmarks you have
performed in the past, or plan to perform in the future,
then I hope to answer them in this series of posts.

I propose to use
*measure the performance improvements of
`array_based_order_book_side<>` vs `map_based_order_book_side<>`* as an
example of how to rigorously answer those questions.
Later it will become evident that this example is too easy, so I will
also use
*measure the some small improvement of 
`array_based_order_book_side<>`* as a further example of how to
rigorously benchmark and compare code changes.
As I go along, I will describe the pitfalls that I try to avoid,
and how I avoid them.
And finally to report the results in enough detail that readers can
decide if they agree with my conclusions.

It is possible, indeed likely, that readers more knowledgeable than
myself will find fault in my methods, my presentation, or my
interpretation of the results are incorrect.
They may be able to point out other pitfalls that I did not consider,
or descriptions that are imprecise, or places where my math was wrong,
or even simple spelling or grammar mistakes.
If so, I invite them to enter their comments into a 
[bug](https://github.com/coryan/coryan.github.io/issues/1)
I have created for this purpose.

## The Problem of Building an Order Book

In this section I will try to address the issues raised in
[I1](#bad-no-context), [I2](#bad-no-problem-description), and
[I3](#bad-no-efficiency-not-justified), and give the reader some
context about the domain where the problems of building a book arise,
what specifically is this problem, and why is it important to solve
this problem very efficiently.

If you are familiar with market feeds and order books you may want to
skip tho the [next section](#detailed-design),
it will be either boring or irritating to you.
If you are not familiar, then this is a very rushed overview, there is
an [earlier post](/2015/08/29/validate-cross-correlation-part-1/) with
a slightly longer introduction to the topic, but the content here
should suffice.

Market data feeds are network protocols used to describe features of
interest in an exchange (or more generally a trading venue, but that
distinction is irrelevant).
These protocols are often custom to each exchange, though their
specification is public, and have large differences in the information
they provide, as well as the actual protocol used.
Having said that, I have found that many of them can be modeled as a
stream of messages that tell you whether a order was *added*,
*modified*, or *deleted* in the exchange.
The messages include a lot of information about the order, but here we
will just concern about with the most salient bits, namely:
the side of the order -- is this an order to buy or sell securities;
the price of the order -- what is the maximum (for buy) or minimum (for
sell) price that the investor placing the order will accept,
and the quantity of the order -- the number of shares (or more
generally *units*) the investor is willing to trade.

With this stream of messages one can build a full picture of all the
activity in the exchange, how many orders are active at any point, at
what prices, how much liquidity is available at each price point,
which orders arrived first, sometimes "where is my order in the
queue", and much more.
The process of building this picture of the current state of the
exchange is called *Building the Book*, and your *Book* is the data
structure (or collection of data structures) that maintains that
picture.
One of the most common questions your book must be
able to answer are: what is the price of the highest buy order active
right now in a security?  And also: how many total shares are
available at that best buy price for that security?  And obviously:
what about the best sell price and the number of shares at that best
price for that security?

If those are all the questions you are going to ask, and this is often
the case, you only need to keep a tally of how many
shares are available to buy at each price level, and how many shares
are available to sell at each price level.
The tally must be sorted by price (in opposite orders for buy
and sells), because when the best price level disappears (all active
orders at the best price are modified or canceled) you need to quickly
find the next best price.
You must naturally keep a different instance of such tally for each
security, after all you are being asked about the best price for GOOG,
not for MSFT.

The challenge is that these feeds can have very high throughput
requirements, it is
not rare to see hundreds of thousands of messages in a second.
That would not be too bad if one could shard the problem
across multiple machines, or at least multiple cores.
Alas! this is not always the case, for example, the Nasdaq ITCH-5.0
feed does not include symbol
information in neither the modify nor delete messages, so one much
process such messages in order until the order they refer to is found,
the symbol is identified, at which point one may shard to a different
server or core.

Furthermore, the messages are not nicely and evenly spaced in these
feeds.
In my measurements I have seen that up to 1% of the messages arrived
in less than 300ns after you receive the previous one.
Yes, that is **nano**seconds.
If you want to control the latency of your book builder to the p99
level -- and you almost always want to do in the trading space -- it
is desirable to completely process 99% of the messages before
the next one arrives.
In other words, you roughly have 300ns to process most messages.

Suffice is to say that the data structure involved in processing a
book must be extremely efficient to deal with peak throughput without
introducing additional lately.

## Detailed Design

In this section I will try to solve the problems identified in
([I4](#bad-no-data-structure-description))
and give a more detailed description of the
classes involved, so the reader can understand the tradeoffs they make
and any weaknesses they might have.
If the reader finds this section too detailed they can
[skip it](#benchmark-design).

### The Map Based Order Book

In JayBeams, a relatively straightforward implementation of the order
book tally I described above
is provided by `map_based_order_book_side<>` (hereafter `mbobs<>`)
[[1]](https://github.com/coryan/jaybeams/blob/eabc035fc23db078e7e6b6adbc26c08e762f37b3/jb/itch5/map_based_order_book.hpp#L52).
It is implemented using a `std::map<>`, indexed by price and
containing the total quantity available for that price.

The class has two operations that are used to process all add, modify,
and delete messages from the market feed.
`reduce_order()` processes both delete and modify messages, because in
ITCH-5.0 all modifications reduce the size of an order.  Naturally
`add_order()` processes messages that create a new order.
The class provides member functions to access the best price and
quantity, which simply call the `begin()` and `rbegin()` in the
internal `std::map<>` member variable.

Therefore, finding the best and worst prices are *O(1)* operations, as
C++ makes this
[complexity guarantee](http://en.cppreference.com/w/cpp/container/map/begin)
for the `begin()` and `rbegin()` member functions.
Likewise, the `add_order()` and `reduce_order()` member functions are
*O(log(N))* on the number of existing price levels, since those are
the
[complexity guarantees](http://en.cppreference.com/w/cpp/container/map/find)
for the find and erase member functions.
Alternatively, we can bound this with *O(log(M))* where *M* is the
number of previous orders received, as each order creates at most one
price level.

### The Array Based Order Book

In the previous post, I made a number of observations on the
characteristics of a market feed:
(1) I reported that market data messages
exhibit great locality of references, with the vast majority of
add/modify/delete messages affecting prices very close to the current
best price,
(2) prices only appear in discrete increments, which make them suitable to
represent by integers,
(3) Integers that appear in a small range can represent indices into an
array,
(4) and access to such arrays is *O(1)*, and also makes efficient use
of the cache.
One can try to exploit all of this by keeping an array for the prices
contiguous with with the best price.
Because the total range of prices is rather large, we cannot keep all
prices in an array, but we can fallback on the `std::map<>`
implementation for the less common case.

My friend Gabriel used all the previous observations to design and
implement `array_based_order_book_side<>` (hereafter `abobs<>`).
The class offers an identical interface to
`mbobs<>`,
with `add_order()` and `remove_order()`
member functions, and with member functions to access the best and
worst available prices.

The implementation is completely different though.
The class maintains two data structures:
(1) a vector representing the best (highest in the case of
buy) prices,
and (2) a `std::map<>` -- which is typically some kind of balanced
tree -- to represent the prices that do not fit in the vector.
In addition, it maintains 
`tk_begin_top` the tick level of the first price price in the vector,
and `tk_inside` the index of the best price.
All elements in the vector past that index have zero values.
The vector size is initialized when a class instance is constructed,
and does not change dynamically.

![A diagram representing the abobs<> template
 class.
 ](/public/2017-01-04-on-benchmarking-part-1/array_based_order_book_side-basic.svg
 "The abobs<> internal data structures.")

The value of `tk_inside` changes when a new order with a better price
than the current best is received.  Analyzing the complexity of this
is better done by cases:

#### Complexity of `add_order()`

There are basically three cases:

1. We expect the majority of the calls to the `add_order()`
   member function to affects a price that is close to the current 
   `tk_inside`.  In this case the member function simply updates one
   of the values of the array, a *O(1)* operation.
2. Sometimes the new price will be past the capacity assigned to the
   array.  In this case the current values in the array need to be
   flushed into the map.  This is a *O(K)* operation, where *K* is the
   capacity assigned to the array, because all *K*
   insertions happen at the same location, and
   `std::map::emplace_hint` is guaranteed to be amortized constant
   time.
3. Sometimes the price is a price worse than `tk_begin_top`, in which
   the complexity is *O(log(N))* same as the map-based class.

#### Complexity of `reduce_order()`

There are also basically three cases:

1. We also expect the majority of the calls to `reduce_order()` to
   member function to affects a price that is close to the current 
   `tk_inside`.  As long as the new total quantity is not zero simply
   updates one of the values of the array, a *O(1)* operation.
2. If the new quantity is zero the class needs to find the new best
   price.  In most cases this is a short search backwards through the
   array.  But if the search through the array is exhausted the
   implementation needs to move *vector.size()/2* prices from the map
   to the vector.  Again this is a *O(vector.size())* operation
   because erasing a range of prices in the map is guaranteed to be
   linear on the number of elements erased.
3. If the price is worse than `tk_begin_top` then this is similar to
   the map-based class and the complexity is *O(log(N))*.

#### Summary of the Complexity

In short, we expect `abobs<>` to behave as a
*O(1)* data structure for the majority of the messages.
This expectation is based on receiving very few messages affecting
prices far away from the inside.
In those cases the class behaves actually worse than
`mbobs<>`.

## Benchmark Design

I tried running an existing program,
such as
[itch5inside](https://github.com/coryan/jaybeams/blob/eabc035fc23db078e7e6b6adbc26c08e762f37b3/tools/itch5inside.cpp),
and measuring how its performance changes with each implementation.
I ran into a number of problems:

1. The program needs to read the source data from a file, this file is
about 6 GiB compressed, so any execution of the full program is also
measuring the performance of the I/O subsystem.

2. The program needs to decompress the file, parse it, and filter the
events by symbol, directing different events to different instances of
`array_order_book_side<>`.  So once more, an execution of the full
program is measuring many other components beyond the one I want to
optimize.

3. The program takes around 35 minutes to process a day worth of market
data.  We expect that multiple runs will be needed to "average out"
the variation caused by all the
operating system noise, so completing a test could take hours.

Such long elapsed times will severely limit my ability to iterate
quickly.
More importantly, running the full program is poor experimental
design.
There are too many variables that we will need to control: the I/O
subsystem, the size of the buffer cache, any programs that are
competing for that cache, any changes to the decompression and/or I/O
libraries, etc.

I would prefer to run an experiment that isolates only the component
that I want to measure.
I do not see any way to do this other than using a synthetic
benchmark.
Admittedly this is a proxy for the performance of the overall
program, but at least I can iterate quickly and test the big program
again at the end.

This is more or less standard practice, and I do not think too
controversial.

## Obtaining Representative Data for the Benchmark

The tricky bit here is that the `abobs<>` class was specifically
designed to take advantage of the distribution characteristics of the
input data.
I need to create test data that has this locality property.
And it must have some kind of goldi-locks medium:
not so much locality of prices that it unfairly favors the `abobs<>`
design, but not so little that it unfairly disadvantages that design
either.

I thought about two alternatives for this problem:

* I could use *traces* from the existing data set.  Somehow 
  save a trace, load it into memory and run the
  something-something-based-book against this data.
  However, we would need to capture multiple traces to
  ensure we have a representative sample of the data.
  And I have a limited amount of market data at my disposal, so this
  is all very limiting.

* I can try to *generate* data with similar statistical distribution.  The
  data may not have the same fidelity of a trace, but it can be easily
  varied by regenerating the data.

Because it is easier to setup and run the test with synthetic data I
chose the second approach.
In addition to the lack of fidelity, there may be characteristics
about the data that I did not think about, and make the class behave
differently in production.
I think I am addressing those limitations by planning to run the full
test separate.

By the way, if the reader disagrees with my assumptions about how this
(and other) decisions impact the validity of the results,
please do let me know in the
[bug](https://github.com/coryan/coryan.github.io/issues/1).
I am trying to be super transparent about my assumptions,
if I am doing my work right you should be able to reproduce the
experiment with different assumptions, show why I am wrong, and we
both learn something.
That sounds suspiciously close to the scientific method.


## Next Up

The next post will include a more detailed description of the
[benchmark](https://github.com/coryan/jaybeams/blob/eabc035fc23db078e7e6b6adbc26c08e762f37b3/jb/itch5/bm_order_book.cpp),
to test these classes.


## Notes

In this post I have set all links to a specific version
([eabc035fc23db078e7e6b6adbc26c08e762f37b3](https://github.com/coryan/jaybeams/tree/eabc035fc23db078e7e6b6adbc26c08e762f37b3))
of the [JayBeams](https://github.com/coryan/jaybeams/) project.
Links to the current version are more succinct, and future readers may
find that bugs in the old code have been fixed in newer versions.
We prefer to use links to fixed versions because it makes the
references and links *reproducible*, partially addressing
the [problem](#bad-not-reproducible) I highlighted earlier.

> Updates: [Gabriel](https://github.com/gfariasr) caught a mistake in
> my complexity analysis, the O() bounds were correct, but I was
> playing fast and lose with the constant factors.
> Updates: Major rewording so I do not sound like a pompous ass.
