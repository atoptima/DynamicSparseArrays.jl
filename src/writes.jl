"""
    insert!(array::Elements{K,T}, key::K, value::T, from, to, semaphores)

Insert the element `(key, value)` in the subarray of `array` starting at 
position `from` and ending at position `to` included.

Return the position where the element is located and a boolean equal to `true`
if it is a new `key`.

    insert!(array::Elements{K,T}, key::K, value::T, semaphores)

Insert the element `(key, value)` in `array`.
"""
function insert!(array::Elements{K,T}, key::K, value, from::Int, to::Int, semaphores) where {K,T}
    pos, _ = find(array, key, from, to)
    if _getkey(array, pos) == key && from <= pos <= to
        array[pos] = (key, value)
        return (pos, false)
    end

    # insert the new key after the one found by the binary search
    return _insert!(array, key, value, pos, semaphores)
end

# Element (key, value) will be inserted after pos
function _insert!(array::Elements{K,T}, key::K, value, pos::Int, semaphores) where {K,T}
    insertion_pos = pos
    next_empty_pos = _nextemptypos(array, pos)
    if next_empty_pos != 0
        _movecellstoright!(array, pos+1, next_empty_pos, semaphores)
        array[pos+1] = (key, value)
        insertion_pos += 1
    else
        previous_empty_pos = _previousemptypos(array, pos)
        if previous_empty_pos != 0
            _movecellstoleft!(array, pos, previous_empty_pos, semaphores)
            array[pos] = (key, value)
        else
            error("No empty cell to insert a new element.") # Should not occur thanks to density.
        end
    end
    return (insertion_pos, true)
end

function insert!(array::Elements{K,T}, key::K, value, semaphores) where {K,T}
    return insert!(array, key, value, 1, length(array), semaphores)
end

"""
    delete!(array, key, from, to, semaphores)

Delete from `array` the element having key `key` and located in the subarray 
starting at position `from` and ending at position `to`.

Return `true` if the element has been deleted; `false` otherwise.
"""
function delete!(array::Elements{K,T}, key::K, from::Int, to::Int) where {K,T}
    pos, _ = find(array, key, from, to)
    if _getkey(array, pos) == key
        return _delete!(array, pos)
    end
    return (0, false)
end

function _delete!(array::Elements{K,T}, pos::Int) where {K,T}
    array[pos] = nothing
    return (pos, true)
end

function delete!(array::Elements{K,T}, key::K) where {K,T}
    return delete!(array, key, 1, length(array))
end

"""
    purge!(array, from, to)

Delete from `array` all elements between positions `from` and `to` included.
Return middle and the number of elements deleted
"""
function purge!(array::Elements{K,T}, from::Int, to::Int) where {K,T}
    to < from && return (0, 0)
    nb_cells_deleted = 0
    for pos in from:to
        cell = array[pos]
        if cell !== nothing
            array[pos] = nothing
            nb_cells_deleted += 1
        end
    end
    mid = from + (to - from) ÷ 2
    return (mid, nb_cells_deleted)
end