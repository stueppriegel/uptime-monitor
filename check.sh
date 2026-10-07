#!/bin/bash
# Testa cada URL de urls.txt e avisa no Telegram só quando o estado muda.
# Variáveis: TG_TOKEN, TG_CHAT. Estado anterior em state/down.txt.
set -u
mkdir -p state; touch state/down.txt
: > state/now.txt

while read -r url; do
  [[ -z "$url" || "$url" == \#* ]] && continue
  ok=0
  for try in 1 2 3; do
    code=$(curl -s -o /dev/null -m 20 -L -w '%{http_code}' "$url" || true)
    [[ "$code" =~ ^[23] ]] && { ok=1; break; }
    sleep 10
  done
  [ "$ok" -eq 0 ] && echo "$url ($code)" >> state/now.txt
done < urls.txt

send() {
  curl -s -m 20 "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
    -d chat_id="$TG_CHAT" --data-urlencode text="$1" >/dev/null
}

sort -o state/now.txt state/now.txt
sort -o state/down.txt state/down.txt

new_down=$(comm -13 state/down.txt state/now.txt)
recovered=$(comm -23 state/down.txt state/now.txt | sed 's/ (.*//')

[ -n "$new_down" ] && send "🔴 Site fora do ar:"$'\n'"$(echo "$new_down" | sed 's/^/• /')"
[ -n "$recovered" ] && send "🟢 Site voltou:"$'\n'"$(echo "$recovered" | sed 's/^/• /')"

cp state/now.txt state/down.txt
