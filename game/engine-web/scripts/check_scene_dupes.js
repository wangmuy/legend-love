// check_scene_dupes.js
// 复刻 SmapHandlers.look 的实体列表生成逻辑，计算每个小场景"首次进入"时的 look 内容列表，
// 检测重复项（同一事件/物品/NPC 名出现多次），并区分"数据本身如此"与"显示逻辑重复"。
// 用法: node scripts/check_scene_dupes.js [sceneId...]（不带参数=全部场景）

const fs = require('fs');
const path = require('path');

const DATA = path.join(__dirname, '..', 'data-web');
const scenes = JSON.parse(fs.readFileSync(path.join(DATA, 'scenes.json'), 'utf8')).scenes;
const eventsRaw = JSON.parse(fs.readFileSync(path.join(DATA, 'events.json'), 'utf8')).events;

// 场景列表：代号 -> scene
const sceneMap = {};
for (const s of scenes) sceneMap[s['代号']] = s;

// 事件编号 -> NPC 名称映射（与 mmap_smap_handlers.lua 一致）
const eventNpcNames = {
  440: '小龙女', 441: '小龙女', 438: '杨过', 439: '杨过', 417: '瑛姑', 111: '范遥',
  109: '谢逊', 110: '谢逊', 105: '金花婆婆', 115: '圣火阵', 631: '金轮法王',
  616: '蓝凤凰', 611: '洪教主', 612: '洪教主', 67: '冰火岛线索', 469: '郭靖', 470: '郭靖',
};

// 场景入口事件（sceneId -> oldevent 编号）
const sceneEntryEvents = { 50: 20 };

// 按场景索引 events.json，构建 D* 表（0-based 字典键）
const dTable = {}; // sceneId -> { tileIndex: {2:eventSpace, 3:eventTouch, 4:eventExtra, ...} }
const gridEvents = {}; // sceneId -> [{tileIndex, eventSpace, eventTouch, eventExtra}]
for (const evt of eventsRaw) {
  const sid = evt.sceneId;
  dTable[sid] = dTable[sid] || {};
  dTable[sid][evt.tileIndex] = {
    2: evt.eventSpace, 3: evt.eventTouch, 4: evt.eventExtra,
  };
  gridEvents[sid] = gridEvents[sid] || [];
  gridEvents[sid].push({ tile: evt.tileIndex, space: evt.eventSpace, touch: evt.eventTouch, extra: evt.eventExtra });
}

// 复刻 look()：返回 { list: [{type, label, eventId?}], dupes: [...] }
function computeLook(sceneId) {
  const scene = sceneMap[sceneId];
  if (!scene) return null;
  const sid = String(sceneId);
  const list = [];
  const seen = new Map(); // key -> count（用于检测重复）
  const keyOf = (e) => `${e.type}:${e.label}`;

  const push = (e) => {
    const k = keyOf(e);
    seen.set(k, (seen.get(k) || 0) + 1);
    list.push(e);
  };

  // 1. 静态 NPC（oldevent_* 前缀 → "搜索"，否则显示名称）
  const npcs = scene['NPC'] || [];
  const staticEventIds = {};
  for (const npc of npcs) {
    const eid = npc['事件编号'];
    if (eid > 0) staticEventIds[eid] = true;
  }
  for (const npc of npcs) {
    const npcName = npc['名称'] || '?';
    if (npcName.match(/^oldevent_/)) {
      const eid = npc['事件编号'] || 0;
      // eventConsumed 初始为空，首次进入全部显示
      push({ type: 'event_trigger', label: '搜索', eventId: eid, src: 'static_npc' });
    } else {
      push({ type: 'npc', label: npcName, eventId: npc['事件编号'], src: 'static_npc' });
    }
  }

  // 2. 动态 D* 表扫描（0~199，取 eventSpace/eventTouch/eventExtra 任一）
  const d = dTable[sceneId] || {};
  const consumed = {};
  for (let i = 0; i < 200; i++) {
    const evt = d[i];
    if (!evt) continue;
    let eventNum = null;
    if (evt[2] > 0) eventNum = evt[2];
    else if (evt[3] > 0) eventNum = evt[3];
    else if (evt[4] > 0) eventNum = evt[4];
    if (eventNum == null) continue;
    if (staticEventIds[eventNum]) continue; // 跳过静态列表已有事件
    if (consumed[eventNum]) continue;
    const npcName = eventNpcNames[eventNum] || ('oldevent_' + eventNum);
    if (eventNpcNames[eventNum] !== undefined) {
      push({ type: 'npc', label: npcName, eventId: eventNum, src: 'dstar_npc' });
    } else {
      push({ type: 'event_trigger', label: '搜索', eventId: eventNum, src: 'dstar' });
    }
  }

  // 3. 场景入口事件
  const entryEvt = sceneEntryEvents[sceneId];
  if (entryEvt) {
    push({ type: 'event_trigger', label: '搜索', eventId: entryEvt, src: 'entry' });
  }

  // 4. 物品列表
  const items = scene['物品'] || [];
  for (const item of items) {
    push({ type: 'item', label: item['名称'] || ('item' + item['代号']), itemId: item['代号'], src: 'item' });
  }

  // 5. 出口列表
  const exits = scene['出口'] || [];
  for (const exit of exits) {
    const target = sceneMap[exit['目标场景']];
    push({ type: 'exit', label: '→ ' + (target ? target['名称'] : '?'), target: exit['目标场景'], src: 'exit' });
  }

  // 6. 格子事件（events.json 中 eventExtra>0 或 eventTouch>0）
  const ge = gridEvents[sceneId] || [];
  for (const evt of ge) {
    let eventId = null, eventType = null;
    if (evt.extra > 0) { eventId = evt.extra; eventType = 'event_extra'; }
    else if (evt.touch > 0) { eventId = evt.touch; eventType = 'event_touch'; }
    if (eventId == null) continue;
    if (consumed[eventId]) continue;
    const label = (eventId >= 1001 && eventId <= 1014) ? '放置天书' : '搜索';
    push({ type: 'event_trigger', label, eventId, eventType, src: 'grid_' + eventType });
  }

  // 检测重复：按事件编号 / 显示标签
  // 分类：
  //   DISPLAY_DUP  —— 显示逻辑重复：同一事件被 D* 扫描与 grid 扫描（或 static NPC 与 grid）
  //                   各列出一次。真实 look() 中两段扫描独立、互不去重，因此会在列表中
  //                   出现多个相同条目；点击任意一个都触发同一事件，事件消耗后全部消失。
  //   DATA_DUP     —— 数据本身如此：events.json 中多个格子（tile）引用同一事件号，
  //                   原版 D* 表就这样，每格一个触发点，列表逐格列出属预期。
  //   EXIT_DUP     —— 数据本身如此：场景有多个出口格子指向同一目标场景。
  const dupes = [];
  const byEvent = new Map();
  for (const e of list) {
    if (e.eventId != null) {
      if (!byEvent.has(e.eventId)) byEvent.set(e.eventId, []);
      byEvent.get(e.eventId).push(e);
    }
  }
  for (const [eid, arr] of byEvent) {
    if (arr.length < 2) continue;
    const srcSet = new Set(arr.map((a) => a.src));
    const gridCnt = arr.filter((a) => a.src.startsWith('grid_')).length;
    const dstarCnt = arr.filter((a) => a.src === 'dstar').length;
    const staticCnt = arr.filter((a) => a.src === 'static_npc').length;
    const kind =
      (gridCnt > 0 && dstarCnt > 0) || (gridCnt > 0 && staticCnt > 0)
        ? 'DISPLAY_DUP'
        : 'DATA_DUP';
    dupes.push({ kind, eventId: eid, count: arr.length, sources: arr.map((a) => a.src + '/' + a.label) });
  }
  const byLabel = new Map();
  for (const e of list) {
    const k = `${e.type}:${e.label}`;
    if (!byLabel.has(k)) byLabel.set(k, []);
    byLabel.get(k).push(e);
  }
  for (const [k, arr] of byLabel) {
    if (arr.length > 1) {
      const hasEventIds = arr.every((a) => a.eventId != null);
      if (!hasEventIds) dupes.push({ kind: 'EXIT_DUP', label: k, count: arr.length, sources: arr.map((a) => a.src) });
    }
  }

  return { sceneId, name: scene['名称'], list, dupes };
}

const args = process.argv.slice(2);
const targets = args.length > 0 ? args.map(Number) : Object.keys(sceneMap).map(Number);
targets.sort((a, b) => a - b);

let sceneWithDupes = 0;
for (const sid of targets) {
  const r = computeLook(sid);
  if (!r) { console.log(`scene ${sid}: 不存在`); continue; }
  const srcCount = {};
  for (const e of r.list) srcCount[e.src] = (srcCount[e.src] || 0) + 1;
  console.log(`\n=== scene ${r.sceneId} ${r.name} (共 ${r.list.length} 项: ${JSON.stringify(srcCount)}) ===`);
  r.list.forEach((e, i) => {
    console.log(`  ${i + 1}. ${e.type === 'event_trigger' ? '搜索' : e.label}${e.eventId ? ` [${e.src} evt${e.eventId}]` : ''}${e.type === 'item' ? ' [物品]' : ''}${e.type === 'exit' ? ' [出口]' : ''}`);
  });
  if (r.dupes.length > 0) {
    sceneWithDupes++;
    console.log(`  ⚠ 重复项:`);
    for (const d of r.dupes) {
      console.log(`    - [${d.kind}] ${d.eventId != null ? '事件 ' + d.eventId : d.label} ×${d.count} (${d.sources.join(', ')})`);
    }
  }
}
console.log(`\n=== 汇总: ${targets.length} 个场景，${sceneWithDupes} 个场景存在重复项 ===`);
// 分类统计
const kindCount = {};
const kindScenes = {};
for (const sid of targets) {
  const r = computeLook(sid);
  if (!r) continue;
  for (const d of r.dupes) {
    kindCount[d.kind] = (kindCount[d.kind] || 0) + 1;
    kindScenes[d.kind] = kindScenes[d.kind] || new Set();
    kindScenes[d.kind].add(r.sceneId + ' ' + r.name);
  }
}
for (const k of Object.keys(kindCount)) {
  console.log(`[${k}] ${kindCount[k]} 处，涉及场景: ${[...kindScenes[k]].join(', ')}`);
}
console.log('结论: DISPLAY_DUP 为显示逻辑重复（同一事件被多段扫描重复列出，无功能影响，点击任一触发同一事件，消耗后全部消失）；');
console.log('      DATA_DUP / EXIT_DUP 为数据本身如此（多格同事件/多出口同目标），原版 D* 表即如此，列表逐格列出属预期。');
