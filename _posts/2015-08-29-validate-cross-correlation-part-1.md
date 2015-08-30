---
layout: post
title: Validate Cross Correlation, Part 1
date: 2015-08-29 21:00
---

I think it is time to validate the idea that cross-correlation is a
good way to estimate delays of market signals.
Originally I validated these notions using
[R](https://www.r-project.org),
because the compile-test-debug cycle of C++ is too slow for these
purposes.
I do not claim that R is the best choice (or even a good choice) for
this purpose: any other scripting language with good support for
statistics would have done the trick, say Matlab, or Python.
I am familiar with R, and generates pretty graphs easily so I went
with it.

## Market feeds and the inside.

If you are familiar with the markets you can skip to the
[next](#feeds-as-functions) section.
If you are not, hopefully the following explanation gives
you enough background to understands what follows.
And if are familiar with the markets and still chose to read it,
my apologies for the lack of precision, accuracy, or for the extremely
elementary treatment.  It is intended as an extremely brief
introduction for those almost completely unfamiliar in the field.

Many, if not most, electronic markets operate as *continuously
crossing* markets of *limit orders* in *independent books*.
We need to expand on those terms a bit because some of the readers may
not be familiar with them.

**Independent Books**: by this we mean that the crossing algorithm in
the exchange, that is, the process by which buy and sell orders are
matched to each other, looks at a single security at a time.
The algorithm considers all the orders in Apple (for example), to
decide if a buyer matches a seller, but does not consider the orders
in Apple and Microsoft together.
The term "book" refers, as far as I know, to a ledger that in old days
was used to keep the list of buy orders and sell orders in the market.
There are markets that cross complex orders, that is, orders that want
to buy or sell more than one security at a time, other than citing
their existence, we will ignore these markets altogether.

**Limit Orders**: most markets support orders that specify a limit
price, that is the worst price they are willing to execute at.
For BUY orders, *worst* means the highest possible price they would
tolerate.  For example, a BUY limit order at $10.00 would be willing
to transact at $9.00, or $9.99, and event at $10.00, but not at $10.01
nor even at $10.01000001.
Likewise, for SELL orders, *worst* means the lowest possible price
they would tolerate.

**Continuously Crossing**: this means that any order that could be
executed is immediately executed.  For example, if the lowest SELL
order in a market is offering $10.01 and a new BUY order enters the
market at $10.02 then the two orders would be immediately executed.
The precise execution price depends on many things, though generally
the orders would be match at $10.01 there are many exceptions to that
rule.
Most markets have periods where certain orders are not
immediately executable, for example, in the US markets DAY orders are
only executable between 09:30 and 16:00 Eastern.
Some kind of auction process is executed at 09:30 to *clear* all DAY
orders that are crossing.

**Non-limit Orders**: there are many more order types than limit
orders, a full treatment of which is outside the scope of this
introduction.  But briefly, MARKET orders execute at the best
available price.  They can be though of as limit orders with an
extremely high (for BUY) or extremely low (for SELL) orders.
There are also orders whose limit price is tied to some market
attribute (PEGGED orders),
orders that only become active if the market is trading below or
above a certain price (STOP orders),
orders that trade slowly during the day, orders that execute only at
the market midpoint, etc., etc., etc.

### Markets as Seen by the Computer Scientist

If you are a computer scientist, these continuously crossing markets
as a computer scientist you will notice an obvious invariant:
at any point in time
the highest BUY order has a limit price strictly lower than the price
of the lowest SELL order.
If this was not the case the best BUY order and the best SELL order
should match, execute and be removed from the book.

So, in the time periods when this invariant holds, the highest BUY
limit price is referred to as the *best bid* price in the market.
Likewise, the lowest SELL order is referred to as the *best offer*
in the market.

We have not mentioned this, but the reader would not be surprised to
hear that each order defines a quantity of securities that it is
willing to trade.  No rational market agent would be willing (or able)
to buy or sell an infinite number whatever securities are traded.

Because there may be multiple orders willing to buy at the same price,
the best bid and best offer are always annotated with the quantities
available at that price level.  The combination of all these figures,
the best bid price, best bid quantity, best offer price and best offer
quantities are referred to as the *inside* of the market (implicitly,
the inside of the market in each specific security).

There are some amusing subtleties regarding how the quantity available
is represented (in the US markets is in units of *roundlots*, which
are almost always 100 shares).  But we will ignore these details for
the moment.

As one should expect, the inside changes over time.  What is often
surprising to new students of market microstructure is that there are
multiple data sources for the inside data.
One can obtain the data through direct market data feeds from the
exchanges (sometimes an exchange may offer several different versions
of the same feed!),
or obtain it through the
[consolidated](https://en.wikipedia.org/wiki/National_market_system_plan)
feeds,
or through market data re-distributors.
These different feeds have different latency characteristics, JayBeams
is a library to measure the difference of these latencies in real-time.

## Market Feeds as Functions {#feeds-as-functions}

The motivation for JayBeams is market data, but we can think of a
particular attribute in a market feed as a function of time.
For example, we could say that the *best bid price* for SPY on the
ITCH-5.0 feed is basically a function $$f(t)$$ with real values.
Whatever is left of the mathematician in me wants to talk about
families of functions in $$\mathbb{R}^4$$ indexed by the security, but
this would not help us (yet).

In the next sections we will just think about a single book at a time,
that is, when we say "the inside for the market" we will mean "the
inside for the market in security X".
We may need to consider multiple securities simultaneously later, and
when we do so we will be explicit.

Let us first examine a single attribute on the inside, say the best
bid quantity.  We will represent this attribute in different feeds as
different functions.
For example, let us call $$f(t)$$ the inside best bid quantity from a
direct feed, and $$g(t)$$ as the inside best bid quantity from a
consolidated feed.

Our expectation is that there is a value $$\tau > 0$$ such that:

$$g(t) \approx f(t - \tau)$$

well, we actually expect $$\tau$$ to change over time because feeds
respond differently under different loads.  But let's start with the
simplifying assumption that $$\tau$$ is mostly constant.

## Time Delay Estimation for Functions

We simply refer the reader to the Wikipedia article on
[Cross-correlation](https://en.wikipedia.org/wiki/Cross-correlation)
and the section therein on
[Time delay analysis](https://en.wikipedia.org/wiki/Cross-correlation#Time_delay_analysis).

As this article points out, one can estimate the delay as:

$$\tau_{delay} = \arg \max_{t}(({f} \star {g})(t))$$

The key observation is that we can estimate the cross-correlation
using the Fast Fourier transform $$\mathcal{F}$$:

$$\tau_{delay} = \arg \max_{t}(
    \mathcal{F}^{-1}({\mathcal{F}(f)}^{*} \cdot {\mathcal{F}(g)})(t))$$

## Enough Math! Show me how it Looks!

Will do, in the next post, this one is getting to long anyway.




