"""
Create an array that simulates the array of the PackedMemoryArray type.
Inputs : 
    - `capacity` is the size of the array
    - `expnbempty` is the number of empty entries expected in the returned array
Output (3-Tuple) :
    - array
    - number of empty entries
    - number of non-empty entries
"""
function array_factory(capacity::Int, expnbempty::Int)
    nbempty = 0
    array =  Vector{Union{Tuple{Int,Int}, Nothing}}(nothing, capacity)
    i = 1
    for j in 1:capacity
        p = rand(rng, 0:0.001:1)
        if p < expnbempty/capacity
            array[j] = nothing
            nbempty += 1
        else
            val = rand(1:150)
            array[j] = (i, val)
            i += 1
        end
    end
    return array, nbempty, i - 1
end

"""
Create an array and a list of semaphores that simulate the PackedCSC type
Inputs : 
    - `capacity` is the size of the array
    - `expnbempty` is the number of empty entries expected in the returned array
Output (4-Tuple) :
    - array
    - list of semaphores
    - number of empty entries
    - number of non-empty entries
"""
function create_partitioned_array(capacity::Int, expnbempty::Int)
    nbempty = 0
    array =  Vector{Union{Tuple{Int,Int}, Nothing}}(nothing, capacity)
    semaphores = Vector{Int}()
    i = 1
    k = 1
    for j in 1:capacity
        p = rand(rng, 0:0.001:1)
        if p < expnbempty/capacity
            array[j] = nothing
            nbempty += 1
        else
            if p > 0.95
                array[j] = (0, k)
                push!(semaphores, j)
                i = 1
                k += 1
            else
                val = rand(1:150)
                array[j] = (i, val)
                i += 1
            end
        end
    end
    return array, semaphores, nbempty, capacity - nbempty
end