#--------------------------
# xebro GmbH - Shopware - 2.1.0
#--------------------------
# Everything project-specific comes from .env only: XO_SHOPWARE_THEME
# (project theme, empty = none), XO_SHOPWARE_FIXTURES_CMD (bin/console
# command for demo data, empty = none), XO_SHOPWARE_APP_URL (public base
# URL — behind the proxy bundle including XO_SHOP_PATH_PREFIX).

.PHONY: shopware.help shopware.logs shopware.bash shopware.console shopware.cmd shopware.cc \
        shopware.build.storefront shopware.watch.storefront shopware.build.admin shopware.watch.admin \
        shopware.db shopware.dump shopware.plugin.refresh shopware.plugin.install shopware.plugin.list \
        shopware.plugin.create shopware.plugin.uninstall \
        shopware.theme.create shopware.theme.change shopware.theme.compile shopware.theme.refresh shopware.theme.dump \
        shopware.install shopware.init shopware.project shopware.setup shopware.fixtures shopware.domain \
        shopware.build shopware.restart shopware.reset shopware.post_start shopware.debug \
        debug help install init post_start restart

# where the shop code lives relative to the project root ("." or e.g. "shop")
XO_SHOPWARE_PROJECT_DIR ?= .

DOCKER_SHOPWARE=${DOCKER_COMPOSE} exec shopware
DOCKER_SHOPWARE_DB=${DOCKER_COMPOSE} exec shopware-db
SHOPWARE_CONSOLE=${DOCKER_SHOPWARE} php /app/bin/console

SHOPWARE_DIR := $(patsubst $(XO_ROOT_DIR)/%,./%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
SHOPWARE_DIR_ABS := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

SHOPWARE := $(notdir $(patsubst %/,%,$(SHOPWARE_DIR)))

shopware.help:
	$(call add_help,${SHOPWARE_DIR}Makefile,"Shopware")

shopware.logs: ## Show shopware docker logs
	@${DOCKER_COMPOSE} logs -f shopware

shopware.bash: ## Open bash inside the shopware container
	@${DOCKER_SHOPWARE} bash

shopware.console: ## Run bin/console command via cmd variable (make shopware.console cmd=...)
	@${SHOPWARE_CONSOLE} $${cmd}

shopware.cmd: ## Run shell command inside the container, e.g. make shopware.cmd cmd="composer -V"
	@${DOCKER_SHOPWARE} bash -c "cd /app && $${cmd}"

shopware.cc: ## Clear the shopware cache
	$(call target_name,$@)
	@${SHOPWARE_CONSOLE} cache:clear

shopware.build.storefront: ## Compile the storefront (theme) assets
	$(call target_name,$@)
	@${DOCKER_SHOPWARE} bash -c "cd /app && ./bin/build-storefront.sh"

shopware.watch.storefront: ## Storefront hot-reload watcher
	@${DOCKER_SHOPWARE} bash -c "cd /app && ./bin/watch-storefront.sh"

shopware.build.admin: ## Compile the administration assets
	$(call target_name,$@)
	@${DOCKER_SHOPWARE} bash -c "cd /app && ./bin/build-administration.sh"

shopware.watch.admin: ## Administration hot-reload watcher
	@${DOCKER_SHOPWARE} bash -c "cd /app && ./bin/watch-administration.sh"

shopware.db: ## Open a MySQL shell on the shopware database
	@${DOCKER_SHOPWARE_DB} mysql -uroot -proot shopware

shopware.dump: ## Dump the shopware database to ./shopware.sql
	$(call target_name,$@)
	@${DOCKER_SHOPWARE_DB} mysqldump -uroot -proot shopware > shopware.sql
	@printf "${Purple}Dump written to: ${Yellow}./shopware.sql\n"

shopware.plugin.refresh: ## Refresh the plugin list
	$(call target_name,$@)
	@${SHOPWARE_CONSOLE} plugin:refresh

shopware.plugin.list: ## List all plugins
	@${SHOPWARE_CONSOLE} plugin:list

shopware.plugin.install: ## Install + activate a plugin, e.g. make shopware.plugin.install plugin=MyPlugin
	$(call target_name,$@)
	@${SHOPWARE_CONSOLE} plugin:refresh
	@${SHOPWARE_CONSOLE} plugin:install --activate $${plugin}
	@${SHOPWARE_CONSOLE} cache:clear

shopware.plugin.create: ## Scaffold a new plugin in ./custom/plugins, e.g. make shopware.plugin.create plugin=MyPlugin
	$(call target_name,$@)
	@${SHOPWARE_CONSOLE} plugin:create $${plugin}
	@${SHOPWARE_CONSOLE} plugin:refresh
	@printf "${Purple}Plugin created: ${Yellow}./custom/plugins/$${plugin}\n"
	@printf "${Purple}Install with:   ${Yellow}make shopware.plugin.install plugin=$${plugin}\n"

shopware.plugin.uninstall: ## Uninstall a plugin, e.g. make shopware.plugin.uninstall plugin=MyPlugin
	$(call target_name,$@)
	@${SHOPWARE_CONSOLE} plugin:uninstall $${plugin}
	@${SHOPWARE_CONSOLE} cache:clear

shopware.theme.create: ## Scaffold a new theme plugin in ./custom/plugins, e.g. make shopware.theme.create theme=MyTheme
	$(call target_name,$@)
	@${SHOPWARE_CONSOLE} theme:create $${theme}
	@${SHOPWARE_CONSOLE} plugin:refresh
	@printf "${Purple}Theme created: ${Yellow}./custom/plugins/$${theme}\n"
	@printf "${Purple}Activate with: ${Yellow}make shopware.plugin.install plugin=$${theme} && make shopware.theme.change theme=$${theme}\n"

shopware.theme.change: ## Assign a theme to all sales channels, e.g. make shopware.theme.change theme=MyTheme
	$(call target_name,$@)
	@${SHOPWARE_CONSOLE} theme:change $${theme} --all
	@${SHOPWARE_CONSOLE} cache:clear

shopware.theme.compile: ## Compile all assigned themes
	$(call target_name,$@)
	@${SHOPWARE_CONSOLE} theme:compile

shopware.theme.refresh: ## Reload theme.json configuration of all themes
	$(call target_name,$@)
	@${SHOPWARE_CONSOLE} theme:refresh

shopware.theme.dump: ## Dump theme config for hot-reload watchers
	$(call target_name,$@)
	@${SHOPWARE_CONSOLE} theme:dump

shopware.domain: ## Point the storefront sales channel domain to XO_SHOPWARE_APP_URL
	$(call target_name,$@)
	@# sales-channel:update:domain only replaces the host and cannot set a
	@# path prefix — hence direct SQL (the headless channel is kept).
	@${DOCKER_SHOPWARE_DB} mysql -uroot -proot shopware -e "UPDATE sales_channel_domain SET url='${XO_SHOPWARE_APP_URL}' WHERE url NOT LIKE '%headless%';" 2>/dev/null
	@${SHOPWARE_CONSOLE} cache:clear

shopware.install:
	$(call headline,"Installing shopware")
	$(call seed_env_vars,".env","${SHOPWARE_DIR}config/.env.seed")
	@mkdir -p ${XO_SHOPWARE_PROJECT_DIR}/custom/plugins ${XO_SHOPWARE_PROJECT_DIR}/custom/apps ${XO_SHOPWARE_PROJECT_DIR}/app
	@mkdir -p ${XO_CONFIG_DIR}/proxy
	$(call ensure_file,${SHOPWARE_DIR_ABS}config/20-shop.conf.template,${XO_CONFIG_DIR}/proxy)

shopware.init: shopware.install ## One-shot init: build image, bootstrap project, start containers, install Shopware + fixtures
	@$(MAKE) --no-print-directory shopware.build
	@$(MAKE) --no-print-directory shopware.project
	@$(MAKE) --no-print-directory docker.up
	@$(MAKE) --no-print-directory shopware.setup
	@$(MAKE) --no-print-directory shopware.post_start

shopware.project: ## Bootstrap the Shopware composer project into ./app (only if missing)
	$(call target_name,$@)
	@if [ -f ${XO_SHOPWARE_PROJECT_DIR}/app/composer.json ]; then \
		printf "${Purple}${XO_SHOPWARE_PROJECT_DIR}/app already contains a project, skipping create-project.\n"; \
	else \
		${DOCKER_COMPOSE} run --rm --no-deps shopware bash -c "composer create-project --no-interaction --no-install shopware/production:${XO_SHOPWARE_VERSION} /tmp/sw && cd /tmp/sw && composer config policy.advisories.ignore --json '[\"mcp/sdk\"]' && composer install --no-interaction && rsync -a /tmp/sw/ /app/"; \
	fi

shopware.setup: ## Install Shopware (DB schema, admin user, sales channel) + theme + fixtures
	$(call target_name,$@)
	@${DOCKER_SHOPWARE_DB} mysql -uroot -proot -N -e "SELECT COUNT(*) FROM shopware.sales_channel" 2>/dev/null | grep -qv '^0$$' \
		|| ${SHOPWARE_CONSOLE} system:install --create-database --basic-setup
	@${SHOPWARE_CONSOLE} plugin:refresh
	@if [ -n "${XO_SHOPWARE_THEME}" ]; then \
		${SHOPWARE_CONSOLE} plugin:install --activate ${XO_SHOPWARE_THEME} || true; \
		${SHOPWARE_CONSOLE} theme:change ${XO_SHOPWARE_THEME} --all; \
	fi
	@${SHOPWARE_CONSOLE} cache:clear
	@$(MAKE) --no-print-directory shopware.fixtures
	@${SHOPWARE_CONSOLE} theme:compile

shopware.fixtures: ## Rebuild demo content via XO_SHOPWARE_FIXTURES_CMD, e.g. make shopware.fixtures only=media
	$(call target_name,$@)
	@if [ -n "${XO_SHOPWARE_FIXTURES_CMD}" ]; then \
		${SHOPWARE_CONSOLE} ${XO_SHOPWARE_FIXTURES_CMD} $$(if [ -n "$${only}" ]; then echo "--only=$${only}"; fi); \
		${SHOPWARE_CONSOLE} cache:clear; \
	else \
		printf "${Purple}XO_SHOPWARE_FIXTURES_CMD not set, skipping fixtures.\n"; \
	fi

shopware.build: ## Pull the current base-dev image (built globally, no local build)
	@${DOCKER_COMPOSE} pull shopware

shopware.restart: ## Restart the shopware container
	$(call target_name,$@)
	@${DOCKER_COMPOSE} restart shopware

shopware.reset: ## Remove the shopware containers (DB is ephemeral); rebuild with make init
	@${DOCKER_COMPOSE} down shopware shopware-db shopware-mail

shopware.post_start:
	@$(call target_name,"Shopware")
	@printf "${Purple}Storefront:  ${Yellow}${XO_SHOPWARE_APP_URL}\n"
	@printf "${Purple}Admin:       ${Yellow}${XO_SHOPWARE_APP_URL}/admin ${Gray}(admin / shopware)\n"
	@printf "${Purple}Mailpit:     ${Yellow}http://localhost:${XO_SHOPWARE_MAIL_PORT}\n"
	@printf "${Purple}MySQL:       ${Yellow}localhost:${XO_SHOPWARE_DB_PORT} ${Gray}(root / root, db: shopware)\n"
	@printf "${Purple}Plugins DIR: ${Yellow}${XO_SHOPWARE_PROJECT_DIR}/custom/plugins\n"

shopware.debug: ## Print shopware component environment
	@$(call target_name,"DEBUGGING Shopware")
	@printf "${Purple}SHOPWARE: ${Yellow} ${SHOPWARE}\n"
	@printf "${Purple}SHOPWARE_DIR: ${Yellow} ${SHOPWARE_DIR}\n"
	@printf "${Purple}VERSION: ${Yellow} shopware/production ${XO_SHOPWARE_VERSION} ${Purple}BASE: ${Yellow}${BASE_ECR_REGISTRY}/base/shopware:base-web\n"

debug: shopware.debug
help: shopware.help
install: shopware.install
init: shopware.init
post_start: shopware.post_start
restart: shopware.restart
