"""
    find(array::Vector{Union{Nothing, T}}, key, from::Int, to::Int) where {T}

Look for the element indexed by `key` in the subarray of `array` starting at 
position `from` and ending at position `to`.

If the element is in the subarray, the method returns the position and the 
the element.

If the element is not in the subarray, the method returns the position and the 
element that has the nearest inferior key (predecessor) in the subarray. 

If the element has no predecessor in the subarray, the method returns the
position and the last element located in the left outside.


    find(array::Vector{Union{Nothing, T}}, key) where {T}

Look for the element indexed by `key` in `array`.

If the element is in the `array`, the method returns the position and the 
the element.

If the element is not in the `array`, the method returns the position and the 
element that has the nearest inferior key (predecessor). 

If the element has no predecessor, the method returns `(0, nothing)`.
"""
function find(array::Vector{Union{Nothing, T}}, key, from::Int, to::Int) where {T}
    while from <= to
        mid = (from + to) ÷ 2
        i = mid
        while i >= from && _isempty(array, i)
            i -= 1
        end
        if i < from
            from = mid + 1
        else
            curkey = _getkey(array, i)
            if !isnothing(curkey) && curkey > key
                to = i - 1
            elseif !isnothing(curkey) && curkey < key
                from = mid + 1
            else
                return (i, array[i])
            end
        end
    end
    i = to
    while i > 0 && _isempty(array, i)
        i -= 1
    end
    if i > 0
        return (i, array[i])
    end
    return (0, nothing)
end

function find(array::Vector{Union{Nothing, T}}, key) where {T}
    return find(array, key, 1, length(array))
end