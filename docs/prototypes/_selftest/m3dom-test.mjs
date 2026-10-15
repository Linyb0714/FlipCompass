import { JSDOM } from 'jsdom';
import { readFileSync } from 'fs';

const html = readFileSync('../U2-核心界面原型-V0.4.5.html','utf8');
const errors = [];
const dom = new JSDOM(html, { runScripts:'dangerously', pretendToBeVisual:true,
  beforeParse(w){ w.addEventListener('error', e=>errors.push('JS Error: '+e.message)); } });
const { window } = dom, d = window.document;

let pass=0, fail=0;
const ok=(n,c,extra='')=>{ if(c){pass++; console.log('  ✓ '+n);} else {fail++; console.log('  ❌ '+n+(extra?' → '+extra:''));} };

console.log('=== A. 渲染无错误 ===');
ok('脚本执行零错误', errors.length===0, errors.join(' | '));
ok('M3 p0 已渲染', d.querySelectorAll('#m3-p0 .item').length>0, d.querySelectorAll('#m3-p0 .item').length+' 张');
ok('M3 p1 已渲染', d.querySelectorAll('#m3-favs .item').length>0);
ok('M3 p2 已渲染', d.querySelectorAll('#m3-p2 .item').length===4);

console.log('\n=== B. p0 推送页结构 ===');
const p0 = d.querySelectorAll('#m3-p0 .item');
ok('4 张卡（1券+3情报）', p0.length===4, p0.length+' 张');
ok('券卡带 data-open="d4"', !!d.querySelector('#m3-p0 .coupon[data-open="d4"]'));
ok('情报卡带 data-open="d5"', d.querySelectorAll('#m3-p0 .info-card[data-open="d5"]').length===3);
ok('券卡有 data-id', !!d.querySelector('#m3-p0 .coupon[data-id="m3a"]'));
ok('券卡显示倒计时 3', d.querySelector('#m3-p0 .cp-count .n')?.textContent==='3');
ok('券卡进度条 72%', d.querySelector('#m3-p0 .cp-bar i')?.style.width==='72%');
ok('未收藏情报无角标', d.querySelectorAll('#m3-p0 .if-fav').length===0);

console.log('\n=== C. p1 收藏夹 ===');
const favs = d.querySelectorAll('#m3-favs .item');
ok('2 条收藏', favs.length===2, favs.length+' 条');
ok('均带 ♥ 角标', d.querySelectorAll('#m3-favs .if-fav').length===2);
ok('9 个 chips 齐备', d.querySelectorAll('#m3-chips .chip').length===9);
ok('首个 chip 为「全部」且 on', d.querySelector('#m3-chips .chip').classList.contains('on'));

console.log('\n=== D. p2 偏好（63px 统一 + data-open）===');
const prefs = d.querySelectorAll('#m3-p2 .pref-row');
ok('4 行', prefs.length===4);
ok('前 3 行带 data-open="d7"', d.querySelectorAll('#m3-p2 [data-open="d7"]').length===3);
ok('RSS 源行无 data-open(后置)', !d.querySelector('#m3-p2 .pref-row:last-child').dataset.open);
ok('口味偏好值已实算', d.querySelector('#m3-p2 .v').textContent==='偏甜 · 少辣 · 汤水党');

console.log('\n=== E. 头部胶囊实算 ===');
ok('胶囊=4（推送流条数·非硬编码12）', d.querySelector('#scr-m3 .head-chip b').textContent==='4', d.querySelector('#scr-m3 .head-chip b').textContent);

console.log('\n=== F. d4 券详情填充 ===');
const w = window;
w.fillD4('m3a');
ok('标题填充', d.querySelector('#d4-title').textContent==='奶茶买一送一');
ok('门槛填充', d.querySelector('#d4-thr').textContent.includes('满 20'));
ok('2 家门店', d.querySelectorAll('#d4-shops .cp-shop').length===2);
ok('未领: CTA=领取', d.querySelector('#d4-cta').textContent==='领取');
ok('未领: 状态胶囊', d.querySelector('#d4-state').textContent==='未领取');
ok('未领: 券码隐藏', d.querySelector('#d4-code').style.display==='none');
ok('未领: CTA 可点', d.querySelector('#d4-cta').disabled===false);

console.log('\n=== G. 券状态机流转 ===');
w.cpAdvance('m3a');
ok('→已领取: CTA', d.querySelector('#d4-cta').textContent==='标记已使用');
ok('→已领取: 状态', d.querySelector('#d4-state').textContent==='已领取');
ok('→已领取: 券码显示', d.querySelector('#d4-code').style.display==='flex');
w.cpAdvance('m3a');
ok('→已使用: CTA', d.querySelector('#d4-cta').textContent==='已使用');
ok('→已使用: 状态色类', d.querySelector('#d4-state').className.includes('used'));
ok('→已使用: 按钮 disabled', d.querySelector('#d4-cta').disabled===true);
w.cpAdvance('m3a');
ok('终态再点无效(仍已使用)', d.querySelector('#d4-state').textContent==='已使用');

console.log('\n=== H. d5 情报详情 + 收藏联动 ===');
w.fillD5('m3c');
ok('标题填充', d.querySelector('#d5-title').textContent.includes('绘本'));
ok('正文 3 段', d.querySelectorAll('#d5-text p').length===3);
ok('标签组渲染', d.querySelectorAll('#d5-tags span').length===2);
ok('未收藏: 文案', d.querySelector('#d5-favtxt').textContent==='收藏');
ok('p1 仍 2 条', d.querySelectorAll('#m3-favs .item').length===2);
w.toggleFav('m3c');
ok('收藏后 p1 → 3 条', d.querySelectorAll('#m3-favs .item').length===3);
ok('收藏后文案=已收藏', d.querySelector('#d5-favtxt').textContent==='已收藏');
ok('p0 该卡出现 ♥', !!d.querySelector('#m3-p0 [data-id="m3c"] .if-fav'));
w.toggleFav('m3c');
ok('取消后 p1 → 2 条', d.querySelectorAll('#m3-favs .item').length===2);

console.log('\n=== I. chips 真筛选 ===');
w.m3Filter('美食');
ok('美食 → 2 条', d.querySelectorAll('#m3-favs .item').length===2);
ok('美食 chip 变 on', d.querySelector('#m3-chips .chip[data-tag="美食"]').classList.contains('on'));
ok('全部 chip 取消 on', !d.querySelector('#m3-chips .chip[data-tag="全部"]').classList.contains('on'));
w.m3Filter('咖啡');
ok('咖啡 → 空态', !!d.querySelector('#m3-favs .chips-empty'));
ok('空态文案含标签名', d.querySelector('#m3-favs .chips-empty').textContent.includes('咖啡'));
w.m3Filter('全部');
ok('复位全部 → 2 条', d.querySelectorAll('#m3-favs .item').length===2);

console.log('\n=== J. d7 偏好编辑 ===');
w.fillD7('taste');
ok('标题=口味偏好', d.querySelector('#d7-title').textContent==='口味偏好');
ok('6 个 tag chip', d.querySelectorAll('#d7-tags .chip').length===6);
ok('预选 3 个(on)', d.querySelectorAll('#d7-tags .chip.on').length===3);
ok('slider 隐藏(多选态)', d.querySelector('#d7-slider').style.display==='none');
w.fillD7('price');
ok('price: slider 显示', d.querySelector('#d7-slider').style.display!=='none');
ok('price: tag 组隐藏', d.querySelector('#d7-tags').style.display==='none');
ok('price: 初始=适中', d.querySelector('#d7-cur').textContent==='适中');
w.d7Slider(2);
ok('slider→看品质', d.querySelector('#d7-cur').textContent==='看品质');
ok('knob 到 100%', d.querySelector('#d7-knob').style.left==='100%');

console.log(`\n结果：${pass} 通过 / ${fail} 失败`);
window.close();
process.exit(fail||errors.length?1:0);
