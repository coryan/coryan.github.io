#!/usr/bin/env Rscript
require(ggplot2)

## ... make the graphs look pretty ...
golden.ratio <- (1+sqrt(5))/2
svg.w <- 8.0
svg.h <- svg.w / golden.ratio
png.w <- 960
png.h <- round(png.w / golden.ratio)

## Get the command line arguments ...
args <- commandArgs(trailingOnly=TRUE)
download <- FALSE
if (length(args) > 0 & args[1] == 'download') {
    download <- TRUE
}

## ... by default load the data from the GitHub pages site ...
url <- 'http://coryan.github.io/public/2017/02/04/on-benchmarking-part-5/'
ni.filename <- 'data-ni.csv'
data.filename <- 'data.csv'
if (download) {
    ni.filename <- paste0(url, ni.filename)
    data.filename <- paste0(url, data.filename)
}

## ... then just load the data...
ni <- read.csv(
    file=ni.filename, header=FALSE, comment.char='#',
    col.names=c('book_type', 'nanoseconds'))

## ... I prefer microseconds because they are easier to think about ...
ni$microseconds <- ni$nanoseconds / 1000.0
ni$idx <- ave(ni$microseconds, ni$book_type, FUN=seq_along)

## ... generate the density graph so we can visualize the data ...
ggplot(data=ni, aes(x=microseconds, color=book_type)) +
    geom_density() + theme(legend.position="bottom")
ggsave(width=svg.w, heigh=svg.h, filename='noni.density.svg')
ggsave(width=svg.w, heigh=svg.h, filename='noni.density.png')

## ... kind of looks random to me ...
ggplot(data=ni, aes(x=idx, y=microseconds, color=book_type)) +
    theme(legend.position="bottom") + facet_grid(book_type ~ .) + geom_point()
ggsave(width=svg.w, heigh=svg.h, filename='noni.plot.svg')
ggsave(width=svg.w, heigh=svg.h, filename='noni.plot.png')

## ... but really it is not, lots of auto-correlation ...
ni.array.ts <- ts(subset(ni, book_type == 'array')$microseconds)
ni.map.ts <- ts(subset(ni, book_type == 'map')$microseconds)

par(mfrow=c(2,1))
acf(ni.array.ts)
acf(ni.map.ts)

svg(width=svg.w, height=svg.h, filename='noni.acf.svg')
par(mfrow=c(2,1))
acf(ni.array.ts)
acf(ni.map.ts)
dev.off()

png(width=png.w, height=png.h, filename='noni.acf.png')
par(mfrow=c(2,1))
acf(ni.array.ts)
acf(ni.map.ts)
dev.off()

## ... after the code changes, how does it look? ...
data <- read.csv(
    file=data.filename, header=FALSE, comment.char='#',
    col.names=c('book_type', 'nanoseconds'))

## ... I prefer microseconds because they are easier to think about ...
data$microseconds <- data$nanoseconds / 1000.0
data$idx <- ave(data$microseconds, data$book_type, FUN=seq_along)
data$ts <- ave(data$microseconds, data$book_type, FUN=cumsum)

summary(data)

## ... generate the density graph so we can visualize the data ...
ggplot(data=data, aes(x=microseconds, color=book_type)) +
    geom_density() + theme(legend.position="bottom")
ggsave(width=svg.w, heigh=svg.h, filename='data.density.svg')
ggsave(width=svg.w, heigh=svg.h, filename='data.density.png')

## ... kind of looks random to me ...
ggplot(data=data, aes(x=idx, y=microseconds, color=book_type)) +
    theme(legend.position="bottom") + facet_grid(book_type ~ .) + geom_point()
ggsave(width=svg.w, heigh=svg.h, filename='data.plot.svg')
ggsave(width=svg.w, heigh=svg.h, filename='data.plot.png')

## ... but really it is not, lots of auto-correlation ...
data.array.ts <- ts(subset(data, book_type == 'array')$microseconds)
data.map.ts <- ts(subset(data, book_type == 'map')$microseconds)

par(mfrow=c(2,1))
acf(data.array.ts)
acf(data.map.ts)

svg(width=svg.w, height=svg.h, filename='data.acf.svg')
par(mfrow=c(2,1))
acf(data.array.ts)
acf(data.map.ts)
dev.off()

png(width=png.w, height=png.h, filename='data.acf.png')
par(mfrow=c(2,1))
acf(data.array.ts)
acf(data.map.ts)
dev.off()

max(abs(tail(acf(data.array.ts)$acf, -1)))
max(abs(tail(acf(data.map.ts)$acf, -1)))

round(max(abs(tail(acf(data.array.ts)$acf, -1))), 2)
round(max(abs(tail(acf(data.map.ts)$acf, -1))), 2)

##
## Run the Mann-Whitney U test for the data
##

## ... verify the effect is large enough ...
require(DescTools)
data.hl <- HodgesLehmann(x=subset(data, book_type=='array')$microseconds,
                         y=subset(data, book_type=='map')$microseconds,
                         conf.level=0.95)
print(data.hl)

## ... verify the standard deviation is within range ...
require(boot)
data.array.sd.boot <- boot(data=subset(data, book_type=='array')$microseconds, R=10000, statistic=function(d, i) sd(d[i]))
data.array.sd.ci <- boot.ci(data.array.sd.boot, type=c('perc', 'norm', 'basic'))
print(data.array.sd.ci)

data.map.sd.boot <- boot(data=subset(data, book_type=='map')$microseconds, R=10000, statistic=function(d, i) sd(d[i]))
data.map.sd.ci <- boot.ci(data.map.sd.boot, type=c('perc', 'norm', 'basic'))
print(data.map.sd.ci)

## ... run the Mann-Whitney U test ...
data.mw <- wilcox.test(microseconds ~ book_type, data=data)
print(data.mw)



##
## Next we explore how the Mann-Whitney U test works (and breaks).
##

## Start with a simple distribution:
lnorm.s1 <- rlnorm(50000, 5, 0.2)
qplot(x=lnorm.s1, geom="density", color=factor("s1"))

ggsave('lnorm.s1.density.svg', width=svg.w, height=svg.h)
ggsave('lnorm.s1.density.png', width=svg.w, height=svg.h)

## ... the first question would be: what happens when you test a
## sample against itself?  Hopefully our test says "you cannot reject
## the null" ...
s1.w <- wilcox.test(x=lnorm.s1, lnorm.s1, conf.int=TRUE)

## ... we can print several fields of the test results ...
print(paste0("The p-value is ", round(s1.w$p.value, 2)))
print(paste0("The location shift estimate is ", round(s1.w$estimate, 2)))
print(paste0("The confidence interval for the location shift estimate is ", paste(round(s1.w$conf.int, 2), collapse=", ")))

## ... or just the full test result ...
print(s1.w)

## ... Okay that was obvious, what about comparing against another
## sample from the same distribution?  Take a second sample ..
lnorm.s2 <- rlnorm(50000, 5, 0.2)
require(reshape2)
df <- melt(data.frame(s1=lnorm.s1, s2=lnorm.s2))
colnames(df) <- c('sample', 'value')
ggplot(data=df, aes(x=value, color=sample)) + geom_density()

ggsave('lnorm.s1.s2.density.svg', width=svg.w, height=svg.h)
ggsave('lnorm.s1.s2.density.png', width=svg.w, height=svg.h)

## ... run the test again ...
w.s1.s2 <- wilcox.test(x=lnorm.s1, y=lnorm.s2, conf.int=TRUE)
print(w.s1.s2)

## What about a more complicated case, say we have two similar
## distributions with different location parameters?  First create two
## samples with really tiny differences in the location parameter:
lnorm.s3 <- 4000.0 + rlnorm(50000, 5, 0.2)
lnorm.s4 <- 4000.1 + rlnorm(50000, 5, 0.2)
df <- melt(data.frame(s3=lnorm.s3, s4=lnorm.s4))
colnames(df) <- c('sample', 'value')
ggplot(data=df, aes(x=value, color=sample)) + geom_density()
ggsave('lnorm.s3.s4.density.svg', width=svg.w, height=svg.h)
ggsave('lnorm.s3.s4.density.png', width=svg.w, height=svg.h)
w.s3.s4 <- wilcox.test(x=lnorm.s3, y=lnorm.s4, conf.int=TRUE)
print(w.s3.s4)

## ... we cannot reject the null hypothesis.  In fact, the confidence
## interval includes 0 (the null hypothesis is that the difference in
## location is 0).
## Why does it fail?  The test is not powered enough, we are using
## 50,000 samples, but the effect is just 0.1, if we check the
## required number of samples would be:
require(pwr)
print(power.t.test(delta=0.1, sd=sd(lnorm.s3), sig.level=0.05, power=0.8))

## So we need about 1.5 million samples to reliably detect such a
## small effect, even at the relatively relaxed significance level of
## 0.05 and low power of 0.8.

## How much of a delta could we reliably detect with the given number of
## samples:
print(power.t.test(n=50000, delta=NULL, sd=sd(lnorm.s3),
                   sig.level=0.05, power=0.8))

## Okay, that is not too bad, anything over 0.6 would be a big enough
## effect. Let's use 1.0 and find out what happens when we apply this ...
lnorm.s5 <- 4000 + rlnorm(50000, 5, 0.2)
lnorm.s6 <- 4001 + rlnorm(50000, 5, 0.2)
df <- melt(data.frame(s5=lnorm.s5, s6=lnorm.s6))
colnames(df) <- c('sample', 'value')
ggplot(data=df, aes(x=value, color=sample)) + geom_density()
ggsave('lnorm.s5.s6.density.svg', width=svg.w, height=svg.h)
ggsave('lnorm.s5.s6.density.png', width=svg.w, height=svg.h)
s5.s6.w <- wilcox.test(x=lnorm.s5, y=lnorm.s6, conf.int=TRUE)
print(s5.s6.w)

## That is nice, notice that the parameter estimate is not very
## accurate (0.8 vs 1.0), but the correct value falls within the
## confidence interval.  We can try with a larger difference to see
## what happens:
lnorm.s7 <- 4000 + rlnorm(50000, 5, 0.2)
lnorm.s8 <- 4005 + rlnorm(50000, 5, 0.2)
df <- melt(data.frame(s7=lnorm.s7, s8=lnorm.s8))
colnames(df) <- c('sample', 'value')
ggplot(data=df, aes(x=value, color=sample)) + geom_density()
ggsave('lnorm.s7.s8.density.svg', width=svg.w, height=svg.h)
ggsave('lnorm.s7.s8.density.png', width=svg.w, height=svg.h)
s7.s8.w <- wilcox.test(x=lnorm.s7, y=lnorm.s8, conf.int=TRUE)
print(s7.s8.w)

## Great, that is a much better estimate.

## So far we have been using a fairly tame distribution, we know the
## distributions in the wild are far less well behaved.  Let's quickly
## confirm that what we are about to try works well for them.

## Create random samples from a mixed distribution of 3 lognormals...
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
ggsave('mixed.test.density.svg', width=svg.w, height=svg.h)
ggsave('mixed.test.density.png', width=svg.w, height=svg.h)

## ... and use that sample to estimate the standard deviation via
## bootstrapping ...
require(boot)
mixed.boot <- boot(data=mixed.test, R=10000,
                   statistic=function(d, i) sd(d[i]))
plot(mixed.boot)
svg(filename="mixed.boot.svg", width=svg.w, height=svg.h)
plot(mixed.boot)
dev.off()
png(filename="mixed.boot.png", width=png.w, height=png.h)
plot(mixed.boot)
dev.off()

## ... the plots look Okay, so we compute the confidence intervals ...
mixed.ci <- boot.ci(mixed.boot, type=c('perc', 'norm', 'basic'))
print(mixed.ci)
## ... and pick the worst case for the estimate ...
mixed.sd <- ceiling(max(mixed.ci$normal[[3]], mixed.ci$basic[[4]],
                        mixed.ci$percent[[4]]))
print(mixed.sd)

## ... with the confidence interval at hand we compute the number of
## samples required to achieve the desired power and significance
## level ...
mixed.pw <- power.t.test(delta=50, sd=mixed.sd, sig.level=0.01, power=0.95)
print(mixed.pw)
nsamples <- ceiling(1.15 * mixed.pw$n / 1000) * 1000
print(nsamples)

## ... create two samples with the mixed distribution ...
mixed.s1 <- 1000 + rmixed(nsamples)
mixed.s2 <- 1050 + rmixed(nsamples)

df <- melt(data.frame(s1=mixed.s1, s2=mixed.s2))
colnames(df) <- c('sample', 'value')
ggplot(data=df, aes(x=value, color=sample)) + geom_density()
ggsave('mixed.s1.s2.svg', width=svg.w, height=svg.h)
ggsave('mixed.s1.s2.png', width=svg.w, height=svg.h)

## ... we can then compute the Mann-Whitney test ...

mixed.w <- wilcox.test(x=mixed.s1, y=mixed.s2, conf.int=TRUE)
print(mixed.w)

## ... that might seem overly complicated, why not the difference of
## means or medians ...
mean(mixed.s1) - mean(mixed.s2)
median(mixed.s1) - median(mixed.s2)

## Create a more complex distribution to demonstrate what happens when
## the change is not just a location parameter ...
rcomplex <- function(n, scale=2000,
                     s1=0.2, l1=0, s2=0.2, l2=1.0, s3=0.2, l3=3.0) {
    g1 <- l1 + rlnorm(0.75*n, sdlog=s1)
    g2 <- l2 + rlnorm(0.20*n, sdlog=s2)
    g3 <- l3 + rlnorm(0.05*n, sdlog=s3)
    v <- scale * append(append(g1, g2), g3)
    ## Generate a random permutation, otherwise g1, g2, and g3 are in
    ## order in the vector
    return(sample(v))
}
complex.s1 <-  950 + rcomplex(nsamples, scale=1500, l3=5.0)
complex.s2 <- 1000 + rcomplex(nsamples)

df <- melt(data.frame(s1=complex.s1, s2=complex.s2))
colnames(df) <- c('sample', 'value')
ggplot(data=df, aes(x=value, color=sample)) +
    theme(legend.position="bottom") + geom_density()
ggsave('complex.s1.s2.svg', width=svg.w, height=svg.h)
ggsave('complex.s1.s2.png', width=svg.w, height=svg.h)

aggregate(value ~ sample, data=df, FUN=sd)

complex.w <- wilcox.test(value ~ sample, data=df, conf.int=TRUE)
print(complex.w)

HodgesLehmann(x=complex.s1, y=complex.s2, conf.level=0.95)

ggplot(data=df, aes(x=value, color=sample)) +
    theme(legend.position="bottom") + stat_ecdf()

require(DescTools)
df.s1.s2 <- df
median.s1.s2 <- aggregate(value ~ sample, data=df.s1.s2, FUN=median)
mean.s1.s2 <- aggregate(value ~ sample, data=df.s1.s2, FUN=mean)
hl.s1.s2 <- aggregate(value ~ sample, data=df.s1.s2, FUN=HodgesLehmann)

ggplot(data=df.s1.s2, aes(x=value, color=sample)) + stat_ecdf() +
    theme(legend.position="bottom") +
    guides(shape=guide_legend("Location Parameter")) +
    geom_point(data=median.s1.s2,
               aes(x=value, y=0, color=sample, shape="median"),
               size=2.5, alpha=0.7) +
    geom_point(data=mean.s1.s2,
               aes(x=value, y=0, color=sample, shape="mean"),
               size=2.5, alpha=0.7) +
    geom_point(data=hl.s1.s2,
               aes(x=value, y=0, color=sample, shape="HL"),
               size=2.5, alpha=0.7)

ggsave('complex.ecdf.s1.s2.svg', width=svg.w, height=svg.h)
ggsave('complex.ecdf.s1.s2.png', width=svg.w, height=svg.h)

d <- sample(complex.s1) - sample(complex.s2)
qplot(x=d, geom="density") +
    theme(legend.position="bottom") +
    geom_point(aes(x=median(d), y=0, shape="HL"), size=2.7, color="blue")
ggsave('complex.diff.s1.s2.svg', width=svg.w, height=svg.h)
ggsave('complex.diff.s1.s2.png', width=svg.w, height=svg.h)

###
### Appendix: Learning about the Hodges-Lehmann Estimator
###
require(DescTools)
require(ggplot2)
routlier <- function(n, scale=2000,
                     s1=0.2, l1=0, s2=0.1, l2=1.0, fraction=0.01) {
    g1 <- l1 + rlnorm((1.0 - fraction)*n, sdlog=s1)
    g2 <- l2 + rlnorm(fraction*n, sdlog=s2)
    v <- scale * append(g1, g2)
    return(sample(v))
}

o1 <- routlier(20000, l2=0.5)
o2 <- routlier(20000, l2=2)

require(reshape2)
df <- melt(data.frame(o1=o1, o2=o2))
colnames(df) <- c('sample', 'value')
mean.o1.o2 <- aggregate(value ~ sample, data=df, FUN=mean)
median.o1.o2 <- aggregate(value ~ sample, data=df, FUN=median)
## hl.o1.o2 <- aggregate(value ~ sample, data=df, FUN=HodgesLehmann)

ggplot(data=df, aes(x=value, color=sample)) +
    theme(legend.position="bottom") + geom_density() +
    geom_point(data=median.o1.o2,
               aes(x=value, y=0, color=sample, shape="median"),
               size=2.5, alpha=0.7) +
    geom_point(data=mean.o1.o2,
               aes(x=value, y=0, color=sample, shape="mean"),
               size=2.5, alpha=0.7)

ggsave('density.o1.o2.svg', width=svg.w, height=svg.h)
ggsave('density.o1.o2.png', width=svg.w, height=svg.h)


print(mean(o1) - mean(o2))
print(median(o1) - median(o2))
print(HodgesLehmann(o1, o2))
print(HodgesLehmann(o2) - HodgesLehmann(o1))

mean.s1.s2 <- aggregate(value ~ sample, data=df.s1.s2, FUN=mean)


ggplot(data=df.s1.s2, aes(x=value, color=sample)) + stat_ecdf() +
    theme(legend.position="bottom") +
    guides(shape=guide_legend("Location Parameter")) +
    geom_point(data=median.s1.s2,
               aes(x=value, y=0, color=sample, shape="median"),
               size=2.5, alpha=0.7) +
    geom_point(data=mean.s1.s2,
               aes(x=value, y=0, color=sample, shape="mean"),
               size=2.5, alpha=0.7) +
    geom_point(data=hl.s1.s2,
               aes(x=value, y=0, color=sample, shape="HL"),
               size=2.5, alpha=0.7)


### Difference of Medians

o3 <- routlier(20000, l2=2.0, fraction=0.49)
o4 <- routlier(20000, l2=4.0, fraction=0.49)

df <- melt(data.frame(o3=o3, o4=o4))
colnames(df) <- c('sample', 'value')
mean.o3.o4 <- aggregate(value ~ sample, data=df, FUN=mean)
median.o3.o4 <- aggregate(value ~ sample, data=df, FUN=median)
hl.o3.o4 <- aggregate(value ~ sample, data=df, FUN=HodgesLehmann)

ggplot(data=df, aes(x=value, color=sample)) +
    theme(legend.position="bottom") + geom_density() +
    geom_point(data=median.o3.o4,
               aes(x=value, y=0, color=sample, shape="median"),
               size=3, alpha=0.6) +
    geom_point(data=mean.o3.o4,
               aes(x=value, y=0, color=sample, shape="mean"),
               size=3, alpha=0.6)

ggsave('density.o3.o4.svg', width=svg.w, height=svg.h)
ggsave('density.o3.o4.png', width=svg.w, height=svg.h)

print(median(o3) - median(o4))
print(HodgesLehmann(o3, o4))

qplot(x=sample(o3) - sample(o4), geom="density")

ls()

q(save='no')
