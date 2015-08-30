#!/bin/sh

# First remove the lines ending in ###, then indent code lines by 4
# spaces, then remove the comment characters, and finally wrap lines
# that end in a backslash.
cat $* | \
    sed -e '/###/d' -e 's/^\([^#]\)/    \1/' -e 's/^# //' | \
    awk '{if (sub(/\\$/,"")) { printf "%s", $0; } else {print $0; }}' | \
    awk '
BEGIN {
  open=0;
}
{
  if (open == 0 && match($0, /^    /) == 1) {
    open = 1;
    print "{% highlight r %}";
  }
  if (open == 1 && match($0, /^    /) == 0) {
    open = 0;
    print "{% endhighlight %}";
  }
  print $0;
}' | sed 's/^    //'

exit 0
