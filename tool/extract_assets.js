const fs = require('fs');
const path = require('path');

const html = fs.readFileSync(
  path.join(__dirname, '../../frontend/public/index.html'),
  'utf8',
);

const heroMatch = html.match(/const HERO_IMG = "(data:image\/jpeg;base64,[^"]+)"/);
if (heroMatch) {
  const b64 = heroMatch[1].split(',')[1];
  const out = path.join(__dirname, '../assets/images');
  fs.mkdirSync(out, { recursive: true });
  fs.writeFileSync(path.join(out, 'hero.jpg'), Buffer.from(b64, 'base64'));
  console.log('hero.jpg written', Buffer.from(b64, 'base64').length);
}

const coinMatch = html.match(/const COIN_SVG = (\{[\s\S]*?\n\});/);
if (coinMatch) {
  const outDir = path.join(__dirname, '../assets/coins');
  fs.mkdirSync(outDir, { recursive: true });
  const objCode = coinMatch[1];
  // eslint-disable-next-line no-eval
  const coins = eval('(' + objCode + ')');
  for (const [symbol, inner] of Object.entries(coins)) {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">${inner}</svg>`;
    fs.writeFileSync(path.join(outDir, `${symbol}.svg`), svg);
  }
  console.log('coins written', Object.keys(coins).length);
}
