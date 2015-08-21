---
title: Hosted Continous Integration: Suitable for C++?
layout: post
---

For reasons that will hopefully will apparent in future posts,
I became interested in using a hosted service to perform continuous
integration of my C++ projects.  There are many offerings out there,
in fact the sheer number can become bewildering (Travis-CI, Circle-CI,
drone.io, just to start).
After trying a
couple of them it became apparent that most, if not all, of them
provide virtual machines based on Ubuntu 12.04 (aka Precise Pangolin).

A reasonable platform choice for most purposes, but an unfortunate one
for me.  Most of my code uses C++11, which was poorly supported in
that version of Ubuntu.  I also tend to use recent versions of the
boost libraries, and the GNU auto configuration tools.

I will probably be discussing soon whether the choice of automake is a
poor one.  But the choice of libraries and compilers I will defend,
not on any technical basis, simply because my hobby
projects are supposed to be fun.
That usually involves not limiting myself to
use well-proven, and stable platforms, as I often argue
professionally.

With this in mind, the next posts will describe my failures (and
successes hopefully) trying to use hosted environments for a small
C++11 project.  I will be writing them as I try different solutions,
so do not expect polished and well reasoned conclusions soon.  Instead,
join me in a journey of toil, suffering, failures, successes, and
ultimately discovery (gulp, I hope).
