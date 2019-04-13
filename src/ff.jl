import Base: /, *, +, -
using BitIntegers

const _P_ = uint256"21888242871839275222246405745257275088548364400416034343698204186575808495617"

mutable struct ff <: Integer
    v::UInt256
    ff(v::T) where T <: Integer = begin 
        t = UInt256(mod(v, _P_))
        return (t >= 0) ? new(t) : new(t + _P_) 
    end 
    ff(v::ff) = v
end



(+)(a::ff, b::ff) = ff(a.v + b.v)
(-)(a::ff, b::ff)  = ff(_P_ + a.v - b.v)
(-)(a::ff)  = ff(_P_ - a.v)
(*)(a::ff, b::ff) = ff(widemul(a.v, b.v) % _P_)
(/)(a::ff, b::ff) = ff(widemul(a.v, invmod(b.v, _P_)) % _P_)