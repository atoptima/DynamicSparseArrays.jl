var documenterSearchIndex = {"docs":
[{"location":"matrix/#Sparse-Matrix","page":"Sparse Matrix","title":"Sparse Matrix","text":"","category":"section"},{"location":"matrix/","page":"Sparse Matrix","title":"Sparse Matrix","text":"todo ","category":"page"},{"location":"matrix/","page":"Sparse Matrix","title":"Sparse Matrix","text":"","category":"page"},{"location":"matrix/","page":"Sparse Matrix","title":"Sparse Matrix","text":"Mode details in following papers :","category":"page"},{"location":"matrix/","page":"Sparse Matrix","title":"Sparse Matrix","text":"WHEATMAN, Brian et XU, Helen. Packed Compressed Sparse Row: A Dynamic Graph Representation. In : 2018 IEEE High Performance extreme Computing Conference (HPEC). IEEE, 2018. p. 1-7.","category":"page"},{"location":"references/#References","page":"References","title":"References","text":"","category":"section"},{"location":"references/#Operations-on-the-main-vector","page":"References","title":"Operations on the main vector","text":"","category":"section"},{"location":"references/","page":"References","title":"References","text":"DynamicSparseArrays.find\nDynamicSparseArrays.pack!\nDynamicSparseArrays.spread!\nDynamicSparseArrays.insert!\nDynamicSparseArrays.delete!\nDynamicSparseArrays.purge!\nDynamicSparseArrays._movecellstoright!\nDynamicSparseArrays._movecellstoleft!","category":"page"},{"location":"references/#DynamicSparseArrays.find","page":"References","title":"DynamicSparseArrays.find","text":"find(array::Vector{Union{Nothing, T}}, key, from::Int, to::Int) where {T}\n\nLook for the element indexed by key in the subarray of array starting at  position from and ending at position to.\n\nIf the element is in the subarray, the method returns the position and the  the element.\n\nIf the element is not in the subarray, the method returns the position and the  element that has the nearest inferior key (predecessor) in the subarray. \n\nIf the element has no predecessor in the subarray, the method returns the position and the last element located in the left outside.\n\nfind(array::Vector{Union{Nothing, T}}, key) where {T}\n\nLook for the element indexed by key in array.\n\nIf the element is in the array, the method returns the position and the  the element.\n\nIf the element is not in the array, the method returns the position and the  element that has the nearest inferior key (predecessor). \n\nIf the element has no predecessor, the method returns (0, nothing).\n\n\n\n\n\n","category":"function"},{"location":"references/#DynamicSparseArrays.pack!","page":"References","title":"DynamicSparseArrays.pack!","text":"pack!(array::Elements{K,T}, window_start, window_end, m)\n\nGiven a subarray of array delimited by window_start included and  window_end included, this method packs the m non-empty cells on the left side of the subarray.\n\n\n\n\n\n","category":"function"},{"location":"references/#DynamicSparseArrays.spread!","page":"References","title":"DynamicSparseArrays.spread!","text":"spread!(array::Elements{K,T}, windows_start, window_end, m)\n\nGiven a subarray of array delimited by window_start included and  window_end included, this method spreads evenly the m non-empty cells that have been packed on the  left side of the subarray.\n\n\n\n\n\n","category":"function"},{"location":"references/#DynamicSparseArrays.insert!","page":"References","title":"DynamicSparseArrays.insert!","text":"insert!(array::Elements{K,T}, key::K, value::T, from, to, semaphores)\n\nInsert the element (key, value) in the subarray of array starting at  position from and ending at position to included.\n\nReturn the position where the element is located and a boolean equal to true if it is a new key.\n\ninsert!(array::Elements{K,T}, key::K, value::T, semaphores)\n\nInsert the element (key, value) in array.\n\n\n\n\n\n","category":"function"},{"location":"references/#DynamicSparseArrays.delete!","page":"References","title":"DynamicSparseArrays.delete!","text":"delete!(array, key, from, to, semaphores)\n\nDelete from array the element having key key and located in the subarray  starting at position from and ending at position to.\n\nReturn true if the element has been deleted; false otherwise.\n\n\n\n\n\n","category":"function"},{"location":"references/#DynamicSparseArrays.purge!","page":"References","title":"DynamicSparseArrays.purge!","text":"purge!(array, from, to)\n\nDelete from array all elements between positions from and to included. Return middle and the number of elements deleted\n\n\n\n\n\n","category":"function"},{"location":"references/#DynamicSparseArrays._movecellstoright!","page":"References","title":"DynamicSparseArrays._movecellstoright!","text":"Move cells of array to the right from position from to position to (from < to). After the move, the cell at position from is empty, the  content of the cell at position to is replaced by the content of the cell at position to - 1.\n\n\n\n\n\n","category":"function"},{"location":"references/#DynamicSparseArrays._movecellstoleft!","page":"References","title":"DynamicSparseArrays._movecellstoleft!","text":"Move cells of array to the left from position from to position to (from > to). After the move, the cell at position from is empty, the  content of the cell at position to is replaced by the content of the cell at position to + 1.\n\n\n\n\n\n","category":"function"},{"location":"vector/#Sparse-Vector","page":"Sparse Vector","title":"Sparse Vector","text":"","category":"section"},{"location":"vector/","page":"Sparse Vector","title":"Sparse Vector","text":"todo ","category":"page"},{"location":"vector/","page":"Sparse Vector","title":"Sparse Vector","text":"","category":"page"},{"location":"vector/","page":"Sparse Vector","title":"Sparse Vector","text":"Mode details in following papers :","category":"page"},{"location":"vector/","page":"Sparse Vector","title":"Sparse Vector","text":"BENDER, Michael A. et HU, Haodong. An adaptive packed-memory array. ACM Transactions on Database Systems (TODS), 2007, vol. 32, no 4, p. 26.","category":"page"},{"location":"vector/","page":"Sparse Vector","title":"Sparse Vector","text":"BENDER, Michael A., DEMAINE, Erik D., et FARACH-COLTON, Martin. Cache-oblivious B-trees. SIAM Journal on Computing, 2005, vol. 35, no 2, p. 341-358.","category":"page"},{"location":"vector/","page":"Sparse Vector","title":"Sparse Vector","text":"ITAI, Alon, KONHEIM, Alan G., et RODEH, Michael. A sparse table implementation of priority queues. In : International Colloquium on Automata, Languages, and Programming. Springer, Berlin, Heidelberg, 1981. p. 417-431.","category":"page"},{"location":"vector/","page":"Sparse Vector","title":"Sparse Vector","text":"One-phase rebalance & Partially dearmotized PMA :","category":"page"},{"location":"vector/","page":"Sparse Vector","title":"Sparse Vector","text":"HU, Haodong. Cache-Oblivious Data Structures forMassive Data Sets.","category":"page"},{"location":"vector/","page":"Sparse Vector","title":"Sparse Vector","text":"PhD Dissertation, 2007, p. 102. Link","category":"page"},{"location":"vector/","page":"Sparse Vector","title":"Sparse Vector","text":"Inspiring codes :","category":"page"},{"location":"vector/","page":"Sparse Vector","title":"Sparse Vector","text":"C implementation of PMA\nJulia draft implementation of APMA","category":"page"},{"location":"#DynamicSparseArrays","page":"Introduction","title":"DynamicSparseArrays","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"** Documentation is work in progress**","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"This package aims to provide dynamic sparse vectors  and matrix in Julia.  Unlike the sparse arrays provided in SparseArrays,  arrays from this package have unfixed size.  It means that we can add or delete rows and  columns after the instantiation of the array.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"This package is a work in progress. We welcome any contributions.","category":"page"},{"location":"#Installation","page":"Introduction","title":"Installation","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"Install the package through the package manager of Julia. In the julia terminal, press the key ']' to access the package manager. Then, run the following command : ","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"pkg> add DynamicSparseArrays","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"You can start using DynamicSparseArrays by doing :","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"using Coluna","category":"page"},{"location":"#Contents","page":"Introduction","title":"Contents","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"Pages = [\n    \"man/matrix.md\",\n    \"man/vector.md\"\n]\nDepth = 1","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"todo (grant)","category":"page"}]
}
