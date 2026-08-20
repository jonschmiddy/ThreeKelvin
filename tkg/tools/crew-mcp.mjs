#!/usr/bin/env node
// Three Kelvin — the crew seat, as an MCP server.
//
//   claude mcp add threekelvin -- node /abs/path/tkg/tools/crew-mcp.mjs /abs/path/mailbox
//
// A thin shim, and deliberately thin. All it does is read one file and write
// another; every rule about what is legal, what a board contains and what
// happens when nobody answers lives in `scripts/net/BotPilot.gd`, where the
// game is. Putting any of it here would mean two places that both believe they
// know the rules, and the one written in JavaScript would be the one that is
// wrong after the next balance change.
//
// The mailbox is the whole interface, which is why this file is optional. A
// shell one-liner plays the same game:
//
//   cat $MAILBOX/board.json
//   echo '{"seq": 7, "do": "play 2"}' > $MAILBOX/move.json
//
// This exists so that a Claude session can do it without a shell — not because
// the shell version is a workaround.
//
// No dependencies on purpose. MCP over stdio is newline-delimited JSON-RPC and
// that is about forty lines of Node; an npm install would make "play a game
// with me" require a package manager.

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const MAILBOX = process.argv[2] || process.env.THREEKELVIN_MAILBOX;
if (!MAILBOX) {
	console.error("usage: crew-mcp.mjs <mailbox-dir>   (or set THREEKELVIN_MAILBOX)");
	process.exit(1);
}
const BOARD = join(MAILBOX, "board.json");
const MOVE = join(MAILBOX, "move.json");

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function board() {
	if (!existsSync(BOARD)) return null;
	try {
		return JSON.parse(readFileSync(BOARD, "utf8"));
	} catch {
		// A board caught mid-write. The bot writes it in one call, so this is
		// rare and always transient — retrying is right and reporting an error
		// would be a lie about the game's state.
		return null;
	}
}

// Wait for a board, optionally a DIFFERENT one than the caller last saw. This
// is what makes a move feel like a move: play a card, get the hand it produced,
// rather than get the hand you just played out of.
async function waitBoard(afterSeq, seconds) {
	const until = Date.now() + seconds * 1000;
	for (;;) {
		const b = board();
		if (b && (afterSeq == null || b.seq !== afterSeq)) return b;
		if (Date.now() > until) return b;
		await sleep(250);
	}
}

const TOOLS = [
	{
		name: "look",
		description:
			"Read the current board: whose turn it is, the hand, the enemy's telegraphed " +
			"intent, the systems in range, or the station shelf. Every board carries a " +
			"`moves` array listing exactly what is legal right now, and a `seq` number. " +
			"Returns the raw board so nothing is lost in summarising it.",
		inputSchema: {
			type: "object",
			properties: {
				wait: {
					type: "number",
					description:
						"Seconds to wait for a board NEWER than `after`. Use when the " +
						"ship is mid-fight and the next decision has not been asked yet.",
				},
				after: {
					type: "number",
					description: "Only return a board whose seq differs from this one.",
				},
			},
		},
	},
	{
		name: "play",
		description:
			"Answer the current board and return whatever comes next. `move` must be one " +
			"of the strings in the board's `moves` array — e.g. 'play 2', 'end_turn', " +
			"'jump 41', 'buy 0', 'hold', 'flee', or 'pass' to hand this one decision to " +
			"the autopilot. A move is stamped with the board's seq, so an answer to a " +
			"board that has already moved on is dropped rather than misapplied.",
		inputSchema: {
			type: "object",
			properties: {
				move: { type: "string", description: "One entry from the board's `moves`." },
				wait: {
					type: "number",
					description: "Seconds to wait for the resulting board. Default 20.",
				},
			},
			required: ["move"],
		},
	},
];

async function call(name, args) {
	if (name === "look") {
		const b = await waitBoard(args.after ?? null, args.wait ?? 0);
		if (!b) return "No board yet. The ship has not been asked for a decision — " +
			"either it is still joining the party, or it is mid-turn and about to ask.";
		return JSON.stringify(b, null, 2);
	}

	if (name === "play") {
		const b = board();
		if (!b) return "No board to answer. Call look first.";
		const move = String(args.move ?? "").trim();
		if (!move) return "No move given.";
		// Not validated against b.moves on purpose. The bot checks legality
		// itself and says so in its log when a move does not apply; duplicating
		// the check here would mean a second opinion about the rules, and this
		// file is the one with no way to be right.
		writeFileSync(MOVE, JSON.stringify({ seq: b.seq, do: move }));
		const next = await waitBoard(b.seq, args.wait ?? 20);
		if (!next || next.seq === b.seq) {
			return `Sent "${move}" for board #${b.seq}. Nothing new yet — the ship may ` +
				`be waiting on the rest of the party, or resolving a fight.`;
		}
		return JSON.stringify(next, null, 2);
	}
	throw new Error(`no such tool: ${name}`);
}

// --- JSON-RPC over stdio --------------------------------------------------

let buf = "";
process.stdin.on("data", async (chunk) => {
	buf += chunk;
	let cut;
	while ((cut = buf.indexOf("\n")) >= 0) {
		const line = buf.slice(0, cut).trim();
		buf = buf.slice(cut + 1);
		if (line) await handle(line);
	}
});

function send(msg) {
	process.stdout.write(JSON.stringify(msg) + "\n");
}

async function handle(line) {
	let req;
	try {
		req = JSON.parse(line);
	} catch {
		return;
	}
	// Notifications carry no id and must not be answered. Replying to one is
	// a protocol error that some clients report as a hang.
	const id = req.id;
	try {
		if (req.method === "initialize") {
			return send({
				jsonrpc: "2.0",
				id,
				result: {
					protocolVersion: req.params?.protocolVersion ?? "2024-11-05",
					capabilities: { tools: {} },
					serverInfo: { name: "threekelvin-crew", version: "1.0.0" },
				},
			});
		}
		if (req.method === "tools/list") {
			return send({ jsonrpc: "2.0", id, result: { tools: TOOLS } });
		}
		if (req.method === "tools/call") {
			const text = await call(req.params.name, req.params.arguments ?? {});
			return send({
				jsonrpc: "2.0",
				id,
				result: { content: [{ type: "text", text }] },
			});
		}
		if (id === undefined) return;
		send({ jsonrpc: "2.0", id, error: { code: -32601, message: "method not found" } });
	} catch (e) {
		if (id === undefined) return;
		send({ jsonrpc: "2.0", id, error: { code: -32603, message: String(e) } });
	}
}
