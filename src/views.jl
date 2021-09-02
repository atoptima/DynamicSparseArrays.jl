# We can get only a column of the dynamic matrix.
# Only usefull to iterate on a column of the dynamic matrix
struct DynamicMatrixColView{K,L,T}
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

# We can only get a row of the buffer
struct BufferView{L,K,T}
    rowid::K
    colids::Vector{L}
    vals::Vector{T}
end

function Base.view(buffer::Buffer{L,K,T}, row::K, ::Colon) where {K,L,T}
    colids, vals = Vector.(get(buffer.rowmajor_coo, row, (L[], T[])))
    @assert length(colids) == length(vals)
    _prepare_keys_vals!(colids, vals, +)
    return BufferView{L,K,T}(row, colids, vals)
end

function Base.view(::Buffer{L,K,T}, ::Colon, col::L) where {K,L,T}
    throw(ArgumentError("Cannot view a column of the BufferView."))
end

function Base.iterate(bf::BufferView, state = 1)
    state > length(bf.vals) && return nothing
    return ((bf.colids[state], bf.vals[state]), state + 1)
end