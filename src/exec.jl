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
  signals::Vector{Signal}
  constraints::Vector{Constraint}
  fileName::String
  error:Union{Nothing, CtxError}
  Ctx() = new(Vector{Scope}(), Vector{Signal}(), Vector{Constraint}(), "", nothing)
end

# const ctx = {
#   scopes: [{}],
#   signals: {
#       one: {
#           fullName: "one",
#           value: bigInt(1),
#           equivalence: "",
#           direction: ""
#       }
#   },
#   currentComponent: "",
#   constraints: [],
#   components: {},
#   templates: {},
#   functions: {},
#   functionParams: {},
#   filePath: fullFilePath,
#   fileName: fullFileName
# };




function exec(ctx::Ctx, ast::Ast)
  if (ast["type"] == "NUMBER") || (ast["type"] == "LINEARCOMBINATION") || (ast["type"] =="SIGNAL") || (ast["type"] == "QEQ")
      return ast;
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


# function error(ctx, ast, errStr) {
#   ctx.error = {
#       pos:   {
#           first_line: ast.first_line,
#           first_column: ast.first_column,
#           last_line: ast.last_line,
#           last_column: ast.last_column
#       },
#       errStr: errStr,
#       errFile: ctx.fileName,
#       ast: ast,
#       message: errStr
#   };
# }

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
#       return fn(baseName);
#   }
#   const res = [];
#   for (let i=0; i<sizes[0]; i++) {
#       res.push(iterateSelectors(ctx, sizes.slice(1), baseName+"["+i+"]", fn));
#       if (ctx.error) return null;
#   }
#   return res;
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
#   let l = getScopeLevel(ctx, name);
#   if (l==-1) l= ctx.scopes.length-1;

#   if (selectors.length == 0) {
#       ctx.scopes[l][name] = value;
#   } else {
#       setScopeArray(ctx.scopes[l][name], selectors);
#   }

#   function setScopeArray(a, sels) {
#       if (sels.length == 1) {
#           a[sels[0].value] = value;
#       } else {
#           setScopeArray(a[sels[0]], sels.slice(1));
#       }
#   }
# }


# selectors struct changed
function setScope(ctx::Ctx, name::String, selectors::Vector{Selector}, value::Template) 
  l = getScopeLevel(ctx, name)
  if l===nothing
    l = length(ctx)
  end

  if length(selectors) == 0
      ctx.scopes[l][name] = value
  else
    cursor = ctx.scopes[l][name]
    for s in view(selectors, 1, length(selectors)-1)
      cursor = cursor.scopes[s.id][s.name]
    end
    s=selectors[end]
    cursor.scopes[s.id][s.name] = value
  end
end



# function getScope(ctx, name, selectors) {

#   const sels = [];
#   if (selectors) {
#       for (let i=0; i< selectors.length; i++) {
#           const idx = exec(ctx, selectors[i]);
#           if (ctx.error) return;

#           if (idx.type != "NUMBER") return error(ctx, selectors[i], "expected a number");
#           sels.push( idx.value.toJSNumber() );
#       }
#   }


#   function select(v, s) {
#       s = s || [];
#       if (s.length == 0)  return v;
#       return select(v[s[0]], s.slice(1));
#   }

#   for (let i=ctx.scopes.length-1; i>=0; i--) {
#       if (ctx.scopes[i][name]) return select(ctx.scopes[i][name], sels);
#   }
#   return null;
# }


# function getScope(ctx::Ctx, name::String, selectors::Vector{Selector}) 
#   const sels = [];
#   if (selectors) {
#       for (let i=0; i< selectors.length; i++) {
#           const idx = exec(ctx, selectors[i]);
#           if (ctx.error) return;

#           if (idx.type != "NUMBER") return error(ctx, selectors[i], "expected a number");
#           sels.push( idx.value.toJSNumber() );
#       }
#   }


#   function select(v, s) {
#       s = s || [];
#       if (s.length == 0)  return v;
#       return select(v[s[0]], s.slice(1));
#   }

#   for (let i=ctx.scopes.length-1; i>=0; i--) {
#       if (ctx.scopes[i][name]) return select(ctx.scopes[i][name], sels);
#   }
#   return null;
# }





function getScopeLevel(ctx::Ctx, name::String) 
  for i=length(ctx.scopes):-1:1 
    if haskey(ctx.scopes[i], name) 
      return i
    end
  end
  return nothing;
end


















