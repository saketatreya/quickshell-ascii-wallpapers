import { readFile } from 'node:fs/promises';
import { dataUrl } from './png.mjs';

const glyphs = new Map([[' ', 0], ['·', 1], ['•', 2], ['●', 3]]);
const defaults = { scene: 'night-coast', fps: 15, speed: 1, cycling: true,
    cycleSeconds: 300, paused: false, playlist: [] };

export class SceneEngine {
    static async create() {
        const catalog = JSON.parse(await readFile(new URL('../scenes/catalog.json', import.meta.url)));
        const scenes = new Map(await Promise.all(catalog.map(async entry => {
            if (!/^[a-z0-9-]+$/.test(entry.slug)) throw new Error('Invalid catalog slug');
            return [entry.slug, await import(`../scenes/${entry.slug}.mjs`)];
        })));
        return new SceneEngine(catalog, scenes);
    }

    constructor(catalog, scenes) {
        this.catalog = catalog;
        this.scenes = scenes;
        this.options = { ...defaults, playlist: [] };
        this.sequence = 0;
        this.revision = 0;
        this.select(defaults.scene);
    }

    configure(input) {
        // Validate the entire request before changing any live state.
        const next = { ...this.options };
        for (const [key, min, max] of [['fps', 1, 30], ['speed', 0.1, 4], ['cycleSeconds', 0.1, 86400]]) {
            if (!(key in input)) continue;
            if (!Number.isFinite(input[key]) || input[key] < min || input[key] > max)
                throw new Error(`${key} must be between ${min} and ${max}`);
            next[key] = input[key];
        }
        for (const key of ['paused', 'cycling']) {
            if (!(key in input)) continue;
            if (typeof input[key] !== 'boolean') throw new Error(`${key} must be a boolean`);
            next[key] = input[key];
        }
        if ('scene' in input) {
            if (!this.scenes.has(input.scene)) throw new Error(`Unknown scene: ${input.scene}`);
            next.scene = input.scene;
        }
        if ('playlist' in input) {
            if (!Array.isArray(input.playlist) || input.playlist.some(slug => !this.scenes.has(slug)))
                throw new Error('playlist must be an array of known scene slugs');
            next.playlist = [...new Set(input.playlist)];
        }
        const changed = next.scene !== this.options.scene;
        this.options = next;
        if (changed) this.select(next.scene);
        return changed;
    }

    select(slug) {
        const piece = this.scenes.get(slug);
        if (!piece) throw new Error(`Unknown scene: ${slug}`);
        const { meta } = piece;
        if (meta.cols !== 200 || meta.rows !== 100 || meta.palette.length > 64)
            throw new Error('Scenes must use a 200×100 grid and at most 64 palette colors');
        this.options.scene = slug;
        this.meta = meta;
        this.draw = piece.default();
        this.colors = new Uint8Array(meta.cols * meta.rows);
        this.pixels = new Uint8Array(this.colors.length * 4);
        this.time = 3;
        this.elapsed = 0;
        this.revision++;
        const palette = new Uint8Array(64 * 4);
        for (let i = 0; i < 64; i++) {
            const hex = meta.palette[i] || meta.ground;
            if (!/^#[0-9a-f]{6}$/i.test(hex)) throw new Error('Invalid scene color');
            for (let c = 0; c < 3; c++) palette[i * 4 + c] = parseInt(hex.slice(c * 2 + 1, c * 2 + 3), 16);
            palette[i * 4 + 3] = 255;
        }
        this.palette = dataUrl(64, 1, palette);
    }

    next(offset = 1) {
        const list = this.options.playlist.length ? this.options.playlist : this.catalog.map(entry => entry.slug);
        const index = list.indexOf(this.options.scene);
        this.select(list[index < 0 ? (offset > 0 ? 0 : list.length - 1) : (index + offset + list.length) % list.length]);
    }

    advance(seconds) {
        if (this.options.paused) return false;
        this.time += seconds * this.options.speed;
        this.elapsed += seconds;
        if (this.options.cycling && this.elapsed >= this.options.cycleSeconds) {
            this.next();
            return true;
        }
        return false;
    }

    metadata() {
        return { type: 'scene', slug: this.options.scene, name: this.meta.name,
            cols: this.meta.cols, rows: this.meta.rows, ground: this.meta.ground,
            palette: this.palette, revision: this.revision };
    }

    frame() {
        const text = this.draw(this.time, { color: this.colors });
        let cell = 0;
        for (const char of text) {
            if (char === '\n') continue;
            const glyph = glyphs.get(char);
            if (glyph === undefined || cell >= this.colors.length || this.colors[cell] >= this.meta.palette.length)
                throw new Error('Invalid scene character grid or palette index');
            this.pixels[cell * 4] = glyph;
            this.pixels[cell * 4 + 1] = this.colors[cell];
            this.pixels[cell * 4 + 3] = 255;
            cell++;
        }
        if (cell !== this.colors.length) throw new Error('Incomplete scene character grid');
        return { type: 'frame', slug: this.options.scene, revision: this.revision,
            sequence: this.sequence++, grid: dataUrl(this.meta.cols, this.meta.rows, this.pixels) };
    }

    status() {
        return { type: 'state', ...this.options, sceneTime: this.time, sequence: this.sequence };
    }
}
