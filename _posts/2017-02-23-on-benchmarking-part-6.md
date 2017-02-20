---
layout: post
title: On Benchmarking, Part 6
date: 2017-02-20 17:00
draft: true
---

{% assign ghsha = "78bdecd855aa9c25ce606cbe2f4ddaead35706f1" %}
{% capture ghver %}https://github.com/coryan/jaybeams/blob/{{ghsha}}{% endcapture %}
{% capture docker_tag %}{{ page.id  | remove_first: '/' | replace: '/', '-' }}{% endcapture %}



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

As part of its continuous integration builds JayBeams creates
*runtime* images with all the necessary code to run the benchmarks.
I have manually tagged the images that I used in this post, with the
post name, so they can be easily fetched.
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
sha256:e9005a2b9fd788deb0171494d303c0aeb0685b46cb8e620f069da5e6e29cd242
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
    _includes/{{page.id}}/workstation-report.md
```

The resulting report is included
[later](#report-for-workstation-resultscsv)
in this post.

## Running on Public Cloud Virtual Machines

Though the previous steps have addressed the problems with recreating
the software stack used to run the benchmarks I have not addressed the
problem of reproducing the hardware stack.

I thought I could solve this problem using public cloud, such as
[Amazon Web Services](https://aws.amazon.com/),
or [Google Cloud Platform](https://cloud.google.com).
Unfortunately I do not know (yet?) how to control the environment on a
public cloud virtual machine to avoid auto-correlation in the sample
data.

Below I will document the steps to run the benchmark on a virtual
machine,
but I should warn the reader upfront that the results are suspect.

The resulting report is included
[later](#report-for-vm-resultscsv)
in this post.

### Create the Virtual Machine

I have chosen Google's public cloud simply because I am more familiar
with it, I make no claims as to whether it is better or worse than the
alternatives.

``` sh
# Set these environment variables based on your preferences
# for Google Cloud Platform
$ PROJECT=[your project name here]
$ ZONE=[your favorite zone here]
$ PROJECTID=$(gcloud projects --quiet list | grep $PROJECT | \
    awk '{print $3}')

# Create a virtual machine to run the benchmark
$ VM=benchmark-runner
$ gcloud compute --project $PROJECT instances \
  create $VM \
  --zone $ZONE --machine-type "n1-standard-2" --subnet "default" \
  --maintenance-policy "MIGRATE" \
  --scopes "https://www.googleapis.com/auth/cloud-platform" \
  --service-account \
    ${PROJECTID}-compute@developer.gserviceaccount.com \
  --image "ubuntu-1604-xenial-v20170202" \
  --image-project "ubuntu-os-cloud" \
  --boot-disk-size "32" --boot-disk-type "pd-standard" \
  --boot-disk-device-name $VM
```

### Login and Run the Benchmark

``` sh
$ gcloud compute --project $PROJECT ssh \
  --ssh-flag=-A --zone $ZONE $VM
$ sudo apt-get update && sudo apt-get install -y docker.io
$ TAG={{docker_tag}}
$ sudo docker run --rm -i -t --cap-add sys_nice --privileged \
    --volume $PWD:/home/jaybeams --workdir /home/jaybeams \
    coryan/jaybeams-runtime-ubuntu16.04:$TAG \
    /opt/jaybeams/bin/bm_order_book_generate.sh 100000
$ exit
```

### Fetch the Results and Generate the Reports

``` sh
# Back in your workstation ...
$ gcloud compute --project $PROJECT copy-files --zone $ZONE \
  $VM:bm_order_book_generate.1.results.csv \
  public/{{page.id}}/vm-results.csv
$ sudo docker run --rm -i -t --volume $PWD:/home/jaybeams \
    --workdir /home/jaybeams coryan/jaybeams-analysis:$TAG \
    /opt/jaybeams/bin/bm_order_book_analyze.R \
    public{{page.id}}/vm-results.csv \
    public{{page.id}}/vm \
    _includes/{{page.id}}/vm-report.mdw
```

### Cleanup

``` sh
# Delete the virtual machine
$ gcloud compute --project $PROJECT \
    instances delete $VM --zone $ZONE
```


## Docker Image Creation

All that remains at this point is to describe how the images
themselves are created.
I automated the process to create images as part of the continuous
integration builds for JayBeams.
After each commit to the `master`
branch [travis](https://travis-ci.org/coryan/jaybeams) checks out the
code, uses an existing development environment to compile and test the
code, and then creates the runtime and analysis images.

If the runtime and analysis images differ from the existing images in
the github [repository](https://hub.docker.com/u/coryan/) the new
images are automatically pushed to the github repository.

If necessary, a new development image is also created as part of the
continuous integration build.
This means that the development image might be one build behind,
as the latest runtime and analysis images may have been created with a
previous build image.
I have an outstanding
[bug](https://github.com/coryan/jaybeams/issues/129) to fix this problem.
In practice this is not a major issue because the development
environment changes rarely.

An [appendix](#appendix-manual-image-creation) to this post includes
step-by-step instructions on what the automated continuous integration
build does.

### Tagging Images for Final Report

The only additional step is to tag the images used to create this
report, so they are not lost in the midst of time:

``` sh
$ TAG={{docker_tag}}
$ for image in \
    coryan/jaybeams-analysis \
    coryan/jaybeams-runtime-fedora25 \
    coryan/jaybeams-runtime-ubuntu16.04; do
  sudo docker pull ${image}:latest
  sudo docker tag ${image}:latest ${image}:$TAG
  sudo docker push ${image}:$TAG
done
```

## Summary

In this post I addressed the last remaining issue identified at the
[beginning](/2017/01/04/on-benchmarking-part-1/) of this series.
I have made the tests as reproducible as I know how.
A reader can execute the tests in a public cloud server, or if they
prefer on their own Linux workstation, by downloading and executing
pre-compiled images.

It is impossible to predict for how long those images will remain
usable, but they certainly go a long way to make the tests and
analysis completely scripted.

Furthermore, the code to create the images themselves has been fully
automated.

## Next Up

I will be taking a break from posting about benchmarks and statistics,
I want to go back to writing some code, more than talking about how to
measure code.

## Notes

All the code for this post is available from the
[{{ghsha}}](https://github.com/coryan/jaybeams/tree/{{ghsha}})
version of JayBeams, including the `Dockerfile`s used to create the
images.

The images themselves were automatically created using
[travis.org](https://travis.org), a service for continuous
integration.
The travis configuration file and helper script are also part of the
code for JayBeams.

The data used generated and used in this post is also available:
[workstation-results.csv](/public/{{page.id}}/workstation-results.csv),
and [vm-results.csv](/public/{{page.id}}/workstation-results.csv).

Metadata about the tests, including platform details can be found in
comments embedded with the data files.

[issue 12]: /2017/01/04/on-benchmarking-part-1/#bad-not-reproducible

### Appendix: Manual Image Creation

Normally the images are created by an automated build, but for
completeness we document the steps to create one of the runtime images
here.
We assume the system has been configured to run docker, and the
desired version of JayBeams has been checked out in the current
directory.

First we create a virtual machine, that guarantees that we do not have
hidden dependencies on previously installed tools or configurations:

``` sh
$ VM=jaybeams-build
$ gcloud compute --project $PROJECT instances \
  create $VM \
  --zone $ZONE --machine-type "n1-standard-2" --subnet "default" \
  --maintenance-policy "MIGRATE" \
  --scopes "https://www.googleapis.com/auth/cloud-platform" \
  --service-account \
    ${PROJECTID}-compute@developer.gserviceaccount.com \
  --image "ubuntu-1604-xenial-v20170202" \
  --image-project "ubuntu-os-cloud" \
  --boot-disk-size "32" --boot-disk-type "pd-standard" \
  --boot-disk-device-name $VM
```

Then we connect to the virtual machine:

``` sh
$ gcloud compute --project $PROJECT ssh \
  --ssh-flag=-A --zone $ZONE $VM
```

install the latest version of docker on the virtual machine:

``` sh
# ... these commands are on the virtual machine ..
$ curl -fsSL https://apt.dockerproject.org/gpg | \
    sudo apt-key add -
$ sudo add-apt-repository \
       "deb https://apt.dockerproject.org/repo/ \
       ubuntu-$(lsb_release -cs) \
       main"
$ sudo apt-get update && sudo apt-get install -y docker-engine
```

we set the build parameters:

``` sh
$ export IMAGE=coryan/jaybeamsdev-ubuntu16.04 \
    COMPILER=g++ \
    CXXFLAGS=-O3 \
    CONFIGUREFLAGS="" \
    CREATE_BUILD_IMAGE=yes \
    CREATE_RUNTIME_IMAGE=yes \
    CREATE_ANALYSIS_IMAGE=yes \
    TRAVIS_BRANCH=master \
    TRAVIS_PULL_REQUEST=false
```

Checkout the code:

``` sh
$ git clone https://github.com/coryan/jaybeams.git
$ cd jaybeams
$ git checkout {{ghsha}}
```

Download the build image and compile, test, and install the code in a
staging area:

``` sh
$ sudo docker pull ${IMAGE?}
$ sudo docker run --rm -it \
    --env CONFIGUREFLAGS=${CONFIGUREFLAGS} \
    --env CXX=${COMPILER?} \
    --env CXXFLAGS="${CXXFLAGS}" \
    --volume $PWD:$PWD \
    --workdir $PWD \
    ${IMAGE?} ci/build-in-docker.sh
```

To recreate the runtime image locally, this will not push to the
github repository, because the github credentials are not provided:

``` sh
$ ci/create-runtime-image.sh
```

Likewise we can recreate the analysis image:

``` sh
$ ci/create-analysis-image.sh
```

We can examine the images created so far:

``` sh
$ sudo docker images
```

Before we exit and delete the virtual machine:

``` sh
$ exit

# ... back on your workstation ...
$ gcloud compute --project $PROJECT \
    instances delete $VM --zone $ZONE
```

----

{% include {{page.id}}/workstation-report.md %}

----

{% include {{page.id}}/vm-report.md %}
