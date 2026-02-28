import fs from 'fs/promises';
import path from 'path';

const ROOT = process.cwd();
const LIB_DIR = path.join(ROOT, 'lib');
const OUT_DIR = path.join(ROOT, 'assets', 'translations');
const OUT_FILE = path.join(OUT_DIR, 'pretranslated_labels.json');

const TARGET_LANGS = ['hi', 'mr', 'gu', 'bn', 'ta'];

async function walk(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = [];
  for (const e of entries) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) files.push(...await walk(p));
    else if (e.isFile() && p.endsWith('.dart')) files.push(p);
  }
  return files;
}

function extractStrings(content) {
  const out = [];
  const patterns = [
    /translate\(\s*'([^'\\]*(?:\\.[^'\\]*)*)'\s*\)/g,
    /translate\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*\)/g,
    /registerTranslation\([^,]+,\s*'([^'\\]*(?:\\.[^'\\]*)*)'\s*\)/g,
    /registerTranslation\([^,]+,\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*\)/g,
  ];

  for (const re of patterns) {
    let m;
    while ((m = re.exec(content)) !== null) {
      const s = m[1]?.trim();
      if (!s) continue;
      if (s.includes('${') || s.includes('$')) continue;
      out.push(s.replace(/\\n/g, ' ').replace(/\\t/g, ' ').trim());
    }
  }
  return out;
}

async function translate(text, target) {
  const url = new URL('https://translate.googleapis.com/translate_a/single');
  url.searchParams.set('client', 'gtx');
  url.searchParams.set('sl', 'en');
  url.searchParams.set('tl', target);
  url.searchParams.set('dt', 't');
  url.searchParams.set('q', text);

  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  const translated = (data?.[0] || []).map((seg) => seg?.[0] || '').join('').trim();
  return translated || text;
}

async function runWithConcurrency(tasks, concurrency = 6) {
  let idx = 0;
  const workers = new Array(concurrency).fill(0).map(async () => {
    while (idx < tasks.length) {
      const i = idx++;
      await tasks[i]();
    }
  });
  await Promise.all(workers);
}

async function main() {
  await fs.mkdir(OUT_DIR, { recursive: true });

  const files = await walk(LIB_DIR);
  const all = new Set();

  for (const f of files) {
    const c = await fs.readFile(f, 'utf8');
    for (const s of extractStrings(c)) {
      if (s.length < 2) continue;
      all.add(s);
    }
  }

  let existing = {};
  try {
    existing = JSON.parse(await fs.readFile(OUT_FILE, 'utf8'));
  } catch {}

  const texts = [...all].sort((a, b) => a.localeCompare(b));
  for (const t of texts) {
    if (!existing[t]) existing[t] = { en: t };
    else if (!existing[t].en) existing[t].en = t;
  }

  const tasks = [];
  for (const text of texts) {
    for (const lang of TARGET_LANGS) {
      if (existing[text]?.[lang]) continue;
      tasks.push(async () => {
        try {
          const tr = await translate(text, lang);
          existing[text][lang] = tr;
        } catch {
          existing[text][lang] = text;
        }
      });
    }
  }

  console.log(`Found ${texts.length} unique static labels. Translating ${tasks.length} pending entries...`);
  await runWithConcurrency(tasks, 8);

  const ordered = Object.fromEntries(Object.entries(existing).sort(([a], [b]) => a.localeCompare(b)));
  await fs.writeFile(OUT_FILE, JSON.stringify(ordered, null, 2));

  console.log(`Wrote ${OUT_FILE}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
