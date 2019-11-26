"""
Move cells of `array` to the right from position `from` to position `to`
(`from` < `to`). After the move, the cell at position `from` is empty, the 
content of the cell at position `to` is replaced by the content of the cell at
position `to - 1`.
"""
function _movecellstoright!(
    array::Vector{Union{Nothing,Tuple{K,T}}}, from::Int, to::Int, semaphores
) where {K,T}
    array[to] == nothing || throw(ArgumentError("The cell erased by the movement must contain nothing."))
    
    _moverightloop!(array, from, to, semaphores)
    return
end

function _moverightloop!(
    array::Vector{Union{Nothing,Tuple{K,T}}}, from, to, ::Nothing
) where {K,T}
    i = to
    @inbounds while i > from
        i -= 1
        array[i+1] = array[i]
    end
    array[i] = nothing
    return
end

function _moverightloop!(
    array::Vector{Union{Nothing,Tuple{K,T}}}, from, to, semaphores::Vector
) where {K,T}
    i = to
    sem_key = semaphore_key(K)
    @inbounds while i > from
        i -= 1
        (key, val) = array[i]
        array[i+1] = (key, val)
        if key == sem_key
            semaphores[Int(val)] = i+1
        end
    end
    array[i] = nothing
    return   
end

"""
Move cells of `array` to the left from position `from` to position `to`
(`from` > `to`). After the move, the cell at position `from` is empty, the 
content of the cell at position `to` is replaced by the content of the cell at
position `to + 1`.
"""
function _movecellstoleft!(
    array::Vector{Union{Nothing,Tuple{K,T}}}, from::Int, to::Int, semaphores
) where {K,T}
    array[to] == nothing || throw(ArgumentError("The cell erased by the movement must contain nothing."))
    _moveleftloop!(array, from, to, semaphores)
    return
end

function _moveleftloop!(
    array::Vector{Union{Nothing,Tuple{K,T}}}, from, to, ::Nothing
) where {K,T}
    i = to
    @inbounds while i < from
        i += 1
        array[i-1] = array[i]
    end
    array[i] = nothing
    return
end

function _moveleftloop!(
    array::Vector{Union{Nothing,Tuple{K,T}}}, from, to, semaphores::Vector
) where {K,T}
    i = to
    sem_key = semaphore_key(K)
    @inbounds while i < from
        i += 1
        (key, val) = array[i]
        array[i-1] = (key, val)
        if key == sem_key
            semaphores[Int(val)] = i-1
        end
    end
    array[i] = nothing
    return
end