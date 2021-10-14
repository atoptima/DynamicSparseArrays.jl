mutable struct Buffer{L,K,T}
    rowmajor_coo::Dict{K, Tuple{Vector{L}, Vector{T}}}
    length::Int
end

function buffer(::Type{K}, ::Type{L}, ::Type{T}) where {K,L,T}
    return Buffer{L,K,T}(Dict{K, Tuple{Vector{L}, Vector{T}}}(), 0)
end

function addrow!(
    buffer::Buffer{L,K,T}, rowid::K, colids::Vector{L}, vals::Vector{T}
) where {K,L,T}
    haskey(buffer.rowmajor_coo, rowid) && error("Row with id $rowid already written in dynamic sparse matrix buffer.")
    p = sortperm(colids)
    buffer.rowmajor_coo[rowid] = (colids[p], vals[p])
    buffer.length += length(vals)
    return
end

function addelem!(
    buffer::Buffer{L,K,T}, rowid::K, colid::L, val::T
) where {K,L,T}
    if !haskey(buffer.rowmajor_coo, rowid)
        buffer.rowmajor_coo[rowid] = (Vector{K}(), Vector{T}())
    end
    r = buffer.rowmajor_coo[rowid]
    push!(r[1], colid)
    push!(r[2], val)
    buffer.length += 1
    return
end

function get_rowids_colids_vals(buffer::Buffer{L,K,T}) where {K,L,T}
    rowids = Vector{K}(undef, buffer.length)
    colids = Vector{L}(undef, buffer.length)
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
    @assert mapreduce(i -> isdefined(rowids, i), &, 1:length(rowids)) 
    @assert mapreduce(i -> isdefined(colids, i), &, 1:length(colids))
    @assert mapreduce(i -> isdefined(vals, i), &, 1:length(vals))
    return rowids, colids, vals
end

function Base.getindex(buffer::Buffer{L,K,T}, row::K, ::Colon) where {L,K,T}
    elems = buffer.rowmajor_coo[row]
    return PackedMemoryArray(elems[1], elems[2])
end