# make-shopware

Shopware-6-Bundle für das xebro-Dev-Setup (`make-core`): Dev-Image auf dem
zentralen FrankenPHP-Base-Image (`base/shopware` aus dem xebro-ECR) plus
eigener MySQL- und Mailpit-Container. Der Shop-Code liegt versioniert in
`./app` (Composer-Projekt, `shopware.project` bootstrapped ihn), die DB ist
flüchtig und wird per `make init` aufgebaut.

## Erstinstallation

```bash
make install   # .env seeden, Verzeichnisse, Proxy-Route registrieren
make init      # Image bauen, Projekt bootstrappen, Container starten,
               # Shopware installieren, Theme + Fixtures
```

## Projekt-Konfiguration (alles über .env)

| Variable | Zweck |
|---|---|
| `XO_SHOPWARE_APP_URL` | Öffentliche Basis-URL. Standalone `http://localhost:8080`; hinter dem proxy-Bundle `https://<XO_SERVER_NAME><XO_SHOP_PATH_PREFIX>` |
| `XO_SHOP_PATH_PREFIX` | Pfad-Präfix hinter dem Proxy (Default `/shop`) |
| `XO_SHOPWARE_TRUSTED_PROXIES` | `REMOTE_ADDR` hinter dem Proxy, leer standalone |
| `XO_SHOPWARE_HEALTHCHECK_PATH` | `/` standalone; `/admin` hinter dem Proxy (die Domain matcht `/` dann nicht mehr) |
| `XO_SHOPWARE_THEME` | Projekt-Theme-Plugin (leer = keins) |
| `XO_SHOPWARE_FIXTURES_CMD` | `bin/console`-Kommando für Demo-Daten (leer = keins) |

## Proxy-Integration

`shopware.install` registriert die Route
(`docker/config/proxy/20-shop.conf.template`): öffentlich bleibt der
`${XO_SHOP_PATH_PREFIX}`-URL-Raum vollständig erhalten, intern strippt der
Proxy den Präfix und setzt `X-Forwarded-Prefix` (Symfony-Konvention — sonst
wären `/admin`, `/api`, `/store-api` unter dem Präfix 404). Die App braucht
dafür `trusted_headers` inkl. `x-forwarded-prefix` in
`app/config/packages/framework.yaml`. `shopware.domain` setzt die
Sales-Channel-Domain per SQL auf `XO_SHOPWARE_APP_URL`
(`sales-channel:update:domain` kann keinen Pfad setzen).

## License

MIT License, Copyright (c) 2026 xebro GmbH. See [LICENSE](./LICENSE).
