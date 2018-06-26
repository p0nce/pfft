//          Copyright Jernej Krempuš 2012
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module pfft.avx_float;

import core.simd;

import pfft.fft_impl;

import pfft.ldc_compat;
import pfft.dmd32_compat;

@target("avx2"): // else no AVX instruction is generated
//version = SSE_AVX; // only backend supported in this fork

version(DigitalMars)
{

}
else version(LDC)
{
}
else version(GNU)
{
    import gcc.builtins;

    template shuf_mask(int a3, int a2, int a1, int a0)
    { 
        enum shuf_mask = a0 | (a1<<2) | (a2<<4) | (a3<<6); 
    }

    float8 insert128_0(float8 a, float4 b)
    {
        return __builtin_ia32_vinsertf128_ps256(a, b, 0);
    }
    
    float8 insert128_1(float8 a, float4 b)
    {
        return __builtin_ia32_vinsertf128_ps256(a, b, 1);
    }

    float8 interleave128_lo(float8 a, float8 b)
    {
        return __builtin_ia32_vperm2f128_ps256(a, b, shuf_mask!(0,2,0,0)); // 32 0010 0000
    }

    float8 interleave128_hi(float8 a, float8 b)
    {
        return __builtin_ia32_vperm2f128_ps256(a, b, shuf_mask!(0,3,0,1));
    }

    float8  reverse128(float8 v)
    {
        return __builtin_ia32_vperm2f128_ps256(v, v, shuf_mask!(0, 0, 0, 1));
    }

    alias __builtin_ia32_unpcklps256 unpcklps;
    alias __builtin_ia32_unpckhps256 unpckhps;
    alias __builtin_ia32_loadups256 loadups;
    alias __builtin_ia32_storeups256 storeups;
    
    auto shufps(param...)(float8 a, float8 b)
    {
        return __builtin_ia32_shufps256(a, b, shuf_mask!param);
    }

}

struct Vector 
{
nothrow:
@nogc:
    alias float8 vec;
    alias float T;
    
    enum vec_size = 8;
  
    enum log2_bitreverse_chunk_size = 3;
 
    static auto v(T* p){ return cast(float4*) p; }
    static auto v8(T* p){ return cast(float8*) p; }
    
    static void _deinterleave2(vec a0, vec a1, ref vec r0, ref vec r1)
    {
        r0 = interleave128_lo(a0, a1);
        r1 = interleave128_hi(a0, a1);
    }
   
    // the three functions below do not do exactly what the names imply, but that's
    // ok (fft works correctly when using them)
 
    static void complex_array_to_real_imag_vec(int n)(T* arr, ref vec rr, ref vec ri)
    {
        static if(n == 8)
        {
            deinterleave(v8(arr)[0], v8(arr)[1], rr, ri); 
        }
        else static if (n == 4)
        {
            vec a = *v8(arr);
            rr = shufps!(2, 2, 0, 0)(a, a);
            ri = shufps!(3, 3, 1, 1)(a, a);
        }
        else static if(n == 2)
        {
            rr = insert128_0(rr, arr[0]);
            rr = insert128_1(rr, arr[2]);
            ri = insert128_0(ri,  arr[1]);
            ri = insert128_1(ri,  arr[3]);
        }
        else
            static assert(0);
    }
   
    static void interleave(vec a0, vec a1, ref vec r0, ref vec r1)
    {
        vec a0_tmp = unpcklps(a0, a1);
        a1 =         unpckhps(a0, a1);
        _deinterleave2(a0_tmp, a1, r0, r1);
    }
    
    static void deinterleave(vec a0, vec a1, ref vec r0, ref vec r1)
    {
        _deinterleave2(a0, a1, a0, a1); 
        r0 = shufps!(2,0,2,0)(a0, a1);
        r1 = shufps!(3,1,3,1)(a0, a1);
    }

    static void transpose(int elements_per_vector)(
        vec a0, vec a1, ref vec r0, ref vec r1)
    {
        static if(elements_per_vector == 8)
        {
            r0 = shufps!(2,0,2,0)(a0, a1);
            r1 = shufps!(3,1,3,1)(a0, a1);
            r0 = shufps!(3,1,2,0)(r0, r0);
            r1 = shufps!(3,1,2,0)(r1, r1);
        }
        else static if(elements_per_vector == 4)
        {
            r0 = shufps!(1,0,1,0)(a0, a1);
            r1 = shufps!(3,2,3,2)(a0, a1);
        }
        else static if(elements_per_vector == 2)
        {
            r0 = interleave128_lo(a0, a1);
            r1 = interleave128_hi(a0, a1);
        }
        else
            static assert(0);
    }

    private static void br16_two(ref vec a0, ref vec a1, ref vec a2, ref vec a3)
    {
        vec b0 = shufps!(1, 0, 1, 0)(a0, a2);
        vec b1 = shufps!(1, 0, 1, 0)(a1, a3);
        vec b2 = shufps!(3, 2, 3, 2)(a0, a2);
        vec b3 = shufps!(3, 2, 3, 2)(a1, a3);

        a0 = shufps!(2, 0, 2, 0)(b0, b1);
        a1 = shufps!(2, 0, 2, 0)(b2, b3);
        a2 = shufps!(3, 1, 3, 1)(b0, b1);
        a3 = shufps!(3, 1, 3, 1)(b2, b3);
    }

    private static void br64(
        ref vec a0, ref vec a1, ref vec a2, ref vec a3,
        ref vec a4, ref vec a5, ref vec a6, ref vec a7)
    {
        // reverse the outer four bits 
        br16_two(a0, a2, a4, a6);
        br16_two(a1, a3, a5, a7);
        
        // reverse the inner two bits
        _deinterleave2(a0, a1, a0, a1); 
        _deinterleave2(a2, a3, a2, a3); 
        _deinterleave2(a4, a5, a4, a5); 
        _deinterleave2(a6, a7, a6, a7); 
    }
    
    template RepeatType(T, int n, R...)
    {
        static if(n == 0)
            alias R RepeatType;
        else
            alias RepeatType!(T, n - 1, T, R) RepeatType;
    }
        
    static void bit_reverse_swap(T* p0, T* p1, size_t m)
    {
        RepeatType!(vec, 8) a, b;    

        foreach(i, _; a)
            a[i] = *v8(p0 + i * m);

        br64(a);

        foreach(i, _; a)
            b[i] = *v8(p1 + i * m);

        foreach(i, _; a)
            *v8(p1 + i * m) = a[i];

        br64(b);

        foreach(i, _; a)
            *v8(p0 + i * m) = b[i];
    }

    static void bit_reverse(T* p0, size_t m)
    {
        RepeatType!(vec, 8) a;    

        foreach(i, _; a)
            a[i] = *v8(p0 + i * m);

        br64(a);

        foreach(i, _; a)
            *v8(p0 + i * m) = a[i];
    }

    static vec scalar_to_vector(T a)
    {
        return a;
    }

    static vec unaligned_load(T* p)
    {
        return loadups(p);
    }

    static void unaligned_store(T* p, vec v)
    {
        storeups(p, v);
    }

    static vec reverse(vec v)
    {
        v = shufps!(0, 1, 2, 3)(v, v);
        return reverse128(v);
    }

    version(LDC)
    {
        static shufps(int m3, int m2, int m1, int m0)(vec a, vec b)
        {
            return shufflevector!(float8, m0, m1, m2+8, m3+8, 
                                          m0+4, m1+4, m2+12, m3+12)(a, b);
        }

        static vec unpcklps(vec a, vec b)
        { 
            return shufflevector!(float8, 0, 8, 1, 9, 
                                          4, 12, 5, 13)(a, b);
        }

        static vec unpckhps(vec a, vec b)
        { 
            return shufflevector!(float8, 2, 10, 3, 11, 
                                          6, 14, 7, 15)(a, b);
        }

        static vec interleave128_lo(vec a, vec b)
        {
            return shufflevector!(float8, 0, 1, 2, 3, 8, 9, 10, 11)(a, b);
        }

        static vec interleave128_hi(vec a, vec b)
        {
            return shufflevector!(float8, 4, 5, 6, 7, 12, 13, 14, 15)(a, b);
        }

        static vec reverse128(vec a)
        {
            return shufflevector!(float8, 4, 5, 6, 7, 0, 1, 2, 3)(a, a);
        }

        static vec loadups(T* p)
        {
            return loadUnaligned!vec(cast(float*)p);
        }

        static void storeups(T* p, vec v)
        {
            storeUnaligned!vec(v, cast(float*)p);
        }

        static float8 insert128_0(float8 a, float4 b)
        {
            float[8] res = a.array;
            float[4] toInsert = b.array;
            res[0..4] = toInsert[0..4];
            return loadups(res.ptr);
        }

        static float8 insert128_1(float8 a, float4 b)
        {
            float[8] res = a.array;
            float[4] toInsert = b.array;
            res[4..8] = toInsert[0..4];
            return loadups(res.ptr);
        }
    }
}

struct Options
{
    enum log2_bitreverse_large_chunk_size = 5;
    enum large_limit = 14;
    enum log2_optimal_n = 8;
    enum passes_per_recursive_call = 4;
    enum log2_recursive_passes_chunk_size = 4;
    enum prefered_alignment = 4 * (1 << 10);
}

version(SSE_AVX)
{
    import pfft.fft_impl;
    enum implementation = 0;
    alias TypeTuple!(FFT!(Vector, Options)) FFTs;
    mixin Instantiate!();
}
