# make-shopware

Shopware 6 bundle for the XDS (`make-core`): dev image on top of
the central FrankenPHP base image (`base/shopware` from the xebro ECR) plus
dedicated MySQL and Mailpit containers. The shop code lives versioned in
`./app` (Composer project, bootstrapped by `shopware.project`); the database
is ephemeral and gets rebuilt via `make init`.

## First-time setup

```bash
make install   # seed .env, create directories, register proxy route
make init      # pull base-dev image, bootstrap project, start containers,
               # install Shopware, theme + fixtures
```

## Project configuration (all via .env)

| Variable | Purpose |
|---|---|
| `XO_SHOPWARE_APP_URL` | Public base URL. Standalone `http://localhost:8080`; behind the proxy bundle `https://<XO_SERVER_NAME><XO_SHOP_PATH_PREFIX>` |
| `XO_SHOP_PATH_PREFIX` | Path prefix behind the proxy (default `/shop`) |
| `XO_SHOPWARE_TRUSTED_PROXIES` | `REMOTE_ADDR` behind the proxy, empty standalone |
| `XO_SHOPWARE_HEALTHCHECK_PATH` | `/` standalone; `/admin` behind the proxy (the domain no longer matches `/` then) |
| `XO_SHOPWARE_THEME` | Project theme plugin (empty = none) |
| `XO_SHOPWARE_FIXTURES_CMD` | `bin/console` command for demo data (empty = none) |
| `XO_SHOPWARE_BASE_DEV_TAG` | Tag of the dev image: rolling `base-dev` (default) or a pinned `dev-<build>` |

## Pinning the base image

Every build of `base-image-shopware` pushes the rolling `base-dev` tag plus
an immutable `dev-<build>` (same build number as `web-<build>` and
`ci-<build>` for the prod Dockerfile and the pipeline image). The bundle
stays version-neutral; a project pins in its committed `.env`:

```
XO_SHOPWARE_BASE_DEV_TAG=dev-118
```

Renovate keeps the pin current with a custom manager in the project repo
(needs read access to the ECR tag list, see the `renovate-runner` repo):

```json
{
  "customManagers": [
    {
      "customType": "regex",
      "managerFilePatterns": ["/^\\.env$/"],
      "matchStrings": ["XO_SHOPWARE_BASE_DEV_TAG=(?<currentValue>dev-\\d+)"],
      "depNameTemplate": "641495738494.dkr.ecr.eu-central-1.amazonaws.com/base/shopware",
      "datasourceTemplate": "docker",
      "versioningTemplate": "regex:^(?<compatibility>[a-z]+)-(?<major>\\d+)$"
    }
  ]
}
```

After a bump run `make shopware.build` (pull) and restart the containers.
Only the last 20 builds per variant are kept in the registry, so do not let
the pin fall that far behind.

## Worker and scheduler

The message queue is consumed by two dedicated containers, mirroring the
prod stack (ECS worker/scheduler services):

| Service | Command |
|---|---|
| `shopware-worker` | `messenger:consume async low_priority --time-limit=300` |
| `shopware-scheduler` | `scheduled-task:run --time-limit=300` |

Both exit after the time limit and are restarted by Docker. Targets:
`shopware.worker.logs`, `shopware.worker.restart` (message handlers are
loaded once per process — restart after changing them),
`shopware.scheduler.logs`.

Because a real worker is running, disable the browser admin worker in the
app (`shopware.admin_worker.enable_admin_worker: false`), otherwise two
open admin sessions collide on the consume lock (HTTP 409).

## Proxy integration

`shopware.install` registers the route
(`docker/config/proxy/20-shop.conf.template`): publicly the
`${XO_SHOP_PATH_PREFIX}` URL space is fully preserved; internally the proxy
strips the prefix and sets `X-Forwarded-Prefix` (Symfony convention — without
stripping, `/admin`, `/api` and `/store-api` would be 404 under the prefix).
The app needs `trusted_headers` including `x-forwarded-prefix` in
`app/config/packages/framework.yaml` for this. `shopware.domain` sets the
sales channel domain via SQL to `XO_SHOPWARE_APP_URL`
(`sales-channel:update:domain` cannot set a path).

## License

MIT License, Copyright (c) 2026 xebro GmbH. See [LICENSE](./LICENSE).
