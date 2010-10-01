# 1 "uniform_grid_utils.cpp"
# 1 "<built-in>"
# 1 "<command-line>"
# 1 "uniform_grid_utils.cpp"
# 19 "uniform_grid_utils.cpp"
# 1 "cl_macros.h" 1
# 20 "uniform_grid_utils.cpp" 2
# 1 "cl_structures.h" 1






struct GridParams
{
    float4 grid_size;
    float4 grid_min;
    float4 grid_max;


    float4 grid_res;
    float4 grid_delta;
    float4 grid_inv_delta;
    int num;
};

struct FluidParams
{
 float smoothing_length;
 float scale_to_simulation;
 float mass;
 float dt;
 float friction_coef;
 float restitution_coef;
 float damping;
 float shear;
 float attraction;
 float spring;
 float gravity;
 int choice;
};


struct SPHParams
{
    float4 grid_min;
    float4 grid_max;
    float grid_min_padding;
    float grid_max_padding;
    float mass;
    float rest_distance;
    float smoothing_distance;
    float simulation_scale;
    float boundary_stiffness;
    float boundary_dampening;
    float boundary_distance;
    float EPSILON;
    float PI;
    float K;
};
# 21 "uniform_grid_utils.cpp" 2
# 1 "neighbors.cpp" 1





# 1 "wpoly6.cl" 1




float Wpoly6(float4 r, float h, __constant struct SPHParams* params)
{
    float r2 = r.x*r.x + r.y*r.y + r.z*r.z;
 float h9 = h*h;
 float hr2 = (h9-r2);
 h9 = h9*h;
    float alpha = 315.f/64.0f/params->PI/(h9*h9*h9);
    float Wij = alpha * hr2*hr2*hr2;
    return Wij;
}

float Wspiky(float rlen, float h, __constant struct SPHParams* params)
{
    float h6 = h*h*h * h*h*h;
    float alpha = 45.f/params->PI/h6;
 float hr2 = (h - rlen);
 float Wij = alpha * hr2*hr2*hr2/rlen;
 return Wij;
}
# 7 "neighbors.cpp" 2


float4 ForNeighbor(__global float4* vars_sorted,
    __constant uint index_i,
    uint index_j,
    float4 r,
    float rlen,
    float rlen_sq,
      __constant struct GridParams* gp,
      __constant struct FluidParams* fp,
      __constant struct SPHParams* sphp)
{




 int num = get_global_size(0);

 if (fp->choice == 1) {


# 1 "density_update.cl" 1



    float Wij = Wpoly6(rlen, sphp->smoothing_distance, sphp);
 return (float4)(sphp->mass*Wij, 0., 0., 0.);
# 29 "neighbors.cpp" 2
  ;
 }

 if (fp->choice == 2) {

# 1 "pressure_update.cl" 1



 float Wij = Wspiky(rlen, sphp->smoothing_distance, sphp);

 float di = vars_sorted[index_i+0*num].x;
 float dj = vars_sorted[index_j+0*num].x;


 float Pi = sphp->K*(di - 1000.0f);
 float Pj = sphp->K*(dj - 1000.0f);

 float kern = sphp->mass * 1.0f * Wij * (Pi + Pj) / (di * dj);





 return kern*r;
# 35 "neighbors.cpp" 2
 }






}

float4 ForPossibleNeighbor(__global float4* vars_sorted,
      __constant uint num,
      __constant uint index_i,
      uint index_j,
      __constant float4 position_i,
        __constant struct GridParams* gp,
        __constant struct FluidParams* fp,
        __constant struct SPHParams* sphp)
{
 float4 frce;
 frce.x = 0.;
 frce.y = 0.;
 frce.z = 0.;
 frce.w = 0.;



 if (index_j != index_i) {

  float4 position_j = vars_sorted[index_j+1*num];


  float4 r = (position_i - position_j) * fp->scale_to_simulation;

  float rlen_sq = dot(r,r);

  float rlen;
  rlen = sqrt(rlen_sq);


  if (rlen <= fp->smoothing_length) {

   frce = ForNeighbor(vars_sorted, index_i, index_j, r, rlen, rlen_sq, gp, fp, sphp);

  }
 }
 return frce;
}
# 22 "uniform_grid_utils.cpp" 2




int4 calcGridCell(float4 p, float4 grid_min, float4 grid_delta)
{




 float4 pp;
 pp.x = (p.x-grid_min.x)*grid_delta.x;
 pp.y = (p.y-grid_min.y)*grid_delta.y;
 pp.z = (p.z-grid_min.z)*grid_delta.z;
 pp.w = (p.w-grid_min.w)*grid_delta.w;

 int4 ii;
 ii.x = (int) pp.x;
 ii.y = (int) pp.y;
 ii.z = (int) pp.z;
 ii.w = (int) pp.w;
 return ii;
}


uint calcGridHash(int4 gridPos, float4 grid_res, __constant bool wrapEdges)
{

 int gx;
 int gy;
 int gz;

 if(wrapEdges) {
  int gsx = (int)floor(grid_res.x);
  int gsy = (int)floor(grid_res.y);
  int gsz = (int)floor(grid_res.z);







  gx = gridPos.x % gsx;
  gy = gridPos.y % gsy;
  gz = gridPos.z % gsz;
  if(gx < 0) gx+=gsx;
  if(gy < 0) gy+=gsy;
  if(gz < 0) gz+=gsz;
 } else {
  gx = gridPos.x;
  gy = gridPos.y;
  gz = gridPos.z;
 }
# 84 "uniform_grid_utils.cpp"
 return (gz*grid_res.y + gy) * grid_res.x + gx;
}




 float4 IterateParticlesInCell(
  __global float4* vars_sorted,
  __constant uint num,
  __constant int4 cellPos,
  __constant uint index_i,
  __constant float4 position_i,
  __global int* cell_indexes_start,
  __global int* cell_indexes_end,
  __constant struct GridParams* gp,
  __constant struct FluidParams* fp,
  __constant struct SPHParams* sphp
    )
 {




  float4 frce;
  frce.x = 0.;
  frce.y = 0.;
  frce.z = 0.;
  frce.w = 0.;

  uint cellHash = calcGridHash(cellPos, gp->grid_res, false);


  uint startIndex = cell_indexes_start[cellHash];




  if (startIndex != 0xffffffff) {
   uint endIndex = cell_indexes_end[cellHash];


   for(uint index_j=startIndex; index_j < endIndex; index_j++) {



    frce += ForPossibleNeighbor(vars_sorted, num, index_i, index_j, position_i, gp, fp, sphp);


   }

  }

  return frce;
 }




 float4 IterateParticlesInNearbyCells(
  __global float4* vars_sorted,
  int num,
  int index_i,
  __constant float4 position_i,
  __global int* cell_indices_start,
  __global int* cell_indices_end,
  __constant struct GridParams* gp,
  __constant struct FluidParams* fp,
  __constant struct SPHParams* sphp)
 {


  float4 frce;

  frce.x = 0.;
  frce.y = 0.;
  frce.z = 0.;
  frce.w = 0.;






  int4 cell = calcGridCell(position_i, gp->grid_min, gp->grid_inv_delta);



  for(int z=cell.z-1; z<=cell.z+1; ++z) {
   for(int y=cell.y-1; y<=cell.y+1; ++y) {
    for(int x=cell.x-1; x<=cell.x+1; ++x) {
     int4 ipos;
     ipos.x = x;
     ipos.y = y;
     ipos.z = z;
     ipos.w = 1;


     frce += IterateParticlesInCell(vars_sorted, num, ipos, index_i, position_i, cell_indices_start, cell_indices_end, gp, fp, sphp);

    }
   }
  }

  return frce;
 }





__kernel void K_SumStep1(
    uint num,
    uint nb_vars,
    __global float4* vars,
    __global float4* vars_sorted,
          __global int* cell_indexes_start,
          __global int* cell_indexes_end,
    __constant struct GridParams* gp,
    __constant struct FluidParams* fp,
    __constant struct SPHParams* sphp
    )
{

 int index = get_global_id(0);
    if (index >= num) return;






    float4 position_i = vars_sorted[index+1*num];



 float4 frce;


    frce = IterateParticlesInNearbyCells(vars_sorted, num, index, position_i, cell_indexes_start, cell_indexes_end, gp, fp, sphp);
# 237 "uniform_grid_utils.cpp"
 vars_sorted[index+3*num] = frce;



}