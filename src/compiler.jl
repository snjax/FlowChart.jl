push!(LOAD_PATH, @__DIR__)

using NodeJS, FF
import JSON
import BitIntegers: UInt256, @uint256_str


include("exec.jl")

path = nodejs_cmd()


function parse(src::String)
  astRep = read(Cmd([nodejs_cmd().exec[1], "parser/parser.js", src]), String);
  return JSON.parse(astRep)
end

function compile(srcFile)
  ast = parse(srcFile)
  @assert ast["type"]=="BLOCK" "ast.type must be BLOCK"
  ctx = Ctx()
  exec!(ctx, ast)
end


compile("localtests/circuit.circom");