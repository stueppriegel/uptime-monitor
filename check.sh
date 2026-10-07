#!/bin/bash
# Testa cada site de urls.txt e avisa no Telegram só quando o estado muda.
# Variáveis: TG_TOKEN, TG_CHAT (obrigatórias para enviar), URLS_FILE (opcional).
# Estado anterior em state/down.txt, linhas "url|código|epoch_início".
set -u
export TZ=America/Sao_Paulo
URLS_FILE=${URLS_FILE:-urls.txt}
mkdir -p state; touch state/down.txt; : > state/now.txt
now=$(date +%s)

fmt_ts() { date -d "@$1" '+%d/%m às %H:%M' 2>/dev/null || date -r "$1" '+%d/%m às %H:%M'; }
fmt_dur() {
  local s=$1 h m
  h=$((s/3600)); m=$(((s%3600)/60))
  if [ "$h" -gt 0 ]; then echo "${h}h ${m}min"
  elif [ "$m" -gt 0 ]; then echo "${m} min"
  else echo "menos de 1 min"; fi
}
describe() {
  case "$1" in
    000) echo "Sem resposta (timeout ou DNS)";;
    5??) echo "Erro no servidor";;
    4??) echo "Acesso recusado ou página ausente";;
    *)   echo "Resposta inesperada";;
  esac
}
host_of() { echo "$1" | sed -E 's#^https?://##; s#/.*##'; }
send() {
  [ -n "${TG_TOKEN:-}" ] && [ -n "${TG_CHAT:-}" ] || { echo "$1"; return; }
  curl -s -m 20 "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
    -d chat_id="$TG_CHAT" -d parse_mode=HTML -d disable_web_page_preview=true \
    --data-urlencode text="$1" >/dev/null
}

# 1) testar
while IFS='|' read -r name url; do
  [[ -z "$name" || "$name" == \#* || -z "$url" ]] && continue
  ok=0; code=000
  for try in 1 2 3; do
    code=$(curl -s -o /dev/null -m 20 -L -w '%{http_code}' "$url" || true)
    [[ "$code" =~ ^[23] ]] && { ok=1; break; }
    sleep 10
  done
  if [ "$ok" -eq 0 ]; then
    prev=$(grep -F "$url|" state/down.txt | head -1)
    since=$now; [ -n "$prev" ] && since=$(echo "$prev" | cut -d'|' -f3)
    echo "$url|$code|$since|$name" >> state/now.txt
  fi
done < "$URLS_FILE"

# 2) novos problemas
while IFS='|' read -r url code since name; do
  grep -qF "$url|" state/down.txt && continue
  send "🔴 <b>SITE INDISPONÍVEL</b>
━━━━━━━━━━━━━━
<b>${name}</b>
🌐 $(host_of "$url")
⚠️ HTTP ${code} · $(describe "$code")
🕐 Detectado em $(fmt_ts "$since")"
done < state/now.txt

# 3) recuperados
while IFS='|' read -r url code since name; do
  grep -qF "$url|" state/now.txt && continue
  name=${name:-$(host_of "$url")}
  send "🟢 <b>SITE RESTABELECIDO</b>
━━━━━━━━━━━━━━
<b>${name}</b>
🌐 $(host_of "$url")
⏱ Ficou fora por $(fmt_dur $((now-since)))
🕐 Normalizado em $(fmt_ts "$now")"
done < state/down.txt

cp state/now.txt state/down.txt
