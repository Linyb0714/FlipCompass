#!/bin/bash
# 原型自测全跑（改完原型必跑，全绿才算通过）
# 依赖：cd docs/prototypes && npm install jsdom
cd "$(dirname "$0")" || exit 1

# Node 会向上查找父目录 node_modules，故依赖装在 prototypes/ 下即可
if [ ! -d ../node_modules/jsdom ]; then
  echo "缺少依赖，请执行：cd docs/prototypes && npm install jsdom"
  exit 2
fi

FAIL=0
TOTAL_PASS=0
TOTAL_FAIL=0

for t in m3logic-test m3dom-test m3-focus-test m1-regress; do
  # 每个测试独立 node 进程 + 内存上限：四个 jsdom 实例串在同一进程组会 OOM
  OUT=$(node --max-old-space-size=384 "$t.mjs" 2>&1)
  RES=$(echo "$OUT" | grep -E "^结果" | tail -1)
  P=$(echo "$RES" | grep -oE "[0-9]+ 通过" | grep -oE "[0-9]+")
  F=$(echo "$RES" | grep -oE "[0-9]+ 失败" | grep -oE "[0-9]+")
  [ -n "$P" ] && TOTAL_PASS=$((TOTAL_PASS + P))
  [ -n "$F" ] && TOTAL_FAIL=$((TOTAL_FAIL + F))
  printf "%-16s %s\n" "$t" "${RES:-无输出}"
  if ! echo "$RES" | grep -q "0 失败"; then
    FAIL=1
    echo "$OUT" | grep "❌" | head -5
  fi
done

echo "-------------------------------"
echo "合计 ${TOTAL_PASS} 通过 / ${TOTAL_FAIL} 失败"
if [ $FAIL -eq 0 ]; then echo "全部通过 ✓"; else echo "存在失败 ✗"; fi
exit $FAIL