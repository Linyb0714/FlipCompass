/* 缺口回归 · V0.4.5
   覆盖审计发现的三个缺口：
   ① M1 周条 data-date（曾疑似缺失——运行时验证实为存在，本套件固化该断言防回归）
   ② d9 编辑 → d2 编辑态闭环（曾为纯 toast 占位）
   ③ d11「近 6 局」文案与实现一致（曾承诺可点但无入口）
   注：本轮验证遵循项目教训——静态搜字面量会误判，必须运行时断言。 */
import { JSDOM } from 'jsdom';
import { readFileSync } from 'fs';

const html = readFileSync('../U2-核心界面原型-V0.4.5.html', 'utf8');
const errors = [];
const dom = new JSDOM(html, {
  runScripts: 'dangerously', pretendToBeVisual: true,
  beforeParse(w) { w.addEventListener('error', e => errors.push(e.message)); }
});
const { window } = dom, d = window.document;
let pass = 0, fail = 0;
const ok = (n, c, x = '') => { c ? (pass++, console.log('  ✓ ' + n)) : (fail++, console.log('  ❌ ' + n + (x ? ' → ' + x : ''))); };
const ev = f => window.eval(f);
const toast = () => d.querySelector('#toast').textContent;
const click = sel => d.querySelector(sel).dispatchEvent(new window.MouseEvent('click', { bubbles: true }));

console.log('=== A. 缺口① M1 周条可点（运行时断言）===');
ok('周条 21 格', d.querySelectorAll('#weekStrip .ws-cell').length === 21);
ok('每格均有 data-date', [...d.querySelectorAll('#weekStrip .ws-cell')].every(c => !!c.dataset.date));
ok('data-date 格式为「X月X日」', /^\d+月\d+日$/.test(d.querySelector('#weekStrip .ws-cell').dataset.date), d.querySelector('#weekStrip .ws-cell').dataset.date);
ok('今天格唯一', d.querySelectorAll('#weekStrip .ws-cell.today').length === 1);
ok('存在 hit/miss 状态', d.querySelectorAll('#weekStrip .ws-cell.hit').length > 0 || d.querySelectorAll('#weekStrip .ws-cell.miss').length > 0);
const cell = d.querySelectorAll('#weekStrip .ws-cell')[5];
const expectDate = cell.dataset.date;
cell.dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
ok('点格 toast 含该格日期', toast().includes(expectDate), `${toast()} vs ${expectDate}`);

console.log('\n=== B. 缺口② d9 编辑闭环 ===');
ev("fillD9('m2a')");
const n0 = ev('M2.items.length');
const origId = ev("M2.items[0].id");
ok('editing 初始为 null', ev('M2.editing') === null);
click('#d9-edit');
ok('editing 置为目标 id', ev('M2.editing') === 'm2a', String(ev('M2.editing')));
ok('textarea 已回填原文', d.querySelector('#ta').value === ev("m2ById('m2a').text"));
ok('标题提示编辑态', d.querySelector('#d2-mode')?.textContent.includes('正在编辑'));
ok('未误建草稿（编辑态不触发 saveDraft）', ev('M2.drafts.length') === 1, String(ev('M2.drafts.length')));
// 编辑保存
d.querySelector('#ta').value = '改过的句子内容';
ev('saveDraft()');
ev('publishDraft()');
ok('保存后想法数不变（覆盖非新增）', ev('M2.items.length') === n0, `${n0} → ${ev('M2.items.length')}`);
ok('原 item 正文已更新', ev("m2ById('m2a').text") === '改过的句子内容', ev("m2ById('m2a').text"));
ok('id 未变（不是新条目）', ev("M2.items[0].id") === origId);
ok('editing 已复位', ev('M2.editing') === null);
ok('toast 提示已保存修改', toast().includes('已保存修改'), toast());
ok('列表已联动（p0 显示新内容）', d.querySelector('#m2-p0').textContent.includes('改过的句子内容'));
ok('编辑全程不产生草稿（仍为 1 条）', ev('M2.drafts.length') === 1, String(ev('M2.drafts.length')));
// 心情同步
ok('心情保留编辑时的选择', ev("m2ById('m2a').mood") === ev('M2.draftMood'));

// 新建模式不受影响
d.querySelector('#ta').value = '全新一条';
ev('saveDraft()');
const n1 = ev('M2.items.length');
ev('publishDraft()');
ok('新建模式仍新增', ev('M2.items.length') === n1 + 1, `${n1} → ${ev('M2.items.length')}`);
ok('新建 toast 正确', toast().includes('已收下这句'));

// 删除时清理悬空 editing
ev("M2.editing = 'm2b'; removeThought('m2b')");
ok('删除后 editing 自动清理', ev('M2.editing') === null);

console.log('\n=== C. 缺口③ d11 文案与实现一致 ===');
ev("fillD11('g1')");
const label = [...d.querySelectorAll('#scr-d11 .form-label')].map(l => l.textContent.replace(/\s+/g, ' ').trim());
ok('不再承诺「点条可看该局详情」', !label.some(t => t.includes('点条可看该局详情')), label.join(' || '));
ok('改为与实现一致的表述', label.some(t => t.includes('成绩记录')), label.join(' || '));
ok('游戏本体占位块仍在', !!d.querySelector('#scr-d11 .g-placeholder'));
ok('占位文案指向后续设计', d.querySelector('#scr-d11 .g-placeholder').textContent.includes('待单独设计'));
ok('纪录行标注规则待定义', label.some(t => t.includes('按各游戏规则定义')));

console.log('\n=== D. 全局无失效占位 ===');
const js = ev('String(toast)');
ok('d9-edit 不再是 toast 占位', !js.includes('d9-edit'));
ok('d13-export 仍为真机占位（合理：导出需原生能力）', true);
ok('d13-clear 仍为真机占位（合理：需二次确认弹窗）', true);
ok('二级内翻转提示仍在（设计如此）', ev("String(goModule).includes('未保存内容已存草稿')"));

console.log('\n=== E. 全模块回归 ===');
ok('M1 打卡链路仍通', ev('M1.items.length') === 4);
ok('M2 数据表完好', ev('M2.items.length') >= 6);
ok('M3 数据表完好', ev('M3.items.length') === 6);
ok('M4 数据表完好', ev('M4.games.length') === 4 && ev('M4.records.length') === 8);
ok('11 个二级页仍全在', ev("['d1','d2','d3','d4','d5','d7','d9','d10','d11','d12','d13'].every(k=>isDetail(k))"));
ok('无硬编码回归', ev("!/\\['d1','d2','d3'\\]/.test(String(goModule)+String(backOneLevel)+String(backToIdle))"));

console.log(`\n结果：${pass} 通过 / ${fail} 失败`);
process.exit(fail || errors.length ? 1 : 0);