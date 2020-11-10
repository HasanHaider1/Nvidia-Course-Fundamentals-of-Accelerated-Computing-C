#include <stdio.h>

/*
 * Host function to initialize vector elements. This function
 * simply initializes each element to equal its index in the
 * vector.
 */

void initWith(float num, float *a, int N)
{
  for(int i = 0; i < N; ++i)
  {
    a[i] = num;
  }
}

/*
 * Device kernel stores into `result` the sum of each
 * same-indexed value of `a` and `b`.
 */

__global__
void addVectorsInto(float *result, float *a, float *b, int N)
{
  int index = threadIdx.x + blockIdx.x * blockDim.x;
  //int stride = blockDim.x * gridDim.x;
  
  if(index < N)
  {
  result[index] = a[index] +b[index];
  }

/*
 *for(int i = index; i < N; i += stride)
 *{
 *  result[i] = a[i] + b[i];
 *}
 */
}

/*
 * Host function to confirm values in `vector`. This function
 * assumes all values are the same `target` value.
 */

void checkElementsAre(float target, float *vector, int N)
{
  for(int i = 0; i < N; i++)
  {
    if(vector[i] != target)
    {
      printf("FAIL: vector[%d] - %0.0f does not equal %0.0f\n", i, vector[i], target);
      exit(1);
    }
  }
  printf("Success! All values calculated correctly.\n");
}

int main()
{
  const int N = 2<<24;
  size_t size = N * sizeof(float);

  float *a;
  float *b;
  float *c;

  cudaMallocManaged(&a, size);
  cudaMallocManaged(&b, size);
  cudaMallocManaged(&c, size);
  
  initWith(3, a, N);
  initWith(4, b, N);
  initWith(0, c, N);

  size_t threadsPerBlock;
  size_t numberOfBlocks;

  /*
   * nsys should register performance changes when execution configuration
   * is updated.
   */
  
  int deviceId;
  cudaGetDevice(&deviceId);
  
  cudaDeviceProp props;
  cudaGetDeviceProperties(&props, deviceId);
  
  threadsPerBlock = 256;
  
  //Calculating the number of Blocks needed
  int BlockNum = (N + threadsPerBlock - 1) / threadsPerBlock;
  
  //Calculating the closest multiple of the number of streaming processers
  numberOfBlocks = (((BlockNum - 1) / props.multiProcessorCount) + 1) * props.multiProcessorCount;
    
  
  cudaError_t addVectorsErr;
  cudaError_t asyncErr;
  
  //Prefetching a
  cudaMemPrefetchAsync(a, size, deviceId);
  //result: number of memory operations on device is now 7815 and on host is 768.
  //Time to do the kernal is now 84872244 nanoseconds.
  
  //Prefetching b after a
  cudaMemPrefetchAsync(b, size, deviceId);
  //result: number of memory operations on device is now 4683 and on host is 768.
  //Time to do the kernal is now 45627368 nanoseconds.
  
  //Prefetching c after a and b
  cudaMemPrefetchAsync(c, size, deviceId);
  //result: number of memory operations on device is now 192 and on host is 768.
  //Time to do the kernal is now 495873 nanoseconds.
  
  

  addVectorsInto<<<numberOfBlocks, threadsPerBlock>>>(c, a, b, N);

  addVectorsErr = cudaGetLastError();
  if(addVectorsErr != cudaSuccess) printf("Error: %s\n", cudaGetErrorString(addVectorsErr));

  asyncErr = cudaDeviceSynchronize();
  if(asyncErr != cudaSuccess) printf("Error: %s\n", cudaGetErrorString(asyncErr));

  checkElementsAre(7, c, N);

  cudaFree(a);
  cudaFree(b);
  cudaFree(c);
}
