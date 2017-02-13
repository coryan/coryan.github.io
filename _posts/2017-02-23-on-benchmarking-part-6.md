---
layout: post
title: On Benchmarking, Part 6
date: 2017-02-23 15:00
draft: true
---

{% assign ghsha = "e444f0f072c1e705d932f1c2173e8c39f7aeb663" %}
{% capture ghver %}https://github.com/coryan/jaybeams/blob/{{ghsha}}{% endcapture %}

> This is a long series of posts where I try to teach myself how to
> run rigorous, reproducible microbenchmarks on Linux.  You may
> want to start from the [first one](/2017/01/04/on-benchmarking-part-1/)
> and learn with me as I go along.
> I am certain to make mistakes, please write be back in
> [this bug](https://github.com/coryan/coryan.github.io/issues/1) when
> I do.

In my [previous post]({{page.previous.url}}) I chose the [Mann-Whitney U
Test](https://en.wikipedia.org/wiki/Mann%E2%80%93Whitney_U_test)
as the model to perform an statistical test of hypothesis comparing the performance of
two implementations of the same functionality.
I also explored why neither the arithmetic mean, nor the median are good measures of effect
in my case, so I learned about the [Hodges-Lehmann
Estimator](https://en.wikipedia.org/wiki/Hodges%E2%80%93Lehmann_estimator)
as a better measure of effect or performance improvement.
Finally I used some mock data to familiarize myself with these tools.

In this post I will solve the last remaining issue from my
[Part 1](/2017/01/04/on-benchmarking-part-1/) of this series.
Specifically [[I12]][issue 12]: how can anybody reproduce the results
that I obtained.

## The Challenge of Reproducibility for Software Systems Performance

## Towards Reproducible Benchmarks

Assuming you have a Linux workstation (or server), configured to run
docker you should be able to simply do this:

{% assign dockerid = '{{ .Id }}' %}
```
$ sudo docker inspect -f '{{ dockerid }}' coryan/jaybeams-runtime-fedora25:latest
sha256:7e7c5e91f2e46b902144d1de4b41b3d02407c38a56b1f58c27576012c0226d24

$ sudo docker run --rm -i -t --cap-add sys_nice --privileged \
    --volume $PWD:/home/jaybeams --workdir /home/jaybeams \
    coryan/jaybeams-runtime-fedora25:latest \
    /opt/jaybeams/bin/bm_order_book_generate.sh
```

then 

```
$ sudo docker inspect -f '{{ dockerid }}' coryan/jaybeams-analysis:latest
sha256:01ad76f9e70e46eb65f840ae36e2d9adc9e864ae93993d8f500172ab68c2d512

$ sudo docker run --rm -i -t --volume $PWD:/home/jaybeams \
    --workdir /home/jaybeams coryan/jaybeams-analysis:latest \
    /opt/jaybeams/bin/bm_order_book_analyze.R \
    bm_order_book_generate.1.results.csv
```

```
Loading required package: boot
Loading required package: ggplot2
Loading required package: parallel
Loading required package: pwr
[1] "Summary of data:"
 book_type      nanoseconds       microseconds         idx       
 array:35000   Min.   : 224499   Min.   : 224.5   Min.   :    1  
 map  :35000   1st Qu.: 402410   1st Qu.: 402.4   1st Qu.: 8751  
               Median : 929061   Median : 929.1   Median :17500  
               Mean   : 838618   Mean   : 838.6   Mean   :17500  
               3rd Qu.:1224166   3rd Qu.:1224.2   3rd Qu.:26250  
               Max.   :2577850   Max.   :2577.8   Max.   :35000  
[1] "Examine the data.plot.* files, observe if there are any obvious correlations in the data"
pdf 
  2 
pdf 
  2 
[1] "max.acf.array=0.0225"
[1] "max.acf.map=0.0487"
[1] "Estimating standard deviation on the 'array' data ..."
          used (Mb) gc trigger   (Mb)  max used   (Mb)
Ncells  500089 26.8     940480   50.3    940480   50.3
Vcells 1587257 12.2  169705721 1294.8 177070069 1351.0
[1] "Estimating standard deviation on the 'map' data ..."
          used (Mb) gc trigger   (Mb)  max used   (Mb)
Ncells  500133 26.8     940480   50.3    940480   50.3
Vcells 1772619 13.6  169889974 1296.2 177242991 1352.3
pdf 
  2 
pdf 
  2 
[1] "Estimated standard deviation: 202"
[1] "Minimum desired effect: 6.67"
[1] "statistic"   "parameter"   "p.value"     "null.value"  "alternative"
[6] "method"      "data.name"   "conf.int"    "estimate"   
[1] "Using the Mann-Whitney U test, the null hypothesis that both the 'array' and 'map' based order books have the same performance is rejected at the desired significance (alpha=0.01, p-value=0 is smaller than alpha).  The effect is quantified using the Hodges-Lehmann estimator, which is compatible with the Mann-Whitney U test, with a value of -796.56 microseconds in the confidence interval=[-798.82,-794.3]"
```

## Running on Cloud Virtual Machines


```
PROJECT="jaybeams-150920"
ZONE="us-central1-c"
PROJECTID=$(gcloud projects --quiet list | grep $PROJECT | awk '{print $3}')
gcloud compute --project $PROJECT instances create "benchmark-runner-01" \
  --zone $ZONE --machine-type "n1-standard-2" --subnet "default" \
  --maintenance-policy "MIGRATE" \
  --scopes "https://www.googleapis.com/auth/cloud-platform" \
  --service-account  ${PROJECTID}-compute@developer.gserviceaccount.com \
  --image "ubuntu-1604-xenial-v20170202" --image-project "ubuntu-os-cloud" \
  --boot-disk-size "32" --boot-disk-type "pd-standard" --boot-disk-device-name "benchmark-runner-01"

gcloud compute --project $PROJECT ssh --zone $ZONE "benchmark-runner-01"

sudo docker run --rm -i -t --cap-add sys_nice \
    --volume $PWD:/home/jaybeams --workdir /home/jaybeams \
    coryan/jaybeams-runtime-ubuntu16.04:latest \
    /opt/jaybeams/bin/bm_order_book_generate.sh

```

## Summary

## Next Up

## Notes

All the code for this post is available from the
[{{ghsha}}](https://github.com/coryan/jaybeams/tree/{{ghsha}})
version of JayBeams.

Metadata about the tests, including platform details can be found in
comments embedded with the data file.
The highlights of that metadata is reproduced here:

* CPU: AMD A8-3870 CPU @ 3.0Ghz
* Memory: 16GiB DDR3 @ 1333 Mhz, in 4 DIMMs.
* Operating System: Linux (Fedora 23, 4.8.13-100.fc23.x86_64)
* C Library: glibc 2.22
* C++ Library: libstdc++-5.3.1-6.fc23.x86_64
* Compiler: gcc 5.3.1 20160406
* Compiler Options: -O3 -Wall -Wno-deprecated-declarations

[issue 12]: /2017/01/04/on-benchmarking-part-1/#bad-not-reproducible
