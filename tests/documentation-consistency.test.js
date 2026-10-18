const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

function markdownFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const absolute = path.join(directory, entry.name);
    return entry.isDirectory() ? markdownFiles(absolute) : entry.name.endsWith('.md') ? [absolute] : [];
  });
}

test('documentación: los enlaces Markdown locales apuntan a archivos existentes', () => {
  const failures = [];
  for (const file of markdownFiles(root)) {
    const source = fs.readFileSync(file, 'utf8');
    for (const match of source.matchAll(/\[[^\]]*\]\(([^)]+)\)/g)) {
      let destination = match[1].trim().replace(/^<|>$/g, '');
      if (!destination || /^(?:https?:|mailto:|tel:|data:|#)/i.test(destination)) continue;
      destination = decodeURIComponent(destination.split('#')[0].split('?')[0]);
      if (!destination) continue;
      const target = path.resolve(path.dirname(file), destination);
      if (!fs.existsSync(target)) failures.push(`${path.relative(root, file)} -> ${destination}`);
    }
  }
  assert.deepEqual(failures, [], `Enlaces rotos:\n${failures.join('\n')}`);
});

test('skills: el índice incluye cada skill y los títulos numerados son únicos', () => {
  const skillsDir = path.join(root, 'skills');
  const indexed = fs.readFileSync(path.join(skillsDir, 'README.md'), 'utf8');
  const skillFiles = fs.readdirSync(skillsDir).filter(name => name.endsWith('.md') && name !== 'README.md');
  const missing = skillFiles.filter(name => !indexed.includes(`\`${name}\``));
  const stale = [...indexed.matchAll(/`([\w-]+\.md)`/g)].map(match => match[1]).filter(name => !fs.existsSync(path.join(skillsDir, name)));
  assert.deepEqual(missing, [], `Skills ausentes del índice: ${missing.join(', ')}`);
  assert.deepEqual(stale, [], `Referencias inexistentes en el índice: ${stale.join(', ')}`);

  const ids = [];
  for (const name of skillFiles) {
    const text = fs.readFileSync(path.join(skillsDir, name), 'utf8');
    const match = text.match(/^# Skill (\d+):/m);
    if (match) ids.push([match[1], name]);
  }
  const duplicates = ids.filter(([id], index) => ids.findIndex(([candidate]) => candidate === id) !== index);
  assert.deepEqual(duplicates, [], `IDs de skill duplicados: ${duplicates.map(([id, name]) => `${id} (${name})`).join(', ')}`);
});
