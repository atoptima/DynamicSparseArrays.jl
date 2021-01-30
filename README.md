# DynamicSparseArrays.jl

[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://atoptima.github.io/DynamicSparseArrays.jl/dev/)
![Build Status](https://github.com/atoptima/DynamicSparseArrays.jl/workflows/CI/badge.svg?branch=master)]
[![codecov](https://codecov.io/gh/atoptima/DynamicSparseArrays.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/atoptima/DynamicSparseArrays.jl)
[![Project Status: Active – The project has reached a stable, usable state and is being actively developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)


Install the package :
```
] add DynamicSparseArrays
```

## Example

```julia
using DynamicSparseArrays
I = [1, 10, 3, 5, 3]
V = [1.0, 2.4, 7.1, 1.1, 1.0]
vector = dynamicsparsevec(I,V) # create a vector

vector[3] == 2.4 + 1.0 # true
vector[78] = 1.5 # insert a value (new row)
vector[2] # retrieve a value
vector[2] = 0 # delete a value


I = [1, 2, 3, 2, 6, 7, 1, 6, 8] #rows
J = [1, 1, 1, 2, 2, 2, 3, 3, 3] #columns
V = [2, 3, 4, 2, 4, 5, 3, 5, 7] #value
matrix = dynamicsparse(I,J,V) # create a matrix

matrix[4,1] = 1 # new column
matrix[2,2] = 0 # delete value
deletecolumn!(matrix, 2) # delete column with id 2
matrix[2,6] == 0 # true
```

