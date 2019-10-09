# DynamicSparseArrays.jl

This package is a work in progress.

The goal is to implement Adaptative Packed Memory Array (APMA) and Packed Compressed Sparse Row Matrix (PCSR) data structures with the insert, delete, search, and SpMV operations.

## References

### PCSR

> WHEATMAN, Brian et XU, Helen. Packed Compressed Sparse Row: A Dynamic Graph Representation. In : 2018 IEEE High Performance extreme Computing Conference (HPEC). IEEE, 2018. p. 1-7.


### APMA

> BENDER, Michael A. et HU, Haodong. An adaptive packed-memory array. ACM Transactions on Database Systems (TODS), 2007, vol. 32, no 4, p. 26.

Not adptative :

> BENDER, Michael A., DEMAINE, Erik D., et FARACH-COLTON, Martin. Cache-oblivious B-trees. SIAM Journal on Computing, 2005, vol. 35, no 2, p. 341-358.

> ITAI, Alon, KONHEIM, Alan G., et RODEH, Michael. A sparse table implementation of priority queues. In : International Colloquium on Automata, Languages, and Programming. Springer, Berlin, Heidelberg, 1981. p. 417-431.


### Codes 

- [C implementation of PMA](https://github.com/pabmont/pma)
- [Julia draft implementation of APMA](https://github.com/JuliaCollections/DataStructures.jl/pull/241)
