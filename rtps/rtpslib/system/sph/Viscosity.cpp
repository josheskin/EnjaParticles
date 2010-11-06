#include "../SPH.h"

namespace rtps {

void SPH::loadViscosity()
{
    printf("create viscosity kernel\n");

    std::string path(SPH_CL_SOURCE_DIR);
    path += "/viscosity_cl.cl";
    k_viscosity = Kernel(ps->cli, path, "viscosity");
  
    k_viscosity.setArg(0, cl_position.getDevicePtr());
    if(sph_settings.integrator == LEAPFROG)
    {
        k_viscosity.setArg(1, cl_veleval.getDevicePtr());
    }
    else if(sph_settings.integrator == EULER)
    {
        k_viscosity.setArg(1, cl_velocity.getDevicePtr());
    }
    k_viscosity.setArg(2, cl_density.getDevicePtr());
    k_viscosity.setArg(3, cl_force.getDevicePtr());
    k_viscosity.setArg(4, cl_SPHParams.getDevicePtr());

} 


float SPH::Wviscosity(float4 r, float h)
{
    //from simple SPH in Krog's thesis
    float h6 = h*h*h * h*h*h;
    float alpha = 45.f/params.PI/h6;
    float rlen = magnitude(r);
    float Wij = alpha * (h - rlen);
    return Wij;

}

void SPH::cpuViscosity()
{

    float scale = params.simulation_scale;
    float h = params.smoothing_distance;
    float mu = 1.001f; //viscosity coefficient (how to select?)
    float4* vel;
    if(sph_settings.integrator == EULER)
    {
        vel = &velocities[0];
    }
    else if(sph_settings.integrator == LEAPFROG)
    {
        vel = &veleval[0];
    }

    for(int i = 0; i < num; i++)
    {

        float4 p = positions[i];
        float4 v = vel[i];
        p = float4(p.x * scale, p.y * scale, p.z * scale, p.w * scale);
        //v = float4(v.x * scale, v.y * scale, v.z * scale, v.w * scale);

        float4 f = float4(0.0f, 0.0f, 0.0f, 0.0f);

        //stuff from Tim's code (need to match #s to papers)
        //float alpha = 315.f/208.f/params->PI/h/h/h;

        for(int j = 0; j < num; j++)
        {
            if(j == i) continue;
            float4 pj = positions[j];
            float4 vj = vel[j];
            pj = float4(pj.x * scale, pj.y * scale, pj.z * scale, pj.w * scale);
            //vj = float4(vj.x * scale, vj.y * scale, vj.z * scale, vj.w * scale);
            float4 r = float4(p.x - pj.x, p.y - pj.y, p.z - pj.z, p.w - pj.w);
 
            float rlen = magnitude(r);
            if(rlen < h)
            {
                float r2 = rlen*rlen;
                float re2 = h*h;
                if(r2/re2 <= 4.f)
                {
                    //float R = sqrt(r2/re2);
                    //float Wij = alpha*(-2.25f + 2.375f*R - .625f*R*R);
                    float Wij = Wviscosity(r, h);
                    float fcoeff = mu * params.mass * Wij / (densities[j] * densities[i]);
                    f.x += fcoeff * (vj.x - v.x); 
                    f.y += fcoeff * (vj.y - v.y); 
                    f.z += fcoeff * (vj.z - v.z); 
                }

            }
        }
        forces[i].x += f.x;
        forces[i].y += f.y;
        forces[i].z += f.z;
    }

}


}
