---
layout: post
title: On Benchmarking, Part 6
date: 2017-02-23 15:00
draft: true
---

{% assign ghsha = "e444f0f072c1e705d932f1c2173e8c39f7aeb663" %}
{% capture ghver %}https://github.com/coryan/jaybeams/blob/{{ghsha}}{% endcapture %}
{% capture docker_tag %}2017-02-23-on-benchmarking-part-6{% endcapture %}

> This is a long series of posts where I try to teach myself how to
> run rigorous, reproducible microbenchmarks on Linux.  You may
> want to start from the [first one](/2017/01/04/on-benchmarking-part-1/)
> and learn with me as I go along.
> I am certain to make mistakes, please write be back in
> [this bug](https://github.com/coryan/coryan.github.io/issues/1) when
> I do.

In my [previous post]({{page.previous.url}}) I chose the [Mann-Whitney U
Test](https://en.wikipedia.org/wiki/Mann%E2%80%93Whitney_U_test)
to perform an statistical test of hypothesis comparing
`array_based_order_book` vs. `map_based_order_book`.
I also explored why neither the arithmetic mean, nor the median are
good measures of effect in this case.
I learned about the [Hodges-Lehmann
Estimator](https://en.wikipedia.org/wiki/Hodges%E2%80%93Lehmann_estimator)
as a better measure of effect for performance improvement.
Finally I used some mock data to familiarize myself with these tools.

In this post I will solve the last remaining issue from my
[Part 1](/2017/01/04/on-benchmarking-part-1/) of this series.
Specifically [[I12]][issue 12]: how can anybody reproduce the results
that I obtained.

## The Challenge of Reproducibility

I have gone to some length to make the tests producible:

* The code under test, and the code used to generate the results is
available from my [github](https://github.com/coryan/) account.
* The code includes full instructions to compile the system, and in
addition to the human readable documentation there are automated
scripts to compile the system.
* I have also documented which specific version of the code was used
to generate each post, so a potential reader (maybe a future version
of myself), can fetch the specific version and rerun the tests.
* Because compilation instructions can be stale, or incorrect, or hard
to follow,
I have made an effort to provide pre-packaged
[docker](https://www.docker.com) images with
all the development tools and dependencies necessary to compile and
execute the benchmarks.

Despite these efforts I expect that it would be difficult, if not
impossible, to reproduce the results for a casual or even a persistent
reader: the exact hardware and software configuration that I used,
though documented, would be extremely hard to put together again.
Within months the packages used to compile and link the code will no
longer be *current*, and may even disappear from the repositories
where I fetched them from.
In addition, it would be quite a task to collect
the specific parts to reproduce a custom-built computer put together
several years ago.

I think containers may offer a practical way to package
the development environment, the binaries, and the analysis tools in a
form that allows us to reproduce the results easily.

I do not believe the reader would be able to reproduce the absolute
performance numbers, those depend closely on the physical hardware
used.
But one should be able to reproduce the main results, such as the
relative performance improvements, or the fact that we observed a
statistically significant improvement in performance.

I aim to explore these ideas in this post, though I cannot say that I
have fully solved the problems that arise when trying to use them.

## Towards Reproducible Benchmarks

As a first step I have modified JayBeams to create *runtime* images
with all the necessary code to run the benchmarks.
Assuming you have a Linux workstation (or server), with docker
configured you should be able to execute the following commands to run
the benchmark:

{% assign dockerid = '{{ .Id }}' %}

``` sh
$ TAG={{docker_tag}}
$ sudo docker pull coryan/jaybeams-runtime-fedora25:$TAG
$ sudo docker run --rm -i -t --cap-add sys_nice --privileged \
    --volume $PWD:/home/jaybeams --workdir /home/jaybeams \
    coryan/jaybeams-runtime-fedora25:$TAG \
    /opt/jaybeams/bin/bm_order_book_generate.sh
```

The results will be generated in a local file named
`bm_order_book_generate.1.results.csv`.
You can verify I used the same version of the runtime image with the
following command:

``` sh
$ sudo docker inspect -f '{{ dockerid }}' \
    coryan/jaybeams-runtime-fedora25:$TAG
sha256:7e7c5e91f2e46b902144d1de4b41b3d02407c38a56b1f58c27576012c0226d24
```

### Reproduce the Analysis

A separate image can be used to reproduce the analysis.  I prefer a
separate image because the analysis image tends to be relatively
large:

``` sh
$ cd $HOME
$ sudo docker pull coryan/jaybeams-analysis:$TAG
$ sudo docker inspect -f '{{ dockerid }}' \
    coryan/jaybeams-analysis:$TAG
sha256:01ad76f9e70e46eb65f840ae36e2d9adc9e864ae93993d8f500172ab68c2d512
```

First we copy the results produced earlier to a directory hierarchy
that will work with my blogging platform:

``` sh
$ cd $HOME/coryan.github.io
$ cp bm_order_book_generate.1.results.csv \
  public{{page.id}}/workstation-results.csv
$ sudo docker run --rm -i -t --volume $PWD:/home/jaybeams \
    --workdir /home/jaybeams coryan/jaybeams-analysis:$TAG \
    /opt/jaybeams/bin/bm_order_book_analyze.R \
    public{{page.id}}/workstation-results.csv \
    public{{page.id}}/workstation \
    _includes/{{page.id}}/workstation-report
```

{% include {{page.id}}/workstation-report.md %}

## Running on Cloud Virtual Machines

[//]: # (PROJECT="jaybeams-150920")
[//]: # (ZONE="us-central1-c")

``` sh
$ PROJECT=[your project name here]
$ ZONE=[your favorite zone here]
$ PROJECTID=$(gcloud projects --quiet list | grep $PROJECT | \
    awk '{print $3}')
$ gcloud compute --project $PROJECT instances \
  create "benchmark-runner" \
  --zone $ZONE --machine-type "n1-standard-2" --subnet "default" \
  --maintenance-policy "MIGRATE" \
  --scopes "https://www.googleapis.com/auth/cloud-platform" \
  --service-account \
    ${PROJECTID}-compute@developer.gserviceaccount.com \
  --image "ubuntu-1604-xenial-v20170202" \
  --image-project "ubuntu-os-cloud" \
  --boot-disk-size "32" --boot-disk-type "pd-standard" \
  --boot-disk-device-name "benchmark-runner"

# Login to new VM and run some commands on it ...
$ gcloud compute --project $PROJECT ssh \
  --ssh-flag=-A --zone $ZONE "benchmark-runner"
$ sudo apt-get update
$ sudo apt-get install -y docker.io
$ TAG={{docker_tag}}
$ sudo docker run --rm -i -t --cap-add sys_nice --privileged \
    --volume $PWD:/home/jaybeams --workdir /home/jaybeams \
    coryan/jaybeams-runtime-ubuntu16.04:$TAG \
    /opt/jaybeams/bin/bm_order_book_generate.sh
$ exit

# Back in your workstation ...
$ gcloud compute --project $PROJECT copy-files --zone $ZONE \
  benchmark-runner:bm_order_book_generate.1.results.csv \
  public/{{page.id}}/vm-results.csv
$ sudo docker run --rm -i -t --volume $PWD:/home/jaybeams \
    --workdir /home/jaybeams coryan/jaybeams-analysis:$TAG \
    /opt/jaybeams/bin/bm_order_book_analyze.R \
    public{{page.id}}/vm-results.csv \
    public{{page.id}}/vm
    _includes/{{page.id}}/vm-report

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
* Operating System: Linux (Fedora 25, 4.9.6-200.fc25.x86_64)
* C Library: glibc-2.24-3.fc25.x86_64
* C++ Library: libstdc++-6.3.1-1.fc25
* Compiler: gcc 6.3.1 20161221
* Compiler Options: -O3 -Wall -Wno-deprecated-declarations

[issue 12]: /2017/01/04/on-benchmarking-part-1/#bad-not-reproducible
