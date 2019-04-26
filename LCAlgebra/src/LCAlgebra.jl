module LCAlgebra


# +       NUM     LC      QEQ
# NUM     NUM     LC      QEQ
# LC      LC      LC      QEQ
# QEQ     QEQ     QEQ     ERR

# *       NUM     LC      QEQ
# NUM     NUM     LC      QEQ
# LC      LC      QEQ     ERR
# QEQ     QEQ     ERR     ERR

using FF
using SparseArrays, BitIntegers
import SparseArrays: sparsevec
import Base: +, -, *, /


export Signal, LinearCombination, QEQ

struct LinearCombination
  v::SparseVector{ff,Int64}
end

struct Signal
  id::Int64
  equivalence::Union{Int64, Missing}
  value::Union{ff, Missing}
  Signal(id::Int64)=new(id, missing, missing)
end



struct QEQ
  a::LinearCombination
  b::LinearCombination
  c::LinearCombination
end

const maxConstraintSize=1<<30

LCA = Union{Integer, Signal, LinearCombination}
LCB = Union{Signal, LinearCombination}
LCP = Union{LinearCombination, QEQ}
LCU = Union{LCA, LCP}


Signal(x::Signal) = x
LinearCombination(x::Signal) = LinearCombination(sparsevec([x.id], [ff(1)], maxConstraintSize))
LinearCombination(x::t) where t<:Integer = LinearCombination(sparsevec([1], [ff(x)], maxConstraintSize))
LinearCombination(x::LinearCombination) = x
QEQ(x::LinearCombination) = QEQ(LinearCombination(SparseVector(maxConstraintSize, Int64[], ff[])), LinearCombination(SparseVector(maxConstraintSize, Int64[], ff[])), x)
QEQ(x::T) where T<: LCA = QEQ(LinearCombination(x)) 
QEQ(x::QEQ) = x



(-)(x::Signal) = -LinearCombination(x)
(-)(x::LinearCombination) = LinearCombination(-x.v)
(-)(x::QEQ) = QEQ(-x.a, x.b, -x.c)


(+)(x::LinearCombination, y::LinearCombination) = LinearCombination(x.v+y.v)
(+)(x::QEQ, y::QEQ) = error("additive operations for (::QEQ, ::QEQ) are not determined")


(+)(x::T, y::QEQ) where T<:LCA = QEQ(y.a, y.b, y.c+LinearCombination(x))
(+)(x::QEQ, y::T) where T<:LCA = QEQ(x.a, x.b, x.c+LinearCombination(y))
(+)(x::A, y::B) where {A<:LCA, B<:LCA}  = LinearCombination(x)+LinearCombination(y)
(-)(x::A, y::B) where {A<:LCU, B<:LCU} = x + (-y)


(*)(x::P, y::T) where {P<:LCB, T<:LCB}= QEQ(LinearCombination(x), LinearCombination(y), LinearCombination(SparseVector(maxConstraintSize, Int64[], ff[])))
(*)(x::QEQ, y::QEQ) = error("multiplicative operations for (::QEQ, ::QEQ) are not determined")

(*)(x::T, y::QEQ) where T<: LCB = error("multiplicative operations for (::LinearCombination, ::QEQ) are not determined")
(*)(x::QEQ, y::T) where T<: LCB = error("multiplicative operations for (::QEQ, ::LinearCombination) are not determined")
(*)(x::QEQ, y::T) where T<:Integer = QEQ(x.a*ff(y), x.b, x.c*ff(y))
(/)(x::QEQ, y::T) where T<:Integer = QEQ(x.a/ff(y), x.b, x.c/ff(y))
(*)(x::T, y::QEQ) where T<:Integer = QEQ(y.a*ff(y), y.b, y.c*ff(y))

(*)(x::P, y::T) where {P<:LCB, T<:Integer} = LinearCombination(LinearCombination(x).v*ff(y))
(/)(x::P, y::T) where {P<:LCB, T<:Integer} = LinearCombination(LinearCombination(x).v/ff(y))
(*)(x::P, y::T) where {P<:Integer, T<:LCB} = LinearCombination(LinearCombination(y).v*ff(x))


# function isZero(a) {
#   if (a.type == "NUMBER") {
#       return a.value.isZero();
#   } else if (a.type == "LINEARCOMBINATION") {
#       for (let k in a.values) {
#           if (!a.values[k].isZero()) return false;
#       }
#       return true;
#   } else if (a.type == "QEQ") {
#       return (isZero(a.a) || isZero(a.b)) && isZero(a.c);
#   } else if (a.type == "ERROR") {
#       return false;
#   } else {
#       return false;
#   }
# }

iszero(::Signal) = false
iszero(x::LinearCombination) = nnz(x.v)==0
iszero(x::QEQ) = iszero(x.c) && (iszero(x.a) || iszero(x.b))




end # module
