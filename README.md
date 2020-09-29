**Note: this project has been updated to DUB and latest compilers. For now only SSE and some example were restored.**

##pfft [![Build Status](https://travis-ci.org/p0nce/pfft.svg?branch=master)](https://travis-ci.org/p0nce/pfft)

The pretty fast fourier transform (pfft) is a fast, in place power of two split format fft library. It is written in D, but can also be used from C and other languages that support calling C functions. 



### Installation 

The instruction below assume you have an rdmd command available. If you don't, just compile the build.d script with "dmd build" and use "build" insted of "rdmd build" below.

#### Installing the D library

To build pfft, use the build.d rdmd script. You can use it like this:

    rdmd build.d

This will build the library suitable for use with D and save it to generated/lib. It will also copy the D files that need to be on the dmd include path to generated/include/pfft. The above command will build the library using the GDC compiler and SSE instruction set. If you want something else, see

    rdmd build.d --help

After you build the library, you can copy the contents of generated/include and generated/lib somewhere where the D compiler can find them. Otherwise you will need to use the flags -I/path/to/generated/include and -L-L/path/to/generated/lib when compiling programs that use pfft. In any case, you will need to use the -L-lpfft flag.

#### Installing the C library

To build the library for use with C, run the following command:

    rdmd build.d --clib

This will build the library for use with C and save it to generated-c/lib. It will use the GDC compiler and the SSE instruction set. To use it differently,
see 

    rdmd build.d --help

You can copy the library somewhere where the C compiler can find it, for example on unix like systems you could do this:

    cp -r generated-c/* /usr/local/

When compiling C programs using pfft you will need to use the -lpfft-c flag.

#### Windows notes

It is recommended that you download the prebuilt (with GDC) version of pfft from [here](https://github.com/jerro/pfft/downloads). This package also contains the C library. It can not be used with DMD, though.

DMD on Windows does not support SIMD intrinsics yet and there is a bug in SIMD support in the recent builds of MinGW GDC that prevents pfft from building. So I have built a version with an older build of MinGW GDC and uploaded it to Github downloads page. Until the bug in MinGW GDC is fixed or SIMD support is added to DMD on Windows, you should use the prebuilt version if you care about performance.

### Usage

For API reference, see the doc directory or  [the documentation pages](http://jerro.github.com/pfft/doc/pfft.pfft.html)

There are three different ways of using pfft:

* Using the pfft.clib module. The functions in this module can be used from C.  The performance of this module should be identical to that of pfft.pfft.
* Using the pfft.stdapi module. This module mimics the API of std.numeric.fft.
* Using the pfft.pfft module. This module uses split format for complex numbers which makes it significantly faster than pfft.stdapi (See the [benchmarks page](http://jerro.github.com/pfft/benchmarks/)). 

For examples of all three ways of using pfft, see the examples directory.



### Benchmarks

See the [benchmarks page](http://jerro.github.com/pfft/benchmarks/)).
