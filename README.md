# Docker Nim

Simple Docker image including the Nim compiler https://nim-lang.org/docs/nimc.html

# Build image

```
$ docker build -t nim-dev .
```

Note that as of 12/6/2017, `nim` and `nimble` were still in the Alpine testing repository, thus requiring the following line prior to execute `apk add`:

```
RUN echo http://nl.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories
```

# Usage

The following examples are using files available in the GitHub repository of this image (folder `examples`):
https://github.com/andreburgaud/docker-nim

## Simple Example

* Compile a source file located on the host file system (`hello.nim`), and execute:

```
$ docker run --rm -v `pwd`/examples/:/workspace/ nim-dev nim c -r hello.nim

```

* Compile a source file located on the host file system (`hello.nim`) in release mode:

```
$ docker run --rm -v `pwd`/examples/:/workspace/ nim-dev nim c -d:release hello.nim

```

* Subsequently execute the binary compiled in the previous step:

```
$ docker run --rm -v `pwd`/examples/:/workspace/ nim-dev ./hello

```

## A More Advanced Example


* Compile a source file located on the host file system (`wc.nim`). First, package `strfmt` needs to be installed:


```
$ docker run --rm -it -v `pwd`/examples/:/workspace/ nim-dev sh -c "nimble install strfmt && nim c -d:release wc.nim"
```

When prompted to download a dependent package from the internet (`strfmt`), press `y` followed by they key `Enter`.

* Now execute the binary created in the previous step:

```
$ docker run --rm -v `pwd`/examples/:/workspace/ nim-dev ./wc wc.nim
```

* Display the help of the newly built `wc`:

```
$ docker run --rm -v `pwd`/examples/:/workspace/ nim-dev ./wc --help
```

## Example using Nimble

```
$ docker run --rm -it -v `pwd`/examples/wc_proj/:/workspace/ nim-dev nimble c -d:release wc.nim

```

When prompted to download a dependent package from the internet (`strfmt`), press `y` followed by they key `Enter`.

* Now execute the binary created in the previous step:

```
$ docker run --rm -it -v `pwd`/examples/wc_proj/:/workspace/ nim-dev ./wc wc.nim
```

