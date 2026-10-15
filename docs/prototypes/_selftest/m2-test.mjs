/* M2 今天的想法 · V0.4.5 自测（数据表 + 草稿三件套 + d9 详情）
   重点验证 R8 草稿三件套：①自动落盘永不丢 ②切走不打断 ③标记看得见 */
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
const drafts = () => ev('M2.drafts.length');
const items = () => ev('M2.items.length');
const today = () => ev('m2Today().length');
const selIdx = () => ev('st.m2.sel[st.m2.p]');
const toast = () => d.querySelector('#toast').textContent;

console.log('=== A. 渲染无错误 ===');
ok('脚本零错误', errors.length === 0, errors.join('|'));
ok('p0 已渲染', d.querySelectorAll('#m2-p0 .item').length > 0);
ok('p1 已渲染', d.querySelectorAll('#m2-p1 .item').length > 0);

console.log('\n=== B. p0 今日想法 ===');
const p0 = d.querySelectorAll('#m2-p0 .item');
ok('记录卡 + 3 今日条目', p0.length === 4, p0.length + ' 项');
ok('记录卡 data-open="d2"', !!d.querySelector('#m2-p0 [data-open="d2"]'));
ok('想法条目接 d9', d.querySelectorAll('#m2-p0 [data-open="d9"]').length === 3);
ok('记录卡草稿标记实算', d.querySelector('#m2-p0 .compose-card .s').textContent.includes('有草稿 1 条'), d.querySelector('#m2-p0 .compose-card .s').textContent);
ok('头部胶囊实算=3', d.querySelector('#m2-count').textContent === '3', d.querySelector('#m2-count').textContent);

console.log('\n=== C. R8① 自动落盘永不丢 ===');
d.querySelector('#ta').value = '这是一句新写的草稿内容';
ev('saveDraft()');
ok('输入→草稿数 2', drafts() === 2, drafts() + ' 条');
ok('草稿内容一致', ev('M2.drafts[0].text') === '这是一句新写的草稿内容');
ok('记录卡提示更新', d.querySelector('#m2-p0 .compose-card .s').textContent.includes('有草稿 2 条'));
ev('saveDraft()');
ok('同内容不重复插入', drafts() === 2, drafts() + ' 条');
d.querySelector('#ta').value = '';
ev('saveDraft()');
ok('清空→草稿数 1', drafts() === 1, drafts() + ' 条');

console.log('\n=== D. d2 双子页切换 ===');
ev("switchPane('drafts')");
ok('草稿箱 pane 显示', d.querySelector('#d2-pane-drafts').classList.contains('on'));
ok('记录 pane 隐藏', !d.querySelector('#d2-pane-write').classList.contains('on'));
ok('草稿 tab 变 on', d.querySelector('#d2-tabs .tab[data-pane="drafts"]').classList.contains('on'));
ok('草稿卡渲染 1 张', d.querySelectorAll('#d2-drafts .draft-card').length === 1);
ok('草稿卡含 − 删除钮', !!d.querySelector('#d2-drafts .d-del'));
ev("switchPane('write')");
ok('切回记录页', d.querySelector('#d2-pane-write').classList.contains('on'));

console.log('\n=== E. 草稿箱：继续写 / 删除 / 空态 ===');
const drId = ev('M2.drafts[0].id');
ev(`openDraft('${drId}')`);
ok('点草稿→回到记录页', d.querySelector('#d2-pane-write').classList.contains('on'));
ok('内容已回填 textarea', d.querySelector('#ta').value.length > 0);
ev(`removeDraft('${drId}')`);
ok('删除草稿→0 条', drafts() === 0, drafts() + ' 条');
ok('空态显示', !!d.querySelector('#d2-drafts .draft-empty'));
ok('记录卡提示回退文案', d.querySelector('#m2-p0 .compose-card .s').textContent.includes('写一半也没关系'), d.querySelector('#m2-p0 .compose-card .s').textContent);

console.log('\n=== F. 发布草稿 → 想法 ===');
const before = items();
d.querySelector('#ta').value = '发布一句试试';
ev('saveDraft()');
ok('先存草稿', drafts() === 1);
ev('publishDraft()');
ok('草稿出栈', drafts() === 0);
ok('想法 +1', items() === before + 1, `${before}→${items()}`);
ok('textarea 已清空', d.querySelector('#ta').value === '');
ok('胶囊 3→4', d.querySelector('#m2-count').textContent === '4', d.querySelector('#m2-count').textContent);
ok('toast 提示已收下', toast().includes('已收下这句'));
d.querySelector('#ta').value = '   ';
ev('publishDraft()');
ok('空内容被拦截', toast().includes('先写点什么吧'), toast());
ok('想法数未变', items() === before + 1);

console.log('\n=== G. d9 想法详情 ===');
ev("fillD9('m2a')");
ok('日期填充', d.querySelector('#d9-date').textContent === '10-12');
ok('心情填充', d.querySelector('#d9-mood').textContent === '雀跃');
ok('时间填充', d.querySelector('#d9-time').textContent === '21:32');
ok('全文填充', d.querySelector('#d9-text').textContent.includes('宝宝先笑了'));
ok('isDetail(d9)=true', ev("isDetail('d9')") === true);
ok('MINI 含 d9', ev('!!MINI.d9'));
ok('TOAST_TINT 含 d9', ev('!!TOAST_TINT.d9'));

console.log('\n=== H. d9 删除 ===');
const b2 = items();
ev("removeThought('m2a')");
ok('想法 -1', items() === b2 - 1, `${b2}→${items()}`);
ok('toast 提示已删除', toast().includes('已删除'));
ok('今日数 4→3', today() === 3, today() + '');

console.log('\n=== I. p1 月视图 ===');
ok('月份导航存在', !!d.querySelector('#m2-p1 .month-nav'));
ok('月视图条目接 d9', d.querySelectorAll('#m2-p1 [data-open="d9"]').length > 0);
ev("M2.month = '2026-09'; renderM2Month()");
ok('切到 9 月→空态', !!d.querySelector('#m2-p1 .chips-empty'));
ev("M2.month = '2026-10'; renderM2Month()");
ok('切回 10 月→有内容', d.querySelectorAll('#m2-p1 .item.th').length > 0);

console.log('\n=== J. 焦点系统 ===');
ok('p0 初始 sel=0（记录卡）', selIdx() === 0);
ev('st.m2.p = 0; st.m2.sel[0] = 1; renderSel("m2")');
ok('下移→选中第 1 条想法', d.querySelectorAll('#m2-p0 .item')[1].classList.contains('sel'));
ok('缩略卡随 d9 联动', d.querySelector('#mini-m2').classList.contains('on'));

console.log(`\n结果：${pass} 通过 / ${fail} 失败`);
process.exit(fail || errors.length ? 1 : 0);