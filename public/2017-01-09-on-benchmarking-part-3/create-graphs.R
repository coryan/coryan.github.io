#!/usr/bin/env Rscript
require(ggplot2)
require(scales)
require(boot)
require(reshape2)
require(dplyr)

## Load data for the multiple runs with different conditions in the
## execution environment ...
data.filename <-
    'http://coryan.github.io/public/2017-01-08-on-benchmarking-part-2/data.csv'

data <- read.csv(
    data.filename, header=FALSE,
    col.names=c('run', 'mtype', 'loaded', 'seed', 'scheduling', 'governor',
                'nanoseconds'),
    comment.char='#')
data$microseconds <- data$nanoseconds / 1000.0

## ... this is a good example of data created by benchmarks that do
## not use a controlled execution environment ...
data.uncontrolled <- subset(
    data, scheduling == 'default' & loaded == 'loaded')

ggplot(data=data.uncontrolled,
       aes(x=microseconds, color=run)) +
    geom_density() +
    xlab("Iteration Latency (us)") +
    ylab("Density") +
    theme(legend.position="bottom")

ggsave(filename="empirical-density-uncontrolled.svg",
       width=8.0, height=8.0/1.61)
ggsave(filename="empirical-density-uncontrolled.png",
       width=8.0, height=8.0/1.61)


summary(data$microseconds)

## ... this is a good example of data created by benchmarks that do
## not use a controlled execution environment ...
data.controlled <- subset(
    data, scheduling == 'rt:unlimited' & loaded == 'unloaded' &
          seed == 'fixed' & governor == 'performance')

ggplot(data=data.controlled,
       aes(x=microseconds, color=run)) +
    geom_density() +
    xlab("Iteration Latency (us)") +
    ylab("Density") +
    theme(legend.position="bottom")

ggsave(filename="empirical-density-controlled.svg",
       width=8.0, height=8.0/1.61)
ggsave(filename="empirical-density-controlled.png",
       width=8.0, height=8.0/1.61)

summary(data.controlled$microseconds)

data.uncontrolled$environment <- factor('uncontrolled')
data.controlled$environment <- factor('controlled')
data.contrast <- rbind(data.uncontrolled, data.controlled)

aggregate(microseconds ~ environment, data=data.contrast, FUN=summary)
aggregate(microseconds ~ environment, data=data.contrast, FUN=IQR)

q(save="no")

