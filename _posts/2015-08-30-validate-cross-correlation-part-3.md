---
layout: post
title: Validate Cross Correlation, Part 3
date: 2015-08-30 13:00
---

In the 
[previous](
{% post_url 2015-08-29-validate-cross-correlation-part-2 %})
post we showed how cross-correlation could be used to find the time
delay between identical and very simple functions.
Now we want to explore what happens when one of the signals has some
noise.


In the last post we were considering two simple triangular signals
*A* and *B*, with *B* delayed some 13 microseconds from *A*.

![A graph of two triangular functions, the x-axis is labeled 'usec', the y-axis is labeled 'value'.  The triangular functions are labeled A and B.  B is time shifted, has the value of A a few microseconds earlier.](/public/triangles.ab.svg "Two triangular functions, time shifted.")

We now modify B by adding some 5% noise to it:

{% highlight r %}
c <- b + runif(length(b), -0.05, 0.05)
ac.df <- rbind(a.df, to.df(c, "C"))
qplot(x=usec, y=value, color=variable, data=ac.df) +
  theme(legend.position="bottom")
{% endhighlight %}

![A graph of two triangular functions, the x-axis is labeled 'usec', the y-axis is labeled 'value'.  The triangular functions are labeled A and C.  C is time shifted, has the value of A a few microseconds earlier, and it is slightly 'noisy'.](/public/triangles.ac.svg "Two triangular functions, one delayed and with 5% noise.")

And compute the cross-correlation with A:

{% highlight r %}
corr.ac.df <- correlation.df(a, c, "A * C")
qplot(x=usec, y=value, color=variable, data=corr.ac.df) +
  scale_y_continuous(name=expression(value^2)) +
  theme(legend.position="bottom")
{% endhighlight %}

![Another sinusoidal graph.The x axis labeled usec, ranging from 0 to 128. The y axis labeled $$value^2$$, ranging from approximately -30 to 30. The sinusoid has a single period, which peaks around 15, and bottoms at around 75.](/public/correlation.ac.svg "The Cross-Correlation of two time shifted Triangular functions, one with 5% noise.")

We can also check the value of this cross correlation:

{% highlight rconsole %}
> which.max(corr.ac.df$value)
[1] 13
> max(corr.ab.df$value)
[1] 42.6875
{% endhighlight %}

No changes!  The cross-correlation can cope with a small amount of
noise without problems.  To finalize the examples with triangular
functions we add a lot of noise to the signal:

{% highlight r %}
d <- b + runif(length(b), -0.2, 0.2)
ad.df <- rbind(a.df, to.df(d, "D (20% noise)"))
qplot(x=usec, y=value, color=variable, data=ad.df) +
  theme(legend.position="bottom")
{% endhighlight %}

![A graph of two triangular functions, the x-axis is labeled 'usec', the y-axis is labeled 'value'.  The triangular functions are labeled A and D.  D is time shifted, has the value of A a few microseconds earlier, and it is very 'noisy'.](/public/triangles.ac.svg "Two triangular functions, one delayed and with 20% noise.")

And once more we compute the cross-correlation:

{% highlight r %}
corr.ad.df <- correlation.df(a, d, "A * D")
qplot(x=usec, y=value, color=variable, data=corr.ad.df) +
  scale_y_continuous(name=expression(value^2)) +
  theme(legend.position="bottom")
{% endhighlight %}

![Another sinusoidal graph.The x axis labeled usec, ranging from 0 to 128. The y axis labeled $$value^2$$, ranging from approximately -30 to 30. The sinusoid has a single period, which peaks around 15, and bottoms at around 75.](/public/correlation.ac.svg "The Cross-Correlation of two time shifted Triangular functions, one with 20% noise.")

And obtain basic statistics about the cross-correlation values:

{% highlight rconsole %}
> which.max(corr.ad.df$value)
[1] 13
> summary(corr.ad.df$value)
   Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
-43.34  -29.57    0.00    0.00   29.57   43.34 
{% endhighlight %} 

Once more, there are no changes to the estimate!  The cross
correlation can deal with uniform noise without problems.


## Quotes and Square functions


