# DynamicSparseArrays.jl
[![Build Status](https://travis-ci.org/atoptima/DynamicSparseArrays.jl.svg?branch=master)](https://travis-ci.org/atoptima/DynamicSparseArrays.jl)
[![codecov](https://codecov.io/gh/atoptima/DynamicSparseArrays.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/atoptima/DynamicSparseArrays.jl)
[![Project Status: Active – The project has reached a stable, usable state and is being actively developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)


Install the package :
```
] add DynamicSparseArrays
```

## Packed Memory Array

```julia
using DynamicSparseArrays
keys = [1,2,3,5]
values = [1.0, 2.4, 7.1, 1.1]
pma = PackedMemoryArray(keys, values) # create the pma

pma[78] = 1.5 # insert a value
pma[2] # retrieve a value
```

## References

The goal is to implement Adaptative Packed Memory Array (APMA) and Packed Compressed Sparse Row Matrix (PCSR) data structures with the insert, delete, search, and SpMV operations.

### PCSR

> WHEATMAN, Brian et XU, Helen. Packed Compressed Sparse Row: A Dynamic Graph Representation. In : 2018 IEEE High Performance extreme Computing Conference (HPEC). IEEE, 2018. p. 1-7.


### APMA

> BENDER, Michael A. et HU, Haodong. An adaptive packed-memory array. ACM Transactions on Database Systems (TODS), 2007, vol. 32, no 4, p. 26.

Not adptative :

> BENDER, Michael A., DEMAINE, Erik D., et FARACH-COLTON, Martin. Cache-oblivious B-trees. SIAM Journal on Computing, 2005, vol. 35, no 2, p. 341-358.

> ITAI, Alon, KONHEIM, Alan G., et RODEH, Michael. A sparse table implementation of priority queues. In : International Colloquium on Automata, Languages, and Programming. Springer, Berlin, Heidelberg, 1981. p. 417-431.

One-phase rebalance & Partially dearmotized PMA :

> HU, Haodong. Cache-Oblivious Data Structures forMassive Data Sets.
PhD Dissertation, 2007, p. 102.
[Link](https://dspace.sunyconnect.suny.edu/bitstream/handle/1951/44806/000000182.sbu.pdf?sequence=3)


### Codes 

- [C implementation of PMA](https://github.com/pabmont/pma)
- [Julia draft implementation of APMA](https://github.com/JuliaCollections/DataStructures.jl/pull/241)
