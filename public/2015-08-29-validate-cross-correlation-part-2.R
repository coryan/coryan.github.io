# ---
# layout: post
# title: Validate Cross Correlation, Part 2
# date: 2015-08-29 23:00
# ---
# Lines that end on ### are removed ###
# Compute the destination directory for the pictures  ###
public.dir <- paste0(Sys.getenv('HOME'), '/coryan.github.io/public/') ###


# If you are unfamiliar with the markets, or how to interpret a market
# feed as a real function you might want to check the
# [previous](
# {% post_url 2015-08-29-validate-cross-correlation-part-1 %})
# post on this topic.


# Let's start with a simple function and apply the fourier transform and
# its inverse, the R snippets are available in the
# [repository](https://github.com/coryan/coryan.github.io/public/2015-08-29-validate-cross-correlation-part-2.R)
# if you prefer to see or modify the code.
# Here we will break after each bit of code to offer some
# explanations.

# first we write a simple function to generate triangular functions.
# Nothing fancy really, but will save us time later

triangle <- function(period) {
  p4 <- period / 4
  up <- (seq(1, period/2) - p4) / p4
  dn <- (p4 - seq(1, period/2)) / p4
  return(c(up, dn))
}

# using the function we create a triangle

t <- triangle(128)

# and wrap the triangle in a data.frame(), because ggplot2 really
# likes data.frame()

df <- data.frame(usec=seq(0, length(t) - 1), value=t, variable="T(t)")

# ggplot2 generates sensible and good looking plots in most cases,
# make sure it is loaded

require(ggplot2)  # May need to install.packages("ggplot2")

# then we can plot the triangle function

qplot(x=usec, y=value, color=variable, data=df)
ggsave(paste0(public.dir, 'triangle.svg'), width=8, height=8/1.61) ###

# ![A sampled function, the x-axis goes from 0 to 128, the values \
# start at -1.0 and grow linearly to 1.0 just before x is equal to \
# 64.  Then the values decrease linearly to -1.0 when x is equal to \
# 128.](/public/triangle.svg "A Simple Triangular function") 

# next, let's apply the FFT transform and the inverse to the
# triangular function

fft.i <- fft(fft(t), inverse=TRUE)

# and save this into a new data.frame()

tmp <- df
tmp$value <- Re(fft.i)
tmp$variable <- 'FFT^1(FFT(t))'
df.i <- rbind(df, tmp)

# let's add the new data to the data.frame()

qplot(x=usec, y=value, color=variable, data=df.i)
ggsave(paste0(public.dir, 'triangle.and.fft.svg'), width=8, height=8/1.61) ###

# ![Two triangular functions as before.  One labeled 'T(t)' with much \
# smaller amplitude. The second, labeled FFT inverse applied to FFT \
# of T(t) has much higher amplitude, it ranges from -128 to \
# +128.](/public/triangle.and.fft.svg "A Simple Triangular function and \
# applying the FFT to it.")

# What is going on here?  To save computations, the "Fast" Fourier
# Transform omits rescaling the function by $$1/N$$, where $$N$$ is
# the number of samples.  If we apply this rescaling manually things
# match perfectly

fft.i <- fft.i / length(fft.i)
tmp <- df
tmp$value <- Re(fft.i)
tmp$variable <- 'FFT^1(FFT(T))(t)'
df.i <- rbind(df, tmp)
qplot(x=usec, y=value, color=variable, data=df.i)
ggsave(paste0(public.dir, 'triangle.and.fft.scaled.svg'), width=8, height=8/1.61) ###

# ![Two triangular functions as before.  One labeled T(t), and a \
# second labeled FFT inverse applied to FFT \
# of T(t).  Both overlap perfectly, they vary in the -1 to +1 \
# range.](/public/triangle.and.fft.scaled.svg "A Simple Triangular \
# function and applying the FFT to it with rescaling.")

# the more or less obvious question is how well does a function
# correlate to itself, this is easy to compute

corr <- Re(fft( Conj(fft(t)) * fft(t), inverse=TRUE)) / length(t)

# we are going to be wrapping these functions in a data.frame() a
# lot, so let's create a function for it

to.df <- function(a, name) {
  return(data.frame(
    usec=seq(0, length(a) - 1), value=a, variable=name))
}

# and plot the results

corr.df <- to.df(corr, "(T * T)(t)")
qplot(x=usec, y=value, color=variable, data=corr.df) +
  scale_y_continuous(name=expression(value^2)) +
  theme(legend.position="bottom")
ggsave(paste0(public.dir, 'correlation.self.svg'), width=8, height=8/1.61) ###

# ![A sinusoidal wave.  The x axis varies from 0 to 128.  The wave \
# starts with a high value at around 32, a low value of -32 reached \
# when x is approximately 64, and growing back to +32 when x is equal \
# to 128.](/public/correlation.self.svg "The cross-correlation of a \
# triangular function with itself.")

# ### More interesting cross-correlations

# Let's see how the correlation works with a time shifted signal

a <- triangle(128)
a.df <- to.df(a, "A")
b <- a[((seq(1, length(a)) - 13) %% length(a)) + 1]
ab.df <- rbind(a.df, to.df(b, "B"))
qplot(x=usec, y=value, color=variable, data=ab.df) +
  theme(legend.position="bottom")
ggsave(paste0(public.dir, 'triangles.ab.svg'), width=8, height=8/1.61) ###

# ![A graph of two triangular functions, the x-axis is labeled 'usec', \
# the y-axis is labeled 'value'.  The triangular functions are \
# labeled A and B.  B is time shifted, has the value of A a few \
# microseconds earlier.](/public/triangles.ab.svg "Two triangular \
# functions, time shifted.")


# Let's see how the cross-correlation looks like, but since we will be
# doing several correlations, we write a helper function ...

correlation <- function(a, b) {
  inv <- Re(fft( Conj(fft(a)) * fft(b), inverse=TRUE))
  return(inv / length(a))
}
correlation.df <- function(a, b, name) {
  return(to.df(correlation(a, b), name))
}
corr.ab.df <- correlation.df(a, b, "A * B")
qplot(x=usec, y=value, color=variable, data=corr.ab.df) +
  scale_y_continuous(name=expression(value^2)) +
  theme(legend.position="bottom")
ggsave(paste0(public.dir, 'correlation.ab.svg'), width=8, height=8/1.61) ###

# ![Another sinusoidal graph.\
# The x axis labeled usec, ranging from 0 to 128. \
# The y axis labeled $$value^2$$, ranging from approximately -30 to 30. \
# The sinusoid has a single period, \
# which peaks around 15, and bottoms at around 75.](\
# /public/correlation.ab.svg "The Cross-Correlation of two time \
# shifted Triangular functions.")

# The graphs are pretty, but exactly where is the peak?

which.max(corr.ab.df$value)

# {% highlight rout %}
# [1] 13
# {% endhighlight %}

# That is a perfect match, but market (or other) signals are rarely so
# perfectly match, what happens if we add some noise?

