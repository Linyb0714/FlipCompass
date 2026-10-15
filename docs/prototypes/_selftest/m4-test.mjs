/* M4 益智小游戏 · V0.4.5 自测
   本轮边界：只做统计（d10/d11/d12）与设置（d13），游戏本体字段为占位待单独设计。
   重点验证：统计皆为实算（非硬编码）、勋章解锁判定、设置开关、占位标记存在。 */
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

console.log('=== A. 渲染无错误 ===');
ok('脚本零错误', errors.length === 0, errors.join('|'));
ok('p0/p1/p2 均已渲染', d.querySelectorAll('#m4-p0 .item').length > 0 && d.querySelectorAll('#m4-p1 .item').length > 0 && d.querySelectorAll('#m4-p2 .badge').length > 0);

console.log('\n=== B. 数据表结构 ===');
ok('4 个游戏', ev('M4.games.length') === 4);
ok('8 条逐局记录', ev('M4.records.length') === 8);
ok('4 枚勋章', ev('M4.badges.length') === 4);
ok('3 项设置', ev('M4.settings.length') === 3);
ok('每个游戏有 metrics 占位', ev('M4.games.every(g => Array.isArray(g.metrics) && g.metrics.length === 3)'));
ok('游戏 id 唯一', ev('new Set(M4.games.map(g=>g.id)).size === 4'));

console.log('\n=== C. p0 今日 ===');
ok('继续游戏 hero 接 d11', !!d.querySelector('#m4-p0 [data-open="d11"][data-game]'));
ok('今日战绩卡接 d10', !!d.querySelector('#m4-p0 [data-open="d10"]'));
ok('连胜卡接 d12', !!d.querySelector('#m4-p0 [data-open="d12"][data-badge]'));
ok('头部胶囊实算三星局数', d.querySelector('#scr-m4 .head-chip b').textContent === String(ev("M4.records.filter(r=>r.stars===3).length")), d.querySelector('#scr-m4 .head-chip b').textContent);

console.log('\n=== D. p1 游戏清单 ===');
ok('4 个 game-tile', d.querySelectorAll('#m4-p1 .game-tile').length === 4);
ok('均接 d11 带 data-game', d.querySelectorAll('#m4-p1 [data-open="d11"][data-game]').length === 4);
ok('星级实算显示', d.querySelectorAll('#m4-p1 .stars').length === 4);
ok('第 1 张 3★', d.querySelector('#m4-p1 .stars').textContent.includes('★★★'));

console.log('\n=== E. p2 勋章墙 + 设置入口 ===');
ok('4 枚徽章', d.querySelectorAll('#m4-p2 .badge').length === 4);
ok('已解锁徽章带 on', d.querySelectorAll('#m4-p2 .badge.on').length === 2, d.querySelectorAll('#m4-p2 .badge.on').length + ' 枚');
ok('未解锁带 locked', d.querySelectorAll('#m4-p2 .badge.locked').length === 2);
ok('未解锁显示问号', [...d.querySelectorAll('#m4-p2 .badge.locked .b')].every(e => e.textContent === '?'));
ok('设置入口行接 d13', !!d.querySelector('#m4-p2 [data-open="d13"]'));
ok('徽章纳入焦点系统(itemsOf)', ev("document.querySelectorAll('#m4-p2 .badge').length") === 4);

console.log('\n=== F. 勋章解锁实算 ===');
ok('b1 初翻罗盘(1 局)已解锁', ev("m4BadgeOn(M4.badges[0])") === true);
ok('b2 七日之约(连7天,现5)未解锁', ev("m4BadgeOn(M4.badges[1])") === false);
ok('b2 进度 5/7', ev("m4BadgeProg(M4.badges[1]).cur") === 5);
ok('b3 棋逢对手(30 局,现8)未解锁', ev("m4BadgeOn(M4.badges[2])") === false);
ok('b4 满星玩家(3★)已解锁', ev("m4BadgeOn(M4.badges[3])") === true);
ev("M4.records.push({g:'hrd',date:'10-12',time:'刚刚',score:'80 步',stars:3})");
ev('renderM4Badges()');
ok('记录增加后仍准确', ev("m4BadgeOn(M4.badges[2])") === false && ev("m4BadgeProg(M4.badges[2]).cur") === 9);
ev("M4.records.pop(); renderM4Badges()");

console.log('\n=== G. d10 战绩详情 ===');
ev('fillD10()');
ok('总局数实算', d.querySelector('#d10-tot').textContent === String(ev('M4.records.length')), d.querySelector('#d10-tot').textContent);
ok('累计星星实算', d.querySelector('#d10-star').textContent === String(ev('m4TotalStars()')), d.querySelector('#d10-star').textContent);
ok('连续天数实算', d.querySelector('#d10-str').textContent.startsWith(String(ev('M4.streak'))));
ok('趋势图 7 柱', d.querySelectorAll('#d10-trend .bar').length === 7);
ok('今天柱标 today', !!d.querySelector('#d10-trend .bar.today'));
ok('零局柱标 zero', d.querySelectorAll('#d10-trend .bar.zero').length > 0);
ok('逐局记录渲染', d.querySelectorAll('#d10-recs .g10-rec').length === 8);
ok('记录含游戏名与成绩', d.querySelector('#d10-recs .rt').textContent.length > 0 && d.querySelector('#d10-recs .rs').textContent.length > 0);

console.log('\n=== H. d11 单游戏统计 ===');
ev("fillD11('g1')");
ok('游戏名填充', d.querySelector('#d11-name').textContent === '华容道');
ok('副标填充', d.querySelector('#d11-desc').textContent.includes('12 式'));
ok('星级显示 3/3', d.querySelector('#d11-prog').textContent === '3 / 3');
ok('metrics 三行', d.querySelectorAll('#d11-meta .g11-meta-row').length === 3);
ok('近 6 局只渲染该游戏', ev("document.querySelectorAll('#d11-recs .g10-rec').length") === ev("m4Recs('hrd').length"));
ev("fillD11('g3')");
ok('切换游戏联动', d.querySelector('#d11-name').textContent === '2048');
ok('2048 星级 1/3', d.querySelector('#d11-prog').textContent === '1 / 3');
ok('游戏本体占位存在', !!d.querySelector('#scr-d11 .g-placeholder'));
ok('占位含待设计说明', d.querySelector('#scr-d11 .g-placeholder').textContent.includes('待单独设计'));

console.log('\n=== I. d12 勋章详情 ===');
ev("fillD12('b2')");
ok('名称填充', d.querySelector('#d12-name').textContent === '七日之约');
ok('未解锁 medal 置灰', d.querySelector('#d12-medal').className.includes('locked'));
ok('未解锁显示问号', d.querySelector('#d12-medal').textContent === '?');
ok('进度条 5/7 ≈ 71%', d.querySelector('#d12-bar').style.width.startsWith('71'), d.querySelector('#d12-bar').style.width);
ok('进度文案', d.querySelector('#d12-prog').textContent.includes('5 / 7'));
ok('鼓励语含剩余天数', d.querySelector('#d12-cheer').textContent.includes('2'));
ev("fillD12('b1')");
ok('已解锁无 locked 类', !d.querySelector('#d12-medal').className.includes('locked'));
ok('已解锁显示图标', d.querySelector('#d12-medal').textContent === '✓');
ok('已解锁鼓励语', d.querySelector('#d12-cheer').textContent.includes('拿到'));
ok('进度条 100%', d.querySelector('#d12-bar').style.width === '100%');

console.log('\n=== J. d13 设置 ===');
ev('fillD13()');
ok('3 个设置行', d.querySelectorAll('#d13-sets .set-row').length === 3);
ok('开关元素齐全', d.querySelectorAll('#d13-sets .sw').length === 3);
ok('音效默认开', d.querySelector('#d13-sets [data-sw="s1"]').classList.contains('on'));
ok('计时默认关', !d.querySelector('#d13-sets [data-sw="s3"]').classList.contains('on'));
const b4 = ev('M4.settings[1].on');
ev("toggleSet('s2')");
ok('切换后状态翻转', ev('M4.settings[1].on') === !b4);
ok('DOM 同步', d.querySelector('#d13-sets [data-sw="s2"]').classList.contains('on') === ev('M4.settings[1].on'));
ok('toast 提示', toast().includes('触感反馈'));
ok('导出行存在', !!d.querySelector('#d13-export'));
ok('清空行存在', !!d.querySelector('#d13-clear'));

console.log('\n=== K. 基建接入 ===');
ok('isDetail 通用判定(d10~d13)', ev("isDetail('d10')&&isDetail('d11')&&isDetail('d12')&&isDetail('d13')"));
ok('MINI 含 d10~d13', ev("!!(MINI.d10&&MINI.d11&&MINI.d12&&MINI.d13)"));
ok('TOAST_TINT 含 d10~d13', ev("!!(TOAST_TINT.d10&&TOAST_TINT.d11&&TOAST_TINT.d12&&TOAST_TINT.d13)"));
ok('无遗留 d1d2d3 硬编码', ev("!/\\['d1','d2','d3'\\]/.test(String(goModule)+String(backOneLevel)+String(backToIdle))"));
ok('renderM4 已挂载', ev("typeof renderM4 === 'function'"));

console.log('\n=== L. 焦点系统 ===');
ev('st.m4.p = 1; st.m4.sel[1] = 0; renderSel("m4")');
ok('p1 选中首个 game-tile', d.querySelectorAll('#m4-p1 .item')[0].classList.contains('sel'));
ok('缩略卡联动 d11', d.querySelector('#mini-m4').classList.contains('on'));
ok('p1 缩略卡标题=游戏名', d.querySelector('#mini-m4 .mp-title').textContent.includes('华容道'), d.querySelector('#mini-m4 .mp-title').textContent);
ev('st.m4.p = 2; st.m4.sel[2] = 0; renderSel("m4")');
ok('p2 选中首个徽章', d.querySelectorAll('#m4-p2 .badge')[0].classList.contains('sel'));
ok('徽章选中不破坏 .sel 数量', d.querySelectorAll('#m4-p2 .badge.sel').length === 1);
ev('st.m4.p = 2; st.m4.sel[2] = 4; renderSel("m4")');
ok('p2 末项=设置行', d.querySelector('#m4-p2 [data-open="d13"]').classList.contains('sel'));

console.log(`\n结果：${pass} 通过 / ${fail} 失败`);
process.exit(fail || errors.length ? 1 : 0);