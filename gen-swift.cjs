const path = require('path');
const fs = require('fs');

// Usage: node gen-swift.cjs <compiled data.js> <output .swift>
const { CATEGORIES } = require(path.resolve(process.argv[2]));
const outPath = process.argv[3];

const esc = (s) => s.replace(/\\/g, '\\\\').replace(/"/g, '\\"');

const lines = [];
lines.push('// Generated from mui-x docs/pages/playground/scratch/kaomoji-picker/data.ts.');
lines.push('// Regenerate with gen-swift.cjs. Do not edit by hand.');
lines.push('');
lines.push('let categoryOrder: [String] = [');
for (const c of CATEGORIES) {
  lines.push(`    "${esc(c.label)}",`);
}
lines.push(']');
lines.push('');
lines.push('let allKaomoji: [Kaomoji] = [');
for (const c of CATEGORIES) {
  for (const item of c.items) {
    const kw = item.keywords.map((k) => `"${esc(k)}"`).join(', ');
    lines.push(
      `    Kaomoji(chars: "${esc(item.chars)}", name: "${esc(item.name)}", keywords: [${kw}], category: "${esc(c.label)}"),`,
    );
  }
}
lines.push(']');
lines.push('');

fs.writeFileSync(outPath, lines.join('\n'));
console.log(`wrote ${outPath}: ${CATEGORIES.reduce((n, c) => n + c.items.length, 0)} kaomoji`);
