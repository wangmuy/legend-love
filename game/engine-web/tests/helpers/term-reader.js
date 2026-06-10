async function readTermLine(page, lineIndex) {
  return page.evaluate((n) => {
    const term = window.__xterm;
    if (!term) return null;
    return term.buffer.active.getLine(n)?.translateToString(true) || '';
  }, lineIndex);
}

async function readAllTermLines(page) {
  return page.evaluate(() => {
    const term = window.__xterm;
    if (!term) return [];
    const lines = [];
    for (let y = 0; y < term.rows; y++) {
      const text = term.buffer.active.getLine(y)?.translateToString(true) || '';
      if (text.trim()) lines.push(text.trimEnd());
    }
    return lines;
  });
}

async function getTerminalText(page) {
  const lines = await readAllTermLines(page);
  return lines.join('\n');
}

module.exports = { readTermLine, readAllTermLines, getTerminalText };
