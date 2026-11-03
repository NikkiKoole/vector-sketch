// desound-processor.js — dreamengine's synth (native/desound, built to wasm by build-web.sh)
// in an AudioWorklet: the browser build's stand-in for native/desound/synth-thread.lua.
// The page posts it the calls src/synth-web.lua wrote down, one message per frame:
// { t: Lua's clock, calls: ['hit 60 5 6 300', ...] }. They're applied before the next 128 frames.

// TextDecoder isn't there in every browser's audio worklet scope.
function decodeUTF8(bytes) {
    try {
        return decodeURIComponent(escape(String.fromCharCode(...bytes)));
    } catch (e) {
        return String.fromCharCode(...bytes);
    }
}

class Desound extends AudioWorkletProcessor {
    constructor(options) {
        super();
        const module = new WebAssembly.Module(options.processorOptions.wasm);
        // A standalone wasm asks for a few WASI calls; only printing matters. fd_write must say how
        // much it wrote: answering 0 made the C library retry forever (the engine warns when its
        // request queue overflows, and that froze the audio thread). The text goes to the page.
        const imports = {};
        for (const imp of WebAssembly.Module.imports(module)) {
            imports[imp.module] = imports[imp.module] || {};
            imports[imp.module][imp.name] = () => 0;
        }
        imports.wasi_snapshot_preview1.fd_write = (fd, iovs, count, writtenPtr) => {
            const view = new DataView(this.ex.memory.buffer);
            let text = '';
            let total = 0;
            for (let i = 0; i < count; i++) {
                const ptr = view.getUint32(iovs + i * 8, true);
                const len = view.getUint32(iovs + i * 8 + 4, true);
                text += decodeUTF8(new Uint8Array(this.ex.memory.buffer, ptr, len));
                total += len;
            }
            view.setUint32(writtenPtr, total, true);
            if (text.trim()) this.port.postMessage({ print: text.trim() });
            return 0;
        };
        this.ex = new WebAssembly.Instance(module, imports).exports;
        if (this.ex._initialize) this.ex._initialize();
        this.ex.de_lua_init();
        this.buffer = this.ex.malloc(128 * 2 * 4);
        this.handles = new Map(); // Lua's note handle -> the engine's
        this.offset = null;       // engine clock - Lua clock
        this.pending = [];
        this.quanta = 0;
        this.port.onmessage = (e) => this.pending.push(e.data);
        this.port.postMessage({ ready: true });
    }

    // Lines the clocks up: the engine's time minus Lua's when a frame's calls arrive. It only
    // moves when they drift apart, so the arrival jitter doesn't shake the booked notes.
    sync(luaTime) {
        const offset = this.ex.audio_time() - luaTime;
        if (this.offset === null || Math.abs(offset - this.offset) > 0.08) this.offset = offset;
    }

    apply(message) {
        this.sync(message.t);
        for (const call of message.calls) {
            const parts = call.split(' ');
            const name = parts[0];
            const args = parts.slice(1).map(Number);
            if (name === 'schedule_note_at_flat') { this.noteAt(args); continue; }
            const fn = this.ex[name];
            if (!fn) continue;
            if (name === 'note_on') {
                const luaHandle = args.shift();
                this.handles.set(luaHandle, fn(...args));
            } else if (name.startsWith('note_')) {
                const handle = this.handles.get(args[0]);
                if (handle === undefined) continue;
                args[0] = handle;
                fn(...args);
                if (name === 'note_off') this.handles.delete(args[0]);
            } else if (name === 'schedule_at') {
                args[0] += this.offset;
                fn(...args);
            } else if (name === 'unschedule') { // slot, t1, t2 (t2 <= t1: from t1 on) on Lua's clock
                args[1] += this.offset;
                if (args[2] > 0) args[2] += this.offset;
                fn(...args);
            } else {
                fn(...args);
            }
        }
    }

    // A booked note with extras (slide, accent, macros, its own gain): src/synth.lua sends the NoteOpts
    // fields flat; here they go into a struct in the wasm's memory ({ int glide_ms; float accent,
    // harmonics, timbre, morph, gain; }, 24 bytes). The engine copies them at the call, so one struct
    // does for every note. A wasm without schedule_note_at plays it plainly.
    noteAt(args) {
        const [t, midi, slot, vol, dur, glide, accent, harmonics, timbre, morph, gain] = args;
        if (!this.ex.schedule_note_at) { if (this.ex.schedule_at) this.ex.schedule_at(t + this.offset, midi, slot, vol, dur); return; }
        if (!this.opts) this.opts = this.ex.malloc(24);
        const view = new DataView(this.ex.memory.buffer); // fresh: memory growth replaces the buffer
        view.setInt32(this.opts, glide, true);
        [accent, harmonics, timbre, morph, gain].forEach((v, i) => view.setFloat32(this.opts + 4 + 4 * i, v, true));
        this.ex.schedule_note_at(t + this.offset, midi, slot, vol, dur, this.opts);
    }

    // One frame's calls per 128 samples: the engine's request queue (512) drains as it renders,
    // so a backlog (a stall, the setup) is spread out instead of overflowing it in one go.
    process(inputs, outputs) {
        if (this.pending.length > 0) {
            const message = this.pending.shift();
            try {
                this.apply(message);
            } catch (e) {
                this.port.postMessage({ error: String(e), calls: message.calls.slice(0, 5) });
            }
        }
        if (++this.quanta % 3445 === 0) this.port.postMessage({ alive: this.quanta, time: this.ex.audio_time() }); // ~10 s
        const out = outputs[0];
        const frames = out[0].length;
        this.ex.de_lua_render(this.buffer, frames);
        const samples = new Float32Array(this.ex.memory.buffer, this.buffer, frames * 2);
        const left = out[0];
        const right = out[1] || out[0];
        for (let i = 0; i < frames; i++) {
            left[i] = samples[2 * i];
            right[i] = samples[2 * i + 1];
        }
        return true;
    }
}

registerProcessor('desound', Desound);
