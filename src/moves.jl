"""
Move cells of `array` to the right from position `from` to position `to`
(`from` < `to`). After the move, the cell at position `from` is empty, the 
content of the cell at position `to` is replaced by the content of the cell at
position `to - 1`.
"""
function _movecellstoright!(
    array::Elements{K,T}, from::Int, to::Int, semaphores
) where {K,T}
    array[to] == nothing || throw(ArgumentError("The cell erased by the movement must contain nothing."))
    _moverightloop!(array, from, to, semaphores)
    return
end

function _moverightloop!(
    array::Elements{K,T}, from, to, ::Nothing
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
    array::Elements{K,T}, from, to, semaphores::Vector
) where {K,T}
    i = to
    sem_key = semaphore_key(K)
    @inbounds while i > from
        i -= 1
        cell = array[i]
        if cell != nothing
            (key, val) = cell
            if key == sem_key
                semaphores[Int(val)] = i+1
            end
        end
        array[i+1] = cell
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
    array::Elements{K,T}, from::Int, to::Int, semaphores
) where {K,T}
    array[to] == nothing || throw(ArgumentError("The cell erased by the movement must contain nothing."))
    _moveleftloop!(array, from, to, semaphores)
    return
end

function _moveleftloop!(
    array::Elements{K,T}, from, to, ::Nothing
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
    array::Elements{K,T}, from, to, semaphores::Vector
) where {K,T}
    i = to
    sem_key = semaphore_key(K)
    @inbounds while i < from
        i += 1
        cell = array[i]
        if cell != nothing
            (key, val) = cell
            if key == sem_key
                semaphores[Int(val)] = i-1
            end
        end
        array[i-1] = cell
    end
    array[i] = nothing
    return
end

"""
Consider the subarray of `array` delimited by `window_start` included and 
`window_end` included.
This method packs the `m` non-empty cells on the left side of the subarray.
"""
function _pack!(
    array::Elements{K,T}, window_start, window_end, m
) where {K,T}
    i = window_start
    j = window_start
    @inbounds while i < window_start + m
        if array[j] === nothing # empty cell
            j += 1
            continue
        end
        if i < j
            array[i] = array[j]
            array[j] = nothing
        end
        i += 1
        j += 1
    end
    return
end

"""
Consider the subarray of `array` delimited by `window_start` included and 
`window_end` included.
This method spreads evenly the `m` non-empty cells that have been packed on the 
left side of the subarray.
"""
function _spread!(
    array::Elements{K,T}, window_start, window_end, m
) where {K,T}
    capacity = window_end - window_start + 1
    nb_empty_cells = capacity - m
    empty_cell_freq = capacity / nb_empty_cells
    next_empty_cell = window_start + floor(nb_empty_cells * empty_cell_freq) - 1
    i = window_start + m - 1
    j = window_end
    @inbounds while i != j && i >= window_start
        if j == next_empty_cell
            nb_empty_cells -= 1
            next_empty_cell = window_start + floor(nb_empty_cells * empty_cell_freq) - 1
            j -= 1
        else
            array[j] = array[i]
            array[i] = nothing
            i -= 1
            j -= 1
        end
    end
    return
end

function _spread!(
    array::Elements{K,T}, window_start, window_end, m, semaphores
) where {K,T}
    capacity = window_end - window_start + 1
    nb_empty_cells = capacity - m
    empty_cell_freq = capacity / nb_empty_cells
    next_empty_cell = window_start + floor(nb_empty_cells * empty_cell_freq) - 1
    i = window_start + m - 1
    j = window_end
    sem_key = semaphore_key(K)
    @inbounds while i >= window_start
        if j == next_empty_cell
            nb_empty_cells -= 1
            next_empty_cell = window_start + floor(nb_empty_cells * empty_cell_freq) - 1
            j -= 1
        else
            if i != j
                array[j] = array[i]
                array[i] = nothing
            end
            (key, val) = array[j]
            if key == sem_key
                semaphores[Int(val)] = j
            end
            i -= 1
            j -= 1
        end
    end
    return
end