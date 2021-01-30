# DynamicSparseArrays

This package aims to provide dynamic sparse vectors 
and matrix in Julia. 
Unlike the sparse arrays provided in `SparseArrays`, 
arrays from this package have unfixed size. 
It means that we can add or delete rows and 
columns after the instantiation of the array.

We designed this package for [Coluna.jl](), a Branch-and-Cut-and-Price (Column-and-row generation)
framework in julia.


We welcome any contributions.

## Installation

Install the package through the package manager of Julia.
In the julia terminal, press the key ']' to access the package manager. Then, run the following command : 

```
pkg> add DynamicSparseArrays
```

You can start using `DynamicSparseArrays` by doing :
```julia
using Coluna
```

## Contents

```@contents
Pages = [
    "man/matrix.md",
    "man/vector.md"
]
Depth = 1
```

---

todo (grant)
