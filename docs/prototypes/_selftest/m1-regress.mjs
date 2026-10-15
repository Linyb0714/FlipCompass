import { JSDOM } from 'jsdom';
import { readFileSync } from 'fs';
const html = readFileSync('../U2-核心界面原型-V0.4.5.html','utf8');
const errors=[];
const dom=new JSDOM(html,{runScripts:'dangerously',pretendToBeVisual:true,
  beforeParse(w){w.addEventListener('error',e=>errors.push(e.message));}});
const {window}=dom, d=window.document;
let pass=0,fail=0; const ok=(n,c,x='')=>{c?(pass++,console.log('  ✓ '+n)):(fail++,console.log('  ❌ '+n+(x?' → '+x:'')));};

console.log('=== M1 回归（确认 V0.4.5 改动未破坏）===');
ok('脚本零错误', errors.length===0, errors.join('|'));
ok('p0 清单 4 项', d.querySelectorAll('#pager-m1 .page')[0].querySelectorAll('.item').length===4);
ok('p2 管理页 = new-card + 4 行 + 说明', d.querySelectorAll('#pager-m1 .page')[2].querySelectorAll('.new-card').length===1);
ok('打卡行 data-open="d1"', d.querySelectorAll('#pager-m1 .task[data-open="d1"]').length===4);
ok('管理行 data-open="d3"', d.querySelectorAll('#pager-m1 .row-item[data-open="d3"]').length===4);
ok('热力图 42 格', d.querySelectorAll('#heat-m1 i').length===42);
ok('周条 21 格', d.querySelectorAll('#weekStrip .ws-cell').length===21);
ok('统计胶囊 今日 1/4', d.querySelector('#stat-today')?.textContent==='1/4');
ok('待机 M1 胶囊仍动态', d.querySelector('#pill-m1')?.textContent.includes('还有'));
ok('M2 d2 页保留', !!d.querySelector('#scr-d2'));
ok('d1 详情页保留', !!d.querySelector('#scr-d1'));
ok('d3 表单页保留', !!d.querySelector('#scr-d3'));
// 打卡流回归
window.checkDone('m1b');
ok('M1 打卡后统计 2/4', d.querySelector('#stat-today')?.textContent==='2/4');
ok('M1 打卡后胶囊 2 项', d.querySelector('#pill-m1')?.textContent.includes('2'));
// 通用导航回归
const det = w => w.eval("isDetail('d4')") && w.eval("isDetail('d5')") && !w.eval("isDetail('m3')") && !w.eval("isDetail('idle')");
ok('isDetail 通用判定 d4/d5=真·m3/idle=假', det(window));
// MINI 缩略预览
ok('MINI 含 d4/d5/d7', window.eval("!!(MINI.d4 && MINI.d5 && MINI.d7)"));
ok('TOAST_TINT 含 d4/d5/d7', window.eval("!!(TOAST_TINT.d4 && TOAST_TINT.d5 && TOAST_TINT.d7)"));
ok('函数体内无 d1d2d3 硬编码', window.eval("!/\\['d1','d2','d3'\\]/.test(String(goModule)+String(backOneLevel)+String(backToIdle))"));
ok('renderM3 已挂载', window.eval("typeof renderM3 === 'function'"));
ok('M3 数据表 6 条', window.eval("M3.items.length")===6);
ok('M3 p0 推送 4 条(inFeed)', window.eval("M3.items.filter(x=>x.inFeed).length")===4);
console.log(`\n结果：${pass} 通过 / ${fail} 失败`);
process.exit(fail?1:0);
