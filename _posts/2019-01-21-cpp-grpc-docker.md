---
layout: post
title: Running a C++ gRPC Server inside Docker
date: 2019-01-20 17:00
---

I recently became interested in using [Kubernetes][k8s-link] (aka *k8s*) to run
production services. One of the challenges I set for myself was to create a
relatively small Docker image for a C++ server of some sort. After some fiddling
with the development environment and tools I was able to create a 15MiB image
that contains both a server and a small client. This post describes how I got
this to work.

## The Plan

My first idea was to create a minimal program, link it statically, and then copy
the program into the Docker image. In principle that should make the image
fairly small, a minimal [Alpine Linux][alpine-link] image is only 4MiB, if the
program is statically linked no other requirements are needed.

Unfortunately, most Linux distributions use [glibc][wikipedia-glibc], which, for all practical purposes [requires][glibc-dynamic-faq] dynamic linking to support
"Name Service Switch" (NSS). Furthermore, glibc is licensed under the
[GNU Lesser General Public License][wikipedia-LGPL], and I do not want to
concern myself with the terms under which the binaries that statically link
glibc may or may not be redistributed. I am interested in writing code, not in
becoming a lawyer.

Fortunately Alpine Linux is based on the [musl][wikipedia-musl] library, which
supports static linking without any of the glibc headaches.

To make the build easy to reproduce, we will first create a Docker image
containing all the development tools. I expect that this image will be rather
large, as the development tools, plus libraries, plus headers can take
significant space. The trick is to use Docker
[multi-stage builds][https://docs.docker.com/develop/develop-images/multistage-build/]
to first compile the server using this large image, and then copy only the
server binary into a much smaller Docker image.

## Setting up the Development Environment

Most of the libraries and tools I needed to compile my server were readily
available as Alpine Linux packages. So I just installed them using:

```console
apk update && apk add build-base gcc g++
```

To get the static version of the C library you need to install one more package:

```console
apk update && apk add libc-dev
```

I prefer to use [Boost][boost-link] instead of writing my own libraries, so I
also installed the development version of Boost and the static version of these
libraries:

```console
apk update && apk add boost-dev boost-static
```

I also prefer [CMake][cmake-link] as a meta-build system, and
[Ninja][ninja-link] as its backend:

```console
apk update && apk add cmake ninja
```

Finally I will use [vcpkg][vcpkg-link] to install any dependencies that do not
have suitable Alpine Linux packages, so add some additional tools:

```console
apk update && apk add curl git perl unzip tar
```

### Compiling Additional dependencies

Some of the dependencies, such as gRPC, do not have readily available packages,
in this case I just use vcpkg to build them. First we need to download and
compile vcpkg itself:

```console
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
./bootstrap-vcpkg.sh --useSystemBinaries
```

Note that vcpkg can download the binaries it needs, such as CMake, or Perl, but
I decided to disable these downloads. Now we can compile the dependencies:

```console
./vcpkg install --triplet x64-linux grpc
```

The `triplet` option is needed because vcpkg seems to default to a non-usable
triplet under Alpine Linux.

## Compiling the gRPC server

With all the development tools in place I created a [small project](https://github.com/coryan/docker-grpc-cpp) with a gRPC echo service.
This project is available from GitHub:

```console
git clone https://github.com/coryan/docker-grpc-cpp.git
cd docker-grpc-cpp
```

I prefer CMake as by build tool for C++, in this case we need to provide a
number of special options:

| Option | Description |
| ------ | ----------- |
| -H.    | Set the source directory |
| -B.build    | Configure the binary output directory |
| -GNinja     | Use `Ninja` as the backend build system |
| -DCMKE_BUILD_TYPE=Release | Compile optimized binaries |
| -DCMAKE_TOOLCHAIN_FILE=.../vcpkg.cmake | Use vcpkg in `find_package()` |
| -DBoost_USE_STATIC_LIBS=ON | Use the static libraries for Boost |
| -DCMAKE_EXE_LINKER_FLAGS="-static" | Create static binaries |

Putting these options together:

```console
cmake -H. -B.build \
    -GNinja \
    -DCMKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=/l/vcpkg/scripts/buildsystems/vcpkg.cmake \
    -DBoost_USE_STATIC_LIBS=ON \
    -DCMAKE_EXE_LINKER_FLAGS="-static"
```

and then build the usual way:

```console
cmake --build .build
```

## Scripting the Build

That is a lot of steps to remember, fortunately they are easy to script.
First I created a [Dockerfile](https://github.com/coryan/docker-grpc-cpp/blob/master/tools/Dockerfile.devtools) prepare an image with the development tools:

```console
sudo docker build -t grpc-cpp-devtools:latest -f tools/Dockerfile.devtools tools
```

As I expected this is a rather large image:

```
REPOSITORY          TAG                 SIZE
grpc-cpp-devtools   latest              974MB
```

But as I planned all along we can use that image to create the server image:

```console
$ sudo docker build -t grpc-cpp-echo:latest -f examples/echo/Dockerfile.server .
```

Which is much smaller:

```
REPOSITORY          TAG                 SIZE
grpc-cpp-echo       latest              11.8MB
grpc-cpp-devtools   latest              974MB
```

## Running the server

Of course this would all be for naught if we cannot run and use the server:

```console
ID=$(sudo docker run -d -P grpc-cpp-echo:latest /r/echo_server)
```

```console
ADDRESS=$(sudo docker port "${ID}" 7000)
sudo docker run --network=host grpc-cpp-echo:latest /r/echo_client \
    --address "${ADDRESS}"
Response ping-0
Response ping-1
Response ping-2
Response ping-3
Response ping-4
Response ping-5
Response ping-6
Response ping-7
Response ping-8
Response ping-9
```



## Further Thoughts

I hope you found these instructions useful. I hope I will have time to describe
using an image such as the one created in this post to run a Kubernetes-based
service.

[alpine-link]: https://alpinelinux.org
[boost-link]: https://boost.org
[cmake-link]: https://cmake.org
[glibc-dynamic-faq]: https://sourceware.org/glibc/wiki/FAQ#Even_statically_linked_programs_need_some_shared_libraries_which_is_not_acceptable_for_me.__What_can_I_do.3F
[k8s-link]: https://kubernetes.io
[ninja-link]: https://ninja-build.org
[vcpkg-link]: https://github.com/Microsoft/vcpkg/
[wikipedia-glibc]: https://en.wikipedia.org/wiki/GNU_C_Library
[wikipedia-LGPL]: https://en.wikipedia.org/wiki/GNU_Lesser_General_Public_License
[wikipedia-musl]: https://en.wikipedia.org/wiki/Musl
