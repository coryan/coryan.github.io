#!/bin/Rscript

require(ggplot2)

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

summary(data)

ggplot(data=data, aes(x=governor, y=microseconds, color=run)) +
    facet_grid(loaded ~ scheduling) +
  geom_boxplot() +
  ylab("Iteration Latency (us)") +
  xlab("CPU Frequency Scaling") +
  theme(legend.position="bottom")

ggsave(filename="microbenchmark-vs-scheduling-setup.boxplot.svg",
       width=8.0, height=8.0/1.61)
ggsave(filename="microbenchmark-vs-scheduling-setup.boxplot.png",
       width=8.0, height=8.0/1.61)

# ... select the subset of the data that follows our scheduling
# recommendations ...
data.rec <- subset(
    data, (scheduling != 'best-effort' & governor == 'performance'))

ggplot(data=data.rec, aes(x=seed, y=microseconds, color=run)) +
    facet_grid(loaded ~ governor + scheduling) +
  geom_boxplot() +
  ylab("Iteration Latency (us)") +
  xlab("PRNG seed selection") +
  theme(legend.position="bottom")

ggsave(filename="microbenchmark-vs-seed.boxplot.svg",
       width=8.0, height=8.0/1.61)
ggsave(filename="microbenchmark-vs-seed.boxplot.png",
       width=8.0, height=8.0/1.61)

# ... fix the seed and see how the graph looks ...
data.rec <- subset(
    data, (scheduling != 'best-effort' & governor == 'performance' &
           seed == 'seed'))

ggplot(data=data.rec, aes(x=seed, y=microseconds, color=run)) +
    facet_grid(loaded + governor ~ scheduling) +
  geom_boxplot() +
  ylab("Iteration Latency (us)") +
  xlab("Run Number") +
  theme(legend.position="none")

ggsave(filename="microbenchmark-vs-load.boxplot.svg",
       width=8.0, height=8.0/1.61)
ggsave(filename="microbenchmark-vs-load.boxplot.png",
       width=8.0, height=8.0/1.61)

# ... fix the load and see how the graph looks ...
data.rec <- subset(
    data, (scheduling != 'best-effort' & governor == 'performance' &
           seed == 'seed' & loaded == 'noload'))

ggplot(data=data.rec, aes(x=seed, y=microseconds, color=run)) +
    facet_grid(loaded + governor ~ scheduling) +
  geom_boxplot() +
  ylab("Iteration Latency (us)") +
  xlab("Run Number") +
  theme(legend.position="none")

ggsave(filename="microbenchmark-vs-rtlimit.boxplot.svg",
       width=8.0, height=8.0/1.61)
ggsave(filename="microbenchmark-vs-rtlimit.boxplot.png",
       width=8.0, height=8.0/1.61)

aggregate(microseconds ~ scheduling, data=data.rec, FUN=IQR)
