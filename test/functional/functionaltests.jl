include("sparsevector.jl")
include("sparsematrix.jl")

function functional_tests()
    # Dynamic Sparse Vector (pma)
    @testset "dynsparsevector (PackedMemoryArray) - func - simple use" begin
        dynsparsevec_simple_use()
        dynsparsevec_fill_empty()
    end
    @testset "Insertions & finds in dyn sparse vector - performance" begin
        dynsparsevec_insertions_and_gets()
    end

    # PackedCSC
    @testset "PackedCSC - func - simple use" begin
        pcsc_simple_use()
    end

    @testset "Insertions & finds in PackedCSC matrix - performance" begin
        pcsc_insertions_and_gets()
    end

    # Dynamic Sparse Matrix (MappedPackedCSC)
    @testset "dynsparsematrix - func - simple use" begin
        dynsparsematrix_simple_use()
    end
    @testset "Insertions & finds in MappedPackedCSC matrix - performance" begin
        dynsparsematrix_insertions_and_gets()
    end
    @testset "Fillin mode" begin
        dynsparsematrix_fill_mode()
    end
    return
end
