module Protoboard

using LCAlgebra
using FF
using SparseArrays
import SparseArrays: nonzeroinds

mutable struct Ctx
  signals::SparseVector{Signal, Int64}
end

# function getSignalValue(ctx, signalName) {
#   const s = ctx.signals[signalName];
#   if (s.equivalence != "") {
#       return getSignalValue(ctx, s.equivalence);
#   } else {
#       const res = {
#           type: "NUMBER"
#       };
#       if (s.value) {
#           res.value = s.value;
#       }
#       return res;
#   }
# }

function getSignalValue(ctx::Ctx, id::Int64)
  s = ctx.signals[id]
  return ismissing(s.equivalence) ? s.value : getSignalValue(ctx, s.equivalence)
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
  return QEQ(canonize(a.a), canonize(a.b), canonize(a.c))
end

function canonize(ctx::Ctx, a)
  return a
end


# function evaluate(ctx, n) {
#   if (n.type == "NUMBER") {
#       return n;
#   } else if (n.type == "SIGNAL") {
#       return getSignalValue(ctx, n.fullName);
#   } else if (n.type == "LINEARCOMBINATION") {
#       const v= {
#           type: "NUMBER",
#           value: bigInt(0)
#       };
#       for (let k in n.values) {
#           const s = getSignalValue(ctx, k);
#           if (s.type != "NUMBER") return {type: "ERROR", errStr: "Invalid signal in linear Combination: " + k};
#           if (!s.value) return { type: "NUMBER" };
#           v.value = v.value.add( n.values[k].times(s.value)).mod(__P__);
#       }
#       return v;
#   } else if (n.type == "QEQ") {
#       const a = evaluate(ctx, n.a);
#       if (a.type == "ERROR") return a;
#       if (!a.value) return { type: "NUMBER" };
#       const b = evaluate(ctx, n.b);
#       if (b.type == "ERROR") return b;
#       if (!b.value) return { type: "NUMBER" };
#       const c = evaluate(ctx, n.c);
#       if (c.type == "ERROR") return c;
#       if (!c.value) return { type: "NUMBER" };

#       return {
#           type: "NUMBER",
#           value: (a.value.times(b.value).add(c.value)).mod(__P__)
#       };
#   } else if (n.type == "ERROR") {
#       return n;
#   } else {
#       return {type: "ERROR", errStr: "Invalid type in evaluate: "+n.type};
#   }
# }



evaluate(ctx::Ctx, n::Union{ff, Missing}) = n
evaluate(ctx::Ctx, n::Signal) = getSignalValue(ctx, n.id)

function evaluate(ctx::Ctx, n::LinearCombination)
  v=ff(0)
  xI = nonzeroinds(n.v)
  xV = nonzeros(n.v)

  for i in 1:nnz(n.v)
    k = xI[i]
    s = getSignalValue(ctx, xI[i])
    if ismissing(s) 
      return s
    end
    v = v + n.v[k] * s
  end
  return v
end

evaluate(ctx::Ctx, n::QEQ) = evaluate(ctx, n.a) * evaluate(ctx, n.b) + evaluate(ctx, n.c)


# function substitute(where, signal, equivalence) {
#   if (equivalence.type != "LINEARCOMBINATION") throw new Error("Equivalence must be a Linear Combination");
#   if (where.type == "LINEARCOMBINATION") {
#       if (!where.values[signal] || where.values[signal].isZero()) return where;
#       const res=clone(where);
#       const coef = res.values[signal];
#       for (let k in equivalence.values) {
#           if (k != signal) {
#               const v = coef.times(equivalence.values[k]).mod(__P__);
#               if (!res.values[k]) {
#                   res.values[k]=v;
#               } else {
#                   res.values[k]= res.values[k].add(v).mod(__P__);
#               }
#               if (res.values[k].isZero()) delete res.values[k];
#           }
#       }
#       delete res.values[signal];
#       return res;
#   } else if (where.type == "QEQ") {
#       const res = {
#           type: "QEQ",
#           a: substitute(where.a, signal, equivalence),
#           b: substitute(where.b, signal, equivalence),
#           c: substitute(where.c, signal, equivalence)
#       };
#       return res;
#   } else {
#       return where;
#   }
# }


end # module
