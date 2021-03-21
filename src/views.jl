# We can get only a column of the dynamic matrix.
# Only usefull to iterate on a column of the dynamic matrix
struct DynamicMatrixColView{K,L,T<:Real}
    mpcsc::MappedPackedCSC{K,L,T}
    col_key::L
    partition::Int
    array::Elements{K,T}
    empty::Bool
end

function Base.view(mpcsc::MappedPackedCSC{K,L,T}, row::K, ::Colon) where {K,L,T}
    throw(ArgumentError("Cannot view a row of a Mapped Packed Compressed Sparse Column Matrix."))
end

function Base.view(mpcsc::MappedPackedCSC{K,L,T}, ::Colon, col::L) where {K,L,T}
    col_pos, col_key = find(mpcsc.col_keys, col)
    empty_col = col_key != col
    array = getfield(getfield(getfield(mpcsc, :pcsc), :pma), :array)
    return DynamicMatrixColView{K,L,T}(mpcsc, col, col_pos, array, empty_col)
end

function Base.iterate(dms::DynamicMatrixColView)
    pcsc = getfield(getfield(dms, :mpcsc), :pcsc)
    getfield(dms, :empty) && return nothing
    from = _pos_of_partition_start(pcsc, dms.partition) + 1
    to = _pos_of_partition_end(pcsc, dms.partition)
    return iterate(dms, (UnitRange{Int}(from, to),))
end

function Base.iterate(dms::DynamicMatrixColView, state)
    array = getfield(dms, :array)
    y = iterate(state...)
    y === nothing && return nothing
    return _iterate(array[y[1]], array, (state[1], Base.tail(y)...))
end
