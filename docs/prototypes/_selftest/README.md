# 原型自测套件

对 `../U2-核心界面原型-V0.4.5.html` 的自动化自测。**改完原型必须复跑，全绿才算通过。**

## 运行

```bash
cd docs/prototypes && npm install jsdom      # 首次：装依赖（Node 会向上查找父目录）
cd docs/prototypes/_selftest

# 逐个执行（推荐，内存最稳）
node --max-old-space-size=320 m3logic-test.mjs    # M3 纯逻辑（无 DOM，最快）
node --max-old-space-size=320 m3dom-test.mjs      # M3 渲染与交互
node --max-old-space-size=320 m3-focus-test.mjs   # M3 焦点系统 × 缩略预览
node --max-old-space-size=320 m2-test.mjs         # M2 数据表 × 草稿三件套 × d9
node --max-old-space-size=320 m4-test.mjs         # M4 统计与设置 × 勋章实算 × 占位块
node --max-old-space-size=320 gap-test.mjs# 缺口回归（周条可点/d9 编辑闭环/文案对齐）
node --max-old-space-size=320 m1-regress.mjs      # M1 回归（确认新改动未破坏）

node run-all.mjs                                  # 一键跑全部
```

> **本机限制**：`run-all.mjs` 连续拉起 5 个子进程会超出沙箱内存上限被 SIGTERM，
> 请**逐个执行**上列 5 条命令（每套独立运行均稳定通过）。脚本本身逻辑正确，
> 在内存充裕的环境可正常一键运行。

## 测试职责

| 脚本 | 层 | 覆盖 | 项数 |
|---|---|---|---|
| `m3logic-test.mjs` | 逻辑 | 券四态/券码可见性/终态禁用、数据表字段、chips 筛选计数、收藏增减、p2 偏好 | 31 |
| `m3dom-test.mjs` | 渲染/交互 | p0/p1/p2 结构、d4 状态流转、d5 收藏联动、chips 真筛选与空态、d7 多选/slider | 58 |
| `m3-focus-test.mjs` | 焦点 | 选中索引↔焦点卡、边界提示、分页索引独立、缩略卡单例与 data-open 联动 | 23 |
| `m2-test.mjs` | 渲染/交互 | M2 数据表、草稿三件套（落盘/双子页/空态/发布出栈）、d9 详情与删除、月视图空态 | 49 |
| `m4-test.mjs` | 渲染/交互 | M4 数据表、三页渲染与data-open 接线、**统计全实算**（总局数/星星/连胜/趋势柱）、**勋章解锁实算**、d10~d13 填充与联动、设置开关、游戏本体占位块存在性 | 75 |
| `gap-test.mjs` | 回归 | 缺口固化：M1 周条 data-date 与点击、d9→d2 编辑态闭环（覆盖非新增/草稿解耦/提示清理）、d11 文案与实现一致、全局占位核查 | 37 |
| `m1-regress.mjs` | 回归 | M1 打卡全链路、d1/d3 保留、热力/周条、`isDetail` 通用判定、MINI/TOAST_TINT 键 | 21 |
| | | **合计** | **294** |

## 常规断言清单（每轮改动都要跑）

1. **`node --check`** — 抽出所有 `<script>` 块后语法校验
2. **CSS 注释平衡** — `s.count('/*') === s.count('*/')`
   > V0.3.10 事故：`:root` 里 `--h-row:63px;` 行尾 `/*` 未闭合，吞掉后续大量规则，隐性失效。
3. **函数唯一性** — grep `function xxx` 计数，重复定义会让新逻辑被旧逻辑覆盖
   > V0.2.4 事故：ghost 三函数双重定义
4. **硬编码清零** — 改判据前先 `count()`，禁止假设出现次数=1
   > V0.4.2 事故：`['d1','d2','d3'].includes(S.cur)` 实为 **5 处**，只改 1 处会形成半残导航栈
5. **乱码扫描** — `s.count('\uFFFD') === 0`
   > V0.4.3 事故：heredoc 写入中文产生 U+FFFD，肉眼难辨，需程序扫描
6. **全局委托冲突** — 新增 chip/点击元素时，检查是否与stage 级委托冲突，必要时放行
   > V0.4.3：d2 心情 chip、d7 偏好 chip 需从全局 chip 委托里 `return` 放行
7. **双击排除清单** — 新增二级页元素要补进 `isBlankTarget`，否则双击会误触返回上一级
8. **布局链回归** — `clip → pager → page → item` 宽度断言 + computed boxSizing
9. **可交互元素纳入焦点系统** — 新增非 `.item` 的可点元素（如 M4 `.badge`）时，`itemsOf` 与 stage 点击选择器**两处都要改**，否则该元素是死链
   > V0.4.4 事故：`.badge` 未纳入 → 勋章墙完全无法选中/进二级
10. **mpTitle 选择器按模块补全** — 新增卡片类型时同步，否则缩略预览标题取到图标字或分类标签
    > V0.4.2 / V0.4.4 两次事故：`.cp-t`（券卡）、`.gt-head .n`（游戏卡）
11. **文案承诺 ≥ 实际实现** — 写了「点 X 可…」就必须真有 X；做不到就改文案，不要留虚假承诺
    > V0.4.5 事故：d11「点条可看该局详情」但条目不可点
12. **静态搜索会误判，必须运行时断言** — 用正则查 `data-x=` 字面量会漏掉 JS 赋值（`el.dataset.x = ...`）
    > V0.4.5 教训：M1 周条 `data-date` 误判为缺失，运行时验证实为正常。**判「缺失」前先跑一次真实交互**

## 测试环境注意事项

- **`const` 声明不挂 `window`**：`MINI`/`TOAST_TINT`/`M2`/`M3` 需用 `window.eval("...")` 在页面上下文求值；只有 `function` 声明可直接 `window.xxx()`
- **文件位置 ≠ 执行时序**：`const` 无提升，但若调用点全在函数体内（交互时才执行），运行无虞——静态位置断言会误报 TDZ
- **jsdom 不做布局**：无 computed style / 真实 getBoundingClientRect，几何断言（焦点卡 324×63、光晕位置）需真实浏览器
- **本机无 Xcode**：仅 CommandLineTools（macOS 12.7.4 + Swift 5.7.2），无法编译 iOS 工程
- **系统 Chrome 与 macOS 版本不兼容**：Chrome 151 在 macOS 12 崩溃（VideoToolbox 符号缺失）

## 待补（需真实浏览器 / 真机）

- [ ] 焦点卡几何断言（324 宽 × 63 高精确覆盖选中项）
- [ ] pref-row 统一 63px 的 computed 高度验证
- [ ] d4 券面撕口 / d5 正文行高 / d9 全文排版 / 草稿卡视觉目检
- [ ] 手势链路：拖动吸附、横向接力、双击返回、碰撞回弹
- [ ] 真机：四态翻转判定、旋转链路、SwiftData 持久化、草稿永久保留