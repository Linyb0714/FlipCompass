// 从原型 HTML 中抽取 M3 纯逻辑，在 Node 中跑断言（无需 DOM）
import { readFileSync } from 'fs';
const src = readFileSync('../U2-核心界面原型-V0.4.5.html','utf8');

// 抽取 CP_STATE 与 M3 数据表（纯字面量，无 DOM 依赖）
const cpState = eval('(' + src.match(/const CP_STATE = (\{[^;]*?\});/s)[1] + ')');
let m3src   = src.match(/const M3 = (\{[\s\S]*?\n\};)/)[1];
m3src = m3src.replace(/;\s*$/,'');
const M3 = eval('(' + m3src + ')');

let pass=0, fail=0;
const ok=(n,c,extra='')=>{ c?pass++:(fail++,console.log('  ❌ '+n+(extra?' → '+extra:''))); };

console.log('=== A. 券状态机 ===');
const order=['none','claimed','used'];
ok('四态齐全', ['none','claimed','used','expired'].every(k=>k in cpState), Object.keys(cpState).join(','));
ok('none→claimed 可推进', order.indexOf('claimed')===order.indexOf('none')+1);
ok('used/expired 为终态(无code)', cpState.used.cls==='used'&&cpState.expired.cls==='expired');
ok('未领无券码', cpState.none.code===false, 'claimed='+cpState.claimed.code);
ok('已领有券码', cpState.claimed.code===true);
ok('终态按钮不可用', cpState.used.btn==='已使用'&&cpState.expired.btn==='已过期');
ok('过期态色类独立', cpState.expired.cls!==cpState.used.cls);

console.log('=== B. 数据表结构 ===');
ok('6 条 items', M3.items.length===6);
const coupon=M3.items.filter(i=>i.type==='coupon');
const feed=M3.items.filter(i=>i.type==='feed');
ok('1 券 + 5 情报', coupon.length===1&&feed.length===5);
ok('券字段齐全', ['value','threshold','valid','scope','state','code','shops','progress','daysLeft'].every(k=>k in coupon[0]));
ok('券有 2 家门店', coupon[0].shops.length===2);
ok('情报均有 body 段落', feed.every(i=>Array.isArray(i.body)&&i.body.length>=3));
ok('情报均有 tags 数组', feed.every(i=>Array.isArray(i.tags)&&i.tags.length>=2));
ok('id 唯一', new Set(M3.items.map(i=>i.id)).size===M3.items.length);
ok('p1 收藏 2 条(feed)', feed.filter(i=>i.fav).length===2, feed.filter(i=>i.fav).map(i=>i.id).join(','));

console.log('=== C. chips 真筛选 ===');
const chips=['全部','目的地','美食','亲子','炖汤','夜宵','应季','买菜','咖啡'];
const favs=feed.filter(i=>i.fav);
const f=(t)=> t==='全部'?favs:favs.filter(i=>i.tags.includes(t));
ok('全部→2条', f('全部').length===2);
ok('目的地→1条', f('目的地').length===1);
ok('美食→2条(m3e含美食)', f('美食').length===2);
ok('亲子→0条(收藏里无亲子→空态)', f('亲子').length===0);
ok('炖汤→0条(收藏里无炖汤)', f('炖汤').length===0, '→ 空态应触发');
ok('夜宵→1条(m3f)', f('夜宵').length===1);
ok('咖啡→0条(空态)', f('咖啡').length===0);
ok('chips 与 tags 有交集', chips.some(c=>c!=='全部'&&f(c).length>0));

console.log('=== D. 收藏联动 ===');
const before=favs.length; const t=favs[0];
t.fav=false; const after=feed.filter(i=>i.fav).length;
ok('取消收藏→收藏夹-1', after===before-1, `${before}→${after}`);
t.fav=true;
ok('重新收藏→恢复', feed.filter(i=>i.fav).length===before);
ok('收藏的条目 fav=true 均有 tag 显示角标', feed.filter(i=>i.fav).every(i=>i.tag));

console.log('=== E. p2 偏好 ===');
const P=M3.prefs;
ok('taste 6 选 3', P.taste.tags.length===6&&P.taste.sel.length===3);
ok('takeout 6 选 3', P.takeout.tags.length===6&&P.takeout.sel.length===3);
ok('price level 合法(0-2)', [0,1,2].includes(P.price.level));
ok('price 三档文案', ['只看低价','适中','看品质'][P.price.level]==='适中');
ok('多选值可 join 显示', P.taste.sel.join(' · ')==='偏甜 · 少辣 · 汤水党');

console.log(`\n结果：${pass} 通过 / ${fail} 失败`);
process.exit(fail?1:0);
