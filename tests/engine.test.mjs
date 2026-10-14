import test from 'node:test';
import assert from 'node:assert/strict';
import { inflateSync } from 'node:zlib';
import { access, readFile } from 'node:fs/promises';
import { SceneEngine } from '../AsciiWallpaper/runtime/engine.mjs';

function decode(data) {
    const png = Buffer.from(data.split(',')[1], 'base64');
    assert.deepEqual([...png.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
    const width = png.readUInt32BE(16), height = png.readUInt32BE(20);
    assert.equal(png[24], 8); assert.equal(png[25], 6);
    const chunks = [];
    for (let offset = 8; offset < png.length;) {
        const length = png.readUInt32BE(offset);
        if (png.toString('ascii', offset + 4, offset + 8) === 'IDAT') chunks.push(png.subarray(offset + 8, offset + 8 + length));
        offset += length + 12;
    }
    return { width, height, pixels: inflateSync(Buffer.concat(chunks)) };
}

test('all 15 scenes produce complete indexed frames, palettes, and have still fallbacks', async () => {
    const engine = await SceneEngine.create();
    assert.equal(engine.catalog.length, 15);
    for (const entry of engine.catalog) {
        engine.select(entry.slug);
        for (const time of [3, 19]) {
            engine.time = time;
            const frame = engine.frame();
            assert.equal(frame.revision, engine.metadata().revision);
            const { width, height, pixels } = decode(frame.grid);
            assert.equal(width, 200); assert.equal(height, 100);
            assert.equal(pixels.length, (width * 4 + 1) * height);
            let drawn = 0;
            for (let y = 0; y < height; y++) {
                assert.equal(pixels[y * 801], 0);
                for (let x = 0; x < width; x++) {
                    const i = y * 801 + 1 + x * 4;
                    assert.ok(pixels[i] <= 3);
                    assert.ok(pixels[i + 1] < engine.meta.palette.length);
                    assert.equal(pixels[i + 3], 255);
                    drawn += pixels[i] > 0;
                }
            }
            assert.ok(drawn > 500, entry.slug);
        }
        const palette = decode(engine.metadata().palette);
        assert.equal(palette.width, 64); assert.equal(palette.height, 1);
        await access(new URL(`../AsciiWallpaper/assets/stills/${entry.slug}.png`, import.meta.url));
    }
});

test('speed changes scene time; pause freezes both animation and cycling', async () => {
    const engine = await SceneEngine.create();
    engine.configure({ speed: 2, cycling: false });
    engine.advance(1.5);
    assert.equal(engine.time, 6);
    engine.configure({ paused: true, cycling: true, cycleSeconds: 1 });
    const before = engine.status();
    engine.advance(90);
    assert.deepEqual(engine.status(), before);
});

test('cycle all scenes and restrict navigation to an ordered playlist', async () => {
    const engine = await SceneEngine.create();
    engine.configure({ scene: engine.catalog[0].slug, cycleSeconds: 1, speed: 4 });
    const visited = [];
    for (let i = 0; i < 15; i++) {
        visited.push(engine.options.scene);
        assert.equal(engine.advance(1), true);
    }
    assert.deepEqual(visited, engine.catalog.map(scene => scene.slug));
    assert.equal(engine.options.scene, engine.catalog[0].slug);
    engine.configure({ playlist: ['tokyo-rain', 'aurora-fjord', 'tokyo-rain'] });
    engine.next(); assert.equal(engine.options.scene, 'tokyo-rain');
    engine.next(-1); assert.equal(engine.options.scene, 'aurora-fjord');
    engine.next(); assert.equal(engine.options.scene, 'tokyo-rain');
});

test('invalid configuration is rejected atomically', async () => {
    const engine = await SceneEngine.create();
    const before = engine.status();
    for (const input of [{ speed: 2, scene: '../secret' }, { fps: NaN }, { speed: 0 },
        { paused: 'yes' }, { playlist: ['missing'] }, { cycleSeconds: 0 }, { fps: 31 }]) {
        assert.throws(() => engine.configure(input));
        assert.deepEqual(engine.status(), before);
    }
    assert.throws(() => engine.select('missing'));
    assert.deepEqual(engine.status(), before);
});

test('the drop-in module carries upstream provenance and licenses', async () => {
    const root = new URL('../AsciiWallpaper/', import.meta.url);
    const provenance = JSON.parse(await readFile(new URL('scenes/provenance.json', root)));
    assert.match(provenance.commit, /^[0-9a-f]{40}$/);
    assert.match(await readFile(new URL('scenes/LICENSE', root), 'utf8'), /Copyright.*bas3line/);
    await access(new URL('assets/scene.frag.qsb', root));
});
