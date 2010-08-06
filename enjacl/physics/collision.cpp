#include "../enja.h"

void EnjaParticles::loadTriangles(std::vector<Triangle> triangles)
{
    n_triangles = triangles.size();
    printf("n triangles: %d\n", n_triangles);
    //load triangles into cl buffer
    //Triangle is a struct that ends up being 4 float4s
    size_t tri_size = sizeof(Triangle) * n_triangles;
    cl_triangles = cl::Buffer(context, CL_MEM_WRITE_ONLY, tri_size, NULL, &err);
    err = queue.enqueueWriteBuffer(cl_triangles, CL_TRUE, 0, tri_size, &triangles[0], NULL, &event);
    queue.finish();
   
    err = collision_kernel.setArg(2, cl_triangles);   //triangles
    err = collision_kernel.setArg(3, n_triangles);   //number of triangles

	printf("sizeof(Triangle) = %d\n", (int) sizeof(Triangle));

#ifdef OPENCL_SHARED

	size_t max_loc_memory = 1024 << 4;  // 16k bytes local memory on mac
	int max_tri = max_loc_memory / sizeof(Triangle);
	//max_tri = n_triangles;
	max_tri = 220; // fits in cache
	printf("max_tri= %d\n", max_tri);
	
	size_t sz = max_tri*sizeof(Triangle);
	printf("sz= %d bytes\n", sz);

   // experimenting with hardcoded local memory in collision_ge.cl
    err = collision_kernel.setArg(5, sz, 0);   //number of triangles
	//exit(0);
#endif

    //need to deal with transforms
}

