// tests/helpers/term.js
// 终端操作辅助函数，供攻略测试通用

async function cmd(p, t) {
  const i = p.locator('#command-input');
  await i.waitFor({ state: 'visible', timeout: 15000 });
  await i.fill(t);
  await p.keyboard.press('Enter');
}

async function getT(p) {
  return p.evaluate(() => {
    const term = window.__xterm;
    if (!term) return '';
    const lines = [];
    for (let y = 0; y < term.buffer.active.length; y++) {
      const s = term.buffer.active.getLine(y)?.translateToString(true) || '';
      if (s.trim()) lines.push(s.trimEnd());
    }
    return lines.join('\n');
  });
}

async function noE(p) {
  return p.evaluate(() => {
    const term = window.__xterm;
    if (!term) return true;
    for (let y = 0; y < term.rows; y++) {
      if ((term.buffer.active.getLine(y)?.translateToString(true) || '').includes('[gameLoop error]')) return false;
    }
    return true;
  });
}

module.exports = { cmd, getT, noE };
