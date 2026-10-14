import { SceneEngine } from '../AsciiWallpaper/runtime/engine.mjs';

const engine = await SceneEngine.create();
const slug = process.argv[2] || 'night-coast';
const time = Number(process.argv[3] || 3);
if (!Number.isFinite(time)) throw new Error('Expected a finite scene time');
engine.select(slug);
engine.time = time;
console.log(JSON.stringify({ ...engine.metadata(), ...engine.frame(), colors: engine.meta.palette }));
