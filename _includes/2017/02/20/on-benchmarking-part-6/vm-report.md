## Report for vm-results.csv




We load the file, which has a well-known name, into a `data.frame`
structure:


{% highlight r %}
data <- read.csv(
    file=data.filename, header=FALSE, comment.char='#',
    col.names=c('book_type', 'nanoseconds'))
{% endhighlight %}

The raw data is in nanoseconds, I prefer microseconds because they are
easier to think about:


{% highlight r %}
data$microseconds <- data$nanoseconds / 1000.0
{% endhighlight %}

We also annotate the data with a sequence number, so we can plot the
sequence of values:


{% highlight r %}
data$idx <- ave(
    data$microseconds, data$book_type, FUN=seq_along)
{% endhighlight %}

At this point I am curious as to how the data looks like, and probably
you too, first just the usual summary:


{% highlight r %}
data.summary <- aggregate(
    microseconds ~ book_type, data=data, FUN=summary)
kable(cbind(
    as.character(data.summary$book_type),
    data.summary$microseconds))
{% endhighlight %}



|      |Min. |1st Qu. |Median |Mean |3rd Qu. |Max.  |
|:-----|:----|:-------|:------|:----|:-------|:-----|
|array |237  |327     |407    |456  |529     |15400 |
|map   |637  |890     |1020   |1080 |1220    |17700 |

Then we visualize the density functions, if the data had extreme tails
or other artifacts we would rejects it:


{% highlight r %}
ggplot(data=data, aes(x=microseconds, color=book_type)) +
    theme(legend.position="bottom") +
    facet_grid(book_type ~ .) + stat_density()
{% endhighlight %}

![plot of chunk unnamed-chunk-5](/public/2017/02/20/on-benchmarking-part-6/vm/unnamed-chunk-5-1.svg)

We also examine the boxplots of the data:


{% highlight r %}
ggplot(data=data,
       aes(y=microseconds, x=book_type, color=book_type)) +
    theme(legend.position="bottom") + geom_boxplot()
{% endhighlight %}

![plot of chunk unnamed-chunk-6](/public/2017/02/20/on-benchmarking-part-6/vm/unnamed-chunk-6-1.svg)

### Check Assumptions: Validate the Data is Independent

I inspect the data in case there are obvious problems with
independence of the samples.
Output as PNG files.  While SVG files look better in a web page, large
SVG files tend to crash browsers.


{% highlight r %}
ggplot(data=data,
       aes(x=idx, y=microseconds, color=book_type)) +
    theme(legend.position="bottom") +
    facet_grid(book_type ~ .) + geom_point()
{% endhighlight %}

![plot of chunk unnamed-chunk-7](/public/2017/02/20/on-benchmarking-part-6/vm/unnamed-chunk-7-1.png)

I would like an analytical test to validate the samples are
indepedent,
a visual inspection of the data may help me detect obvious problems,
but I may miss more subtle issues.
For this part of the analysis it is easier to separate the data by
book type, so we create two timeseries for them:


{% highlight r %}
data.array.ts <- ts(
    subset(data, book_type == 'array')$microseconds)
data.map.ts <- ts(
    subset(data, book_type == 'map')$microseconds)
{% endhighlight %}

Plot the correlograms:


{% highlight r %}
acf(data.array.ts)
{% endhighlight %}

![plot of chunk unnamed-chunk-9](/public/2017/02/20/on-benchmarking-part-6/vm/unnamed-chunk-9-1.svg)

{% highlight r %}
acf(data.map.ts)
{% endhighlight %}

![plot of chunk unnamed-chunk-9](/public/2017/02/20/on-benchmarking-part-6/vm/unnamed-chunk-9-2.svg)

Compute the maximum auto-correlation factor, ignore the first value,
because it is the auto-correlation at lag 0, which is always 1.0:


{% highlight r %}
max.acf.array <- max(abs(
    tail(acf(data.array.ts, plot=FALSE)$acf, -1)))
max.acf.map <- max(abs(
    tail(acf(data.map.ts, plot=FALSE)$acf, -1)))
{% endhighlight %}

I think any value higher than $$0.05$$ indicates that the samples are
not truly independent:


{% highlight r %}
max.autocorrelation <- 0.05
if (max.acf.array >= max.autocorrelation |
    max.acf.map >= max.autocorrelation) {
    warning("Some evidence of auto-correlation in ",
         "the samples max.acf.array=",
         round(max.acf.array, 4),
         ", max.acf.map=",
         round(max.acf.map, 4))
} else {
    cat("PASSED: the samples do not exhibit high auto-correlation")
}
{% endhighlight %}



{% highlight text %}
## Warning: Some evidence of auto-correlation in the samples
## max.acf.array=0.0964, max.acf.map=0.256
{% endhighlight %}

I am going to proceed, even though the data on virtual machines tends
to have high auto-correlation.

### Power Analysis: Estimate Standard Deviation

Use bootstraping to estimate the standard deviation, we are going to
need a function to execute in the bootstrapping procedure:


{% highlight r %}
sd.estimator <- function(D,i) {
    return(sd(D[i,'microseconds']));
}
{% endhighlight %}

Because this can be slow, we use all available cores:


{% highlight r %}
core.count <- detectCores()
b.array <- boot(
    data=subset(data, book_type == 'array'), R=10000,
    statistic=sd.estimator,
    parallel="multicore", ncpus=core.count)
plot(b.array)
{% endhighlight %}

![plot of chunk unnamed-chunk-13](/public/2017/02/20/on-benchmarking-part-6/vm/unnamed-chunk-13-1.png)

{% highlight r %}
ci.array <- boot.ci(
    b.array, type=c('perc', 'norm', 'basic'))

b.map <- boot(
    data=subset(data, book_type == 'map'), R=10000,
    statistic=sd.estimator,
    parallel="multicore", ncpus=core.count)
plot(b.map)
{% endhighlight %}

![plot of chunk unnamed-chunk-13](/public/2017/02/20/on-benchmarking-part-6/vm/unnamed-chunk-13-2.png)

{% highlight r %}
ci.map <- boot.ci(
    b.map, type=c('perc', 'norm', 'basic'))
{% endhighlight %}

We need to verify that the estimated statistic roughly follows a
normal distribution, otherwise the bootstrapping procedure would
require a lot more memory than we have available:
The Q-Q plots look reasonable, so we can estimate the standard
deviation using a simple procedure:


{% highlight r %}
estimated.sd <- ceiling(max(
    ci.map$percent[[4]], ci.array$percent[[4]],
    ci.map$basic[[4]], ci.array$basic[[4]],
    ci.map$normal[[3]], ci.array$normal[[3]]))
cat(estimated.sd)
{% endhighlight %}



{% highlight text %}
## 396
{% endhighlight %}

### Power Analysis: Determine Required Number of Samples

We need to determine if the sample size was large enough given the
estimated standard deviation, the expected effect size, and the
statistical test we are planning to use.

The is the minimum effect size that we could be interested in is based
on saving at least one cycle per operation in the classes we are
measuring.

The test executes 20,000 iterations:


{% highlight r %}
test.iterations <- 20000
{% endhighlight %}

and we assume that the clock cycle is approximately 3Ghz:


{% highlight r %}
clock.ghz <- 3
{% endhighlight %}

We can use this to compute the minimum interesting effect:


{% highlight r %}
min.delta <- 1.0 / (clock.ghz * 1000.0) * test.iterations
cat(min.delta)
{% endhighlight %}



{% highlight text %}
## 6.667
{% endhighlight %}

That is, any result smaller than 6.6667 microseconds would not
be interesting and should be rejected.
We need a few more details to compute the minimum number of samples,
first, the desired significance of any results, which we set to:


{% highlight r %}
desired.significance <- 0.01
{% endhighlight %}

Then, the desired statistical power of the test, which we set to:


{% highlight r %}
desired.power <- 0.95
{% endhighlight %}

We are going to use a non-parametric test, which has a 15% overhead
above the t-test:


{% highlight r %}
nonparametric.extra.cost <- 1.15
{% endhighlight %}

In any case, we will require at least 5000 iterations, because it is
relatively fast to run that many:


{% highlight r %}
min.samples <- 5000
{% endhighlight %}

If we do not have enough power to detect 10 times the minimum effect
we abort the analysis, while if we do not have enough samples to
detect the minimum effect we simply generate warnings:


{% highlight r %}
required.pwr.object <- power.t.test(
    delta=10 * min.delta, sd=estimated.sd,
    sig.level=desired.significance, power=desired.power)
print(required.pwr.object)
{% endhighlight %}



{% highlight text %}
## 
##      Two-sample t test power calculation 
## 
##               n = 1259
##           delta = 66.67
##              sd = 396
##       sig.level = 0.01
##           power = 0.95
##     alternative = two.sided
## 
## NOTE: n is number in *each* group
{% endhighlight %}

We are going to round the number of iterations to the next higher
multiple of 1000, because it is easier to type, say, and reason about
nice round numbers:



{% highlight r %}
required.nsamples <- max(
    min.samples, 1000 * ceiling(nonparametric.extra.cost *
                                required.pwr.object$n / 1000))
cat(required.nsamples)
{% endhighlight %}



{% highlight text %}
## 5000
{% endhighlight %}

That is, we need 5000 samples to detect an effect of 
66.67 microseconds at the desired significance
and power levels.


{% highlight r %}
if (required.nsamples > length(data.array.ts)) {
    stop("Not enough samples in 'array' data to",
         " detect expected effect (",
         10 * min.delta,
         ") should be >=", required.nsamples,
         " actual=", length(array.map.ts))
}
if (required.nsamples > length(data.map.ts)) {
    stop("Not enough samples in 'map' data to",
         " detect expected effect (",
         10 * min.delta,
         ") should be >=", required.nsamples,
         " actual=", length(map.map.ts))
}
{% endhighlight %}



{% highlight r %}
desired.pwr.object <- power.t.test(
    delta=min.delta, sd=estimated.sd,
    sig.level=desired.significance, power=desired.power)
desired.nsamples <- max(
    min.samples, 1000 * ceiling(nonparametric.extra.cost *
                                desired.pwr.object$n / 1000))
print(desired.pwr.object)
{% endhighlight %}



{% highlight text %}
## 
##      Two-sample t test power calculation 
## 
##               n = 125711
##           delta = 6.667
##              sd = 396
##       sig.level = 0.01
##           power = 0.95
##     alternative = two.sided
## 
## NOTE: n is number in *each* group
{% endhighlight %}

That is, we need at least 145000
samples to detect the minimum interesting effect of 6.6667
microseconds.
Notice that our tests have 100000 samples.


{% highlight r %}
if (desired.nsamples > length(data.array.ts) |
    desired.nsamples > length(data.map.ts)) {
    warning("Not enough samples in the data to",
            " detect the minimum interating effect (",
            round(min.delta, 2), ") should be >= ",
            desired.nsamples,
            " map-actual=", length(data.map.ts),
            " array-actual=", length(data.array.ts))
} else {
    cat("PASSED: The samples have the minimum required power")
}
{% endhighlight %}



{% highlight text %}
## Warning: Not enough samples in the data to detect the
## minimum interating effect (6.67) should be >= 145000 map-
## actual=100000 array-actual=100000
{% endhighlight %}

### Run the Statistical Test

We are going to use the
[Mann-Whitney U test](https://en.wikipedia.org/wiki/Mann%E2%80%93Whitney_U_test)
to analyze the results:


{% highlight r %}
data.mw <- wilcox.test(
    microseconds ~ book_type, data=data, conf.int=TRUE)
estimated.delta <- data.mw$estimate
{% endhighlight %}

The estimated effect is -600.7931 microseconds, if this
number is too small we need to stop the analysis:


{% highlight r %}
if (abs(estimated.delta) < min.delta) {
    stop("The estimated effect is too small to",
         " draw any conclusions.",
         " Estimated effect=", estimated.delta,
         " minimum effect=", min.delta)
} else {
    cat("PASSED: the estimated effect (",
        round(estimated.delta, 2),
        ") is large enough.")
}
{% endhighlight %}



{% highlight text %}
## PASSED: the estimated effect ( -600.8 ) is large enough.
{% endhighlight %}

Finally, the p-value determines if we can reject the null hypothesis
at the desired significance.
In our case, failure to reject means that we do not have enough
evidence to assert that the `array_based_order_book` is faster or
slower than `map_based_order_book`.
If we do reject the null hypothesis then we can use the
[Hodges-Lehmann estimator](
https://en.wikipedia.org/wiki/Hodges%E2%80%93Lehmann_estimator)
to size the difference in performance,
aka the *effect* of our code changes.


{% highlight r %}
if (data.mw$p.value >= desired.significance) {
    cat("The test p-value (", round(data.mw$p.value, 4),
        ") is larger than the desired\n",
        "significance level of alpha=",
        round(desired.significance, 4), "\n", sep="")
    cat("Therefore we CANNOT REJECT the null hypothesis",
        " that both the 'array'\n",
        "and 'map' based order books have the same",
        " performance.\n", sep="")
} else {
    interval <- paste0(
        round(data.mw$conf.int, 2), collapse=',')
    cat("The test p-value (", round(data.mw$p.value, 4),
        ") is smaller than the desired\n",
        "significance level of alpha=",
        round(desired.significance, 4), "\n", sep="")
    cat("Therefore we REJECT the null hypothesis that",
        " both the\n",
        " 'array' and 'map' based order books have\n",
        "the same performance.\n", sep="")
    cat("The effect is quantified using the Hodges-Lehmann\n",
        "estimator, which is compatible with the\n",
        "Mann-Whitney U test, the estimator value\n",
        "is ", round(data.mw$estimate, 2),
        " microseconds with a 95% confidence\n",
        "interval of [", interval, "]\n", sep="")
}
{% endhighlight %}



{% highlight text %}
## The test p-value (0) is smaller than the desired
## significance level of alpha=0.01
## Therefore we REJECT the null hypothesis that both the
##  'array' and 'map' based order books have
## the same performance.
## The effect is quantified using the Hodges-Lehmann
## estimator, which is compatible with the
## Mann-Whitney U test, the estimator value
## is -600.8 microseconds with a 95% confidence
## interval of [-602.48,-599.11]
{% endhighlight %}

### Mini-Colophon

This report was generated using [`knitr`](https://yihui.name/knitr/)
the details of the R environment are:


{% highlight r %}
library(devtools)
devtools::session_info()
{% endhighlight %}



{% highlight text %}
## Session info -----------------------------------------------
{% endhighlight %}



{% highlight text %}
##  setting  value                       
##  version  R version 3.2.3 (2015-12-10)
##  system   x86_64, linux-gnu           
##  ui       X11                         
##  language (EN)                        
##  collate  C                           
##  tz       Zulu                        
##  date     2017-02-20
{% endhighlight %}



{% highlight text %}
## Packages ---------------------------------------------------
{% endhighlight %}



{% highlight text %}
##  package    * version date       source        
##  Rcpp         0.12.3  2016-01-10 CRAN (R 3.2.3)
##  boot       * 1.3-17  2015-06-29 CRAN (R 3.2.1)
##  colorspace   1.2-4   2013-09-30 CRAN (R 3.1.0)
##  devtools   * 1.12.0  2016-12-05 CRAN (R 3.2.3)
##  digest       0.6.9   2016-01-08 CRAN (R 3.2.3)
##  evaluate     0.10    2016-10-11 CRAN (R 3.2.3)
##  ggplot2    * 2.0.0   2015-12-18 CRAN (R 3.2.3)
##  gtable       0.1.2   2012-12-05 CRAN (R 3.0.0)
##  highr        0.6     2016-05-09 CRAN (R 3.2.3)
##  httpuv       1.3.3   2015-08-04 CRAN (R 3.2.3)
##  knitr      * 1.15.1  2016-11-22 CRAN (R 3.2.3)
##  labeling     0.3     2014-08-23 CRAN (R 3.1.1)
##  magrittr     1.5     2014-11-22 CRAN (R 3.2.1)
##  memoise      1.0.0   2016-01-29 CRAN (R 3.2.3)
##  munsell      0.4.2   2013-07-11 CRAN (R 3.0.2)
##  plyr         1.8.3   2015-06-12 CRAN (R 3.2.1)
##  pwr        * 1.2-0   2016-08-24 CRAN (R 3.2.3)
##  reshape2     1.4     2014-04-23 CRAN (R 3.1.0)
##  scales       0.3.0   2015-08-25 CRAN (R 3.2.3)
##  servr        0.5     2016-12-10 CRAN (R 3.2.3)
##  stringi      1.0-1   2015-10-22 CRAN (R 3.2.2)
##  stringr      1.0.0   2015-04-30 CRAN (R 3.2.2)
##  withr        1.0.2   2016-06-20 CRAN (R 3.2.3)
{% endhighlight %}
