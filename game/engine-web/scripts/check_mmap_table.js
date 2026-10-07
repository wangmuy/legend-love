// check_mmap_table.js — 比对 check_mmap_list.js 输出与攻略 quick_pass_game.md 编号表一致性
const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const out = execSync("node scripts/check_mmap_list.js", { encoding: "utf8" });
const scriptLines = out.split("\n").filter((l) => /^[0-9]+\. /.test(l));
const md = fs.readFileSync(path.join(__dirname, "..", "quick_pass_game.md"), "utf8");
// 只提取「大地图场景编号表」小节（14 天书对应表也是 | N | 行，需限定范围）
const sectionStart = md.indexOf("## 大地图场景编号表");
const sectionEnd = md.indexOf("## ", sectionStart + 10);
if (sectionStart < 0 || sectionEnd < 0) {
    console.error("找不到「大地图场景编号表」小节");
    process.exit(2);
}
const section = md.slice(sectionStart, sectionEnd);
const tableLines = section.split("\n").filter((l) => /^\| [0-9]+ \|/.test(l));

console.log("脚本行数:", scriptLines.length, " 攻略表格行数:", tableLines.length);

let mismatch = 0;
for (let i = 0; i < Math.max(scriptLines.length, tableLines.length); i++) {
  const s = scriptLines[i] || "(无)";
  const t = tableLines[i] || "(无)";
  // 脚本: "N. 名称  [sceneId=X]"  攻略: "| N | 名称 | X | 备注"
  const sm = s.match(/^([0-9]+)\. (.+?)  \[sceneId=([0-9]+)\]/);
  const tm = t.match(/^\| ([0-9]+) \| (.+?) \| ([0-9]+) \|/);
  if (!sm || !tm) {
    console.log("解析失败行", i + 1, JSON.stringify(s), JSON.stringify(t));
    mismatch++;
    continue;
  }
  const nameMatch = sm[2].replace(/^山洞 .*$/, "山洞") === tm[2].replace(/^山洞 .*$/, "山洞");
  if (sm[1] !== tm[1] || sm[3] !== tm[3] || !nameMatch) {
    console.log("不一致 行" + (i + 1) + ":", JSON.stringify(sm), JSON.stringify(tm));
    mismatch++;
  }
}
console.log("不一致数:", mismatch);
process.exit(mismatch === 0 ? 0 : 1);
