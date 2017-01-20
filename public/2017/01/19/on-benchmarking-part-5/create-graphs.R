#!/usr/bin/env Rscript
require(ggplot2)

## In this script we demonstrate how the non-parametric test works,
## and learn how it breaks!

## ... make the graphs look pretty ...
golden.ratio <- (1+sqrt(5))/2
save.width <- 8.0
save.height <- save.width / golden.ratio
png.w <- 960
png.h <- round(png.w / golden.ratio)

## Start with a simple distribution:
lnorm.s1 <- rlnorm(50000, 5, 0.2)
qplot(x=lnorm.s1, geom="density", color=factor("s1"))

ggsave('lnorm.s1.density.svg', width=save.width, height=save.height)
ggsave('lnorm.s1.density.png', width=save.width, height=save.height)

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

ggsave('lnorm.s1.s2.density.svg', width=save.width, height=save.height)
ggsave('lnorm.s1.s2.density.png', width=save.width, height=save.height)

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
ggsave('lnorm.s3.s4.density.svg', width=save.width, height=save.height)
ggsave('lnorm.s3.s4.density.png', width=save.width, height=save.height)
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
ggsave('lnorm.s5.s6.density.svg', width=save.width, height=save.height)
ggsave('lnorm.s5.s6.density.png', width=save.width, height=save.height)
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
ggsave('lnorm.s7.s8.density.svg', width=save.width, height=save.height)
ggsave('lnorm.s7.s8.density.png', width=save.width, height=save.height)
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
ggsave('mixed.test.density.svg', width=save.width, height=save.height)
ggsave('mixed.test.density.png', width=save.width, height=save.height)

## ... and use that to estimate the standard deviation ...
require(boot)
mixed.boot <- boot(data=mixed.test, R=10000,
                   statistic=function(d, i) sd(d[i]))
plot(mixed.boot)
svg(filename="mixed.boot.svg", width=save.width, height=save.height)
plot(mixed.boot)
dev.off()
png(filename="mixed.boot.png", width=png.w, height=png.h)
plot(mixed.boot)
dev.off()

mixed.ci <- boot.ci(mixed.boot, type=c('perc', 'norm', 'basic'))
print(mixed.ci)
mixed.sd <- ceiling(max(mixed.ci$normal[[3]], mixed.ci$basic[[4]],
                        mixed.ci$percent[[4]]))
print(mixed.sd)

mixed.pw <- power.t.test(delta=50, sd=mixed.sd, sig.level=0.01, power=0.95)
print(mixed.pw)
nsamples <- ceiling(mixed.pw$n / 1000) * 1000
print(nsamples)

## ... 
mixed.s1 <- 1000 + rmixed(nsamples)
mixed.s2 <- 1050 + rmixed(nsamples)

df <- melt(data.frame(s1=mixed.s1, s2=mixed.s2))
colnames(df) <- c('sample', 'value')
ggplot(data=df, aes(x=value, color=sample)) + geom_density()
ggsave('mixed.s1.s2.svg', width=save.width, height=save.height)
ggsave('mixed.s1.s2.png', width=save.width, height=save.height)
mixed.w <- wilcox.test(x=mixed.s1, y=mixed.s2, conf.int=TRUE)
print(mixed.w)

## What happens if we double the number of samples?
mixed.s3 <- 1000 + rmixed(2 * nsamples)
mixed.s4 <- 1050 + rmixed(2 * nsamples)

df <- melt(data.frame(s3=mixed.s3, s4=mixed.s4))
colnames(df) <- c('sample', 'value')
ggplot(data=df, aes(x=value, color=sample)) + geom_density()
ggsave('mixed.s3.s4.svg', width=save.width, height=save.height)
ggsave('mixed.s3.s4.png', width=save.width, height=save.height)
mixed.w <- wilcox.test(x=mixed.s3, y=mixed.s4, conf.int=TRUE)
print(mixed.w)

ls()

q(save='no')
