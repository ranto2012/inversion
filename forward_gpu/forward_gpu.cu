﻿
#include <cmath>
#include <memory>
#include <complex>
#include <exception>

#include <cuda_runtime.h>
#include <thrust/complex.h>

#include "forward_gpu.h"
#include "device_ptr.h"
#include "device_array.h"
#include "cuda_helper.h"
#include "../data/data.h"
#include "../global/global.h"


void forward_gpu::init_cuda_device()
{
	int device_count;
	auto err = cudaGetDeviceCount(&device_count);
	CHECK;
	global::log("forward", "init_cuda_device complete");
}

__global__ void test_device_kernel(float_t *a, float_t *b, float_t *c, int num)
{
	int i = threadIdx.x;
	if (i >= num)
	{
		return;
	}
	c[i] = a[i] * b[i];
}

__host__ complex return_dHz_w(float_t a, float_t i0, float_t h,
	device_array *hankel,
	device_array *resistence,
	device_array *height,
	thrust::complex<float_t> w)
{
	constexpr float_t a1 = -7.91001919000e+00;
	constexpr float_t s1 = 8.79671439570e-02;
}

//计算正演kernel函数
//a: float_t，回线半径(m)
//i0: float_t，发射电流(A)
//h: float_t，发射、接收回线高度(m)
//cosine: device_array，余弦变换系数
//hankel: device_array，汉克尔变换系数
//resistence: device_array，地层电阻率
//height: device_array，地层厚度
//time: device_array，时间
//response: device_array，输出响应
__global__ void forward_kernel(float_t a, float_t i0, float_t h,
	device_array *cosine,
	device_array *hankel,
	device_array *resistence,
	device_array *height,
	device_array *time,
	device_array *reponse_late_m,
	device_array *reponse_late_e)
{
	constexpr float_t mu0 = global::mu0;
	constexpr float_t pi = global::pi;
	
	const int time_idx = blockIdx.x;
	const int time_num = blockDim.x;
	const int cosine_idx = threadIdx.x;

	extern __shared__ thrust::complex<float_t> res_complex[];
	__shared__ float_t t;
	__shared__ float_t* cosine_ptr;

	//每个block中的第一个线程为计算准备数据
	if (cosine_idx == 0)
	{
		t = time->get()[time_idx];
		cosine_ptr = cosine->get();
	}

	__syncthreads();

	thrust::complex<float_t> w = 1 / t * std::exp<float_t>((-150 + cosine_idx - 1)*std::log(10.0) / 20);
	thrust::complex<float_t> hz_w = return_dHz_w(a, i0, h, hankel, resistence, height, w);

	res_complex[cosine_idx] = hz_w.imag() / w * cosine_ptr[cosine_idx];

	//二分求和
	for (int offset = time_num / 2; offset > 0; offset >>= 1)
	{
		if (threadIdx.x < offset)
		{
			res_complex[time_idx] += res_complex[time_idx + offset];
		}
		__syncthreads();
	}

	//每个block中的第一个线程做收尾计算
	if (cosine_idx == 0)
	{
		const float_t t = time->get()[time_idx];
		const float_t res = std::sqrt(std::pow(res_complex->real(), 2) + std::pow(res_complex->imag, 2));

		reponse_late_m->get()[time_idx] = mu0 * pow(pi*i0*std::pow(a, 2) / 30 / res, 2.0 / 3) / pi / t;
	}
}

void forward_gpu::test_cuda_device()
{
	global::scoped_timer("test_cuda");

	device_ptr<float_t> da;
	device_ptr<float_t> db;
	device_ptr<float_t> dc;

	float_t a[] = { 1,2,3,4,5 };
	float_t b[] = { 1,2,3,4,5 };

	auto size = sizeof(a) / sizeof(float_t);
	float_ptr c(new float_t[size]);

	da.allocate(size);
	db.allocate(size);
	dc.allocate(size);

	copy_to_device(a, da.get(), size);
	copy_to_device(b, db.get(), size);

	test_device_kernel <<<1, 32 >>> (da, db, dc, size);

	copy_to_host(dc.get(), c.get(), size);

	for (auto i = 0; i < size; ++i)
	{
		if (a[i] * b[i] != c[i])
		{
			throw std::runtime_error("测试cuda设备失败，计算错误");
		}
	}
}

forward_base::forward_data forward_gpu::forward()
{
	global::scoped_timer("forward");

	return forward_data();
}