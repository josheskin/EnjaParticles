#ifndef UNIFORMGRID_H_INCLUDED
#define UNIFORMGRID_H_INCLUDED

#include "../structs.h"

namespace rtps {

class UniformGrid
{
public:
    UniformGrid(){};
    UniformGrid(float4 min, float4 max, float cell_size, float sim_scale=1.);
	UniformGrid(float4 min, float4 max, int4 nb_cells, float sim_scale=1.);
	//UniformGrid(float4 min, float4 max, float cell_size);
    ~UniformGrid();

    void make_cube(float4 *positions, float spacing, int num);
	void makeCube(float4* position, float4 pmin, float4 pmax, float spacing, int& num, int& offset);

	void makeSphere(float4* position, float4* velocity, float4 center, float radius, int& num, int& offset, float spacing);

    float4 getMin(){ return min; };
    float4 getMax(){ return max; };
    float4 getBndMin(){ return bnd_min; };
    float4 getBndMax(){ return bnd_max; };
	float4 getDelta() { return delta; };
	float4 getRes() { return res; };
	float4 getSize() { return size; };
	int getNbPoints() { return (int) (res.x*res.y*res.z); }

	void print();

public:
	float sim_scale;
    float4 min;
    float4 max; 
	float4 bnd_min;
	float4 bnd_max;

    float4 size;
    float4 res;
	float4 delta;
};
   
}
#endif