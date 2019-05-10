module Protoboard

using LCAlgebra
using FF
using SparseArrays
import SparseArrays: nonzeroinds


# Constraint system chunk. 1st element is one signal. 
# Other elements may be corresponded to other signals, shifted to any offset.
# nsignals - number of signals
# xsignals - number of external signals (>=1, because 1st signal is external everywhere)
# muted - bitmask of muted signals, array from 1 to nsignals

mutable struct CSTemplate
  nsignals::Int64
  xsignals::Int64
  unmuted::Vector{Int64}
  constraints::Vector{QEQ}
end


and(l::Bool...) = reduce((x::Bool, y::Bool)->x&&y, l)

function optimize!(cs::CSTemplate)
  constraints = cs.constraints
  nconstraints=length(constraints)
  nsignals=cs.nsignals
  xsignals=cs.xsignals
  unmuteds = Set(1:nsignals)
  unmutedc = Set(1:nconstraints)
  linearc = Set()

  indexs = Vector{Set}
  indexc = Vector{Set}

  function mute(ic::Int64, is::Int64)
    #mute constraint
    for j in indexc[ic]
      delete!(indexs[j], ic)
    end
    delete!(unmutedc, ic)
    
    #mute signal
    local c = constraints[ic]
    for i in indexs[is]
      if i != ic
        constraints[i] = substitute(constraints[i], is, c)
        local newindexc = Set(ids(constraints[i]))
        local to_delete = setdiff(indexc[ic], newindexc)
        local to_insert = setdiff(newindexc, indexc[ic])
        indexc[ic] = newindexc
        for j in to_delete
          delete!(indexs[j], i)
        end
        for j in to_insert
          insert!(indexs[j], i)
        end
        if islc(constraints[i])
          push!(linearc, i)
        end
      end
    end
    delete!(unmuteds, is)
  end



  for i in 1:nsignals
    indexs[i] = Set()
  end

  for i in 1:nconstraints
    c = cs.constraints[i]
    ids = ids(c)
    indexc[i] = Set(ids)
    for j in ids
      push!(indexs[j], i)
    end
  end

  for i in 1:nconstraints
    if islc(constraints[i])
      push!(linearc, i)
    end
  end


  while length(linearc) > 0
    for i in collect(linearc)
      c = constraints[i]
      if iszero(c)
        delete!(linearc, i)
        for j in indexc[i]
          delete!(indexs[j], i)
        end
        delete!(unmutedc, i)
      else
        delete!(linearc, i)
        ls = maximum(indexc[i])
        if ls > xsignals
          mute(i, ls)
        end
      end
    end
  end

  cs.unmuted = collect(unmuteds)
  cs.constraints = cs.constraints[collect(unmutedc)]
  return cs
end

end # module
