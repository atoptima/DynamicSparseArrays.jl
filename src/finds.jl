"""
    find(array::Elements, key, from, to)

Look for the element indexed by `key` in the subarray of `array` starting at 
position `from` and ending at position `to`.

    find(array::Elements, key)
Look for the element indexed by `key` in `array`.

Return the position of the element in `array` and the element.
Return `(0, nothing)` if the `key` is not in the `array`.
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
            if curkey > key
                to = i - 1
            elseif curkey < key
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