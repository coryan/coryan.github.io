# ---
# layout: post
# title: Validate Cross Correlation, Part 3
# date: 2015-08-30 13:00
# ---

# In the 
# [previous](
# {% post_url 2015-08-29-validate-cross-correlation-part-2 %})
# post we showed how cross-correlation could be used to find the time
# delay between identical and very simple functions.
# Now we want to explore what happens when one of the signals has some
# noise.

# Load the previous script ###
source(paste0(Sys.getenv('HOME'), '/coryan.github.io/public/2015-08-29-validate-cross-correlation-part-2.R')) ###

# In the last post we were considering two simple triangular signals
# *A* and *B*, with *B* delayed some 13 microseconds from *A*.

# ![A graph of two triangular functions, the x-axis is labeled 'usec', \
# the y-axis is labeled 'value'.  The triangular functions are \
# labeled A and B.  B is time shifted, has the value of A a few \
# microseconds earlier.](/public/triangles.ab.svg "Two triangular \
# functions, time shifted.")

# We now modify B by adding some 5% noise to it:

c <- b + runif(length(b), -0.05, 0.05)
ac.df <- rbind(a.df, to.df(c, "C"))
qplot(x=usec, y=value, color=variable, data=ac.df) +
  theme(legend.position="bottom")
ggsave(paste0(public.dir, 'triangles.ac.svg'), width=8, height=8/1.61) ###

# ![A graph of two triangular functions, the x-axis is labeled 'usec', \
# the y-axis is labeled 'value'.  The triangular functions are \
# labeled A and C.  C is time shifted, has the value of A a few \
# microseconds earlier, and it is slightly \
# 'noisy'.](/public/triangles.ac.svg "Two triangular functions, \
# one delayed and with 5% noise.")

# And compute the cross-correlation with A:

corr.ac.df <- correlation.df(a, c, "A * C")
qplot(x=usec, y=value, color=variable, data=corr.ac.df) +
  scale_y_continuous(name=expression(value^2)) +
  theme(legend.position="bottom")
ggsave(paste0(public.dir, 'correlation.ac.svg'), width=8.0, height=8.0/1.61) ###

# ![Another sinusoidal graph.\
# The x axis labeled usec, ranging from 0 to 128. \
# The y axis labeled "value squared, ranging from approximately -30 to 30. \
# The sinusoid has a single period, \
# which peaks around 15, and bottoms at around 75.](\
# /public/correlation.ac.svg "The Cross-Correlation of two time \
# shifted Triangular functions, one with 5% noise.")

# We can also check the value of this cross correlation:

which.max(corr.ac.df$value) ###
max(corr.ab.df$value) ###
# {% highlight rconsole %}
# > which.max(corr.ac.df$value)
# [1] 13
# > max(corr.ab.df$value)
# [1] 42.6875
# {% endhighlight %}

# No changes!  The cross-correlation can cope with a small amount of
# noise without problems.  To finalize the examples with triangular
# functions we add a lot of noise to the signal:

d <- b + runif(length(b), -0.2, 0.2)
ad.df <- rbind(a.df, to.df(d, "D (20% noise)"))
qplot(x=usec, y=value, color=variable, data=ad.df) +
  theme(legend.position="bottom")
ggsave(paste0(public.dir, 'correlation.ad.svg'), width=8.0, height=8.0/1.61) ###

# ![A graph of two triangular functions, the x-axis is labeled 'usec', \
# the y-axis is labeled 'value'.  The triangular functions are \
# labeled A and D.  D is time shifted, has the value of A a few \
# microseconds earlier, and it is very \
# 'noisy'.](/public/triangles.ac.svg "Two triangular functions, \
# one delayed and with 20% noise.")

# And once more we compute the cross-correlation:

corr.ad.df <- correlation.df(a, d, "A * D")
qplot(x=usec, y=value, color=variable, data=corr.ad.df) +
  scale_y_continuous(name=expression(value^2)) +
  theme(legend.position="bottom")
ggsave(paste0(public.dir, 'correlation.ac.svg'), width=8.0, height=8.0/1.61) ###

# ![Another sinusoidal graph.\
# The x axis labeled usec, ranging from 0 to 128. \
# The y axis labeled "value squared", ranging from approximately -30 to 30. \
# The sinusoid has a single period, \
# which peaks around 15, and bottoms at around 75.](\
# /public/correlation.ac.svg "The Cross-Correlation of two time \
# shifted Triangular functions, one with 20% noise.")

# And obtain basic statistics about the cross-correlation values:

which.max(corr.ad.df$value) ###
summary(corr.ad.df$value) ###
# {% highlight rconsole %}
# > which.max(corr.ad.df$value)
# [1] 13
# > summary(corr.ad.df$value)
#    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
# -43.34  -29.57    0.00    0.00   29.57   43.34 
# {% endhighlight %} 

# Once more, there are no changes to the estimate!  The cross
# correlation can deal with uniform noise without problems.


# ## Quotes and Square functions

# So far we have been using triangular functions because they were
# easy to generate.  Market signals more closely resemble square
# functions: a quote value is valid until it changes.  Moreover,
# market data is not regularly sampled in time.  One might receive no
# updates for several milliseconds, and then receive multiple updates
# in the same microsecond!  But to illustrate how this would work we
# can make our life easy.  Suppose we have the best bid quantity
# sampled every microsecond, and it had the following values:

S <- c(rep(1000, 100), rep(1100, 100), rep(1200, 56))
S.df <- to.df(S, "S")
qplot(x=usec, y=value, color=variable, data=S.df) +
  ylim(0, max(S.df$value)) +
  theme(legend.position="bottom")
ggsave(paste0(public.dir, 'square.S.svg'), width=8, height=8/1.61) ###

# ![A graph of a step function. \
# The x-axis is labeled 'usec', it ranges from 0 to 256. \
# The y-axis is labeled 'value', it ranges from 1000 to 1200. \
# The values are labeled 'S'.
# The function has contant value 1000 from 0 to 100, \
# then constant value 1100 from 100 to 200, \
# and then constant value 1200.\
# ](/public/square.S.svg "A Step Function.")

# We use a similar trick as before to create a time shifted version of
# this signal, and add some noise to it:

T <- S[((seq(1, length(S)) - 27) %% length(S)) + 1]
T <- T + runif(length(T), -10, 10)
ST.df <- rbind(S.df, to.df(T, "T"))
qplot(x=usec, y=value, color=variable, data=ST.df) +
  ylim(0, max(ST.df$value)) +
  theme(legend.position="bottom")
ggsave(paste0(public.dir, 'squares.ST.svg'), width=8, height=8/1.61) ###

# ![A graph of two step functions. \
# The x-axis is labeled 'usec', it ranges from 0 to 256. \
# The y-axis is labeled 'value', it ranges from 1000 to 1200. \
# The values are labeled 'S' and 'T'.
# The 'S' values has contant value 1000 from 0 to 100, \
# then constant value 1100 from 100 to 200, \
# and then constant value 1200.\
# The 'T' values are the 'S' values delayed by approximately 30 \
# microseconds, with some amount of noise.\
# ](/public/squares.ST.svg "A Step Function.")

# And as before we can compute the cross-correlation:

corr.ST.df <- correlation.df(S, T, "S * T")
qplot(x=usec, y=value, color=variable, data=corr.ST.df) +
  scale_y_continuous(name=expression(value^2)) +
  theme(legend.position="bottom")
ggsave(paste0(public.dir, 'correlation.ST.svg'), width=8.0, height=8.0/1.61) ###

# ![A graph with a peak around 30.\
# The x axis labeled usec, ranging from 0 to 256. \
# The y axis labeled "value squared", ranging from approximately \
# 299500000 to over 301500000. \
# The values start at around 307500000 grow linearly to the peak \
# at over 301500000, the decreate linearly for some time, and \
# and then decrease in 2 apparently linear segments. \
# The values are basically constant between 120 and 180. \
# Then grow again in two linear segments finishing just below \
# 301000000.](\
# /public/correlation.ST.svg "The Cross-Correlation of Step \
# functions, one with some noise.")

# And obtain basic statistics about the cross-correlation values:

which.max(corr.ST.df$value) ###
summary(corr.ST.df$value) ###
# {% highlight rconsole %}
# > which.max(corr.ST.df$value)
# [1] 27
# > summary(corr.ST.df$value)
#      Min.   1st Qu.    Median      Mean   3rd Qu.      Max. 
# 299500000 299600000 299900000 300200000 300700000 301600000 
# {% endhighlight %} 

# One problem is that the different between the peak and the minimum
# is not that high, in relative terms it is only 0.7%.

# ## Conclusion

# In these last three posts we have reviewed how cross-correlations
# work for simple triangular functions, triangular functions with some
# noise and finally for step functions with noise.
# We observed that some FFT libraries avoid computation by not
# rescaling, which can present problems interpreting the results.
# We also observed that the result of the cross-correlation is a
# measure of area, which can have very large values for some functions
# and it would also be desirable to rescale.
