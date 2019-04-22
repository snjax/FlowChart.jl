module TestFF

using FF
using BitIntegers, Test



@testset "defenitions" begin
  @test @isdefined ff
  @test ff <: Integer
end

@testset "arithmetics" begin
  @test ff(1)/2 == ff(uint256"0x183227397098d014dc2822db40c0ac2e9419f4243cdcb848a1f0fac9f8000001")
  @test ff(-1) == ff(uint256"0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000000")
end

end #module