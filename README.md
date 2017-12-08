# Docker Nim

Simple Docker image including the Nim language compiler and tools (https://nim-lang.org/)

[![Docker Pulls](https://img.shields.io/docker/pulls/andreburgaud/nim.svg)](https://hub.docker.com/r/andreburgaud/nim/)
[![Docker Automated Build](https://img.shields.io/docker/automated/andreburgaud/nim.svg)](https://hub.docker.com/r/andreburgaud/nime/)
[![Docker Build Status](https://img.shields.io/docker/build/andreburgaud/nim.svg)](https://hub.docker.com/r/andreburgaud/nim/)

# Usage

```
$ docker pull andreburgaud/nim
```

The following examples are using files available in the GitHub repository of this image (folder `examples`):
https://github.com/andreburgaud/docker-nim

# Simple Example

* Compile a source file located on the host file system (`hello.nim`), and execute it (option `-r`) :

```
$ docker run --rm -v `pwd`/examples/:/workspace/ andreburgaud/nim nim c -r hello.nim
```

* Compile a source file located on the host file system (`hello.nim`) in release mode:

```
$ docker run --rm -v `pwd`/examples/:/workspace/ andreburgaud/nim nim c -d:release hello.nim
```

* Subsequently, execute the binary compiled in the previous step:

```
$ docker run --rm -v `pwd`/examples/:/workspace/ andreburgaud/nim ./hello
```

# More Advanced Example

* Compile a source file located on the host file system (`wc.nim`). First, package `strfmt` needs to be installed:

```
$ docker run --rm -it -v `pwd`/examples/:/workspace/ andreburgaud/nim sh -c "nimble install strfmt && nim c -d:release wc.nim"
```

When prompted to download a dependent package from the internet (`strfmt`), press `y` followed by the key `Enter`.

* Now, execute the binary created in the previous step:

```
$ docker run --rm -v `pwd`/examples/:/workspace/ andreburgaud/nim ./wc wc.nim
```

* Display the help of the newly built `wc`:

```
$ docker run --rm -v `pwd`/examples/:/workspace/ andreburgaud/nim ./wc --help
```

# Example using Nimble

```
$ docker run --rm -it -v `pwd`/examples/wc_proj/:/workspace/ andreburgaud/nim nimble c -d:release wc.nim
```

When prompted to download a dependent package from the internet (`strfmt`), press `y` followed by they key `Enter`.

* Now, execute the binary created in the previous step:

```
$ docker run --rm -it -v `pwd`/examples/wc_proj/:/workspace/ andreburgaud/nim ./wc wc.nim
```

# Build Local Image

```
$ docker build -t nim-dev .
```

Note that as of 12/6/2017, `nim` and `nimble` were still in the Alpine testing repository, thus requiring the following line, in the `Dockerfile`, prior to execute `apk add`:

```
RUN echo http://nl.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories
```
