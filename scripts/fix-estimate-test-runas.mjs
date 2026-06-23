import fs from 'fs';

const path = 'force-app/main/default/classes/EstimateCreateControllerTest.cls';
let content = fs.readFileSync(path, 'utf8');
const lines = content.split(/\r?\n/);
const out = [];
let braceDepth = 0;
let inClass = false;
let inMethod = false;
let methodHasRunAs = false;
let runAsOpen = false;

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];

  if (line.match(/^private class EstimateCreateControllerTest/)) {
    inClass = true;
  }

  if (inClass && line.match(/^    static void \w+\(\) \{/)) {
    inMethod = true;
    methodHasRunAs = false;
    runAsOpen = false;
    out.push(line);
    continue;
  }

  if (inMethod && line.includes('System.runAs(ContractTestDataFactory.getAdminUser()) {')) {
    methodHasRunAs = true;
    runAsOpen = true;
    out.push(line);
    continue;
  }

  if (inMethod && line.match(/^    \}$/)) {
    if (runAsOpen) {
      out.push('        }');
      runAsOpen = false;
    }
    out.push(line);
    inMethod = false;
    continue;
  }

  if (inMethod && !methodHasRunAs && line.match(/^        \S/)) {
    out.push('        System.runAs(ContractTestDataFactory.getAdminUser()) {');
    methodHasRunAs = true;
    runAsOpen = true;
    out.push(line);
    continue;
  }

  out.push(line);
}

fs.writeFileSync(path, out.join('\n'));
console.log('Updated', path);
