---
layout: post
title: On Benchmarking, Part 1
date: 2017-01-04 01:00
---

Software engineers often evaluate the performance of their systems
through simple performance "experiments".  Then they make changes to
the system, maybe to its environment, or to the code, run the
"experiment" again and if the new results are faster they quickly
declare success and claim they have improved the performance.

I have no time, or the expertise, to describe all the different ways
in which these experiments are often flawed.  Nor do I want to re-hash
all the discussions in the literature as to the sad state of rigor 
the software engineering (or computer science if you prefer) when it
comes to designing, reporting, and evaluating performance experiments.

I will limit myself to showing one example on how to
design a performance experiment as rigorously as I know how.
I propose to describe the pitfalls that I try to avoid,
and how I avoid them.
And finally to report the results in enough detail that readers can
decide if they agree with my conclusions.
It is possible, indeed likely, that more knowledgeable readers than
myself will find fault in my methods, my presentation, or my
interpretation of the results.
If so, I invite them to enter their
[comments](https://github.com/coryan/coryan.github.io/issues/1)
into a bug report I created for this purpose.

## Detailed Design of the Class and Performance Impact

For this exercise we will consider the ITCH order book introduced in
the [previous post]({{ page.previous.url }}).
This is a template class ([array_based_order_book_side<>](https://github.com/coryan/jaybeams/blob/eabc035fc23db078e7e6b6adbc26c08e762f37b3/jb/itch5/array_based_order_book.hpp#L127))
with two main member functions:

* `add_order`: increases the quantity of shares at a given price.
* `reduce_order`: reduces the quantity of shares at a given price.

The template parameter controls whether this class represents the BUY
or SELL side of the book.  We illustrate how this class is designed
for the BUY side, the SELL side is analogous.

As shown in the following diagram, the class maintains two data
structures.  A vector representing the best (highest in the case of
BUY) prices, a `std::map<>` (which is typically some kind of balanced
tree) to represent the prices that do not fit in the vector.
One index, `tk_begin_top` tracks the best price in the vector.  A
second index `tk_inside` tracks which location in the vector has the
best price.  All elements in the vector past that index have zero values.

![A diagram representing the array_based_order_book_side<> template
 class.  Two data structures are show, a balanced binary tree
 labeled "std::map<>", and a array, labeled "std::vector".
 An arrow shows that prices increase with the indices in the array.
 Another arrow points to one of the cells in the array, the arrow is
 labeled "tk_inside".
 All cells after the one indicated by the tk_inside arrow are greyed
 out.
 The first cell is labled "tk_begin_top".
 ](/public/2017-01-04-array_based_order_book_side-basic.svg
 "The array_based_order_book_side<> internal data structures.")

Most `add_order` and `reduce_order` operations into this data
structure are expected to only affect the values stored by the array.
The value of `tk_inside` changes when a new better price in inserted
into the vector.
This is a $$O(1)$$ operation, which simply updates the indices.
If a `reduce_order` operation sets the value to zero, the data
structure needs to search backwards through the vector until it finds
a non-zero value.
This is a $$O(vector.size())$$ operation, but we expect
that over 90% of these searches finish in less than $$14$$ steps,
and in practice no more than $$vector.size() / 2$$ elements need to be
moved.

In rare occassions, we expect the vector to be full of zeroes, and we
need to "move" values from the map into the vector.  This
`move_bottom_to_top` function is a
$$O(\ln(map.size)  + vector.size)$$ operation,
because while it needs to change the map up to $$vector.size$$ times,
all those changes are to a contiguous range, which is
[guaranteed](http://en.cppreference.com/w/cpp/container/map/erase) to
be linear on the range size.

Sometimes we will also need to move the `tk_inside` pointer beyond the
capacity of the vector.  In this case we first make room by moving the
as many as $$vector.size$$ elements from the vector into the map.
This can also be implemented as a amortized $$O(vector.size)$$
operation, because all the insertions happen at the same location, and
`std::map::emplace_hint` is guaranteed to be amortized constant time.

In short, most of the operations should execute in a short constant
time that depends on the detail of their implementation.
Sometimes, we need to perform operations that are linear on the size of
the array.

We want to make some change this class so it can process a ITCH-5.0
feed faster, that is, we want to make total time required to process a
day worth of market data shorter.
In a production environment we would have further constraints, maybe
the total amount of memory must be limited, or we cannot allow the
tail (say p99.9) latency to process each event to grow beyond a
certain limit.

## We need a benchmark

Running a program,
such as
[itch5inside](https://github.com/coryan/jaybeams/blob/eabc035fc23db078e7e6b6adbc26c08e762f37b3/tools/itch5inside.cpp),
and measuring how its performance changes as we modify the
`array_based_order_book_side` class has multiple problems:

* The program needs to read the source data from a file, this file is
about 6 GiB compressed, so any execution of the full program is also
measuring the performance of the I/O subsystem.

* The program needs to decompress the file, parse it, and filter the
events by symbol, directing different events to different instances of
`array_order_book_side<>`.  So once more, an execution of the full
program is measuring many other components beyond the one we want to
optimize.

* The program takes around 35 minutes to process a day worth of market
data.  We expect that multiple runs will be needed to "average out"
(we will not use averages, no peeking) the variation caused by all the
operating system noise (we will control for that too, but no peeking
again).

Such long elapsed times will severely limit our ability to iterate
quickly.
More importantly, running the full program is poor experimental
design.
There are too many variables that we will need to control for: the I/O
subsystem, the size of the buffer cache, any programs that are
competing for that cache, any changes to the decompression and/or I/O
libraries, etc. etc.

We want to run an experiment that isolates only the component that we
want to measure.  Therefore we need to use a synthetic benchmark, a
proxy for the performance of the overall program.

This is not uncommon in software engineering.  Testing the performance
of large systems is expensive in engineering time for preparing and
executing the test.  Not to mention the hardware and operational costs
of running separate, isolated, instances of the system just for
testing its performance.
Engineers often evaluate the performance of smaller components, or
smaller subsystems, before running load or performance tests on the
full system.

## Obtaining Representative Data for the Benchmark

We recall from our [previous post]({{ page.previous.url }}) that the
class we are benchmarking was specifically designed to take advantage
of the distribution characteristics of the input data.
In the common case the event should be close to the inside, and we
exploit that locality by keep the inside prices and prices close to it
in an array, that has better complexity guarantees for search and
update.
Our test data must have this locality property.  Not so much that it
unfairly favors the data structure design.  But not so little that the
algorithm is disadvantaged either.

Two techniques come to mind to test with realistic data:

* We can use *traces* from the existing data set.  Cache or otherwise
  save a trace in memory and execute it repeatedly against an instance
  of the class.  However, we would need to capture multiple traces to
  ensure we have a representative sample of the data, which is also
  challenging.

* We can *generate* data with similar statistical distribution.  The
  data may not have the same fidelity of a trace, but it can be easily
  varied by regenerating the data.

Because it is easier to setup and run the test with synthetic data we
chose to do so.
There are limitations on this approach: the synthetic data may lack
fidelity, and fail to capture important characteristics of the problem
in production.

An interesting question for future analysis would be to capture how
many times does real data creates the expensive operations described
earlier, and compare those rates with the rates observed with the
synthetic data.

The reader may disagree with my assumptions about how this (and other)
decisions impact the validity of the results.
That is their privilege, and in fact they might be correct.
My duty is to disclose the assumptions, and explain myself to the
reader.
A reader that disagrees is welcome to reproduce the experiment, or
design a better one and show that the analysis was incorrect.

This is the how the scientific process (and good engineering) works.
We disclose our work, we are rigorous in our descriptions,
future engineers improve on that work to produce even better systems.
There is no shame in making assumptions to allow the work to be completed,
we just need to state them clearly and qualify our conclusions on the
basis of those assumptions.

## Benchmark Setup

We have implemented a
[benchmark](https://github.com/coryan/jaybeams/blob/eabc035fc23db078e7e6b6adbc26c08e762f37b3/jb/itch5/bm_order_book.cpp),
called `bm_order_book`, which
is able to test both the `array_based_order_book_side` and
`map_based_order_book_side` class templates.

A more detailed description of the benchmark internals and its results
are the subject of a future post.

## Notes

In this post we have referred all links to a specific version
([eabc035fc23db078e7e6b6adbc26c08e762f37b3](https://github.com/coryan/jaybeams/tree/eabc035fc23db078e7e6b6adbc26c08e762f37b3))
of the code.
Links to the current version are more succinct, and future readers may
find that bugs in the old code have been fixed in newer versions.
We prefer to use links to fixed versions because it makes the
references and links *reproducible*.

> Updates: [Gabriel](https://github.com/gfariasr) caught a mistake in
> my complexity analysis, the O() bounds were correct, but I was
> playing fast and lose with the constant factors.
