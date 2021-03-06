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
import SparseArrays: sparsevec, nonzeroinds
import Base: +, -, *, /


export Signal, SignalState, LinearCombination, QEQ, islc, ids, iszero, substitute


struct LinearCombination
  v::SparseVector{ff,Int64}
end

struct Signal
  id::Int64
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
LinearCombination(x::Signal) = LinearCombination(dropzeros!(sparsevec([x.id], [ff(1)], maxConstraintSize)))
LinearCombination(x::t) where t<:Integer = LinearCombination(dropzeros!(sparsevec([1], [ff(x)], maxConstraintSize)))
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

cmp(x::LinearCombination, y::LinearCombination) = sign(cmp(nnz(x.v), nnz(y.v))*4 + cmp(nonzeros(x.v), nonzeros(y.v))*2 + cmp(nonzeroinds(x.v), nonzeroinds(y.v)))

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
islc(x::QEQ) = iszero(x.a) || iszero(x.b)
ids(x::LinearCombination) = nonzeroinds(x.v)
ids(x::QEQ) = unique(vcat(nonzeroinds(x.a.v), nonzeroinds(x.b.v), nonzeroinds(x.c.v)))


function substitute(x::LinearCombination, s::Signal, zero::LinearCombination)
  t = zero.v[s.id]
  if t == 0
    return x
  end
  return  x - x.v[s.id]/t*zero
end

substitute(x::QEQ, s::Signal, zero::LinearCombination)=canonize!(QEQ(substitute(x.a, s, zero), substitute(x.b, s, zero), substitute(x.c, s, zero))) 

evaluate(x::Signal, values::T) where T<: AbstractVector = values[x.id]
evaluate(x::LinearCombination, values::T) where T<: AbstractVector = sum(x .* values)
evaluate(x::QEQ, values::T) where T<: AbstractVector = evaluate(x.a, values) * evaluate(x.b, values) + evaluate(x.c, values)

function canonize!(x::QEQ)
  a = x.a.v[1]
  b = x.b.v[1]
  if iszero(x.a) || iszero(x.b) 
    copyto!(x.a.v, sparsevec(ff[], maxConstraintSize))
    copyto!(x.b.v, sparsevec(ff[], maxConstraintSize))
  elseif a!=0 || b!=0
    x.a.v[1] = 0
    x.b.v[1] = 0
    copyto!(x.c.v, (x.c + x.a * b + x.b * a + a*b).v)
  end
  return x
end

end # module
