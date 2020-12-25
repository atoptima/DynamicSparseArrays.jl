mutable struct Buffer{L,K,T}
    rowmajor_coo::Dict{L, Tuple{Vector{L}, Vector{T}}}
    length::Int
end

function buffer(::Type{K}, ::Type{L}, ::Type{T}) where {K,L,T}
    return Buffer{L,K,T}(Dict{L, Tuple{Vector{K}, Vector{T}}}(), 0)
end

function addrow!(
    buffer::Buffer{L,K,T}, rowid::L, colids::Vector{K}, vals::Vector{T}
) where {K,L,T}
    haskey(buffer.rowmajor_coo, rowid) && error("Row with id $rowid already written in dynamic sparse matrix buffer.")
    p = sortperm(colids)
    buffer.rowmajor_coo[rowid] = (colids[p], vals[p])
    buffer.length += length(vals)
    return
end

function get_rowids_colids_vals(buffer::Buffer{L,K,T}) where {K,L,T}
    rowids = Vector{L}(undef, buffer.length)
    colids = Vector{K}(undef, buffer.length)
    vals = Vector{T}(undef, buffer.length)

    curpos = 1
    for (rowid, brow) in buffer.rowmajor_coo
        bcolids = brow[1]
        bvals = brow[2]
        for i in 1:length(bvals)
            rowids[curpos] = rowid
            colids[curpos] = bcolids[i]
            vals[curpos] = bvals[i]
            curpos += 1
        end
    end
    return rowids, colids, vals
end

function Base.getindex(buffer::Buffer{L,K,T}, row::L, ::Colon) where {L,K,T}
    elems = buffer.rowmajor_coo[row]
    return PackedMemoryArray(elems[1], elems[2])
end