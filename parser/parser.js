const fs = require("fs");
const path = require("path");
const parser = require("./jaz.js").parser;

function compile(srcFile) {
  const fullFileName = srcFile;
  const fullFilePath = path.dirname(fullFileName);
  const src = fs.readFileSync(fullFileName, "utf8");
  const ast = parser.parse(src);
  return ast;
}


console.log(JSON.stringify(compile(process.argv[2])));