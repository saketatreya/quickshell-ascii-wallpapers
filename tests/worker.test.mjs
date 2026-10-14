import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { once } from 'node:events';
import { setTimeout as delay } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

function worker(t) {
    const child = spawn(process.execPath, [fileURLToPath(new URL('../AsciiWallpaper/runtime/worker.mjs', import.meta.url))]);
    const packets = [], waiters = [];
    let stderr = '';
    child.stderr.on('data', data => { stderr += data; });
    t.after(() => { if (child.exitCode === null) child.kill(); assert.equal(stderr, ''); });
    createInterface({ input: child.stdout }).on('line', line => {
        const packet = JSON.parse(line);
        packets.push(packet);
        for (const waiter of [...waiters]) {
            if (waiter.match(packet)) { waiters.splice(waiters.indexOf(waiter), 1); clearTimeout(waiter.timer); waiter.resolve(packet); }
        }
    });
    function wait(match) {
        return new Promise((resolve, reject) => {
            const waiter = { match, resolve, timer: setTimeout(() => reject(new Error('Worker response timed out')), 5000) };
            waiters.push(waiter);
        });
    }
    let id = 0;
    return { child, packets, wait,
        async command(command) {
            const requestId = ++id;
            const response = wait(packet => packet.requestId === requestId);
            child.stdin.write(JSON.stringify({ ...command, requestId }) + '\n');
            return response;
        }
    };
}

test('worker lifecycle, errors, paused selection, restart-free recovery and EOF shutdown', { timeout: 10000 }, async t => {
    const w = worker(t);
    const ready = await w.wait(p => p.type === 'ready');
    assert.equal(ready.protocol, 1);
    assert.equal(ready.catalog.length, 15);
    const initial = await w.command({ command: 'configure', paused: true, cycling: false });
    assert.equal(initial.type, 'state');
    const count = w.packets.filter(p => p.type === 'frame').length;
    await delay(180);
    assert.equal(w.packets.filter(p => p.type === 'frame').length, count);
    const bad = await w.command({ command: 'configure', speed: 3, scene: 'missing' });
    assert.equal(bad.type, 'command-error');
    const next = await w.command({ command: 'next' });
    assert.equal(next.speed, 1);
    assert.equal(next.paused, true);
    assert.notEqual(next.scene, initial.scene);
    assert.equal((await w.command({ command: 'scene', scene: 'tokyo-rain' })).scene, 'tokyo-rain');
    const resumed = await w.command({ command: 'resume' });
    assert.equal(resumed.paused, false);
    await w.wait(p => p.type === 'frame');
    const exited = once(w.child, 'exit');
    w.child.stdin.end();
    assert.deepEqual(await exited, [0, null]);
});

test('slow consumers apply backpressure and can resume without corrupt JSON', { timeout: 10000 }, async t => {
    const w = worker(t);
    await w.wait(p => p.type === 'ready');
    await w.command({ command: 'configure', fps: 30, cycling: false });
    w.child.stdout.pause();
    await delay(3000);
    const resumed = w.wait(p => p.type === 'frame');
    w.child.stdout.resume();
    await resumed;
    const state = await w.command({ command: 'pause' });
    assert.equal(state.paused, true);
    // At most the pipe and one write are buffered, rather than an unbounded queue.
    assert.ok(state.sequence < 60, 'worker should stop producing while stdout is blocked');
});
