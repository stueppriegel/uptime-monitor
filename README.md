# uptime-monitor

Checa os sites listados em `urls.txt` a cada 5 minutos (GitHub Actions) e avisa
no Telegram quando algum cai ou volta. Roda fora da VPS, então também detecta
queda total do servidor.

Secrets necessários no repositório: `TG_TOKEN` e `TG_CHAT`.
Para adicionar um site, edite `urls.txt`.
