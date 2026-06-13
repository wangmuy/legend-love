(function() {
    'use strict';

    /* ── 1. xterm.js ── */
    const term = new Terminal({
        cursorBlink: true,
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
    window.__xterm = term;  // 暴露给测试框架

    /* ── 1b. FitAddon for auto-resize ── */
    const fitAddon = new FitAddon.FitAddon();
    term.loadAddon(fitAddon);
    fitAddon.fit();
    window.addEventListener('resize', () => fitAddon.fit());

    /* ── 2. Fengari ── */
    const { lua, lauxlib, lualib } = fengari;
    const L = fengari.L;  // pre-created Lua state

    /* ── 3. Event queue & input ── */
    const eventQueue = [];
    const commandInput = document.getElementById('command-input');

    commandInput.addEventListener('keydown', function(e) {
        if (e.key === 'Enter') {
            const text = this.value.trim();
            this.value = '';
            if (text) {
                term.write('\r\n> ' + text + '\r\n');
                eventQueue.push({ type: 'input', data: text });
            }
        }
    });

    document.addEventListener('keydown', function(e) {
        if (document.activeElement !== commandInput) {
            commandInput.focus();
        }
    });

    /* ── 3b. IndexedDB storage ── */
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
        return new Promise((resolve, reject) => {
            const tx = dbInstance.transaction(STORE_NAME, 'readonly');
            const store = tx.objectStore(STORE_NAME);
            const req = store.getAll();
            req.onsuccess = function(e) {
                const records = e.target.result || [];
                for (const rec of records) {
                    saveCache[rec.key] = rec.value;
                }
                resolve();
            };
            req.onerror = function(e) {
                reject(e.target.error);
            };
        });
    }

    function dbSave(key, value) {
        saveCache[key] = value;
        if (!dbInstance) return;
        const tx = dbInstance.transaction(STORE_NAME, 'readwrite');
        const store = tx.objectStore(STORE_NAME);
        store.put({ key: key, value: value });
    }

    function dbLoad(key) {
        return saveCache[key] || null;
    }

    function dbDelete(key) {
        delete saveCache[key];
        if (!dbInstance) return;
        const tx = dbInstance.transaction(STORE_NAME, 'readwrite');
        const store = tx.objectStore(STORE_NAME);
        store.delete(key);
    }

    function dbListKeys() {
        const keys = [];
        for (const k of Object.keys(saveCache)) {
            if (k.startsWith('save_')) keys.push(k);
        }
        return keys.sort();
    }

    /* ── 4. JSBridge injection ── */
    function injectJSBridge() {
        lua.lua_pushstring(L, 'JSBridge');
        lua.lua_newtable(L);

        lua.lua_pushstring(L, 'write');
        lua.lua_pushcfunction(L, function(state) {
            const str = lua.lua_tostring(state, -1);
            term.write(str);
            return 0;
        });
        lua.lua_settable(L, -3);

        lua.lua_pushstring(L, 'getEvent');
        lua.lua_pushcfunction(L, function(state) {
            const ev = eventQueue.shift();
            if (ev) {
                lua.lua_newtable(state);
                lua.lua_pushstring(state, 'type');
                lua.lua_pushstring(state, ev.type);
                lua.lua_settable(state, -3);
                lua.lua_pushstring(state, 'data');
                lua.lua_pushstring(state, ev.data);
                lua.lua_settable(state, -3);
                return 1;
            }
            lua.lua_pushnil(state);
            return 1;
        });
        lua.lua_settable(L, -3);

        lua.lua_pushstring(L, 'getEventCount');
        lua.lua_pushcfunction(L, function(state) {
            lua.lua_pushnumber(state, eventQueue.length);
            return 1;
        });
        lua.lua_settable(L, -3);

        lua.lua_pushstring(L, 'save');
        lua.lua_pushcfunction(L, function(state) {
            const key = fengari.to_jsstring(lua.lua_tolstring(state, 1));
            const val = fengari.to_jsstring(lua.lua_tolstring(state, 2));
            dbSave(key, val);
            return 0;
        });
        lua.lua_settable(L, -3);

        lua.lua_pushstring(L, 'load');
        lua.lua_pushcfunction(L, function(state) {
            const key = fengari.to_jsstring(lua.lua_tolstring(state, 1));
            const val = dbLoad(key);
            if (val !== null) {
                lua.lua_pushstring(state, val);
            } else {
                lua.lua_pushnil(state);
            }
            return 1;
        });
        lua.lua_settable(L, -3);

        lua.lua_pushstring(L, 'delete');
        lua.lua_pushcfunction(L, function(state) {
            const key = fengari.to_jsstring(lua.lua_tolstring(state, 1));
            dbDelete(key);
            return 0;
        });
        lua.lua_settable(L, -3);

        lua.lua_pushstring(L, 'listSaves');
        lua.lua_pushcfunction(L, function(state) {
            const keys = dbListKeys();
            lua.lua_newtable(state);
            for (let i = 0; i < keys.length; i++) {
                lua.lua_pushstring(state, keys[i]);
                lua.lua_rawseti(state, -2, i + 1);
            }
            return 1;
        });
        lua.lua_settable(L, -3);

        lua.lua_setglobal(L, 'JSBridge');
    }

    /* ── 5. Lua module loader ── */
    function loadLuaModule(path, source) {
        const fn = fengari.load(source, path);
        fn(L);
    }

    /* ── 5b. JS-to-Lua value converter ── */
    function pushJsValue(state, val) {
        const lua = fengari.lua;
        if (val === null || val === undefined) {
            lua.lua_pushnil(state);
        } else if (typeof val === 'boolean') {
            lua.lua_pushboolean(state, val);
        } else if (typeof val === 'number') {
            lua.lua_pushnumber(state, val);
        } else if (typeof val === 'string') {
            lua.lua_pushstring(state, val);
        } else if (Array.isArray(val)) {
            lua.lua_newtable(state);
            for (let i = 0; i < val.length; i++) {
                pushJsValue(state, val[i]);
                lua.lua_rawseti(state, -2, i + 1);
            }
        } else if (typeof val === 'object') {
            lua.lua_newtable(state);
            for (const key of Object.keys(val)) {
                lua.lua_pushstring(state, key);
                pushJsValue(state, val[key]);
                lua.lua_settable(state, -3);
            }
        }
    }

    function injectParsedJson(cacheKey, jsonString) {
        const obj = JSON.parse(jsonString);
        lua.lua_getglobal(L, 'dataCache');
        lua.lua_pushstring(L, cacheKey);
        pushJsValue(L, obj);
        lua.lua_settable(L, -3);
        lua.lua_pop(L, 1);
    }

    /* ── 6. Data files ── */
    const dataFiles = {};
    async function loadDataFiles() {
        const files = ['dialogues', 'scenes', 'chars', 'items', 'skills', 'entrances', 'wmap', 'events', 'config', 'shops'];
        for (const name of files) {
            const response = await fetch('data-web/' + name + '.json');
            const text = await response.text();
            dataFiles[name] = text;
            dataFiles['data-web/' + name + '.json'] = text;
        }
    }

    /* ── 7. Bootstrap ── */
    async function bootstrap() {
        term.write('金庸群侠传 Web MUD v0.1\r\n');
        term.write('Loading Lua VM...\r\n');

        injectJSBridge();
        term.write('  JSBridge: ready\r\n');

        term.write('Loading engine_web.lua...\r\n');
        const engineResp = await fetch('engine_web.lua');
        const engineSource = await engineResp.text();
        await loadLuaModule('engine_web.lua', engineSource);
        term.write('  EngineAPI: ready\r\n');

        term.write('Loading data_loader.lua...\r\n');
        const loaderResp = await fetch('data_loader.lua');
        const loaderSource = await loaderResp.text();
        await loadLuaModule('data_loader.lua', loaderSource);
        term.write('  Data loader: ready\r\n');

        term.write('Loading state_manager.lua...\r\n');
        const stateResp = await fetch('state_manager.lua');
        const stateSource = await stateResp.text();
        await loadLuaModule('state_manager.lua', stateSource);
        term.write('  State manager: ready\r\n');

        term.write('Loading web_game_bridge.lua...\r\n');
        const bridgeResp = await fetch('web_game_bridge.lua');
        const bridgeSource = await bridgeResp.text();
        await loadLuaModule('web_game_bridge.lua', bridgeSource);
        term.write('  Web game bridge: ready\r\n');

        term.write('Loading framework modules...\r\n');
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
        const frameworkSources = {};
        for (const fwFile of frameworkFiles) {
            try {
                const resp = await fetch(fwFile);
                if (resp.ok) {
                    frameworkSources[fwFile.replace('.lua', '').replace('/', '.')] = await resp.text();
                }
            } catch (e) {
                term.write('  [WARN] ' + fwFile + ' not found\r\n');
            }
        }

        // Register all framework modules in package.preload
        for (const [name, source] of Object.entries(frameworkSources)) {
            lua.lua_getglobal(L, 'registerFrameworkModule');
            lua.lua_pushstring(L, name);
            lua.lua_pushstring(L, source);
            lua.lua_pcall(L, 2, 0, 0);
        }
        term.write('  Framework modules: ' + Object.keys(frameworkSources).length + ' registered\r\n');

        term.write('Loading game scripts...\r\n');
        const scriptFiles = [
            'script/jymain.lua',
            'script/jyconst.lua',
            'script/jymodify.lua',
        ];
        const scriptSources = {};
        for (const sFile of scriptFiles) {
            try {
                const resp = await fetch(sFile);
                if (resp.ok) {
                    const src = await resp.text();
                    // Register as framework source but NOT via package.preload (scripts don't use require)
                    lua.lua_getglobal(L, 'FrameworkSources');
                    lua.lua_pushstring(L, sFile);
                    lua.lua_pushstring(L, src);
                    lua.lua_settable(L, -3);
                    lua.lua_pop(L, 1);
                    scriptSources[sFile] = src;
                }
            } catch (e) {
                term.write('  [WARN] ' + sFile + ' not found\r\n');
            }
        }
        term.write('  Game scripts: ' + Object.keys(scriptSources).length + ' loaded\r\n');

        term.write('Opening IndexedDB...\r\n');
        await openDatabase();
        await loadAllSavesToCache();
        term.write('  IndexedDB: ready (' + Object.keys(saveCache).length + ' cached keys)\r\n');

        term.write('Loading game data...\r\n');
        await loadDataFiles();

        const fileList = ['dialogues', 'scenes', 'chars', 'items', 'skills', 'entrances', 'wmap', 'config', 'shops'];
        const fastParse = ['events'];
        for (const name of fileList) {
            lua.lua_getglobal(L, 'loadJSON');
            lua.lua_pushstring(L, name);
            lua.lua_pushstring(L, dataFiles[name]);
            if (lua.lua_pcall(L, 2, 1, 0) !== 0) {
                const err = lua.lua_tostring(L, -1);
                lua.lua_pop(L, 1);
                term.write('  ' + name + ': FAILED (' + err + ')\r\n');
            } else {
                const ok = lua.lua_toboolean(L, -1);
                lua.lua_pop(L, 1);
                term.write('  ' + name + ': ' + (ok ? 'OK' : 'FAILED') + '\r\n');
            }
        }
        for (const name of fastParse) {
            term.write('  ' + name + ': parsing...\r\n');
            injectParsedJson(name, dataFiles[name]);
            term.write('  ' + name + ': OK\r\n');
        }

        lua.lua_getglobal(L, 'finalizeDataLoad');
        lua.lua_pcall(L, 0, 0, 0);

        term.write('\r\nInitializing game framework...\r\n');
        lua.lua_getglobal(L, 'initWebFramework');
        lua.lua_pcall(L, 0, 0, 0);

        term.write('\r\n');
        term.write('\x1b[32mSystem ready. Type help to start.\x1b[0m\r\n');

        requestAnimationFrame(gameLoop);
    }

    /* ── 8. Game loop ── */
    function gameLoop(timestamp) {
        lua.lua_getglobal(L, 'processEventQueue');
        if (lua.lua_type(L, -1) === lua.LUA_TFUNCTION) {
            lua.lua_pushnumber(L, timestamp);
            const result = lua.lua_pcall(L, 1, 0, 0);
            if (result !== 0) {
                const err = lua.lua_tostring(L, -1);
                lua.lua_pop(L, 1);
                term.write('\x1b[31m[gameLoop error] ' + (err || '?') + '\x1b[0m\r\n');
            }
        } else {
            lua.lua_pop(L, 1);
        }

        requestAnimationFrame(gameLoop);
    }

    /* ── 9. Start ── */
    bootstrap().catch(function(err) {
        term.write('\r\n\x1b[31mBootstrap failed: ' + err.message + '\x1b[0m\r\n');
    });

})();
