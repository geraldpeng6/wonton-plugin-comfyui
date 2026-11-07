# shellcheck shell=bash disable=SC2034
# SSO/MCP/IDENTITY_NA/SMOKE_NOTE 由探针套件（scripts/probes.sh）读取。

# ComfyUI：sso=none（应用无登录，网关会话即身份）；清单没有 mcp。
SSO=none
MCP=0

web_assert() { grep -qi '<title>ComfyUI</title>'; }

# ComfyUI 没有可断言的用户体系：单用户、无登录，能打开网页的人就是网关认出的用户。
IDENTITY_NA=1
SMOKE_NOTE="ComfyUI 单用户无登录，没有当前用户接口；网关会话挡在应用前面"

# 用户数据：保存的工作流存在数据目录 user/default/workflows/（经 userdata API 写读），
# 升级和重装都不该丢。
data_write() {
  local marker body url
  [[ -n "${SMOKE_WEB_URL:-}" ]] || { echo "SMOKE_WEB_URL 未设置（探针套件没取到网页地址）"; return 1; }
  url="${SMOKE_WEB_URL%/}"   # 套件给的地址带尾斜杠，拼路径前去掉，避免 //userdata 打不进路由
  marker="wonton-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
  body="$(jq -nc --arg m "$marker" '{"marker":$m,"nodes":[]}')"
  curl -sS --noproxy '*' --fail-with-body -b "$SMOKE_JAR" -X POST \
    --data-binary "$body" -H 'Content-Type: application/json' \
    "$url/userdata/workflows%2Fsmoke-$marker.json?overwrite=true" >/dev/null ||
    { echo "POST $url/userdata/workflows%2Fsmoke-$marker.json 失败（jar=$SMOKE_JAR 大小=$(wc -c <"$SMOKE_JAR" 2>/dev/null) wonton_app=$(grep -c wonton_app "$SMOKE_JAR" 2>/dev/null)）"; return 1; }
  printf '%s' "$marker" > "$SMOKE_STATE/comfyui-data-marker" || { echo "存不了标记：$SMOKE_STATE"; return 1; }
}

data_check() {
  local marker got url
  [[ -n "${SMOKE_WEB_URL:-}" ]] || { echo "SMOKE_WEB_URL 未设置（探针套件没取到网页地址）"; return 1; }
  url="${SMOKE_WEB_URL%/}"
  marker="$(cat "$SMOKE_STATE/comfyui-data-marker" 2>/dev/null)" || { echo "读不到标记"; return 1; }
  got="$(curl -sS --noproxy '*' --fail-with-body -b "$SMOKE_JAR" "$url/userdata/workflows%2Fsmoke-$marker.json")" ||
    { echo "工作流 smoke-$marker.json 读不回来"; return 1; }
  grep -qF "\"marker\":\"$marker\"" <<<"$got" ||
    { echo "读回的内容对不上：$(head -c 200 <<<"$got")"; return 1; }
}
