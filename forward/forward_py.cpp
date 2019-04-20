﻿
#include <pybind11/pybind11.h>

#include <vector>
#include <exception>
#include <fstream>
#include <cmath>
#include <algorithm>

#include "../data/data.h"
#include "../global/global.h"
#include "../forward_gpu/forward_gpu.h"

namespace py = pybind11;

PYBIND11_MODULE(forward_py, m)
{
	m.doc() = "正演模块";


}

