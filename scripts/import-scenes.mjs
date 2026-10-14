// Development only. Import scene algorithms from an explicitly supplied checkout.
import { stripTypeScriptTypes } from 'node:module';
import { readFile, readdir, writeFile, copyFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { execFileSync } from 'node:child_process';

if (!process.argv[2]) throw new Error('Usage: node scripts/import-scenes.mjs /path/to/bas3line/ascii');
const upstream = resolve(process.argv[2]);
const out = new URL('../AsciiWallpaper/scenes/', import.meta.url);
const catalog = [];
for (const file of (await readdir(resolve(upstream, 'src/pieces'))).sort()) {
    if (!file.endsWith('.ts')) continue;
    const source = await readFile(resolve(upstream, 'src/pieces', file), 'utf8');
    if (!/category:\s*"scenes"/.test(source)) continue;
    const slug = file.slice(0, -3);
    const target = new URL(slug + '.mjs', out);
    const code = stripTypeScriptTypes(source).split('\n').map(line => line.trimEnd()).join('\n');
    await writeFile(target, '// ascii.rest by bas3line, MIT. See LICENSE.\n' + code);
    const { meta } = await import(target);
    catalog.push({ slug, name: meta.name, note: meta.note, cols: meta.cols, rows: meta.rows, ground: meta.ground });
}
await writeFile(new URL('catalog.json', out), JSON.stringify(catalog, null, 2) + '\n');
await copyFile(resolve(upstream, 'LICENSE'), new URL('LICENSE', out));
await writeFile(new URL('provenance.json', out), JSON.stringify({
    repository: 'https://github.com/bas3line/ascii',
    commit: execFileSync('git', ['-C', upstream, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(),
    license: 'MIT', conversion: 'TypeScript types stripped; scene algorithms unchanged',
    glyphs: 'Noto Sans Mono, rasterized into a four-glyph atlas',
}, null, 2) + '\n');
console.log(`Imported ${catalog.length} scenes. Run scripts/build-assets.py and npm test.`);
