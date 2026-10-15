/* 焦点系统 × M3 验证：选中索引 ↔ 焦点卡定位 ↔ 缩略预览联动
   注：jsdom 不做布局，故不验证像素几何（324×63 等），只验证「选中/焦点/缩略卡」三者索引一致 */
import { JSDOM } from 'jsdom';
import { readFileSync } from 'fs';
const html = readFileSync('../U2-核心界面原型-V0.4.5.html','utf8');
const errors=[];
const dom=new JSDOM(html,{runScripts:'dangerously',pretendToBeVisual:true,
  beforeParse(w){w.addEventListener('error',e=>errors.push(e.message));}});
const {window}=dom, d=window.document;
let pass=0,fail=0; const ok=(n,c,x='')=>{c?(pass++,console.log('  ✓ '+n)):(fail++,console.log('  ❌ '+n+(x?' → '+x:'')));};
const items=()=>[...d.querySelectorAll('#pager-m3 .page')[window.eval('st.m3.p')].querySelectorAll('.item, .new-card')];
const selIdx=()=>window.eval('st.m3.sel[st.m3.p]');

console.log('=== M3 焦点系统 × 缩略预览 ===');
ok('脚本零错误', errors.length===0, errors.join('|'));

// p0
ok('初始 p0 选中 0', selIdx()===0);
ok('第 0 张带 .sel', items()[0].classList.contains('sel'));
ok('焦点卡在 m3 clip 内', !!d.querySelector('#pager-m3'));

// 上下移动选中（selStep）
window.selStep('m3', 1);
ok('下移→sel=1', selIdx()===1);
ok('第 1 张带 .sel', items()[1].classList.contains('sel'));
ok('第 0 张已取消 sel', !items()[0].classList.contains('sel'));
ok('.sel 数量恒为 1', items().filter(i=>i.classList.contains('sel')).length===1);

window.selStep('m3', 1); window.selStep('m3', 1);
ok('继续下移→sel=3', selIdx()===3);
ok('末项带 .sel', items()[3].classList.contains('sel'));

// 边界
const t0 = window.eval("document.querySelector('#toast').textContent");
window.selStep('m3', 1);
ok('撞尾→提示已是最后一条', d.querySelector('#toast').textContent.includes('已是最后一条'), d.querySelector('#toast').textContent);
window.selStep('m3', -1); window.selStep('m3', -1); window.selStep('m3', -1);
window.selStep('m3', -1);
ok('撞头→提示已是第一条', d.querySelector('#toast').textContent.includes('已是第一条'), d.querySelector('#toast').textContent);

// 切到 p1：sel[1] 独立于 p0
window.eval("st.m3.p = 1");
ok('p1 选中索引独立=0', selIdx()===0);
window.eval("st.m3.p = 0");
ok('切回 p0 选中恢复 0', selIdx()===0);

// 切到 p2
window.eval("st.m3.p = 2");
ok('p2 4 行', items().length===4);
ok('p2 第 0 行带 .sel', items()[0].classList.contains('sel'));

// 无 data-open 行（RSS）选中不产生缩略卡
const miniOn = ()=>d.querySelector('#mini-m3').classList.contains('on');
ok('初始 p2(口味偏好·有d7) 出缩略卡', miniOn());
window.eval("st.m3.sel[2] = 3");  // RSS 源行（无 data-open）
window.renderSel('m3');
ok('选无 data-open 行 → 不出缩略卡', !miniOn());
window.eval("st.m3.sel[2] = 0");  // 口味偏好（有 d7）
window.renderSel('m3');
ok('选有 d7 行 → 缩略卡显示', miniOn(), 'on='+miniOn());

// p0 券卡 → d4 缩略卡
window.eval("st.m3.p = 0; st.m3.sel[0] = 0");
window.renderSel('m3');
ok('选券卡 → d4 缩略卡', miniOn());
ok('缩略卡标题=券名', d.querySelector('#mini-m3 .mp-title').textContent.includes('奶茶'), d.querySelector('#mini-m3 .mp-title').textContent);
ok('d4 双子页(页点 2 枚)', d.querySelectorAll('#mini-m3 .mp-dots i').length===2);

// 单例约束：切到 m1 后 m3 缩略卡应收起
window.eval("st.m1.p = 0; st.m1.sel[0] = 0");
window.goModule('m1');
ok('切 m1 后 m3 缩略卡收起（单例）', !miniOn());

console.log(`\n结果：${pass} 通过 / ${fail} 失败`);
process.exit(fail?1:0);
