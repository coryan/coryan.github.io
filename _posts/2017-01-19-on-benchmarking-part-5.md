---
layout: post
title: On Benchmarking, Part 5
date: 2017-01-19 01:00
draft: true
---

{% assign ghsha = "50b03a99fcb907aa5589692c2cf47b01dae21b8e" %}
{% capture ghver %}https://github.com/coryan/jaybeams/blob/{{ghsha}}{% endcapture %}

> This is a long series of posts where I try to teach myself how to
> run rigorous, reproducible microbenchmarks on Linux.  You may
> want to start from the [first one](/2017/01/04/on-benchmarking-part-1/)
> and learn with me as I go along.
> I am certain to make mistakes, please write be back in
> [this bug](https://github.com/coryan/coryan.github.io/issues/1) when
> I do.

In my [previous post]({{page.previous.url}}) I convinced myself that
the data we are dealing with does not fit the most common
distributions such as normal, exponential or lognormal.
I decided to forge ahead using nonparametric statistics.
I used bootstrapping to estimate the standard deviation of the 
population, and then used that result to estimate the number of
samples necessary to produce a good test.

In this post I will teach myself how to run the statistical test using
mostly fake data.
The objective is to fine tune our procedure and to make sure we
understand the numbers that the test spews out.

## Next Up

In the next post we will finally run the statistical test against
freshly minted data.

## Appendix: Familiarizing with the Mann-Whitney Test

I find it useful to test new statistical tools with fake data to
familiarize myself with them.
I also think it is useful to gain some understand of what the results
should be in ideal conditions, so we can interpret the results of live
conditions better.

### The trivial test

I asked R to generate some random samples for me, fitting the
[Lognormal](https://en.wikipedia.org/wiki/Log-normal_distribution)
distribution.
I picked Lognormal because, if you squint really hard, it looks
vaguely like latency data:

{% highlight r %}
lnorm.s1 <- rlnorm(50000, 5, 0.2)
qplot(x=lnorm.s1, geom="density", color=factor("s1"))
{% endhighlight %}

![](/public/{{page.id}}/lnorm.s1.density.svg
"Estimated Density of Randomly Selected Samples from a Lognormal Distribution")

I always try to see what a statistical test says when I feed it
identical data on both sides.  One should expect the test to *fail to
reject the null hypothesis* in this case, because the null hypothesis
is that both sets are the same.
If you find the language of statistical testing somewhat convoluted
(e.g. "fail to reject" instead of simple "accept"), you are not alone,
I think that is the sad cost of rigor.

{% highlight r %}
s1.w <- wilcox.test(x=lnorm.s1, lnorm.s1, conf.int=TRUE)
print(s1.w)
{% endhighlight %}

{% highlight r %}
	Wilcoxon rank sum test with continuity correction

data:  lnorm.s1 and lnorm.s1
W = 1.25e+09, p-value = 1
alternative hypothesis: true location shift is not equal to 0
95 percent confidence interval:
 -0.3711732  0.3711731
sample estimates:
difference in location 
         -6.243272e-08 
{% endhighlight %}

That seems like a reasonable answer, the p-value is about as high as
it can get, and the estimate of the location parameter difference is
close to 0.

### Two Samples from the same Distribution

I next try with a second sample from the same distribution, the test
should fail to reject the null again, and the estimate should be close
to 0:

{% highlight r %}
lnorm.s2 <- rlnorm(50000, 5, 0.2)
require(reshape2)
df <- melt(data.frame(s1=lnorm.s1, s2=lnorm.s2))
colnames(df) <- c('sample', 'value')
ggplot(data=df, aes(x=value, color=sample)) + geom_density()
{% endhighlight %}

![](/public/{{page.id}}/lnorm.s1.s2.density.svg
"Estimated Density of Two Randomly Selected Samples from a Lognormal Distribution")

{% highlight r %}
w.s1.s2 <- wilcox.test(x=lnorm.s1, y=lnorm.s2, conf.int=TRUE)
print(w.s1.s2)
{% endhighlight %}

{% highlight r %}
	Wilcoxon rank sum test with continuity correction

data:  lnorm.s1 and lnorm.s2
W = 1252400000, p-value = 0.5975
alternative hypothesis: true location shift is not equal to 0
95 percent confidence interval:
 -0.2713750  0.4712574
sample estimates:
difference in location 
            0.09992599 
{% endhighlight %}

That seems like a good answer too.  Conventionally the one fails to
reject the null if the p-value is above 0.01 or 0.05.
The output of the test is telling us that under the null hypothesis
one would obtain this result (or something more extreme) $$59%$$ of
the time.
That seems pretty good odds to reject the null indeed.
Notice that the estimate for the location parameter difference is not
zero (which we know to be the true value), but the confidence interval
does include 0.

### Statistical Power Revisited

Okay, so this test seems to give sensible answers when we give it data
from identical distributions.
What I want to do is try it with different distributions, let's start
with something super simple: two distributions that are slightly
shifted from each other:

{% highlight r %}
lnorm.s3 <- 4000.0 + rlnorm(50000, 5, 0.2)
lnorm.s4 <- 4000.1 + rlnorm(50000, 5, 0.2)
df <- melt(data.frame(s3=lnorm.s3, s4=lnorm.s4))
colnames(df) <- c('sample', 'value')
ggplot(data=df, aes(x=value, color=sample)) + geom_density()
ggsave('lnorm.s3.s4.density.svg', width=save.width, height=save.height)
ggsave('lnorm.s3.s4.density.png', width=save.width, height=save.height)
w.s3.s4 <- wilcox.test(x=lnorm.s3, y=lnorm.s4, conf.int=TRUE)
print(w.s3.s4)
{% endhighlight %}

{% highlight r %}
	Wilcoxon rank sum test with continuity correction

data:  lnorm.s3 and lnorm.s4
W = 1249300000, p-value = 0.8718
alternative hypothesis: true location shift is not equal to 0
95 percent confidence interval:
 -0.4038061  0.3425407
sample estimates:
difference in location 
           -0.03069523 
{% endhighlight %}

![](/public/{{page.id}}/lnorm.s3.s4.density.svg
"Estimated Density of Two Randomly Selected Samples from a Lognormal Distribution")

Hmmm... Ideally we would have rejected the null in this case, what is
going on?  And why does the 95% confidence interval for the estimate
includes 0?  We know the difference is 0.1.
I "forgot" to do power analysis again.  This test is not sufficiently
powered:

``` r
require(pwr)
print(power.t.test(delta=0.1, sd=sd(lnorm.s3), sig.level=0.05, power=0.8))

     Two-sample t test power calculation 

              n = 1486639
          delta = 0.1
             sd = 30.77399
      sig.level = 0.05
          power = 0.8
    alternative = two.sided

NOTE: n is number in *each* group
```

Ugh, we would need about 1.5 million samples to reliably detect an
effect the size of our small 0.1 shift.  How much can we detect with
about 50,000 samples?

``` r
print(power.t.test(n=50000, delta=NULL, sd=sd(lnorm.s3),
                   sig.level=0.05, power=0.8))

     Two-sample t test power calculation 

              n = 50000
          delta = 0.5452834
             sd = 30.77399
      sig.level = 0.05
          power = 0.8
    alternative = two.sided

NOTE: n is number in *each* group
```

### A Sufficiently Powered Test

Okay, something higher than 0.54 would work, let's use 1.0 because
that is easy to type:

``` r
lnorm.s5 <- 4000 + rlnorm(50000, 5, 0.2)
lnorm.s6 <- 4001 + rlnorm(50000, 5, 0.2)
df <- melt(data.frame(s5=lnorm.s5, s6=lnorm.s6))
colnames(df) <- c('sample', 'value')
ggplot(data=df, aes(x=value, color=sample)) + geom_density()
ggsave('lnorm.s5.s6.density.svg', width=save.width, height=save.height)
ggsave('lnorm.s5.s6.density.png', width=save.width, height=save.height)
s5.s6.w <- wilcox.test(x=lnorm.s5, y=lnorm.s6, conf.int=TRUE)
print(s5.s6.w)

	Wilcoxon rank sum test with continuity correction

data:  lnorm.s5 and lnorm.s6
W = 1220100000, p-value = 5.454e-11
alternative hypothesis: true location shift is not equal to 0
95 percent confidence interval:
 -1.6227139 -0.8759441
sample estimates:
difference in location 
             -1.249286 
```

![](/public/{{page.id}}/lnorm.s5.s6.density.svg
"Estimated Density of Two Randomly Selected Samples from a Lognormal Distribution")

It is working again!  Now we can reject the null hypothesis at the
0.01 level (p-value is much smaller than that).
The effect estimate is -1.24, and we know the test is powered enough
to detect that.
We also know (now) that the test basically estimates the location
parameter of the `x` series against the second series.

### Better Accuracy for the Test

The parameter estimate is not very accurate though, the true parameter
is -1.0, we got -1.24.  Yes, the true value falls in the 95%
confidence interval.  We can either increase the number of samples or
the effect, let's go with the effect:

``` r
lnorm.s7 <- 4000 + rlnorm(50000, 5, 0.2)
lnorm.s8 <- 4005 + rlnorm(50000, 5, 0.2)
df <- melt(data.frame(s7=lnorm.s7, s8=lnorm.s8))
colnames(df) <- c('sample', 'value')
ggplot(data=df, aes(x=value, color=sample)) + geom_density()
ggsave('lnorm.s7.s8.density.svg', width=save.width, height=save.height)
ggsave('lnorm.s7.s8.density.png', width=save.width, height=save.height)
s7.s8.w <- wilcox.test(x=lnorm.s7, y=lnorm.s8, conf.int=TRUE)
print(s7.s8.w)

	Wilcoxon rank sum test with continuity correction

data:  lnorm.s7 and lnorm.s8
W = 1136100000, p-value < 2.2e-16
alternative hypothesis: true location shift is not equal to 0
95 percent confidence interval:
 -5.110127 -4.367495
sample estimates:
difference in location 
             -4.738913 
```

![](/public/{{page.id}}/lnorm.s7.s8.density.svg
"Estimated Density of Two Randomly Selected Samples from a Lognormal Distribution")

I think the lesson here is that for better estimates of the parameter
you need to have a sample count much higher than the minimum required
to detect that effect size.

### Testing with Mixed Distributions

So far we have been using a very simple Lognormal distribution, I
know the test data is more difficult than this, I rejected a number of
standard distributions in the [previous]({{page.previous.url}}) post.

First we create a function to generate random samples from a mix of
distributions:

``` r
rmixed <- function(n, shape=0.2, scale=2000) {
    g1 <- rlnorm(0.7*n, sdlog=shape)
    g2 <- 1.0 + rlnorm(0.2*n, sdlog=shape)
    g3 <- 3.0 + rlnorm(0.1*n, sdlog=shape)
    v <- scale * append(append(g1, g2), g3)
    ## Generate a random permutation, otherwise g1, g2, and g3 are in
    ## order in the vector
    return(sample(v))
}

## Let's first get some samples from this distribution ...
mixed.test <- 1000 + rmixed(20000)
qplot(x=mixed.test, color=factor("mixed.test"), geom="density")
```

![](/public/{{page.id}}/mixed.test.density.svg
"Estimated Density of Randomly Selected Samples from a Mixed Distribution")

That is more interesting, admittedly not as difficult as the
distribution from our benchmarks, but at least not trivial.
I would like to know how many samples to take to measure an effect of
$$50$$, which requires computing the standard deviation of the mixed
distribution.


## Notes

The data for this post was generated using the
[driver script]({{ghver}}/jb/itch5/bm_order_book_generate.sh)
for the order book benchmark,
with the
[{{ghsha}}](https://github.com/coryan/jaybeams/tree/{{ghsha}})
version of JayBeams.
The data thus generated was processed with a small R
[script](/public/{{page.id}}/generate-graphs.R) to perform the
statistical analysis and generate the graphs shown in this post.
The R script as well as the
[data](/public/{{page.id}}/data.csv) used here are available for
download through the links.

Metadata about the tests, including platform details can be found in
comments embedded with the data file.
The highlights of that metadata is reproduced here:

* CPU: AMD A8-3870 CPU @ 3.0Ghz
* Memory: 16GiB DDR3 @ 1333 Mhz, in 4 DIMMs.
* Operating System: Linux (Fedora 23, 4.8.13-100.fc23.x86_64)
* C Library: glibc 2.22
* C++ Library: libstdc++-5.3.1-6.fc23.x86_64
* Compiler: gcc 5.3.1 20160406
* Compiler Options: -O3 -ffast-math -Wall -Wno-deprecated-declarations

The data and graphs in the
[Appendix](#appendix-familiarizing-with-the-mann-whitney-test)
is randomly generated, the reader will not get the same results I did
when executing the script to generate those graphs.
