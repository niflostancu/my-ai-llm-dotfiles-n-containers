/**
 * Custom welcome screen extension showing a logo, agent resources (prompt
 * files, skills, extensions etc.) and some other short info.
 */

import { execSync, ExecSyncOptionsWithStringEncoding } from "node:child_process";
import path from "node:path";

import type { ExtensionAPI, SourceInfo, Theme } from "@earendil-works/pi-coding-agent";
import { type Component, truncateToWidth, type TUI, wrapTextWithAnsi } from "@earendil-works/pi-tui";
import { DefaultResourceLoader, getAgentDir } from "@earendil-works/pi-coding-agent";

const CWD = process.cwd();

function getResourceLoader(): Promise<DefaultResourceLoader | undefined> {
	let loaderPromise = (async () => {
		try {
			const loader = new DefaultResourceLoader({
				cwd: CWD,
				agentDir: getAgentDir(),
			});
			await loader.reload();
			return loader;
		} catch {
			return undefined;
		}
	})();
	return loaderPromise;
}

// generated with https://patorjk.com/software/taag/
const LOGO = [
	" ",
	" ▗▄▄▖▗▄▄▄▖     ▗▄▖  ▗▄▄▖▗▄▄▄▖▗▖  ▗▖▗▄▄▄▖ ",
	" ▐▌ ▐▌ █      ▐▌ ▐▌▐▌   ▐▌   ▐▛▚▖▐▌  █   ",
	" ▐▛▀▘  █      ▐▛▀▜▌▐▌▝▜▌▐▛▀▀▘▐▌ ▝▜▌  █   ",
	" ▐▌  ▗▄█▄▖    ▐▌ ▐▌▝▚▄▞▘▐▙▄▄▖▐▌  ▐▌  █   ",
	" ",
];
/** Normal (frame) padding */
const LEFT_PAD = 1;
/** Value padding */
const VAL_PAD = 11;
/** Max columns */
const MAX_WIDTH = 120;

function wrapPadded(padding: number, text: string, width: number): string[] {
  const wrapped = wrapTextWithAnsi(text, width - padding);
  const continuation = " ".repeat(padding);
  return wrapped.map((line, index) => `${index === 0 ? "" : continuation}${line}`);
}

function infoLine(label: string, value: string, theme: Theme): string {
	return "".padStart(LEFT_PAD) +
		theme.fg("accent", label.padEnd(VAL_PAD)) +
		theme.fg("text", value)
}

export function contextFiles(loader: DefaultResourceLoader): string {
	const files = loader.getAgentsFiles().agentsFiles ?? [];
	if (!files.length) return "(none)";
	return files.map((f: { path: string }) => path.basename(f.path)).join(", ");
}

export function skills(loader: DefaultResourceLoader): string {
	const list = loader.getSkills().skills ?? [];
	if (!list.length) return "(none)";
	return list.map((s: { name: string }) => s.name).join(", ");
}

export function extensions(loader: DefaultResourceLoader): string {
	const list = loader.getExtensions().extensions ?? [];
	const getExtName = (resourcePath: string, sourceInfo?: SourceInfo) => {
		const source = sourceInfo?.source ?? "";
		if (source.startsWith("npm:") || source.startsWith("git:")) {
			return source;
		}
		const parsed = path.parse(resourcePath);
		let name = parsed.name;
		if (name == "index") { name = path.parse(parsed.dir).name }
		return `${name}`;
	};
	return list.map((ex) => getExtName(ex.path, ex.sourceInfo)).join(", ");
}

export function gitInfo(): string {
	// stdio: ignore stdin & stderr so "fatal: not a git repository" never leaks
	const opts: ExecSyncOptionsWithStringEncoding = {
		cwd: CWD,
		encoding: "utf8",
		timeout: 2000,
		stdio: ["ignore", "pipe", "ignore"],
	};
	try {
		const branch = execSync("git rev-parse --abbrev-ref HEAD", opts).trim();
		const out = execSync("git status --porcelain", opts);
		const files = out ? out.split("\n").filter(Boolean).length : 0;
		let upDown = "";
		try {
			const ahead = execSync("git rev-list --count @{upstream}..HEAD", opts)
				.trim();
			const behind = execSync("git rev-list --count HEAD..@{upstream}", opts)
				.trim();
			upDown = ` ↑${ahead} ↓${behind}`;
		} catch {
			// no upstream — that's fine
		}
		return `${branch} (${files} changed${upDown})`;
	} catch {
		return "not a git repo";
	}
}

function cwdLine(): string {
	return `${CWD} [${gitInfo()}]`;
}

export function piVersion(): string {
	try {
		return execSync("pi --version", {
			encoding: "utf8",
			stdio: ["ignore", "pipe", "ignore"],
		}).trim().replace(/^v?/i, "");
	} catch {
		return "unknown";
	}
}


class CustomHeader implements Component {
	private tui: TUI;
	private theme: Theme;
	private loader: DefaultResourceLoader | undefined;
	private _cachedLines: string[] | undefined;

	constructor(tui: TUI, theme: Theme, loader: DefaultResourceLoader | undefined) {
		this.tui = tui;
		this.theme = theme;
		this.loader = loader;
		this._cachedLines = undefined;
  	}

	render(width: number): string[] {
		if (this._cachedLines == undefined) {
			const maxWidth = Math.min(width, MAX_WIDTH);
			this._rebuild(maxWidth);
		}
		return this._cachedLines || [];
	}
	invalidate() {
		this._cachedLines = undefined;
	}
	/** Build the welcome lines once the update result is known. */
	private _rebuild(width: number) {
		let lines: string[] = LOGO.map((line) => 
			truncateToWidth(`${this.theme.fg("accent", line)}`, width));
		const pad = LEFT_PAD + VAL_PAD;

		lines.push(...wrapPadded(pad, infoLine("version", piVersion(), this.theme), width));
		if (this.loader != undefined) {
			lines.push(...wrapPadded(pad, infoLine("context", contextFiles(this.loader), this.theme), width));
			lines.push(...wrapPadded(pad, infoLine("skills", skills(this.loader), this.theme), width));
			lines.push(...wrapPadded(pad, infoLine("extensions", extensions(this.loader), this.theme), width));
			lines.push(...wrapPadded(pad, infoLine("cwd", cwdLine(), this.theme), width));
		} else {
			lines.push(...wrapPadded(pad, this.theme.fg("error",
				"Could not obtain a resourceLoader instance!"), width));
		}

		this._cachedLines = lines;
	}
}

export default function (pi: ExtensionAPI) {
	// Set custom header immediately on load (if UI is available)
	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		const loader = await getResourceLoader();
		if (!loader) return;
		ctx.ui.setHeader((tui, theme) => {
			return new CustomHeader(tui, theme, loader);
		});
	});
}
