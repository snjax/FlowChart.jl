module Protoboard

using LCAlgebra
using FF
using SparseArrays
import SparseArrays: nonzeroinds

mutable struct Ctx
  signals::Vector{Signal}
end


# function canonize(ctx, a) {
#   if (a.type == "LINEARCOMBINATION") {
#       const res = clone(a);
#       for (let k in a.values) {
#           let s = k;
#           while (ctx.signals[s].equivalence) s= ctx.signals[s].equivalence;
#           if ((typeof(ctx.signals[s].value) != "undefined")&&(k != "one")) {
#               const v = res.values[k].times(ctx.signals[s].value).mod(__P__);
#               if (!res.values["one"]) {
#                   res.values["one"]=v;
#               } else {
#                   res.values["one"]= res.values["one"].add(v).mod(__P__);
#               }
#               delete res.values[k];
#           } else if (s != k) {
#               if (!res.values[s]) {
#                   res.values[s]=bigInt(res.values[k]);
#               } else {
#                   res.values[s]= res.values[s].add(res.values[k]).mod(__P__);
#               }
#               delete res.values[k];
#           }
#       }
#       for (let k in res.values) {
#           if (res.values[k].isZero()) delete res.values[k];
#       }
#       return res;
#   } else if (a.type == "QEQ") {
#       const res = {
#           type: "QEQ",
#           a: canonize(ctx, a.a),
#           b: canonize(ctx, a.b),
#           c: canonize(ctx, a.c)
#       };
#       return res;
#   } else {
#       return a;
#   }
# }

# use equivalence as Vector{Int64} with zero values for default 

function canonize(ctx::Ctx, a::LinearCombination)
  res = deepcopy(a)
  xI = nonzeroinds(a.v)
  xV = nonzeros(a.v)

  for i in 1:nnz(a.v)
    k = xI[i]
    s = k
    while !ismissing(ctx.signals[s].equivalence)
      s = ctx.signals[s].equivalence
    end
    if !ismissing(ctx.signals[s].value) && k != 1
      v = res.v[k] * ctx.signals[s].value
      res.v[1] += v
      res.v[k] = ff(0)
    elseif s!=k
      res.v[k]=res.v[s]+res.v[k]
      res.v[k] = ff(0)
    end
  end
  dropzeros!(res)
  return res
end

function canonize(ctx::Ctx, a::QEQ)
  return QEQ(canonize.([a.a, a.b, a.c])...)
end

function canonize(ctx::Ctx, a)
  return a
end

end # module
