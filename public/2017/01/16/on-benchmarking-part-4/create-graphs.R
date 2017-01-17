#!/usr/bin/env Rscript
require(ggplot2)
require(boot)
require(pwr)
require(DescTools)
require(MASS)
require(fitdistrplus)

## Just load the data...
data.filename <- 'http://coryan.github.io/public/2017/01/16/on-benchmarking-part4/data.csv'
data <- read.csv(file=data.filename, header=FALSE, comment.char='#', col.names=c('book_type', 'nanoseconds'))

## ... I prefer microseconds because they are easier to think about ...
data$microseconds <- data$nanoseconds / 1000.0

## ... print the summary so we can just check the data is correct ...
summary(data)

## ... plot (and save) a density plot to visualize the data overall ...
ggplot(data=data, aes(x=microseconds, color=book_type)) + geom_density()

## ... make the graphs look pretty ...
golden.ratio <- (1+sqrt(5))/2
save.width <- 8.0
save.height <- save.width / golden.ratio
png.w <- 960
png.h <- round(png.w / golden.ratio)

ggsave(width=save.width, height=save.height, filename="explore.density.svg")
ggsave(width=save.width, height=save.height, filename="explore.density.png")

plot.descdist <- function(data, bktype) {
    svg(filename=paste0("explore.", bktype, ".descdist.svg"),
        width=save.width, height=save.height)
    d <- subset(data, book_type == bktype)
    descdist(d$microseconds, boot=1000)
    mtext(bktype)
    dev.off()
    rm(d)
}

plot.descdist(data, 'map')
plot.descdist(data, 'array')

aggregate(microseconds ~ book_type, data=data, FUN=median)
aggregate(microseconds ~ book_type, data=data, FUN=function(x) round(sd(x)))

## ... use bootstraping to estimate the standard deviation ...                                    
sd.estimator <- function(D,i) {
    b=D[i,];
    return(sd(b$microseconds));
}

b.array <- boot(data=subset(data, book_type == 'array'), R=10000, statistic=sd.estimator)
svg(filename=paste0("bootstrap.array.sd.svg"),
    width=save.width, height=save.height)
plot(b.array)
mtext("Array Based Order Book")
dev.off()
png(filename=paste0("bootstrap.array.sd.png"), width=png.w, height=png.h)
plot(b.array)
mtext("Array Based Order Book")
dev.off()
ci.array <- boot.ci(b.array, type=c('perc', 'norm', 'basic'))

b.map <- boot(data=subset(data, book_type == 'map'), R=10000, statistic=sd.estimator)
svg(filename=paste0("bootstrap.map.sd.svg"),
    width=save.width, height=save.height)
plot(b.map)
mtext("Map Based Order Book")
dev.off()
png(filename=paste0("bootstrap.map.sd.png"), width=png.w, height=png.h)
plot(b.map)
mtext("Map Based Order Book")
dev.off()
ci.map <- boot.ci(b.map, type=c('perc', 'norm', 'basic'))

ci.map
ci.array

estimated.sd <- ceiling(max(ci.map$percent[[4]], ci.array$percent[[4]],
            ci.map$basic[[4]], ci.array$basic[[4]],
            ci.map$normal[[3]], ci.array$normal[[3]]))

## ... compute the minimum effect size ...

## These constants are valid for my environment,
## change as needed / wanted ...
clock.ghz <- 3
test.iterations <- 20000
## ... this is the minimum effect size that we
## are interested in, anything larger is great,
## smaller is too small to care ...
min.delta <- 1.0 / (clock.ghz * 1000.0) * test.iterations
min.delta

## ... these constants are based on the
## discussion in the post ...
desired.delta <- min.delta
desired.significance <- 0.01
desired.power <- 0.95
nonparametric.extra.cost <- 1.15

## ... the power object has several
## interesting bits, so store it ...
required.power <- power.t.test(
    delta=desired.delta, sd=estimated.sd,
    sig.level=desired.significance, power=desired.power)

## ... I like multiples of 1000 because
## they are easier to type and say ...
required.nsamples <-
    1000 * ceiling(nonparametric.extra.cost *
                   required.power$n / 1000)
required.nsamples

## ... while it would be great to detect changes of
## 6.6us, we would be happy if we detected
## something much larger ...
desired.delta <- max(min.delta, 50)
## ... re-run power analysis ...
required.power <- power.t.test(
    delta=desired.delta, sd=estimated.sd,
    sig.level=desired.significance, power=desired.power)
required.nsamples <-
    1000 * ceiling(nonparametric.extra.cost *
                   required.power$n / 1000)
required.nsamples

## Appendix: Goodness of Fit
a.data <- subset(data, book_type == 'array')
m.data <- subset(data, book_type == 'map')

## Both are "close" to the line for Gamma, let's try to fit them:
m.gamma.fit <- fitdist(m.data$microseconds, distr="gamma")
plot(m.gamma.fit)
svg(filename="map.fit.gamma.svg", height=save.height, width=save.width)
plot(m.gamma.fit)
dev.off()
png(filename="map.fit.gamma.png", height=png.h, png.w)
plot(m.gamma.fit)
dev.off()

a.gamma.fit <- fitdist(a.data$microseconds, distr="gamma")
plot(a.gamma.fit)
svg(filename="array.fit.gamma.svg", height=save.height, width=save.width)
plot(a.gamma.fit)
dev.off()
png(filename="array.fit.gamma.png", height=png.h, png.w)
plot(a.gamma.fit)
dev.off()


## The Array data almost fits lognormal, let's try it analytically:
a.fit <- fitdist(a.data$microseconds, distr="lnorm")
plot(a.fit)
svg(filename="array.fit.lognormal.svg", height=save.height, width=save.width)
plot(a.fit)
dev.off()
png(filename="array.fit.lognormal.png", height=png.h, width=png.w)
plot(a.fit)
dev.off()


## ... now run a non-parametric test for "is this sample data from
## that distribution", or more precisely: is the null hypothesis  that
## the data *is* from the distribution likely given the data ...
a.ks <- ks.test(x=a.data$microseconds, y="plnorm", a.fit$estimate)
a.ks

## Try to fit Beta to Array and Map
m.data$seconds <- m.data$microseconds / 1000000

## We can estimate the good initial values for the parameters using
## this ...
## https://en.wikipedia.org/wiki/Beta_distribution#Parameter_estimation
beta.start <- function(x) {
    m <- mean(x)
    v <- var(x)
    if (v >= m * (1 - m)) {
        ## ... not a great estimate, but meh ...
        return(list(shape1=1, shape2=1))
    }
    t <- (m * (1 - m) / v - 1)
    s1 <- m * t
    s2 <- (1 - m) * t
    return(list(shape1=s1, shape2=s2))
}

## Try to fit the Map-based data to the Beta distribution:
m.beta.fit <- fitdist(
    m.data$seconds, distr="beta", start=beta.start(m.data$seconds))
plot(m.beta.fit)
svg(filename="map.fit.beta.svg", height=save.height, width=save.width)
plot(m.beta.fit)
dev.off()
png(filename="map.fit.beta.png", height=png.h, png.w)
plot(m.beta.fit)
dev.off()

m.beta.ks <- ks.test(x=m.data$seconds, y="beta", m.beta.fit$estimate)
m.beta.ks

## Try to fit the Map-based data to the Beta distribution:
a.data$seconds <- a.data$microseconds / 1000000
a.beta.fit <- fitdist(
    a.data$seconds, distr="beta", start=beta.start(a.data$seconds))
plot(a.beta.fit)
svg(filename="array.fit.beta.svg", height=save.height, width=save.width)
plot(a.beta.fit)
dev.off()

png(filename="array.fit.beta.png", height=png.h, width=png.w)
plot(a.beta.fit)
dev.off()

a.beta.ks <- ks.test(x=a.data$seconds, y="beta", a.beta.fit$estimate)
a.beta.ks


## Try to fit the Array and Map based data to the Weibull
## distribution:
a.weibull.fit <- fitdist(
    a.data$seconds, distr="weibull")
plot(a.weibull.fit)
svg(filename="array.fit.weibull.svg", height=save.height, width=save.width)
plot(a.weibull.fit)
dev.off()
png(filename="array.fit.weibull.png", height=png.h, width=png.w)
plot(a.weibull.fit)
dev.off()

a.weibull.ks <- ks.test(x=a.data$seconds, y="pweibull", a.weibull.fit$estimate)
a.weibull.ks

m.weibull.fit <- fitdist(
    m.data$seconds, distr="weibull")
plot(m.weibull.fit)
svg(filename="map.fit.weibull.svg", height=save.height, width=save.width)
plot(m.weibull.fit)
dev.off()
png(filename="map.fit.weibull.png", height=png.h, width=png.w)
plot(m.weibull.fit)
dev.off()

m.weibull.ks <- ks.test(x=m.data$seconds, y="pweibull", m.weibull.fit$estimate)
m.weibull.ks
