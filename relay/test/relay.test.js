// The relay's limits, under plain Node: `node --test relay/test/`.
// No install: node:test and node:assert only, nothing newer than Node 20.
//
// Two halves. The first holds `src/limits.js` (pure) to the game: the code
// check against codes the game itself made, the frame size, the bucket and
// the silent-guest rule with the time passed in. The second drives the real
// `src/index.js` through stand-ins for the sockets and the object, to see
// that a party of real ships gets exactly the frames it got before.
//
// `codes.fixture.json` was written ONCE by the game's own `LobbyCode`
// (`valid` from encode_room, `cases` with parse's verdict on each string). It
// is a record of what the game does, so do not edit it by hand: if LobbyCode
// changes, make it again from LobbyCode.

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import relay, { Party } from "../src/index.js";
import {
	ALPHABET,
	DATA_HEADER,
	MAX_FRAME,
	RATE,
	SILENT_MS,
	T_DATA,
	admitted,
	checkChar,
	isDataFrame,
	isRoomCode,
	isSilent,
	rateFor,
	takeToken,
} from "../src/limits.js";

const fixture = JSON.parse(readFileSync(new URL("./codes.fixture.json", import.meta.url), "utf8"));

// --- the lobby code -----------------------------------------------------------

test("every code the game made is a room code here", () => {
	assert.ok(fixture.valid.length >= 200, `the fixture holds ${fixture.valid.length} codes, under 200`);
	assert.equal(new Set(fixture.valid).size, fixture.valid.length, "a code is in the fixture twice");
	for (const code of fixture.valid) {
		assert.equal(isRoomCode(code), true, `${code} was made by LobbyCode.encode_room and is refused`);
	}
});

test("on strings near a code, the verdict is LobbyCode's", () => {
	assert.ok(fixture.cases.length >= 200, `the fixture holds ${fixture.cases.length} cases, under 200`);
	const refused = fixture.cases.filter((c) => !c.ok).length;
	assert.ok(refused >= 100, `only ${refused} of the cases are ones LobbyCode refuses`);
	for (const c of fixture.cases) {
		assert.equal(isRoomCode(c.code), c.ok, `${JSON.stringify(c.code)}: LobbyCode says ${c.ok}`);
	}
});

test("a malformed code is refused", () => {
	const good = fixture.valid[0];
	assert.equal(isRoomCode(good), true);
	const body = good.slice(1, 6);
	const check = good[6];

	assert.equal(isRoomCode(""), false, "empty");
	assert.equal(isRoomCode(undefined), false, "not a string");
	assert.equal(isRoomCode(good.slice(0, 6)), false, "a character short");
	assert.equal(isRoomCode(good + "0"), false, "a character long");
	assert.equal(isRoomCode("D" + body + check), false, "the direct kind's letter");
	assert.equal(isRoomCode("0" + body + check), false, "no kind letter");
	assert.equal(isRoomCode(good.toLowerCase()), false, "lower case: the caller folds case, not the check");
	assert.equal(isRoomCode(`R${body.slice(0, 2)}-${body.slice(2)}${check}`.slice(0, 7)), false, "a dash");
	for (const left of "ILOU") {
		assert.equal(isRoomCode(`R${left}${body.slice(1)}${check}`), false, `${left} is not in the alphabet`);
	}

	// Every other check character, on every code, is refused: exactly one of 32 passes.
	for (const code of fixture.valid) {
		let pass = 0;
		for (const c of ALPHABET) if (isRoomCode(code.slice(0, 6) + c)) pass++;
		assert.equal(pass, 1, `${code.slice(0, 6)}? has ${pass} check characters that pass`);
	}
});

test("the check character is LobbyCode._check_char", () => {
	// R is place 24 in the alphabet; the body's values are weighted 1..5.
	assert.equal(ALPHABET.length, 32);
	assert.equal(ALPHABET.indexOf("R"), 24);
	assert.equal(checkChar("R", [0, 0, 0, 0, 0]), ALPHABET[24]);
	assert.equal(checkChar("R", [1, 2, 3, 4, 5]), ALPHABET[(24 + 1 + 4 + 9 + 16 + 25) % 32]);
	assert.equal(checkChar("D", [0]), ALPHABET[13], "the kind is folded in, so a D and an R body differ");
});

// --- one frame ----------------------------------------------------------------

function dataFrame(total, to = 0, from = 99) {
	const buf = new ArrayBuffer(total);
	const view = new DataView(buf);
	view.setUint8(0, T_DATA);
	view.setInt32(1, from, true);
	view.setInt32(5, to, true);
	return buf;
}

test("a frame the size of the game's buffer passes, one byte more does not", () => {
	assert.equal(MAX_FRAME, 65536, "RelayPeer.BUFFER_BYTES");
	assert.equal(DATA_HEADER, 11, "RelayPeer.DATA_HEADER");
	assert.equal(isDataFrame(dataFrame(DATA_HEADER)), true, "a header and no payload");
	assert.equal(isDataFrame(dataFrame(MAX_FRAME)), true, "exactly the buffer");
	assert.equal(isDataFrame(dataFrame(MAX_FRAME + 1)), false, "one byte over");
	assert.equal(isDataFrame(dataFrame(MAX_FRAME + DATA_HEADER)), false, "a buffer of payload and a header");
	assert.equal(isDataFrame(dataFrame(1 << 20)), false, "the largest message the platform carries");
	assert.equal(isDataFrame(dataFrame(DATA_HEADER - 1)), false, "short of a header");
	assert.equal(isDataFrame("x".repeat(64)), false, "text");
	const other = dataFrame(64);
	new DataView(other).setUint8(0, 1);
	assert.equal(isDataFrame(other), false, "another frame type");
});

// --- the bucket ---------------------------------------------------------------

test("the limits sit well above what a party of eight sends", () => {
	// NetSession.SPOT_EVERY_MS = 150: a ship on a map, frames a second.
	const spot = 1000 / 150;
	const guest = spot; // to the host alone
	const host = 8 * spot * 7; // every ship's spot, one frame to each guest
	assert.ok(RATE.client.perSecond >= 10 * guest, "a guest's limit is under ten times what it sends");
	assert.ok(RATE.host.perSecond >= 4 * host, "the host's limit is under four times what it sends");
	for (const r of [RATE.host, RATE.client]) {
		assert.equal(r.burst, r.perSecond * 10, "the burst is ten seconds of the rate");
	}
	assert.equal(rateFor("host"), RATE.host);
	assert.equal(rateFor("client"), RATE.client);
	assert.equal(rateFor(undefined), RATE.client, "anything that is not the host is a guest");
});

test("a bucket starts full, empties, refuses, and fills again with time", () => {
	const rate = { perSecond: 10, burst: 5 };
	const a = { n: rate.burst, t: 1000 };
	for (let i = 0; i < 5; i++) assert.equal(takeToken(a, 1000, rate), true, `token ${i + 1} of the burst`);
	assert.equal(takeToken(a, 1000, rate), false, "the sixth in the same instant");
	const kept = { ...a };
	assert.equal(takeToken(a, 1050, rate), false, "50 ms is half a token");
	assert.deepEqual(a, kept, "a refusal changes nothing");
	assert.equal(takeToken(a, 1100, rate), true, "100 ms is one token");
	assert.equal(takeToken(a, 1100, rate), false);
	// A long quiet fills it to the burst and no further.
	assert.equal(takeToken(a, 1100 + 3600 * 1000, rate), true);
	assert.equal(a.n, rate.burst - 1);
	// A clock that steps back gives nothing and takes nothing away.
	const b = { n: 2, t: 5000 };
	assert.equal(takeToken(b, 4000, rate), true);
	assert.equal(b.n, 1);
	// An attachment from before the bucket existed starts full.
	const old = { id: 3, role: "client" };
	assert.equal(takeToken(old, 77, rate), true);
	assert.equal(old.n, rate.burst - 1);
	assert.equal(old.t, 77);
});

// How many of `frames` sent evenly over `seconds` get a token.
function passed(role, perSecond, seconds) {
	const a = admitted(2, role, 0);
	const total = Math.round(perSecond * seconds);
	let ok = 0;
	for (let i = 0; i < total; i++) {
		if (!takeToken(a, (i * 1000) / perSecond, rateFor(role))) break;
		ok++;
	}
	return { ok, total };
}

test("an hour of the busiest real party never empties a bucket", () => {
	const spot = 1000 / 150;
	// Twice the derived peak each, for the frames that are not spots.
	const host = passed("host", 2 * 8 * spot * 7, 3600);
	assert.equal(host.ok, host.total, "the host was cut off");
	const guest = passed("client", 2 * spot, 3600);
	assert.equal(guest.ok, guest.total, "a guest was cut off");
});

test("a stalled connection that then delivers ten seconds at once is not cut off", () => {
	const spot = 1000 / 150;
	const host = admitted(1, "host", 0);
	const backlog = Math.ceil(10 * 8 * spot * 7);
	for (let i = 0; i < backlog; i++) assert.equal(takeToken(host, 60000, RATE.host), true, `frame ${i}`);
});

test("a socket far faster than a ship runs out", () => {
	for (const role of ["host", "client"]) {
		const r = rateFor(role);
		const run = passed(role, r.perSecond * 2, 60);
		assert.ok(run.ok < run.total, `${role}: twice the limit for a minute passed whole`);
		// Twice the rate drains the burst in ten seconds, give or take a frame.
		assert.ok(Math.abs(run.ok - r.burst * 2) <= 2, `${role}: stopped after ${run.ok} frames`);
	}
});

// --- the silent guest -----------------------------------------------------------

test("a guest that has said nothing fifteen seconds after joining is silent", () => {
	assert.equal(SILENT_MS, 15000);
	assert.ok(SILENT_MS > 10000, "NetSession.HANDSHAKE_TIMEOUT: a real ship has given up by itself first");
	const t0 = 1_000_000;
	const guest = admitted(2, "client", t0);
	assert.equal(isSilent(guest, t0), false, "the moment it joined");
	assert.equal(isSilent(guest, t0 + SILENT_MS), false, "at fifteen seconds exactly");
	assert.equal(isSilent(guest, t0 + SILENT_MS + 1), true, "a millisecond past");
	assert.equal(isSilent(guest, t0 - 5000), false, "a clock that stepped back");

	const spoke = { ...guest, spoke: true };
	assert.equal(isSilent(spoke, t0 + 3600 * 1000), false, "a guest that spoke once is never silent");

	const host = admitted(1, "host", t0);
	assert.equal(isSilent(host, t0 + 3600 * 1000), false, "the host waits alone in a lobby as long as it likes");

	assert.equal(isSilent(null, t0), false, "a refused socket has no attachment");
	assert.equal(isSilent({ id: 3, role: "client" }, t0 + 3600 * 1000), false, "an attachment from before the rule");
});

// --- the game's own numbers ---------------------------------------------------
// Every limit is a constant of the game's, copied. This reads the game's files
// and fails when one of them moves, naming what to change with it.

test("the game still says what the limits were built on", () => {
	const read = (path) => readFileSync(new URL(`../../${path}`, import.meta.url), "utf8");
	const holds = (path, line, then) => {
		assert.ok(read(path).includes(line), `${path} no longer has \`${line}\`. ${then}`);
	};
	const code = "relay/src/limits.js (isRoomCode) is a copy of this check: change it to match, and make relay/test/codes.fixture.json again from LobbyCode.";
	const lobby = "tkg/scripts/net/LobbyCode.gd";
	holds(lobby, `const ALPHABET: String = "${ALPHABET}"`, code);
	holds(lobby, "const ROOM_BITS: int = 25", code);
	holds(lobby, '"R": kind = Kind.ROOM', code);
	holds(lobby, "var want := 12 if kind == Kind.DIRECT else 7", code);
	holds(lobby, "var sum := ALPHABET.find(head) if ALPHABET.find(head) >= 0 else 7", code);
	holds(lobby, "sum += values[i] * (i + 1)", code);
	holds(lobby, "return ALPHABET[sum % 32]", code);
	holds(
		"tkg/scripts/net/RelayTransport.gd",
		"base_url.trim_suffix(\"/\"), LobbyCode.normalise(room_code), role],",
		"The relay takes the code in LobbyCode's normal form (relay/src/limits.js, isRoomCode): send it that way, or change the relay first.",
	);

	const peer = "tkg/scripts/net/RelayPeer.gd";
	holds(peer, `const BUFFER_BYTES: int = ${MAX_FRAME}`, "relay/src/limits.js MAX_FRAME is this number: change it to match.");
	holds(peer, `const DATA_HEADER: int = ${DATA_HEADER}`, "relay/src/limits.js DATA_HEADER is this number: change it to match.");
	holds(peer, `const T_DATA: int = ${T_DATA}`, "relay/src/limits.js T_DATA is this number: change it to match.");

	const session = "tkg/scripts/net/NetSession.gd";
	holds(session, "const SPOT_EVERY_MS := 150", "relay/src/limits.js RATE was worked out from this: work it out again (a faster spot is more frames a second).");
	holds(session, "const HANDSHAKE_TIMEOUT: float = 10.0", "relay/src/limits.js SILENT_MS must stay longer than this: change it to match.");

	const seats = "relay/src/limits.js RATE was worked out for a party of this size: work it out again.";
	holds("tkg/scripts/net/NetTransport.gd", "const MAX_PLAYERS: int = 8", seats);
	holds("relay/src/index.js", "const MAX_PLAYERS = 8;", seats);
});

// --- the real relay, on stand-in sockets --------------------------------------
// Not the platform: these stand-ins do what the documentation says the real
// ones do and no more. A closed socket stays in getWebSockets(), as the real
// one may until the far end answers.

class Socket {
	constructor() {
		this.sent = [];
		this.closed = null;
		this.attachment = null;
		this.accepted = false;
	}
	accept() {
		this.accepted = true;
	}
	send(data) {
		if (this.closed) throw new Error("send on a closed socket");
		this.sent.push(data);
	}
	close(code, reason) {
		if (this.closed) throw new Error("closed twice");
		this.closed = { code, reason };
	}
	serializeAttachment(value) {
		this.attachment = structuredClone(value);
	}
	deserializeAttachment() {
		return structuredClone(this.attachment);
	}
}

class Ctx {
	constructor() {
		this.sockets = [];
		this.kept = new Map();
		this.storage = {
			get: async (k) => this.kept.get(k),
			put: async (k, v) => void this.kept.set(k, v),
		};
	}
	acceptWebSocket(ws) {
		this.sockets.push(ws);
	}
	getWebSockets() {
		return this.sockets.slice();
	}
}

// The three globals index.js takes from the platform, for the length of `fn`.
async function onPlatform(clock, fn) {
	const real = { pair: globalThis.WebSocketPair, response: globalThis.Response, now: Date.now };
	globalThis.WebSocketPair = class {
		constructor() {
			this[0] = new Socket();
			this[1] = new Socket();
		}
	};
	globalThis.Response = class {
		constructor(body, init = {}) {
			this.body = body;
			this.status = init.status ?? 200;
			this.webSocket = init.webSocket ?? null;
		}
	};
	Date.now = () => clock.now;
	try {
		return await fn();
	} finally {
		globalThis.WebSocketPair = real.pair;
		globalThis.Response = real.response;
		Date.now = real.now;
	}
}

function request(path, upgrade = true) {
	return {
		url: `https://relay.example${path}`,
		headers: { get: (name) => (upgrade && name === "Upgrade" ? "websocket" : null) },
	};
}

// One party: `join()` returns the relay's end of the new socket, which is where
// the frames sent TO that ship collect (`sent`).
function party() {
	const ctx = new Ctx();
	const room = new Party(ctx, {});
	const join = async (role) => {
		const before = ctx.sockets.length;
		const res = await room.fetch(request(`/party/R000000?role=${role}`));
		assert.equal(res.status, 101);
		assert.equal(ctx.sockets.length, before + 1, "the socket was not accepted for hibernation");
		return ctx.sockets[before];
	};
	return { ctx, room, join };
}

function frames(ws) {
	return ws.sent.map((buf) => {
		const view = new DataView(buf);
		const type = view.getUint8(0);
		if (type === 4) return `DENY ${new TextDecoder().decode(new Uint8Array(buf, 1))}`;
		if (type === T_DATA) return `DATA from ${view.getInt32(1, true)} to ${view.getInt32(5, true)} (${buf.byteLength})`;
		return `${{ 1: "HELLO", 2: "JOIN", 3: "LEAVE" }[type]} ${view.getUint32(1, true)}`;
	});
}

test("a real party sees the frames it always saw", async () => {
	const clock = { now: 5_000_000 };
	await onPlatform(clock, async () => {
		const { room, join } = party();
		const host = await join("host");
		assert.deepEqual(frames(host), ["HELLO 1"]);

		// The host waits a long while alone, then two friends arrive and say hello.
		clock.now += 45 * 60 * 1000;
		const a = await join("client");
		assert.deepEqual(frames(a), ["HELLO 2", "JOIN 1"]);
		await room.webSocketMessage(a, dataFrame(40, 1, 777));
		clock.now += 20000;
		const b = await join("client");
		assert.deepEqual(frames(b), ["HELLO 3", "JOIN 1", "JOIN 2"]);
		await room.webSocketMessage(b, dataFrame(40, 1));
		assert.deepEqual(frames(host), ["HELLO 1", "JOIN 2", "DATA from 2 to 1 (40)", "JOIN 3", "DATA from 3 to 1 (40)"]);

		// Godot's targeting, and `from` is the relay's word, not the sender's.
		await room.webSocketMessage(host, dataFrame(MAX_FRAME, 0, 55));
		await room.webSocketMessage(host, dataFrame(20, 3));
		await room.webSocketMessage(host, dataFrame(21, -3));
		const fromHost = ["DATA from 1 to 0 (65536)"];
		assert.deepEqual(frames(a).slice(2), ["JOIN 3", ...fromHost, "DATA from 1 to -3 (21)"]);
		assert.deepEqual(frames(b).slice(3), [...fromHost, "DATA from 1 to 3 (20)"]);

		// An hour in the lobby with nobody speaking costs nobody a seat.
		clock.now += 3600 * 1000;
		await room.webSocketMessage(host, dataFrame(12, 0));
		assert.equal(a.closed, null);
		assert.equal(b.closed, null);

		// A guest leaves; then the host does, and the party ends as before.
		const seenByB = b.sent.length;
		await room.webSocketClose(a);
		assert.deepEqual(frames(b).slice(seenByB), ["LEAVE 2"]);
		await room.webSocketClose(host);
		assert.deepEqual(b.closed, { code: 4002, reason: "host left" });
	});
});

test("the door's answers are the ones it gave", async () => {
	const clock = { now: 9_000 };
	await onPlatform(clock, async () => {
		const { ctx, room, join } = party();
		const lost = await join("client");
		assert.deepEqual(frames(lost), ["DENY No party with that code. Check it with the host."]);
		assert.equal(lost.closed, null, "told why and not hung up on");
		assert.equal(lost.attachment, null, "a refused socket is not a peer");

		const host = await join("host");
		const second = await join("host");
		assert.deepEqual(frames(second), ["DENY That code is already hosting a party."]);

		const guests = [];
		for (let i = 0; i < 7; i++) {
			const g = await join("client");
			await room.webSocketMessage(g, dataFrame(30, 1));
			guests.push(g);
		}
		const ninth = await join("client");
		assert.deepEqual(frames(ninth), ["DENY The party is full."]);
		assert.equal(ctx.sockets.filter((ws) => ws.attachment && !ws.attachment.gone).length, 8);
		assert.equal(host.closed, null);
	});
});

test("a path that is not a code gets the missing party's answer, and no object", async () => {
	const clock = { now: 1 };
	await onPlatform(clock, async () => {
		let reached = 0;
		const env = {
			PARTY: {
				idFromName: (name) => name,
				get: () => ({
					fetch: async () => {
						reached++;
						return new Response(null, { status: 101 });
					},
				}),
			},
		};
		const good = fixture.valid[5];

		// A real code reaches its object, in either case, under the upper-case name.
		const names = [];
		env.PARTY.idFromName = (name) => (names.push(name), name);
		await relay.fetch(request(`/party/${good}?role=host`), env);
		await relay.fetch(request(`/party/${good.toLowerCase()}?role=client`), env);
		assert.equal(reached, 2);
		assert.deepEqual(names, [good, good]);

		// One with a wrong check character does not, for either role.
		const wrong = good.slice(0, 6) + ALPHABET[(ALPHABET.indexOf(good[6]) + 1) % 32];
		for (const role of ["client", "host"]) {
			const res = await relay.fetch(request(`/party/${wrong}?role=${role}`), env);
			assert.equal(res.status, 101, "the socket opens, as it does for a code nobody hosts");
			// (the stand-in pair: [0] is handed to the caller, [1] is the relay's end)
			assert.ok(res.webSocket instanceof Socket);
		}
		assert.equal(reached, 2, "a malformed code reached an object");

		// The words are the missing party's, byte for byte.
		const sockets = [];
		const RealPair = globalThis.WebSocketPair;
		globalThis.WebSocketPair = class extends RealPair {
			constructor() {
				super();
				sockets.push(this[1]);
			}
		};
		await relay.fetch(request(`/party/${wrong}?role=client`), env);
		await relay.fetch(request("/party/D0000000000?role=client"), env);
		globalThis.WebSocketPair = RealPair;
		assert.equal(sockets.length, 2);
		for (const s of sockets) {
			assert.equal(s.accepted, true);
			assert.deepEqual(frames(s), ["DENY No party with that code. Check it with the host."]);
			assert.equal(s.closed, null, "told why and not hung up on");
		}

		// And what was never a party path is answered as before.
		assert.equal((await relay.fetch(request("/"), env)).status, 404);
		assert.equal((await relay.fetch(request("/party/R0000-00"), env)).status, 404);
		assert.equal((await relay.fetch(request(`/party/${good}`, false), env)).status, 426);
		assert.equal(reached, 2);
	});
});

test("a guest that never speaks gives its seat back when the next ship arrives", async () => {
	const clock = { now: 100_000 };
	await onPlatform(clock, async () => {
		const { room, join } = party();
		const host = await join("host");
		const quiet = [];
		for (let i = 0; i < 7; i++) quiet.push(await join("client"));
		const talker = quiet.pop();
		await room.webSocketMessage(talker, dataFrame(30, 1));

		// Inside fifteen seconds the party is simply full.
		clock.now += SILENT_MS;
		assert.deepEqual(frames(await join("client")), ["DENY The party is full."]);
		assert.ok(quiet.every((q) => q.closed === null));

		// Past it, the next arrival is seated, and the party is told who left.
		clock.now += 1;
		const seenByHost = host.sent.length;
		const friend = await join("client");
		for (const q of quiet) assert.deepEqual(q.closed, { code: 1008, reason: "said nothing" });
		assert.equal(talker.closed, null, "a guest that spoke was turned out");
		assert.equal(host.closed, null);
		assert.deepEqual(frames(friend), ["HELLO 9", "JOIN 1", "JOIN 8"]);
		assert.deepEqual(frames(host).slice(seenByHost), ["LEAVE 2", "LEAVE 3", "LEAVE 4", "LEAVE 5", "LEAVE 6", "LEAVE 7", "JOIN 9"]);

		// The far end answering the close does not announce the leaving twice.
		const before = host.sent.length;
		for (const q of quiet) await room.webSocketClose(q);
		assert.equal(host.sent.length, before);
	});
});

test("a frame arriving is also when the silent are counted", async () => {
	const clock = { now: 100_000 };
	await onPlatform(clock, async () => {
		const { room, join } = party();
		const host = await join("host");
		const quiet = await join("client");
		clock.now += SILENT_MS + 1;
		await room.webSocketMessage(host, "a text frame is enough to ask");
		assert.deepEqual(quiet.closed, { code: 1008, reason: "said nothing" });
		assert.deepEqual(frames(host), ["HELLO 1", "JOIN 2", "LEAVE 2"]);

		// A guest whose first frame is itself late is kept: it spoke before it was counted.
		const late = await join("client");
		clock.now += SILENT_MS + 5000;
		await room.webSocketMessage(late, dataFrame(30, 1));
		assert.equal(late.closed, null);
		// Frames that are not DATA do not count as speaking.
		const mute = await join("client");
		await room.webSocketMessage(mute, "hello");
		await room.webSocketMessage(mute, dataFrame(DATA_HEADER - 1, 1));
		await room.webSocketMessage(mute, dataFrame(MAX_FRAME + 1, 1));
		clock.now += SILENT_MS + 1;
		await room.webSocketMessage(host, dataFrame(12, 0));
		assert.deepEqual(mute.closed, { code: 1008, reason: "said nothing" });
		assert.equal(late.closed, null);
	});
});

test("a frame over the game's buffer is dropped and the socket kept", async () => {
	const clock = { now: 100_000 };
	await onPlatform(clock, async () => {
		const { room, join } = party();
		const host = await join("host");
		const guest = await join("client");
		const seen = host.sent.length;
		await room.webSocketMessage(guest, dataFrame(MAX_FRAME + 1, 1));
		await room.webSocketMessage(guest, dataFrame(1 << 20, 0));
		assert.equal(host.sent.length, seen, "an oversize frame was passed on");
		assert.equal(guest.closed, null);
		await room.webSocketMessage(guest, dataFrame(MAX_FRAME, 1));
		assert.deepEqual(frames(host).slice(seen), ["DATA from 2 to 1 (65536)"]);
	});
});

test("a socket that outruns its bucket is closed with 1008 and the party told", async () => {
	const clock = { now: 100_000 };
	await onPlatform(clock, async () => {
		const { room, join } = party();
		const host = await join("host");
		const guest = await join("client");
		const other = await join("client");
		await room.webSocketMessage(other, dataFrame(30, 1));
		const seen = host.sent.length;

		// The whole burst passes, in one instant; the next frame does not.
		for (let i = 0; i < RATE.client.burst; i++) await room.webSocketMessage(guest, dataFrame(12, 1));
		assert.equal(guest.closed, null);
		assert.equal(host.sent.length, seen + RATE.client.burst);
		await room.webSocketMessage(guest, dataFrame(12, 1));
		assert.deepEqual(guest.closed, { code: 1008, reason: "too many frames" });
		assert.deepEqual(frames(host).slice(-1), ["LEAVE 2"]);
		assert.deepEqual(frames(other).slice(-1), ["LEAVE 2"]);

		// What it sends after that goes nowhere, and its seat is free.
		const after = host.sent.length;
		await room.webSocketMessage(guest, dataFrame(12, 1));
		await room.webSocketClose(guest);
		assert.equal(host.sent.length, after);

		// The count is kept in the attachment, so it holds across a sleep: text
		// frames and short ones spend tokens too.
		const texter = await join("client");
		for (let i = 0; i < RATE.client.burst; i++) await room.webSocketMessage(texter, "x");
		assert.equal(texter.closed, null);
		await room.webSocketMessage(texter, "x");
		assert.deepEqual(texter.closed, { code: 1008, reason: "too many frames" });

		// A host that outruns its own ends the party the way a host leaving does.
		for (let i = 0; i < RATE.host.burst; i++) await room.webSocketMessage(host, "x");
		assert.equal(host.closed, null);
		await room.webSocketMessage(host, "x");
		assert.deepEqual(host.closed, { code: 1008, reason: "too many frames" });
		assert.deepEqual(other.closed, { code: 4002, reason: "host left" });
	});
});

test("a refused socket that talks anyway is closed", async () => {
	const clock = { now: 100_000 };
	await onPlatform(clock, async () => {
		const { room, join } = party();
		const lost = await join("client");
		assert.equal(lost.closed, null);
		await room.webSocketMessage(lost, dataFrame(30, 0));
		assert.deepEqual(lost.closed, { code: 1008, reason: "not in the party" });
		// And again, while the close is still on its way: nothing is thrown.
		await room.webSocketMessage(lost, dataFrame(30, 0));
	});
});
