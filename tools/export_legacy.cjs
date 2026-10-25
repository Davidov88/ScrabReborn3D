const fs = require('fs');
const vm = require('vm');
const path = require('path');
const sourceRoot = 'G:/projects/game metal man/scrap-reborn/v2';
const ts = require(sourceRoot + '/node_modules/typescript');
const output = {};
for (const name of ['parts','weapons','ammo','levels']) {
  const source = fs.readFileSync(sourceRoot + '/src/game/data/' + name + '.ts','utf8');
  const code = ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
  const context = {exports:{}};
  vm.runInNewContext(code,context);
  output[name]=context.exports;
}
fs.writeFileSync(path.join(__dirname,'legacy-source.json'),JSON.stringify(output,null,2));
console.log('Legacy data exported without modifying source game');
