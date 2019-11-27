_segidofpos(pos::Int, seg_capacity::Int) = ((pos - 1) ÷ seg_capacity) + 1
_isempty(array::Elements, pos::Int) = array[pos] === nothing

function _nextemptypos(array::Elements, from::Int)
    pos = from + 1
    while pos <= length(array)
        _isempty(array, pos) && return pos
        pos += 1
    end
    return 0
end

function _previousemptypos(array::Elements, from::Int)
    pos = from - 1
    while pos >= 1
        _isempty(array, pos) && return pos
        pos -= 1
    end
    return 0
end

function _getkey(array::Elements{K,T}, pos::Int)::Union{Nothing, K} where {K,T}
    if pos == 0 || _isempty(array, pos)
        return nothing
    end
    return array[pos][1]
end

# from included, to excluded
function _nbcells(array::Elements, from::Int, to::Int)
    @assert 1 <= from && to <= length(array) + 1
    from >= to && return 0
    nbcells = 0
    for pos in from:(to-1)
        if !_isempty(array, pos)
            nbcells += 1
        end
    end
    return nbcells
end