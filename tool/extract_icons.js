const fs = require('fs');
const path = require('path');

const html = fs.readFileSync(
  path.join(__dirname, '../../frontend/public/index.html'),
  'utf8',
);

const iconMatch = html.match(/const PATHS = (\{[\s\S]*?\n\});/);
if (!iconMatch) {
  console.error('ICON not found');
  process.exit(1);
}
const icons = eval('(' + iconMatch[1] + ')');
const outDir = path.join(__dirname, '../assets/icons');
fs.mkdirSync(outDir, { recursive: true });
for (const [name, inner] of Object.entries(icons)) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${inner}</svg>`;
  fs.writeFileSync(path.join(outDir, `${name}.svg`), svg);
}
console.log('icons', Object.keys(icons).length);
