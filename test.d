//          Copyright Jernej Krempuš 2012
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

import std.stdio, std.range, std.algorithm, std.conv, 
    std.math, std.numeric, std.complex, std.random;

version(Double)
{
    alias real U;
    
    import impl = pfft.impl_double;
}
else
{
	alias double U;
	
	import impl = pfft.impl_float;
}

auto rms(R)(R r)
{
    return std.math.sqrt(reduce!q{ a + b.re^^2 + b.im^^2 }(0.0, r) / r.length);
}

void main(string[] args)
{
    int log2n = parse!int(args[1]);
    int n = 1<<log2n;
    
    auto re = new impl.T[n];
    auto im = new impl.T[n];
    auto c = new Complex!(U)[n];
    
    rndGen.seed(1);
    foreach(i, e; re)
    {
        c[i].re = uniform(0.0,1.0);
        c[i].im = uniform(0.0,1.0);
        re[i] = c[i].re;
        im[i] = c[i].im;
    }
    
    auto ft = (new Fft(n)).fft!U(c);
    
    auto tables = impl.fft_table(log2n);
    impl.fft(re.ptr, im.ptr, log2n, tables);
    
    auto diff = map!
        ((a){ return a[2] - complex(a[0], a[1]); })
        (zip(re, im, ft));
    
    writefln("%.2e", rms(diff) / rms(ft));
}
