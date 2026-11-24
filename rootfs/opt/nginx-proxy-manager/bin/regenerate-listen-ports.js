#!/usr/bin/env node

// Regenerate host configs after NPM_HTTP_PORT or NPM_HTTPS_PORT changes.
// Writes files only. Does not reload Nginx or update host meta.

import fs from "node:fs";
import { dirname, join } from "node:path";
import { chdir } from "node:process";
import { fileURLToPath } from "node:url";
import internalNginx from "../internal/nginx.js";
import { global as logger } from "../logger.js";
import { migrateUp } from "../migrate.js";
import deadHostModel from "../models/dead_host.js";
import proxyHostModel from "../models/proxy_host.js";
import redirectionHostModel from "../models/redirection_host.js";
import settingModel from "../models/setting.js";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
chdir(root);

const isMounted = (file) => {
	let info;
	try {
		info = fs.readFileSync("/proc/self/mountinfo", "utf8");
	} catch {
		return false;
	}
	return info.split("\n").some((line) => line.split(" ")[4] === file);
};

const loadEnabled = (model) => {
	return model
		.query()
		.where("is_deleted", 0)
		.andWhere("enabled", 1)
		.groupBy("id")
		.allowGraph(model.defaultAllowGraph)
		.withGraphFetched(`[${model.defaultExpand.join(", ")}]`)
		.orderBy(...model.defaultOrder);
};

const regenerateHosts = async (model, hostType, label) => {
	const rows = await loadEnabled(model);
	const kept = new Set();
	logger.info(`[${label}] Regenerating ${rows.length} config(s)`);

	for (const row of rows) {
		const file = internalNginx.getConfigName(hostType, row.id);
		if (isMounted(file)) {
			logger.warn(`Skipping mounted file ${file}`);
			kept.add(file);
			continue;
		}
		await internalNginx.generateConfig(hostType, row);
		kept.add(file);
	}

	const dir = `/data/nginx/${internalNginx.getFileFriendlyHostType(hostType)}`;
	if (!fs.existsSync(dir)) {
		return;
	}
	for (const name of fs.readdirSync(dir)) {
		if (!name.endsWith(".conf")) {
			continue;
		}
		const file = join(dir, name);
		if (kept.has(file) || isMounted(file)) {
			if (!kept.has(file) && isMounted(file)) {
				logger.warn(`Skipping mounted file ${file}`);
			}
			continue;
		}
		fs.unlinkSync(file);
		const errFile = `${file}.err`;
		if (fs.existsSync(errFile) && !isMounted(errFile)) {
			fs.unlinkSync(errFile);
		}
		logger.info(`Removed stale config ${file}`);
	}
};

const regenerateDefaultSite = async () => {
	const row = await settingModel.query().findById("default-site");
	if (!row) {
		return;
	}
	const file = internalNginx.getConfigName("default", row.id);
	if (isMounted(file)) {
		logger.warn(`Skipping mounted file ${file}`);
		return;
	}
	logger.info("[Default Site] Regenerating config");
	await internalNginx.generateConfig("default", row);

	const dir = "/data/nginx/default_host";
	if (!fs.existsSync(dir)) {
		return;
	}
	for (const name of fs.readdirSync(dir)) {
		if (!name.endsWith(".conf")) {
			continue;
		}
		const extra = join(dir, name);
		if (extra === file || isMounted(extra)) {
			continue;
		}
		fs.unlinkSync(extra);
		logger.info(`Removed stale config ${extra}`);
	}
};

const removeTemporaryConfigs = () => {
	const dir = "/data/nginx/temp";
	if (!fs.existsSync(dir)) {
		return;
	}
	for (const name of fs.readdirSync(dir)) {
		if (!name.endsWith(".conf")) {
			continue;
		}
		const file = join(dir, name);
		if (isMounted(file)) {
			logger.warn(`Skipping mounted file ${file}`);
			continue;
		}
		fs.unlinkSync(file);
		logger.info(`Removed temporary config ${file}`);
	}
};

try {
	await migrateUp();
	await regenerateHosts(proxyHostModel, "proxy_host", "Proxy Host");
	await regenerateHosts(redirectionHostModel, "redirection_host", "Redirection Host");
	await regenerateHosts(deadHostModel, "dead_host", "404 Host");
	await regenerateDefaultSite();
	removeTemporaryConfigs();
	await internalNginx.test();
	logger.info("Regenerated Nginx configs for the current listen ports");
	process.exit(0);
} catch (err) {
	logger.error(err && err.message ? err.message : String(err));
	process.exit(1);
}
