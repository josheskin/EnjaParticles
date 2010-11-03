__kernel void euler(__global float4* pos, __global float4* vel, __global float4* force, float h)
{
#include "test.h"

    unsigned int i = get_global_id(0);

    float4 p = pos[i];
    float4 v = vel[i];
    float4 f = force[i];


    //external force is gravity
    f.z += gravity;

    v += h*f;
    p += h*v;
    p.w = 1.0f; //just in case

    vel[i] = v;
    pos[i] = p;
}

