/* ── 金庸群侠传 Web MUD — 主线程 (UI only) ── */
(function() {
    'use strict';

    /* ── 1. xterm.js ── */
    const term = new Terminal({
        cursorBlink: true,
        convertEol: true,
        fontSize: 14,
        fontFamily: "'Courier New', 'Noto Sans SC', monospace",
        theme: {
            background: '#0a0a0a',
            foreground: '#c0c0c0',
            cursor: '#0f0',
            cursorAccent: '#000',
            selectionBackground: '#335',
            black: '#000000',
            red: '#cc4444',
            green: '#44cc44',
            yellow: '#cccc44',
            blue: '#4444cc',
            magenta: '#cc44cc',
            cyan: '#44cccc',
            white: '#c0c0c0',
        },
    });
    term.open(document.getElementById('terminal'));
    window.__xterm = term;

    /* ── 1b. FitAddon for auto-resize ── */
    const fitAddon = new FitAddon.FitAddon();
    term.loadAddon(fitAddon);
    fitAddon.fit();
    window.addEventListener('resize', () => fitAddon.fit());

    /* ── 2. Input ── */
    const commandInput = document.getElementById('command-input');
    let workerReady = false;
    let worker = null;

    commandInput.addEventListener('keydown', function(e) {
        if (e.key === 'Enter') {
            const text = this.value.trim();
            this.value = '';
            if (text) {
                term.write('\r\n> ' + text + '\r\n');
                if (worker && workerReady) {
                    worker.postMessage({ type: 'input', data: text });
                }
            }
        }
    });

    document.addEventListener('keydown', function(e) {
        if (document.activeElement !== commandInput) {
            commandInput.focus();
        }
    });

    /* ── 3. IndexedDB storage ── */
    let dbInstance = null;
    const DB_NAME = 'jyLegendWebMud';
    const DB_VERSION = 1;
    const STORE_NAME = 'saves';
    const saveCache = {};

    function openDatabase() {
        return new Promise((resolve, reject) => {
            const req = indexedDB.open(DB_NAME, DB_VERSION);
            req.onupgradeneeded = function(e) {
                const db = e.target.result;
                if (!db.objectStoreNames.contains(STORE_NAME)) {
                    db.createObjectStore(STORE_NAME, { keyPath: 'key' });
                }
            };
            req.onsuccess = function(e) {
                dbInstance = e.target.result;
                resolve();
            };
            req.onerror = function(e) {
                reject(e.target.error);
            };
        });
    }

    async function loadAllSavesToCache() {
        if (!dbInstance) return;
        const tx = dbInstance.transaction(STORE_NAME, 'readonly');
        const store = tx.objectStore(STORE_NAME);
        return new Promise((resolve) => {
            const req = store.getAll();
            req.onsuccess = function() {
                for (const record of req.result) {
                    saveCache[record.key] = record.value;
                }
                resolve();
            };
            req.onerror = function() {
                resolve();
            };
        });
    }

    function dbSave(key, value) {
        saveCache[key] = value;
        if (!dbInstance) return;
        const tx = dbInstance.transaction(STORE_NAME, 'readwrite');
        const store = tx.objectStore(STORE_NAME);
        store.put({ key, value });
    }

    function dbLoad(key) {
        return saveCache[key] !== undefined ? saveCache[key] : null;
    }

    function dbDelete(key) {
        delete saveCache[key];
        if (!dbInstance) return;
        const tx = dbInstance.transaction(STORE_NAME, 'readwrite');
        const store = tx.objectStore(STORE_NAME);
        store.delete(key);
    }

    function dbListKeys() {
        return Object.keys(saveCache);
    }

    /* ── 4. Worker 启动与通信 ── */
    async function startWorker() {
        worker = new Worker('worker.js');

        worker.onmessage = function(e) {
            const msg = e.data;

            if (msg.type === 'output') {
                term.write(msg.text);
            } else if (msg.type === 'log') {
                // 加载日志直接输出到终端
                term.write(msg.text + '\r\n');
            } else if (msg.type === 'error') {
                term.write('\r\n\x1b[31m[worker error] ' + msg.text + '\x1b[0m\r\n');
            } else if (msg.type === 'worker_ready') {
                // Worker 就绪，开始发送初始化数据
                sendInitData();
            } else if (msg.type === 'ready') {
                workerReady = true;
                window.__workerReady = true;
                // 由主线程直接输出开始菜单和欢迎辞，避免 Worker 消息队列延迟
                term.write('欢迎来到金庸群侠传 Web MUD 文字版！\r\n');
                term.write('\r\n');
                term.write('\x1b[32mSystem ready. Type help to start.\x1b[0m\r\n');
                term.write('1. 重新开始\r\n');
                term.write('2. 载入进度\r\n');
                term.write('3. 离开游戏\r\n');
                term.write('输入 choose 1 开始新游戏，choose 2 载入进度，choose 3 离开\r\n');
            } else if (msg.type === 'db_save') {
                dbSave(msg.key, msg.value);
            } else if (msg.type === 'db_load') {
                const value = dbLoad(msg.key);
                worker.postMessage({ type: 'db_result', key: msg.key, value: value });
            } else if (msg.type === 'db_delete') {
                dbDelete(msg.key);
            } else if (msg.type === 'db_list') {
                const keys = dbListKeys();
                worker.postMessage({ type: 'db_result', key: '__list', value: keys });
            } else if (msg.type === 'lua_result') {
                // 透传给等待的 luaEval 调用方
                if (luaEvalCallbacks[msg.id]) {
                    luaEvalCallbacks[msg.id](msg);
                    delete luaEvalCallbacks[msg.id];
                }
            }
        };
    }

    // luaEval 回调注册表
    let luaEvalIdCounter = 0;
    const luaEvalCallbacks = {};

    // 向 Worker 发送 Lua 代码执行请求，返回 Promise
    window.__luaEval = function(code) {
        return new Promise((resolve) => {
            const id = ++luaEvalIdCounter;
            luaEvalCallbacks[id] = (msg) => resolve(msg);
            worker.postMessage({ type: 'lua_eval', id: id, code: code });
        });
    };

    /* ── 5. 向 Worker 发送初始化数据（单条批量消息） ── */

    // 模块清单
    const frameworkFiles = [
        'framework/coroutine_scheduler.lua',
        'framework/state_machine.lua',
        'framework/input_manager.lua',
        'framework/game_states.lua',
        'framework/event_bridge.lua',
        'framework/event_executor.lua',
        'framework/menu_async.lua',
        'framework/menu_state_machine.lua',
        'framework/async_dialog.lua',
        'framework/async_message_box.lua',
        'framework/async_globals.lua',
        'framework/async_wrapper.lua',
        'framework/input_async.lua',
        'framework/jymain_adapter.lua',
        'framework/jymain_async.lua',
        'framework/talk_async.lua',
        'framework/war_async.lua',
        'framework/item_async.lua',
        'framework/person_status_async.lua',
        'framework/perf_log.lua',
        'framework/lib_file.lua',
        'framework/lib_Byte.lua',
        'framework/lib_log.lua',
        'framework/luabit.lua',
        'framework/config.lua',
        'framework/script_loader.lua',
    ];

    const engineFiles = [
        'engine_web.lua',
        'data_loader.lua',
        'state_manager.lua',
        'web_game_bridge.lua',
        'web_command_engine.lua',
        'mmap_smap_handlers.lua',
    ];

    const scriptFiles = [
        'script/jymain.lua',
        'script/jyconst.lua',
        'script/jymodify.lua',
    ];

    const dataFilesList = ['dialogues', 'scenes', 'chars', 'items', 'skills', 'entrances', 'wmap', 'config', 'shops'];

    async function sendInitData() {
        term.write('金庸群侠传 Web MUD v0.1\r\n');
        term.write('Loading...\r\n');

        // 收集所有源码
        async function fetchText(path) {
            const resp = await fetch(path);
            return resp.ok ? await resp.text() : null;
        }

        const engine = [];
        for (const path of engineFiles) {
            const source = await fetchText(path);
            if (source) engine.push({ path, source });
        }

        const framework = [];
        for (const fwFile of frameworkFiles) {
            const source = await fetchText(fwFile);
            if (source) {
                const name = fwFile.replace('.lua', '').replace('/', '.');
                framework.push({ name, source });
            }
        }

        const scripts = [];
        for (const sFile of scriptFiles) {
            const source = await fetchText(sFile);
            if (source) scripts.push({ path: sFile, source });
        }

        // IndexedDB
        term.write('Opening IndexedDB...\r\n');
        await openDatabase();
        await loadAllSavesToCache();
        term.write('  IndexedDB: ready (' + Object.keys(saveCache).length + ' cached keys)\r\n');

        // 数据文件
        term.write('Loading game data...\r\n');
        const data = [];
        for (const name of dataFilesList) {
            const json = await fetchText('data-web/' + name + '.json');
            if (json) data.push({ name, json });
        }
        // events 用 fast parse
        const eventsJson = await fetchText('data-web/events.json');

        // 发送批量初始化消息
        worker.postMessage({
            type: 'init_all',
            engine: engine,
            framework: framework,
            scripts: scripts,
            data: data,
            events: eventsJson,
        });
    }

    /* ── 6. 启动 ── */
    startWorker();
})();
