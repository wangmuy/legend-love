/* ── Web Worker: 金庸群侠传 Web MUD Lua Engine ── */
'use strict';

/* ── 1. 加载 Fengari Lua VM ── */
// Worker 中没有 window，但 fengari-web.js 依赖它。
self.window = self;

self.importScripts(
  'https://cdn.jsdelivr.net/npm/fengari-web@0.1.4/dist/fengari-web.js'
);

const { lua } = fengari;
const L = fengari.L;

/* ── 2. 事件队列（由 onmessage 填充，JSBridge.getEvent 消费） ── */
const eventQueue = [];

/* ── 3. JSBridge ── 通过 postMessage 与主线程通信 ── */
function injectWorkerJSBridge() {
  lua.lua_pushstring(L, 'JSBridge');
  lua.lua_newtable(L);

  lua.lua_pushstring(L, 'write');
  lua.lua_pushcfunction(L, function(state) {
    const str = lua.lua_tostring(state, -1);
    self.postMessage({ type: 'output', text: str + '\n' });
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
    const key = lua.lua_tostring(state, 1);
    const val = lua.lua_tostring(state, 2);
    self.postMessage({ type: 'db_save', key: key, value: val });
    return 0;
  });
  lua.lua_settable(L, -3);

  lua.lua_pushstring(L, 'load');
  lua.lua_pushcfunction(L, function(state) {
    const key = lua.lua_tostring(state, 1);
    self.postMessage({ type: 'db_load', key: key });
    lua.lua_pushnil(state);
    return 1;
  });
  lua.lua_settable(L, -3);

  lua.lua_pushstring(L, 'delete');
  lua.lua_pushcfunction(L, function(state) {
    const key = lua.lua_tostring(state, 1);
    self.postMessage({ type: 'db_delete', key: key });
    return 0;
  });
  lua.lua_settable(L, -3);

  lua.lua_pushstring(L, 'listSaves');
  lua.lua_pushcfunction(L, function(state) {
    self.postMessage({ type: 'db_list' });
    lua.lua_newtable(state);
    return 1;
  });
  lua.lua_settable(L, -3);

  lua.lua_setglobal(L, 'JSBridge');
}

/* ── 4. Lua module loading helpers ── */
function loadLuaModule(path, source) {
  const fn = fengari.load(source, path);
  fn(L);
  // 清理模块返回值（如 return {}），避免 Lua 栈积累
  lua.lua_settop(L, 0);
}

function injectParsedJson(cacheKey, jsonString) {
  // 用 JS JSON.parse 替代 Lua parseJSON（大文件快 100x）
  let parsed;
  try {
    parsed = JSON.parse(jsonString);
  } catch (e) {
    return;
  }
  // 将 JS 对象推入 Lua 表
  pushValueToLua(parsed);
  lua.lua_getglobal(L, 'dataCache');
  lua.lua_pushstring(L, cacheKey);
  lua.lua_pushvalue(L, -3);
  lua.lua_settable(L, -3);
  lua.lua_pop(L, 2);
}

function pushValueToLua(val) {
  lua.lua_newtable(L);
  if (Array.isArray(val)) {
    for (let i = 0; i < val.length; i++) {
      const v = val[i];
      lua.lua_pushinteger(L, i + 1);
      if (v === null || v === undefined) {
        lua.lua_pushnil(L);
      } else if (typeof v === 'boolean') {
        lua.lua_pushboolean(L, v);
      } else if (typeof v === 'number') {
        lua.lua_pushnumber(L, v);
      } else if (typeof v === 'string') {
        lua.lua_pushstring(L, v);
      } else if (typeof v === 'object') {
        pushValueToLua(v);
      } else {
        lua.lua_pushnil(L);
      }
      lua.lua_settable(L, -3);
    }
  } else {
    for (const key of Object.keys(val)) {
      const v = val[key];
      lua.lua_pushstring(L, key);
      if (v === null || v === undefined) {
        lua.lua_pushnil(L);
      } else if (typeof v === 'boolean') {
        lua.lua_pushboolean(L, v);
      } else if (typeof v === 'number') {
        lua.lua_pushnumber(L, v);
      } else if (typeof v === 'string') {
        lua.lua_pushstring(L, v);
      } else if (typeof v === 'object') {
        pushValueToLua(v);
      } else {
        lua.lua_pushnil(L);
      }
      lua.lua_settable(L, -3);
    }
  }
}

/* ── 5. Game loop ── */
function gameLoop() {
  lua.lua_getglobal(L, 'processEventQueue');
  if (lua.lua_type(L, -1) === lua.LUA_TFUNCTION) {
    lua.lua_pushnumber(L, Date.now());
    if (lua.lua_pcall(L, 1, 0, 0) !== 0) {
      const err = lua.lua_tostring(L, -1);
      lua.lua_pop(L, 1);
      self.postMessage({ type: 'log', text: '\x1b[31m[gameLoop error] ' + err + '\x1b[0m' });
    }
  } else {
    lua.lua_pop(L, 1);
  }
  self.setTimeout(gameLoop, 16);
}

/* ── 6. 消息处理 ── */
self.onmessage = function(e) {
  try {
    const msg = e.data;

    if (msg.type === 'engine_source') {
      loadLuaModule(msg.path, msg.source);
      self.postMessage({ type: 'log', text: '  ' + msg.path + ': OK' });
    }

    if (msg.type === 'framework_source') {
      lua.lua_getglobal(L, 'registerFrameworkModule');
      lua.lua_pushstring(L, msg.name);
      lua.lua_pushstring(L, msg.source);
      lua.lua_pcall(L, 2, 0, 0);
    }

    if (msg.type === 'script_source') {
      lua.lua_getglobal(L, 'FrameworkSources');
      lua.lua_pushstring(L, msg.path);
      lua.lua_pushstring(L, msg.source);
      lua.lua_settable(L, -3);
      lua.lua_pop(L, 1);
    }

    if (msg.type === 'load_json') {
      lua.lua_getglobal(L, 'loadJSON');
      lua.lua_pushstring(L, msg.name);
      lua.lua_pushstring(L, msg.json);
      if (lua.lua_pcall(L, 2, 1, 0) !== 0) {
        const err = lua.lua_tostring(L, -1);
        lua.lua_pop(L, 1);
        self.postMessage({ type: 'log', text: '  ' + msg.name + ': FAILED (' + err + ')' });
      } else {
        const ok = lua.lua_toboolean(L, -1);
        lua.lua_pop(L, 1);
        self.postMessage({ type: 'log', text: '  ' + msg.name + ': ' + (ok ? 'OK' : 'FAILED') });
      }
    }

    if (msg.type === 'load_json_fast') {
      injectParsedJson(msg.name, msg.json);
      self.postMessage({ type: 'log', text: '  ' + msg.name + ': OK' });
    }

    if (msg.type === 'init_all') {
      // 批量初始化：一次性接收所有数据
      self.postMessage({ type: 'log', text: 'Loading ' + msg.engine.length + ' engine modules...' });
      for (const m of msg.engine) {
        loadLuaModule(m.path, m.source);
      }
      self.postMessage({ type: 'log', text: '  Engine modules: OK' });

      self.postMessage({ type: 'log', text: 'Registering ' + msg.framework.length + ' framework modules...' });
      for (const m of msg.framework) {
        lua.lua_getglobal(L, 'registerFrameworkModule');
        lua.lua_pushstring(L, m.name);
        lua.lua_pushstring(L, m.source);
        lua.lua_pcall(L, 2, 0, 0);
      }
      self.postMessage({ type: 'log', text: '  Framework modules: ' + msg.framework.length + ' registered' });

      self.postMessage({ type: 'log', text: 'Loading ' + msg.scripts.length + ' game scripts...' });
      for (const m of msg.scripts) {
        lua.lua_getglobal(L, 'FrameworkSources');
        lua.lua_pushstring(L, m.path);
        lua.lua_pushstring(L, m.source);
        lua.lua_settable(L, -3);
        lua.lua_pop(L, 1);
      }
      self.postMessage({ type: 'log', text: '  Game scripts: ' + msg.scripts.length + ' loaded' });

      self.postMessage({ type: 'log', text: 'Loading ' + msg.data.length + ' data files...' });
      for (const d of msg.data) {
        lua.lua_getglobal(L, 'loadJSON');
        lua.lua_pushstring(L, d.name);
        lua.lua_pushstring(L, d.json);
        if (lua.lua_pcall(L, 2, 1, 0) !== 0) {
          const err = lua.lua_tostring(L, -1);
          lua.lua_pop(L, 1);
          self.postMessage({ type: 'log', text: '  ' + d.name + ': FAILED (' + err + ')' });
        } else {
          lua.lua_pop(L, 1);
          self.postMessage({ type: 'log', text: '  ' + d.name + ': OK' });
        }
      }
      // events 用 fast parse
      if (msg.events) {
        self.postMessage({ type: 'log', text: '  events: parsing...' });
        injectParsedJson('events', msg.events);
        self.postMessage({ type: 'log', text: '  events: OK' });
      }

      self.postMessage({ type: 'log', text: 'Finalizing data load...' });
      lua.lua_getglobal(L, 'finalizeDataLoad');
      lua.lua_pcall(L, 0, 0, 0);

      self.postMessage({ type: 'log', text: 'Initializing game framework...' });
      lua.lua_getglobal(L, 'initWebFramework');
      if (lua.lua_pcall(L, 0, 0, 0) !== 0) {
        const err = lua.lua_tostring(L, -1);
        lua.lua_pop(L, 1);
        self.postMessage({ type: 'log', text: '\x1b[31mFramework init FAILED: ' + err + '\x1b[0m' });
        return;
      }
      // 先跑一帧 gameLoop 让菜单渲染，再通知主线程 ready
      self.setTimeout(function() {
        gameLoop();
        self.postMessage({ type: 'ready' });
      }, 16);
    }

    if (msg.type === 'input') {
      eventQueue.push({ type: 'input', data: msg.data });
    }

  } catch (ex) {
    self.postMessage({ type: 'log', text: '\x1b[31m[worker onmessage error] ' + (ex.message || String(ex)) + '\x1b[0m' });
  }
};

/* ── 7. 初始化 ── */
injectWorkerJSBridge();
self.postMessage({ type: 'worker_ready' });
