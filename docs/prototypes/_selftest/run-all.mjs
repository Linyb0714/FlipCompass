/* 原型自测一键运行
   用法：cd docs/prototypes/_selftest && node run-all.mjs
   依赖：cd docs/prototypes && npm install jsdom

   注意：每套测试各自 new 一个 jsdom 实例（隔离性最好），但连续多子进程在本机
   可能触发内存上限被SIGTERM。故对未产出结果的套件做一次单独重试，仍失败则
   提示手动逐个执行——不静默跳过，避免误判为「全绿」。 */
import { execFileSync } from 'child_process';
import { existsSync } from 'fs';

const SUITES = ['m3logic-test', 'm3dom-test', 'm3-focus-test', 'm2-test', 'm4-test', 'gap-test', 'm1-regress'];
const HEAP = 256;   // 本机沙箱内存受限，256 稳定；内存充裕可调高

if (!existsSync('../node_modules/jsdom')) {
  console.log('缺少依赖，请执行：cd docs/prototypes && npm install jsdom');
  process.exit(2);
}

function run(name) {
  try {
    return execFileSync(process.execPath, [`--max-old-space-size=${HEAP}`, `${name}.mjs`],
      { encoding: 'utf-8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 120000 });
  } catch (e) {
    return (e.stdout || '') + (e.stderr || '');
  }
}

const rows = [];
const failed = [];
let pass = 0, fail = 0;

for (const name of SUITES) {
  let out = run(name);
  let m = out.match(/^结果：(\d+) 通过 \/ (\d+) 失败/m);

  // 首次无结果（多为被 SIGTERM）→ 单独重试一次
  if (!m) {
    rows.push([name, '首次未完成，单独重试…']);
    out = run(name);
    m = out.match(/^结果：(\d+) 通过 \/ (\d+) 失败/m);
  }

  if (m) {
    const p = +m[1], f = +m[2];
    pass += p; fail += f;
    rows.push([name, `${p} 通过 / ${f} 失败`]);
    if (f > 0) {
      failed.push(name);
      const detail = out.split('\n').filter(l => l.includes('❌')).slice(0, 5);
      rows.push(['  └', detail.join('\n  ')]);
    }
  } else {
    failed.push(name);
    rows.push([name, '仍无结果（可手动执行：node --max-old-space-size=320 ' + name + '.mjs）']);
  }
}

for (const [a, b] of rows) console.log(`${a.padEnd(16)} ${b}`);
console.log('-------------------------------');
console.log(`合计 ${pass} 通过 / ${fail} 失败`);
console.log(failed.length === 0 ? '全部通过 ✓' : `存在失败或未完成 ✗（${failed.join(', ')}）`);
process.exit(failed.length ? 1 : 0);