import { createInterface } from 'node:readline';
import { SceneEngine } from './engine.mjs';

const engine = await SceneEngine.create();
let configured = false, blocked = false, timer, last = performance.now(), lastHeartbeat = 0;

function send(packet) {
    if (!process.stdout.write(JSON.stringify(packet) + '\n')) blocked = true;
}
process.stdout.on('drain', () => { blocked = false; });
process.stdout.on('error', error => {
    if (error.code === 'EPIPE') process.exit(0);
    throw error;
});

function tick() {
    const start = performance.now();
    const delta = Math.min(2, (start - last) / 1000);
    last = start;
    if (!blocked) {
        try {
            if (configured && !engine.options.paused) {
                if (engine.advance(delta)) send(engine.metadata());
                send(engine.frame());
            }
            if (start - lastHeartbeat >= 1000) {
                send({ type: 'heartbeat' });
                lastHeartbeat = start;
            }
        } catch (error) {
            send({ type: 'error', message: error.message });
            process.exitCode = 1;
            input.close();
            return;
        }
    }
    timer = setTimeout(tick, Math.max(1,
        (configured && !engine.options.paused ? 1000 / engine.options.fps : 1000) - (performance.now() - start)));
}

const input = createInterface({ input: process.stdin });
input.on('line', line => {
    let request;
    try {
        if (line.length > 65536) throw new Error('Command too long');
        request = JSON.parse(line);
        if (!request || typeof request !== 'object' || Array.isArray(request)) throw new Error('Expected an object');
        if (!configured && request.command !== 'configure') throw new Error('Configure the worker first');
        const revision = engine.revision;
        switch (request.command) {
        case 'configure': engine.configure(request); break;
        case 'next': engine.next(); break;
        case 'previous': engine.next(-1); break;
        case 'scene': engine.select(request.scene); break;
        case 'pause': engine.configure({ paused: true }); break;
        case 'resume': engine.configure({ paused: false }); break;
        default: throw new Error('Unknown command');
        }
        if (!configured || revision !== engine.revision) send(engine.metadata());
        configured = true;
        send(engine.frame());
        send({ ...engine.status(), requestId: request.requestId });
        // Resume immediately instead of waiting for the paused one-second timer.
        clearTimeout(timer);
        last = performance.now();
        timer = setTimeout(tick, 1000 / engine.options.fps);
    } catch (error) {
        send({ type: 'command-error', message: error.message, requestId: request?.requestId });
    }
});
input.on('close', () => { clearTimeout(timer); process.exit(process.exitCode || 0); });
send({ type: 'ready', protocol: 1, catalog: engine.catalog });
tick();
