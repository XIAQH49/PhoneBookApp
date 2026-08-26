const fs = require('fs');
const logPath = process.argv[2] ?? 'm2_build_raw.log';
let raw = fs.readFileSync(logPath, 'utf8');
let clean = raw.replace(/\x1b\[[0-9;]*m/g, '');
const re = /ArkTS:WARN File:\s*([A-Za-z]:[^:]*?\.ets):(\d+):(\d+)/g;
let m; const map = new Map();
const full = [];
while ((m = re.exec(clean)) !== null) {
  let file = m[1].replace(/[\r\n]+/g, '');
  file = file.replace(/^.*\/entry\//, 'entry/');
  const after = clean.slice(m.index + m[0].length, m.index + m[0].length + 400);
  const line1 = after.split(/\r?\n/)[0];
  const kind = line1.includes('may throw') ? 'maythrow' : line1.includes('deprecated') ? 'deprecated' : 'other';
  if (!map.has(file)) map.set(file, []);
  map.get(file).push(m[2] + ':' + m[3] + ' ' + kind);
  full.push(file + ':' + m[2] + ':' + m[3] + ' ' + kind);
}
let mt = 0, dp = 0, ot = 0;
for (const f of full) { if (f.endsWith('maythrow')) mt++; else if (f.endsWith('deprecated')) dp++; else ot++; }
console.log('total warn:', full.length, '| maythrow:', mt, '| deprecated:', dp, '| other:', ot);
const sorted = [...map.entries()].sort((a,b)=>b[1].length-a[1].length);
for (const [k,v] of sorted) {
  console.log(String(v.length).padStart(4) + '  ' + k);
  console.log('      ' + v.join(', '));
}
