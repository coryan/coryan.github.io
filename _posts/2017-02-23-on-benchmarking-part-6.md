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

```
sudo docker run --rm -i -t --cap-add sys_nice \
    --volume $PWD:/home/jaybeams --workdir /home/jaybeams \
    coryan/jaybeams-runtime-ubuntu16.04:tip \
    /opt/jaybeams/bin/bm_order_book_generate.sh
```

then 

```
sudo docker run --rm -i -t --volume $PWD:/home/jaybeams \
    --workdir /home/jaybeams coryan/jaybeams-analysis \
    /opt/jaybeams/bin/bm_order_book_analyze.R bm_order_book_generate.1.results.csv
```

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
