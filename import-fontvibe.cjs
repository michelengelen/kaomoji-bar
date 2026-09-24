// Build data/kaomoji.json from the fontvibe-kaomoji "core" tier.
//
// Usage:
//   node import-fontvibe.cjs <core.json> <output kaomoji.json> [--seed <data.js>]
//
// core.json comes from:
//   https://raw.githubusercontent.com/Funovate/fontvibe-kaomoji/main/data/core.json
//
// The script keeps curated entries. It reads them from the existing
// output file, or from a compiled playground data module (--seed).
// Curated entries stay first in their category and keep their names.
const fs = require('fs');
const path = require('path');

const MAX_KEYWORDS = 8;
const MAX_DISPLAY_WIDTH = 28;

const GROUPS = {
  happy: { label: 'Happy', cats: ['happy', 'excited', 'cute', 'uwu', 'wink'] },
  love: { label: 'Love', cats: ['love', 'shy', 'hug'] },
  sad: { label: 'Sad', cats: ['sad', 'hurt', 'sympathy', 'sorry', 'scared'] },
  rage: {
    label: 'Rage',
    cats: ['angry', 'table flip', 'fight', 'rude', 'weapons', 'dissatisfied'],
  },
  surprised: { label: 'Surprised', cats: ['surprised', 'confused', 'doubt', 'facepalm'] },
  greetings: { label: 'Greetings', cats: ['greeting', 'friends'] },
  critters: {
    label: 'Critters',
    cats: ['animals', 'cat', 'bear', 'bunny', 'fish', 'bird', 'pig', 'dog', 'spider'],
  },
  moves: { label: 'Dance & Music', cats: ['dance', 'music', 'running', 'gaming'] },
  cool: { label: 'Cool', cats: ['cool', 'lenny', 'shrug', 'indifferent'] },
  sleepy: { label: 'Sleepy', cats: ['sleepy'] },
  food: { label: 'Food', cats: ['food'] },
  weird: {
    label: 'Weird',
    cats: ['special', 'hiding', 'writing', 'magic', 'sparkle', 'nosebleed', 'bio', 'uncategorized'],
  },
};

const catToGroup = {};
for (const [groupId, group] of Object.entries(GROUPS)) {
  for (const cat of group.cats) {
    catToGroup[cat] = groupId;
  }
}

function cleanKeywords(keywords) {
  const seen = new Set();
  const out = [];
  for (const raw of keywords ?? []) {
    const keyword = String(raw).toLowerCase().trim();
    if (keyword && !seen.has(keyword)) {
      seen.add(keyword);
      out.push(keyword);
    }
  }
  return out.slice(0, MAX_KEYWORDS);
}

/* ---------------------------- read inputs ---------------------------- */

const args = process.argv.slice(2);
const seedIndex = args.indexOf('--seed');
let seedPath = null;
if (seedIndex !== -1) {
  seedPath = args[seedIndex + 1];
  args.splice(seedIndex, 2);
}
const [corePath, outPath] = args;
if (!corePath || !outPath) {
  console.error('usage: node import-fontvibe.cjs <core.json> <output> [--seed <data.js>]');
  process.exit(1);
}

const core = JSON.parse(fs.readFileSync(corePath, 'utf8'));

/* Curated entries: { chars, name, keywords, group } */
let curated = [];
if (seedPath) {
  const { CATEGORIES } = require(path.resolve(seedPath));
  for (const category of CATEGORIES) {
    for (const item of category.items) {
      curated.push({
        chars: item.chars,
        name: item.name,
        keywords: cleanKeywords(item.keywords),
        group: category.id in GROUPS ? category.id : 'weird',
      });
    }
  }
} else if (fs.existsSync(outPath)) {
  const existing = JSON.parse(fs.readFileSync(outPath, 'utf8'));
  for (const category of existing.categories) {
    for (const item of category.items) {
      if (item.curated) {
        curated.push({
          chars: item.chars,
          name: item.name,
          keywords: item.keywords,
          group: category.id,
        });
      }
    }
  }
}

/* -------------------------- index the corpus ------------------------- */

const byText = new Map();
for (const entry of core) {
  const text = entry.text?.trim();
  if (text && !byText.has(text)) {
    byText.set(text, entry);
  }
}

/* A curated entry adopts the corpus category when the corpus knows the
 * kaomoji. Extra corpus keywords are appended. */
for (const item of curated) {
  const entry = byText.get(item.chars);
  if (entry) {
    const group = catToGroup[entry.category];
    if (group) {
      item.group = group;
    }
    item.keywords = cleanKeywords([...item.keywords, ...(entry.keywords?.en ?? [])]);
  }
}

/* ------------------------------- merge ------------------------------- */

const curatedChars = new Set(curated.map((item) => item.chars));
const imported = [];
let skipped = { unusable: 0, wide: 0, duplicate: 0 };

const seenText = new Set();
for (const entry of core) {
  const text = entry.text?.trim();
  const name = entry.names?.en;
  const keywords = cleanKeywords(entry.keywords?.en);
  if (!text || !name || keywords.length < 2) {
    skipped.unusable += 1;
    continue;
  }
  if (entry.display_width > MAX_DISPLAY_WIDTH || /[\r\n]/.test(text)) {
    skipped.wide += 1;
    continue;
  }
  if (seenText.has(text) || curatedChars.has(text)) {
    skipped.duplicate += 1;
    continue;
  }
  seenText.add(text);
  imported.push({
    chars: text,
    name,
    keywords,
    group: catToGroup[entry.category],
    rank: entry.sources?.length ?? 0,
    width: entry.display_width ?? text.length,
  });
}

imported.sort((a, b) => b.rank - a.rank || a.width - b.width || a.chars.localeCompare(b.chars));

/* ------------------------------- output ------------------------------ */

const categories = Object.entries(GROUPS).map(([groupId, group]) => ({
  id: groupId,
  label: group.label,
  items: [
    ...curated
      .filter((item) => item.group === groupId)
      .map(({ chars, name, keywords }) => ({ chars, name, keywords, curated: true })),
    ...imported
      .filter((item) => item.group === groupId)
      .map(({ chars, name, keywords }) => ({ chars, name, keywords })),
  ],
}));

const output = {
  attribution:
    'Dataset derived from fontvibe-kaomoji by Funovate (CC BY 4.0), ' +
    'https://github.com/Funovate/fontvibe-kaomoji',
  categories,
};

fs.mkdirSync(path.dirname(path.resolve(outPath)), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(output, null, 1));

const total = categories.reduce((n, c) => n + c.items.length, 0);
console.log(`wrote ${outPath}: ${total} kaomoji (${curated.length} curated)`);
console.log('per category:', categories.map((c) => `${c.id}:${c.items.length}`).join(' '));
console.log('skipped:', JSON.stringify(skipped));
