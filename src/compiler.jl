using NodeJS
using BitIntegers
import JSON

path = nodejs_cmd()


function parse(src::String)
  astRep = read(Cmd([nodejs_cmd().exec[1], "parser/parser.js", src]), String);
  return JSON.parse(astRep)
end

function compile(srcFile)
  ast = parse(srcFile)
  @assert ast["type"]=="BLOCK" "ast.type must be BLOCK"
  println(ast)
end

struct Scope
end

struct Signal
end

struct Constraint
end

struct Ctx
  scopes::Vector{Scope}
  signals::Vector{Signal}
  constraints::Vector{Constraint}
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




compile("localtests/circuit.circom");