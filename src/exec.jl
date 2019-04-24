import BitIntegers: UInt256, @uint256_str
import SHA: sha256

Ast = Dict{String, Any}

abstract type AbstractTemplate end

Scope = Dict{String, AbstractTemplate}

struct Template <: AbstractTemplate
  scopes::Vector{Scope}
end

struct Selector
  id::Int64
  name::String
end


struct Signal
end

struct Constraint
  # = lc.QEQ|ERROR
end

struct Component
  signals::Vector{String}
  template::String
  params::Dict{String, UInt256}
end

struct Function
  # not used in exec
end

struct FunctionParams
  # copied directly from untyped ast
end

struct CtxErrorPos
  firstLine::Int64
  firstColumn::Int64
  lastLine::Int64
  lastColumn::Int64
end

struct CtxError
  pos::CtxErrorPos
  errStr::String
  errFile::String
  ast::Ast
  message::String
end

mutable struct Ctx
  scopes::Vector{Scope}
  signals::Dict{String, Signal}
  constraints::Vector{Constraint}
  components::Dict{String, Component}
  currentComponent::String
  functions::Dict{String, Function}
  functionParams::Dict{String, Vector{FunctionParams}}
  templates::Dict{String, Template}
  returnValue::UInt256
  fileName::String
  filePath::String
  includedFiles::Set{String}
  error:Union{Nothing, CtxError}
  Ctx() = new(Vector{Scope}(), Vector{Signal}(), Vector{Constraint}(), "", nothing)
end


## In executor
# ctx.constraints
# ctx.scopes
# ctx.signals
# ctx.error
# ctx.fileName
# ctx.filePath
# ctx.returnValue
# ctx.includedFiles
# ctx.components
# ctx.currentComponent
# ctx.functions
# ctx.functionParams

# ctx.templates

## In compiler/codegen/witness
# ctx.callFunction
# ctx.assert
# ctx.setPin
# ctx.setSignal
# ctx.setVar
# ctx.getPin
# ctx.getSignal
# ctx.getVar
# ctx.signalName2Idx
# ctx.signalNames
# ctx.totals


function exec(ctx::Ctx, ast::Ast)
  if (ast["type"] == "NUMBER") || (ast["type"] == "LINEARCOMBINATION") || (ast["type"] =="SIGNAL") || (ast["type"] == "QEQ")
      return ast
  elseif ast["type"] == "VARIABLE"
      return execVariable(ctx, ast)
  elseif ast["type"] == "PIN"
      return execPin(ctx, ast)
  elseif ast["type"] == "OP"
      if ast.op == "="
          return execVarAssignement(ctx, ast)
      elseif ast.op == "<--"
          return execSignalAssign(ctx, ast)
      elseif ast.op == "<=="
          return execSignalAssignConstrain(ctx, ast)
      elseif ast.op == "==="
          return execConstrain(ctx, ast)
      elseif ast.op == "+="
          return execVarAddAssignement(ctx, ast)
      elseif ast.op == "*="
          return execVarMulAssignement(ctx, ast)
      elseif ast.op == "+"
          return execAdd(ctx, ast)
      elseif ast.op == "-"
          return execSub(ctx, ast)
      elseif ast.op == "UMINUS"
          return execUMinus(ctx, ast)
      elseif ast.op == "*"
          return execMul(ctx, ast)
      elseif ast.op == "%"
          return execMod(ctx, ast)
      elseif ast.op == "PLUSPLUSRIGHT"
          return execPlusPlusRight(ctx, ast)
      elseif ast.op == "PLUSPLUSLEFT"
          return execPlusPlusLeft(ctx, ast)
      elseif ast.op == "MINUSMINUSRIGHT"
          return execMinusMinusRight(ctx, ast)
      elseif ast.op == "MINUSMINUSLEFT"
          return execMinusMinusLeft(ctx, ast)
      elseif ast.op == "/"
          return execDiv(ctx, ast)
      elseif ast.op == "\\"
          return execIDiv(ctx, ast)
      elseif ast.op == "**"
          return execExp(ctx, ast)
      elseif ast.op == "&"
          return execBAnd(ctx, ast)
      elseif ast.op == "&&"
          return execAnd(ctx, ast)
      elseif ast.op == "||"
          return execOr(ctx, ast)
      elseif ast.op == "<<"
          return execShl(ctx, ast)
      elseif ast.op == ">>"
          return execShr(ctx, ast)
      elseif ast.op == "<"
          return execLt(ctx, ast)
      elseif ast.op == ">"
          return execGt(ctx, ast)
      elseif ast.op == "<="
          return execLte(ctx, ast)
      elseif ast.op == ">="
          return execGte(ctx, ast)
      elseif ast.op == "=="
          return execEq(ctx, ast)
      elseif ast.op == "!="
          return execNeq(ctx, ast)
      elseif ast.op == "?"
          return execTerCon(ctx, ast)
      else
          error(ctx, ast, "Invalid operation: " + ast.op)
      end
  elseif ast["type"] == "DECLARE"
      if ast["declareType"] == "COMPONENT"
          return execDeclareComponent(ctx, ast)
      elseif (ast["declareType"] == "SIGNALIN")||(ast["declareType"] == "SIGNALOUT")||(ast["declareType"] == "SIGNAL")
          return execDeclareSignal(ctx, ast)
      elseif ast["declareType"] == "VARIABLE"
          return execDeclareVariable(ctx, ast)
      else 
          error(ctx, ast, "Invalid declaration: " + ast["declareType"])
      end
  elseif ast["type"] == "FUNCTIONCALL"
      return execFunctionCall(ctx, ast)
  elseif ast["type"] == "BLOCK"
      return execBlock(ctx, ast)
  elseif ast["type"] == "FOR"
      return execFor(ctx, ast)
  elseif ast["type"] == "WHILE"
      return execWhile(ctx, ast)
  elseif ast["type"] == "IF"
      return execIf(ctx, ast)
  elseif ast["type"] == "RETURN"
      return execReturn(ctx, ast)
  elseif ast["type"] == "TEMPLATEDEF"
      return execTemplateDef(ctx, ast)
  elseif ast["type"] == "FUNCTIONDEF"
      return execFunctionDef(ctx, ast)
  elseif ast["type"] == "INCLUDE"
      return execInclude(ctx, ast)
  elseif ast["type"] == "ARRAY"
      return execArray(ctx, ast)
  else 
      error(ctx, ast, "Invalid AST node type: " + ast["type"])
  end
end


function error(ctx::Ctx, ast::Ast, errStr::String) 
  ctx.error = CtxError(
      CtxErrorPos(ast["first_line"], ast["first_column"], ast["last_line"], ast["last_column"]),
      errStr,
      ctx.fileName,
      ast: ast,
      errStr
  )
end


# function iterateSelectors(ctx, sizes, baseName, fn) {
#   if (sizes.length == 0) {
#       return fn(baseName)
#   }
#   const res = []
#   for (let i=0; i<sizes[0]; i++) {
#       res.push(iterateSelectors(ctx, sizes.slice(1), baseName+"["+i+"]", fn))
#       if (ctx.error) return null
#   }
#   return res
# }

# TODO - replace basename string to hashes
function iterateSelectors(ctx::Ctx, sizes::P, baseName::String, fn::T) where {T<: Function, P<: AbstractVector{Int64}}
  if length(sizes) == 0
      return fn(baseName)
  end
  res = []
  for i=1:sizes[1]
    push!(res, iterateSelectors(ctx, view(sizes, 2, length(sizes)), baseName+"["+i+"]", fn))
    if (ctx.error) 
      return nothing
    end
  end
  return res
end


# function setScope(ctx, name, selectors, value) {
#   let l = getScopeLevel(ctx, name)
#   if (l==-1) l= ctx.scopes.length-1

#   if (selectors.length == 0) {
#       ctx.scopes[l][name] = value
#   } else {
#       setScopeArray(ctx.scopes[l][name], selectors)
#   }

#   function setScopeArray(a, sels) {
#       if (sels.length == 1) {
#           a[sels[0].value] = value
#       } else {
#           setScopeArray(a[sels[0]], sels.slice(1))
#       }
#   }
# }


# selectors struct changed
function setScope(ctx::Ctx, name::String, selectors::Vector{Selector}, value::Template) 
  l = getScopeLevel(ctx, name)
  if l === nothing
    l = length(ctx.scopes)
  end

  if length(selectors) == 0
      ctx.scopes[l][name] = value
  else
    cursor = ctx.scopes[l][name]
    for s in view(selectors, 1, length(selectors) - 1)
      cursor = cursor.scopes[s.id][s.name]
    end
    s = selectors[end]
    cursor.scopes[s.id][s.name] = value
  end
end



# function getScope(ctx, name, selectors) {

#   const sels = []
#   if (selectors) {
#       for (let i=0; i< selectors.length; i++) {
#           const idx = exec(ctx, selectors[i])
#           if (ctx.error) return

#           if (idx.type != "NUMBER") return error(ctx, selectors[i], "expected a number")
#           sels.push( idx.value.toJSNumber() )
#       }
#   }


#   function select(v, s) {
#       s = s || []
#       if (s.length == 0)  return v
#       return select(v[s[0]], s.slice(1))
#   }

#   for (let i=ctx.scopes.length-1; i>=0; i--) {
#       if (ctx.scopes[i][name]) return select(ctx.scopes[i][name], sels)
#   }
#   return null
# }


# function getScope(ctx::Ctx, name::String, selectors::Vector{Selector}) 
#   const sels = []
#   if (selectors) {
#       for (let i=0; i< selectors.length; i++) {
#           const idx = exec(ctx, selectors[i])
#           if (ctx.error) return

#           if (idx.type != "NUMBER") return error(ctx, selectors[i], "expected a number")
#           sels.push( idx.value.toJSNumber() )
#       }
#   }


#   function select(v, s) {
#       s = s || []
#       if (s.length == 0)  return v
#       return select(v[s[0]], s.slice(1))
#   }

#   for (let i=ctx.scopes.length-1; i>=0; i--) {
#       if (ctx.scopes[i][name]) return select(ctx.scopes[i][name], sels)
#   }
#   return null
# }





function getScopeLevel(ctx::Ctx, name::String) 
  for i=length(ctx.scopes):-1:1 
    if haskey(ctx.scopes[i], name) 
      return i
    end
  end
  return nothing
end






function execBlock(ctx::Ctx, ast::Ast)
    for i = 1:length(ast.statements)
        exec(ctx, ast.statements[i])
        if (ctx.returnValue || ctx.error)
            return
        end
    end
end

# function execTemplateDef(ctx::Ctx, ast::Ast)
#     const scope = ctx.scopes[0];  // Lets put templates always in top scope.
#     //    const scope = ctx.scopes[ctx.scopes.length-1]
#     if (getScope(ctx, ast.name)) {
#         return error(ctx, ast, "Name already exists: "+ast.name)
#     }
#     scope[ast.name] = {
#         type: "TEMPLATE",
#         params: ast.params,
#         block: ast.block,
#         fileName: ctx.fileName,
#         filePath: ctx.filePath,
#         scopes: copyScope(ctx.scopes)
#     }
# end
#
# function execFunctionDef(ctx::Ctx, ast::Ast)
#     const scope = ctx.scopes[0]; // Lets put functions always in top scope.
#     //    const scope = ctx.scopes[ctx.scopes.length-1]
#     if (getScope(ctx, ast.name)) {
#         return error(ctx, ast, "Name already exists: "+ast.name)
#     }
#     ctx.functionParams[ast.name] = ast.params
#     scope[ast.name] = {
#         type: "FUNCTION",
#         params: ast.params,
#         block: ast.block,
#         fileName: ctx.fileName,
#         filePath: ctx.filePath,
#         scopes: copyScope(ctx.scopes)
#     }
# end
#
# function execDeclareComponent(ctx::Ctx, ast::Ast)
#     const scope = ctx.scopes[ctx.scopes.length-1]
#
#     if (ast.name.type != "VARIABLE") return error(ctx, ast, "Invalid component name")
#     if (getScope(ctx, ast.name.name)) return error(ctx, ast, "Name already exists: "+ast.name.name)
#
#     const baseName = ctx.currentComponent ? ctx.currentComponent + "." + ast.name.name : ast.name.name
#
#     const sizes=[]
#     for (let i=0; i< ast.name.selectors.length; i++) {
#         const size = exec(ctx, ast.name.selectors[i])
#         if (ctx.error) return
#
#         if (size.type != "NUMBER") return error(ctx, ast.name.selectors[i], "expected a number")
#
#         sizes.push( size.value.toJSNumber() )
#     }
#
#
#     scope[ast.name.name] = iterateSelectors(ctx, sizes, baseName, function(fullName) {
#
#         ctx.components[fullName] = "UNINSTANTIATED"
#
#         return {
#             type: "COMPONENT",
#             fullName: fullName
#         }
#     })
#
#     return {
#         type: "VARIABLE",
#         name: ast.name.name,
#         selectors: []
#     }
# }
#
# function execInstantiateComponet(ctx, vr, fn) {
#
#     if (vr.type != "VARIABLE") return error(ctx, fn, "Left hand instatiate component must be a variable")
#     if (fn.type != "FUNCTIONCALL") return error(ctx, fn, "Right type of instantiate component must be a function call")
#
#     const componentName = vr.name
#     const templateName = fn.name
#
#     const scopeLevel = getScopeLevel(ctx, templateName)
#     if (scopeLevel == -1) return error(ctx,fn, "Invalid Template")
#     const template = getScope(ctx, templateName)
#
#     if (template.type != "TEMPLATE") return error(ctx, fn, "Invalid Template")
#
#
#     const paramValues = []
#     for (let i=0; i< fn.params.length; i++) {
#         const v = exec(ctx, fn.params[i])
#         if (ctx.error) return
#
#         paramValues.push(v)
#     }
#     if (template.params.length != paramValues.length) error(ctx, fn, "Invalid Number of parameters")
#
#     const vv = getScope(ctx, componentName, vr.selectors)
#
#     if (!vv) return error(ctx, vr, "Component not defined"+ componentName)
#
#     instantiateComponent(vv)
#
#     function instantiateComponent(varVal) {
#
#         function extractValue(v) {
#             if (Array.isArray(v)) {
#                 return v.map(extractValue)
#             } else {
#                 return v.value.toString()
#             }
#         }
#
#         if (Array.isArray(varVal)) {
#             for (let i =0; i<varVal.length; i++) {
#                 instantiateComponent(varVal[i])
#             }
#             return
#         }
#
#         if (ctx.components[varVal.fullName] != "UNINSTANTIATED") error(ctx, fn, "Component already instantiated")
#
#         const oldComponent = ctx.currentComponent
#         const oldFileName = ctx.fileName
#         const oldFilePath = ctx.filePath
#         ctx.currentComponent = varVal.fullName
#
#         ctx.components[ctx.currentComponent] = {
#             signals: [],
#             params: {}
#         }
#
#         const oldScopes = ctx.scopes
#
#         ctx.scopes = oldScopes.slice(0, scopeLevel+1)
#
#         if (template.params.length != paramValues.length) return error(ctx, fn, "Invalid number of parameters: " + templateName)
#
#         const scope = {}
#         for (let i=0; i< template.params.length; i++) {
#             scope[template.params[i]] = paramValues[i]
#             ctx.components[ctx.currentComponent].params[template.params[i]] = extractValue(paramValues[i])
#         }
#
#         ctx.components[ctx.currentComponent].template = templateName
#         ctx.fileName = template.fileName
#         ctx.filePath = template.filePath
#         ctx.scopes = copyScope( template.scopes )
#         ctx.scopes.push(scope)
#
#         execBlock(ctx, template.block)
#
#         ctx.fileName = oldFileName
#         ctx.filePath = oldFilePath
#         ctx.currentComponent = oldComponent
#         ctx.scopes = oldScopes
#     }
# end
#
# function execFunctionCall(ctx::Ctx, ast::Ast)
#
#     const scopeLevel = getScopeLevel(ctx, ast.name)
#     if (scopeLevel == -1) return error(ctx, ast, "Function not defined: " + ast.name)
#     const fnc = getScope(ctx, ast.name)
#
#     if (fnc.type != "FUNCTION") return error(ctx, ast, "Not a function: " + ast.name)
#
#     const paramValues = []
#     for (let i=0; i< ast.params.length; i++) {
#         const v = exec(ctx, ast.params[i])
#         if (ctx.error) return
#
#         paramValues.push(v)
#     }
#
#     if (ast.params.length != paramValues.length) error(ctx, ast, "Invalid Number of parameters")
#
#     const oldFileName = ctx.fileName
#     const oldFilePath = ctx.filePath
#
#     const oldScopes = ctx.scopes
#
#     ctx.scopes = oldScopes.slice(0, scopeLevel+1)
#
#     const scope = {}
#     for (let i=0; i< fnc.params.length; i++) {
#         scope[fnc.params[i]] = paramValues[i]
#     }
#
#     ctx.fileName = fnc.fileName
#     ctx.filePath = fnc.filePath
#     ctx.scopes = copyScope( fnc.scopes )
#     ctx.scopes.push(scope)
#
#     execBlock(ctx, fnc.block)
#
#     const res = ctx.returnValue
#     ctx.returnValue = null
#
#     ctx.fileName = oldFileName
#     ctx.filePath = oldFilePath
#     ctx.scopes = oldScopes
#
#     return res
# end

function execReturn(ctx::Ctx, ast::Ast)
    ctx.returnValue = exec(ctx, ast.value)
end

# function execDeclareSignal(ctx::Ctx, ast::Ast)
#     const scope = ctx.scopes[ctx.scopes.length-1]
#
#     if (ast.name.type != "VARIABLE") return error(ctx, ast, "Invalid component name")
#     if (getScope(ctx, ast.name.name)) return error(ctx, ast, "Name already exists: "+ast.name.name)
#
#     const baseName = ctx.currentComponent ? ctx.currentComponent + "." + ast.name.name : ast.name.name
#
#     const sizes=[]
#     for (let i=0; i< ast.name.selectors.length; i++) {
#         const size = exec(ctx, ast.name.selectors[i])
#         if (ctx.error) return
#
#         if (size.type != "NUMBER") return error(ctx, ast.name.selectors[i], "expected a number")
#         sizes.push( size.value.toJSNumber() )
#     }
#
#     scope[ast.name.name] = iterateSelectors(ctx, sizes, baseName, function(fullName) {
#         ctx.signals[fullName] = {
#             fullName: fullName,
#             direction: ast.declareType == "SIGNALIN" ? "IN" : (ast.declareType == "SIGNALOUT" ? "OUT" : ""),
#             private: ast.private,
#             component: ctx.currentComponent,
#             equivalence: "",
#             alias: [fullName]
#         }
#         ctx.components[ctx.currentComponent].signals.push(fullName)
#         return {
#             type: "SIGNAL",
#             fullName: fullName,
#         }
#     })
#     return {
#         type: "VARIABLE",
#         name: ast.name.name,
#         selectors: []
#     }
# end
#
# function execDeclareVariable(ctx::Ctx, ast::Ast)
#     const scope = ctx.scopes[ctx.scopes.length-1]
#
#     if (ast.name.type != "VARIABLE") return error(ctx, ast, "Invalid linear combination name")
#     if (getScope(ctx, ast.name.name)) return error(ctx, ast, "Name already exists: "+ast.name.name)
#
#     const sizes=[]
#     for (let i=0; i< ast.name.selectors.length; i++) {
#         const size = exec(ctx, ast.name.selectors[i])
#         if (ctx.error) return
#
#         if (size.type != "NUMBER") return error(ctx, ast.name.selectors[i], "expected a number")
#         sizes.push( size.value.toJSNumber() )
#     }
#
#     scope[ast.name.name] = iterateSelectors(ctx, sizes, "", function() {
#         return {
#             type: "NUMBER",
#             value: bigInt(0)
#         }
#     })
#
#     return {
#         type: "VARIABLE",
#         name: ast.name.name,
#         selectors: []
#     }
# end
#
# function execVariable(ctx::Ctx, ast::Ast)
#     let v
#     try {
#         v = getScope(ctx, ast.name, ast.selectors)
#     } catch(err) {
#         console.log(JSON.stringify(ast, null,1))
#     }
#     if (ctx.error) return
#
#     if (!v) return error(ctx, ast, "Variable not defined")
#
#     // If the signal has an assigned value (constant) just return the constant
#     if ((v.type == "SIGNAL") && (ctx.signals[v.fullName].value)) {
#         return {
#             type: "NUMBER",
#             value: ctx.signals[v.fullName].value
#         }
#     }
#     let res
#     res=v
#     return res
# end
#
# function execPin(ctx::Ctx, ast::Ast)
#     const component = getScope(ctx, ast.component.name, ast.component.selectors)
#     if (!component) return error(ctx, ast.component, "Component does not exists: "+ast.component.name)
#     if (ctx.error) return
#     let signalFullName = component.fullName + "." + ast.pin.name
#     for (let i=0; i< ast.pin.selectors.length; i++) {
#         const sel = exec(ctx, ast.pin.selectors[i])
#         if (ctx.error) return
#
#         if (sel.type != "NUMBER") return error(ctx, ast.pin.selectors[i], "expected a number")
#
#         signalFullName += "[" + sel.value.toJSNumber() + "]"
#     }
#     if (!ctx.signals[signalFullName]) error(ctx, ast, "Signal not defined:" + signalFullName)
#     return {
#         type: "SIGNAL",
#         fullName: signalFullName
#     }
# end
#
# function execFor(ctx::Ctx, ast::Ast)
#
#     ctx.scopes.push({})
#     exec(ctx, ast.init)
#     if (ctx.error) return
#
#     let v = exec(ctx, ast.condition)
#     if (ctx.error) return
#
#     if (typeof v.value != "undefined") {
#         while ((v.value.neq(0))&&(!ctx.returnValue)) {
#             exec(ctx, ast.body)
#             if (ctx.error) return
#
#             exec(ctx, ast.step)
#             if (ctx.error) return
#
#             v = exec(ctx, ast.condition)
#             if (ctx.error) return
#         }
#     }
#     ctx.scopes.pop()
# end
#
# function execWhile(ctx::Ctx, ast::Ast)
#     let v = exec(ctx, ast.condition)
#     if (ctx.error) return
#
#     if (typeof v.value != "undefined") {
#         while ((v.value.neq(0))&&(!ctx.returnValue)) {
#             exec(ctx, ast.body)
#             if (ctx.error) return
#
#             v = exec(ctx, ast.condition)
#             if (ctx.error) return
#         }
#     }
# end
#
# function execIf(ctx::Ctx, ast::Ast)
#     let v = exec(ctx, ast.condition)
#     if (ctx.error) return
#
#     if (typeof v.value != "undefined") {
#         if ((v.value.neq(0))&&(!ctx.returnValue)) {
#             exec(ctx, ast.then)
#             if (ctx.error) return
#         } else {
#             if (ast.else) {
#                 exec(ctx, ast.else)
#                 if (ctx.error) return
#             }
#         }
#     }
# end
#
# function execVarAssignement(ctx::Ctx, ast::Ast)
#     let v
#     if (ast.values[0].type == "DECLARE") {
#         v = exec(ctx, ast.values[0])
#         if (ctx.error) return
#     } else {
#         v = ast.values[0]
#     }
#     const num = getScope(ctx, v.name, v.selectors)
#     if (ctx.error) return
#
#     if ((typeof(num) != "object")||(num == null)) return  error(ctx, ast, "Variable not defined")
#
#     if (num.type == "COMPONENT") return execInstantiateComponet(ctx, v, ast.values[1])
#     if (ctx.error) return
# //    if (num.type == "SIGNAL") return error(ctx, ast, "Cannot assign to a signal with `=` use <-- or <== ops")
#
#     const res = exec(ctx, ast.values[1])
#     if (ctx.error) return
#
#     setScope(ctx, v.name, v.selectors, res)
#
#     return v
# end
#
# function execLt(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     if (a.type != "NUMBER") return { type: "NUMBER" }
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#     if (b.type != "NUMBER") return { type: "NUMBER" }
#     if (!a.value || !b.value) return { type: "NUMBER" }
#     return {
#         type: "NUMBER",
#         value: a.value.lt(b.value) ? bigInt(1) : bigInt(0)
#     }
# end
#
# function execGt(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     if (a.type != "NUMBER") return { type: "NUMBER" }
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#     if (b.type != "NUMBER") return { type: "NUMBER" }
#     if (!a.value || !b.value) return { type: "NUMBER" }
#     return {
#         type: "NUMBER",
#         value: a.value.gt(b.value) ? bigInt(1) : bigInt(0)
#     }
# end
#
# function execLte(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     if (a.type != "NUMBER") return { type: "NUMBER" }
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#     if (b.type != "NUMBER") return { type: "NUMBER" }
#     if (!a.value || !b.value) return { type: "NUMBER" }
#     return {
#         type: "NUMBER",
#         value: a.value.lesserOrEquals(b.value) ? bigInt(1) : bigInt(0)
#     }
# end
#
# function execGte(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     if (a.type != "NUMBER") return { type: "NUMBER" }
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#     if (b.type != "NUMBER") return { type: "NUMBER" }
#     if (!a.value || !b.value) return { type: "NUMBER" }
#     return {
#         type: "NUMBER",
#         value: a.value.greaterOrEquals(b.value) ? bigInt(1) : bigInt(0)
#     }
# end
#
# function execEq(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     if (a.type != "NUMBER") return { type: "NUMBER" }
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#     if (b.type != "NUMBER") return { type: "NUMBER" }
#     if (!a.value || !b.value) return { type: "NUMBER" }
#     return {
#         type: "NUMBER",
#         value: a.value.eq(b.value) ? bigInt(1) : bigInt(0)
#     }
# end
#
# function execNeq(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     if (a.type != "NUMBER") return { type: "NUMBER" }
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#     if (b.type != "NUMBER") return { type: "NUMBER" }
#     if (!a.value || !b.value) return { type: "NUMBER" }
#     return {
#         type: "NUMBER",
#         value: a.value.eq(b.value) ? bigInt(0) : bigInt(1)
#     }
# end
#
# function execBAnd(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     if (a.type != "NUMBER") return { type: "NUMBER" }
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#     if (b.type != "NUMBER") return { type: "NUMBER" }
#     if (!a.value || !b.value) return { type: "NUMBER" }
#     return {
#         type: "NUMBER",
#         value: a.value.and(b.value).and(__MASK__)
#     }
# end
#
# function execAnd(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     if (a.type != "NUMBER") return { type: "NUMBER" }
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#     if (b.type != "NUMBER") return { type: "NUMBER" }
#     if (!a.value || !b.value) return { type: "NUMBER" }
#     return {
#         type: "NUMBER",
#         value: (a.value.neq(0) && a.value.neq(0)) ? bigInt(1) : bigInt(0)
#     }
# end
#
# function execOr(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     if (a.type != "NUMBER") return { type: "NUMBER" }
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#     if (b.type != "NUMBER") return { type: "NUMBER" }
#     if (!a.value || !b.value) return { type: "NUMBER" }
#     return {
#         type: "NUMBER",
#         value: (a.value.neq(0) || a.value.neq(0)) ? bigInt(1) : bigInt(0)
#     }
# end
#
# function execShl(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     if (a.type != "NUMBER") return { type: "NUMBER" }
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#     if (b.type != "NUMBER") return { type: "NUMBER" }
#     if (!a.value || !b.value) return { type: "NUMBER" }
#     const v = b.value.greater(256) ? 256 : b.value.value
#     return {
#         type: "NUMBER",
#         value: a.value.shiftLeft(v).and(__MASK__)
#     }
# end
#
# function execShr(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     if (a.type != "NUMBER") return { type: "NUMBER" }
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#     if (b.type != "NUMBER") return { type: "NUMBER" }
#     if (!a.value || !b.value) return { type: "NUMBER" }
#     const v = b.value.greater(256) ? 256 : b.value.value
#     return {
#         type: "NUMBER",
#         value: a.value.shiftRight(v).and(__MASK__)
#     }
# end
#
# function execMod(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     if (a.type != "NUMBER") return { type: "NUMBER" }
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#     if (b.type != "NUMBER") return { type: "NUMBER" }
#     if (!a.value || !b.value) return { type: "NUMBER" }
#     return {
#         type: "NUMBER",
#         value: a.value.mod(b.value)
#     }
# end
#
# function execExp(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     if (a.type != "NUMBER") return { type: "NUMBER" }
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#     if (b.type != "NUMBER") return { type: "NUMBER" }
#     if (!a.value || !b.value) return { type: "NUMBER" }
#     return {
#         type: "NUMBER",
#         value: a.value.modPow(b.value, __P__)
#     }
# end
#
# function execDiv(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     if (a.type != "NUMBER") return { type: "NUMBER" }
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#     if (b.type != "NUMBER") return { type: "NUMBER" }
#     if (!a.value || !b.value) return { type: "NUMBER" }
#     if (b.value.isZero()) return error(ctx, ast, "Division by zero")
#     return {
#         type: "NUMBER",
#         value: a.value.times(b.value.modInv(__P__)).mod(__P__)
#     }
# end
#
# function execIDiv(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     if (a.type != "NUMBER") return { type: "NUMBER" }
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#     if (b.type != "NUMBER") return { type: "NUMBER" }
#     if (!a.value || !b.value) return { type: "NUMBER" }
#     if (b.value.isZero()) return error(ctx, ast, "Division by zero")
#     return {
#         type: "NUMBER",
#         value: a.value.divide(b.value)
#     }
# end
#
# function execAdd(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#
#     const res = lc.add(a,b)
#     if (res.type == "ERROR") return error(ctx, ast, res.errStr)
#
#     return res
# end
#
# function execSub(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#
#     const res = lc.sub(a,b)
#     if (res.type == "ERROR") return error(ctx, ast, res.errStr)
#
#     return res
# end
#
# function execUMinus(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#
#     const res = lc.negate(a)
#     if (res.type == "ERROR") return error(ctx, ast, res.errStr)
#
#     return res
# end
#
# function execMul(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#
#     const res = lc.mul(a,b)
#     if (res.type == "ERROR") return error(ctx, ast, res.errStr)
#
#     return res
# end
#
# function execVarAddAssignement(ctx::Ctx, ast::Ast)
#     const res = execAdd(ctx,{ values: [ast.values[0], ast.values[1]] } )
#     if (ctx.error) return
#     return execVarAssignement(ctx, { values: [ast.values[0], res] })
# end
#
# function execVarMulAssignement(ctx::Ctx, ast::Ast)
#     const res = execMul(ctx,{ values: [ast.values[0], ast.values[1]] } )
#     if (ctx.error) return
#     return execVarAssignement(ctx, { values: [ast.values[0], res] })
# end
#
# function execPlusPlusRight(ctx::Ctx, ast::Ast)
#     const resBefore = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     const resAfter = execAdd(ctx,{ values: [ast.values[0], {type: "NUMBER", value: bigInt(1)}] } )
#     if (ctx.error) return
#     execVarAssignement(ctx, { values: [ast.values[0], resAfter] })
#     return resBefore
# end
#
# function execPlusPlusLeft(ctx::Ctx, ast::Ast)
#     if (ctx.error) return
#     const resAfter = execAdd(ctx,{ values: [ast.values[0], {type: "NUMBER", value: bigInt(1)}] } )
#     if (ctx.error) return
#     execVarAssignement(ctx, { values: [ast.values[0], resAfter] })
#     return resAfter
# end
#
# function execMinusMinusRight(ctx::Ctx, ast::Ast)
#     const resBefore = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     const resAfter = execSub(ctx,{ values: [ast.values[0], {type: "NUMBER", value: bigInt(1)}] } )
#     if (ctx.error) return
#     execVarAssignement(ctx, { values: [ast.values[0], resAfter] })
#     return resBefore
# end
#
# function execMinusMinusLeft(ctx::Ctx, ast::Ast)
#     if (ctx.error) return
#     const resAfter = execSub(ctx,{ values: [ast.values[0], {type: "NUMBER", value: bigInt(1)}] } )
#     if (ctx.error) return
#     execVarAssignement(ctx, { values: [ast.values[0], resAfter] })
#     return resAfter
# end
#
# function execTerCon(ctx::Ctx, ast::Ast)
#     const cond = exec(ctx, ast.values[0])
#     if (ctx.error) return
#
#     if (!cond.value) return { type: "NUMBER" }
#
#     if (cond.value.neq(0)) {
#         return exec(ctx, ast.values[1])
#     } else {
#         return exec(ctx, ast.values[2])
#     }
# end
#
# function execSignalAssign(ctx::Ctx, ast::Ast)
#     let vDest
#     if (ast.values[0].type == "DECLARE") {
#         vDest = exec(ctx, ast.values[0])
#         if (ctx.error) return
#     } else {
#         vDest = ast.values[0]
#     }
#
#     let dst
#     if (vDest.type == "VARIABLE") {
#         dst = getScope(ctx, vDest.name, vDest.selectors)
#         if (ctx.error) return
#     } else if (vDest.type == "PIN") {
#         dst = execPin(ctx, vDest)
#         if (ctx.error) return
#     } else {
#         error(ctx, ast, "Bad assignement")
#     }
#
#     if (!dst) return  error(ctx, ast, "Signal not defined")
#     if (dst.type != "SIGNAL") return  error(ctx, ast, "Signal assigned to a non signal")
#
#     let sDest=ctx.signals[dst.fullName]
#     if (!sDest) return error(ctx, ast, "Invalid signal: "+dst.fullName)
#     while (sDest.equivalence) sDest=ctx.signals[sDest.equivalence]
#
#     if (sDest.value) return error(ctx, ast, "Signals cannot be assigned twice")
#
#     let src = exec(ctx, ast.values[1])
#     if (ctx.error) return
#
#
#     /*
#     let vSrc
#     if (ast.values[1].type == "DECLARE") {
#         vSrc = exec(ctx, ast.values[1])
#         if (ctx.error) return
#     } else {
#         vSrc = ast.values[1]
#     }
#
#     if (vSrc.type == "VARIABLE") {
#         src = getScope(ctx, vSrc.name, vSrc.selectors)
#         if (!src) error(ctx, ast, "Variable not defined: " + vSrc.name)
#         if (ctx.error) return
#     } else if (vSrc.type == "PIN") {
#         src = execPin(ctx, vSrc)
#     }
#     */
#
#     let assignValue = true
#     if (src.type == "SIGNAL") {
#         sDest.equivalence = src.fullName
#         sDest.alias = sDest.alias.concat(src.alias)
#         while (sDest.equivalence) sDest=ctx.signals[sDest.equivalence]
#         assignValue = false
#     }
#
#     if (assignValue) {
#         //        const resLC = exec(ctx, vSrc)
#         if (ctx.error) return
#
#         //        const v = lc.evaluate(ctx, resLC)
#         const v = lc.evaluate(ctx, src)
#
#         if (v.value) {
#             sDest.value = v.value
#         }
#     }
#
#     return vDest
# end
#
# function execConstrain(ctx::Ctx, ast::Ast)
#     const a = exec(ctx, ast.values[0])
#     if (ctx.error) return
#     const b = exec(ctx, ast.values[1])
#     if (ctx.error) return
#
#     const res = lc.sub(a,b)
#     if (res.type == "ERROR") return error(ctx, ast, res.errStr)
#
#     if (!lc.isZero(res)) {
#         ctx.constraints.push(lc.toQEQ(res))
#     }
#
#     return res
# end
#
# function execSignalAssignConstrain(ctx::Ctx, ast::Ast)
#     const v = execSignalAssign(ctx,endst)
#     if (ctx.error) return
#     execConstrain(ctx::Ctx, ast::Ast
#     if (ctx.error) return
#     return v
# end
#
# function execInclude(ctx::Ctx, ast::Ast)
#     const incFileName = path.resolve(ctx.filePath, ast.file)
#     const incFilePath = path.dirname(incFileName)
#
#     ctx.includedFiles = ctx.includedFiles || []
#     if (ctx.includedFiles[incFileName]) return
#
#     ctx.includedFiles[incFileName] = true
#
#     const src = fs.readFileSync(incFileName, "utf8")
#
#     if (!src) return error(ctx, ast, "Include file not found: "+incFileName)
#
#     const incAst = parser.parse(src)
#
#     const oldFilePath = ctx.filePath
#     const oldFileName = ctx.fileName
#     ctx.filePath = incFilePath
#     ctx.fileName = incFileName
#
#     exec(ctx, incAst)
#
#     ast.block = incAst
#
#     ctx.filePath = oldFilePath
#     ctx.fileName = oldFileName
# end
#
# function execArray(ctx::Ctx, ast::Ast)
#     const res = []
#
#     for (let i=0; i<ast.values.length; i++) {
#         res.push(exec(ctx, ast.values[i]))
#     }
#
#     return res
# end
#
# function copyScope(scope::Scope)
#     var scopesClone = []
#     for (let i=0; i<scope.length; i++) {
#         scopesClone.push(scope[i])
#     }
#     return scopesClone
# end
#









