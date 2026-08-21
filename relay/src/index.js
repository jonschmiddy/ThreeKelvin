// Three Kelvin — party relay.
//
// A dumb pipe with a door policy. It assigns peer ids, routes frames between
// the four ships in a party, and knows nothing else: no game state, no rules,
// no authority. The host is still a player's machine. See docs/netcode.md §2.
//
// Three properties hold this up, and all three are about cost or correctness
// rather than features:
//
// 1. THE LOBBY CODE IS THE ADDRESS. `idFromName(code)` maps a party's code
//    straight onto its Durable Object. There is no room registry, no database
//    and nothing to allocate or clean up — a party exists exactly as long as
//    somebody is connected to it.
//
// 2. IT HIBERNATES. `ctx.acceptWebSocket()` rather than `server.accept()`, and
//    NO timers, alarms or outbound sockets anywhere in this file. A Durable
//    Object is billed for wall-clock time while it is in memory and unable to
//    hibernate, so an ordinary accept() bills for the entire hour a party is
//    connected — 450 GB-s — against a few GB-s for the milliseconds this file
//    actually spends executing. In capacity terms that is the difference
//    between the free tier carrying about 490 four-player dives a day and
//    about 28. Anything added here that keeps the object awake — a setInterval
//    keepalive is the obvious temptation — silently turns a free relay into a
//    metered one.
//
// 3. IT HOLDS NO STATE OF ITS OWN. Hibernation wipes memory, so every fact
//    about the room lives either in a socket's attachment or in storage.
//    A field on `this` would be null after the first ten idle seconds, which
//    is a bug that cannot happen in a test that never idles.

// Must match NetTransport.MAX_PLAYERS — see the note there. Both ends police
// the door, so a mismatch is a player this lets in that the host turns away.
const MAX_PLAYERS = 8;
const HOST_ID = 1;

// Frame types. Byte 0 of every message.
const T_HELLO = 1; // relay -> peer: [1][u32 your_id]
const T_JOIN = 2; // relay -> peer: [2][u32 peer_id]
const T_LEAVE = 3; // relay -> peer: [3][u32 peer_id]
const T_DENY = 4; // relay -> peer: [4][utf8 reason], then close
const T_DATA = 16; // both ways:    [16][i32 from][i32 to][u8 mode][u8 chan][payload]

const DATA_HEADER = 11;

// Close codes. 4000+ is the application range. The client turns these back into
// sentences, so they have to mean something specific rather than "closed".
const CLOSE_DENIED = 4001;
const CLOSE_HOST_LEFT = 4002;

export default {
	async fetch(request, env) {
		const url = new URL(request.url);
		const match = url.pathname.match(/^\/party\/([A-Za-z0-9]{1,16})$/);
		if (!match) {
			return new Response("Three Kelvin relay. Connect to /party/<code>.", {
				status: 404,
				headers: { "content-type": "text/plain" },
			});
		}
		if (request.headers.get("Upgrade") !== "websocket") {
			return new Response("Expected a WebSocket upgrade.", { status: 426 });
		}
		// Upper-cased so that a code typed in lower case reaches the same object
		// as the one the host was given. LobbyCode already folds case on the
		// client; this is the half that would otherwise still split the room.
		const code = match[1].toUpperCase();
		const id = env.PARTY.idFromName(code);
		return env.PARTY.get(id).fetch(request);
	},
};

export class Party {
	constructor(ctx, env) {
		this.ctx = ctx;
		this.env = env;
	}

	async fetch(request) {
		const url = new URL(request.url);
		const role = url.searchParams.get("role") === "host" ? "host" : "client";

		const pair = new WebSocketPair();
		const [client, server] = Object.values(pair);

		// Only sockets that were ADMITTED count as peers. A refused socket has no
		// attachment and lingers for the moment it takes the client to hang up —
		// counting those would let four bad join attempts wedge a room nobody
		// could then enter.
		const peers = this.ctx.getWebSockets().filter((ws) => attach(ws));
		const host = peers.find((ws) => attach(ws).role === "host");

		// The door policy, in the order the answers matter to a player.
		let deny = null;
		if (role === "host" && host) {
			deny = "That code is already hosting a party.";
		} else if (role === "client" && !host) {
			// The important refusal. Without it, joining a mistyped-but-valid code
			// silently creates an empty room and the player waits forever in a
			// party of one, which looks exactly like a network problem.
			deny = "No party with that code. Check it with the host.";
		} else if (peers.length >= MAX_PLAYERS) {
			deny = "The party is full.";
		}

		if (deny) {
			// Told why, and NOT hung up on. Closing here races the message: the
			// client's socket reports CLOSED and the engine discards whatever was
			// still buffered, so the player is told "the connection failed" when
			// the relay had just finished explaining that the party is full.
			//
			// The client closes itself the moment it reads a DENY, so the socket
			// is gone either way — and because a refused socket carries no
			// attachment, it is not a peer while it waits.
			this.ctx.acceptWebSocket(server);
			server.send(denyFrame(deny));
			return new Response(null, { status: 101, webSocket: client });
		}

		const peerId = role === "host" ? HOST_ID : await this.nextId();

		// acceptWebSocket, not server.accept(). See the header — this is the line
		// that decides whether the relay is free or metered.
		this.ctx.acceptWebSocket(server);
		server.serializeAttachment({ id: peerId, role });

		// Who you are, then who is already here, then tell them about you. In that
		// order: a JOIN that arrives before HELLO gives the client a roster entry
		// it cannot place, because it does not yet know its own id.
		server.send(u32Frame(T_HELLO, peerId));
		for (const other of peers) {
			const a = attach(other);
			if (a) server.send(u32Frame(T_JOIN, a.id));
		}
		this.broadcast(u32Frame(T_JOIN, peerId), server);

		return new Response(null, { status: 101, webSocket: client });
	}

	// Peer ids never repeat within a party's life. Deriving one from the live
	// sockets instead — max(id)+1 — reuses the number of whoever left last, and
	// a returning id collides with bookkeeping the other machines have not
	// finished tearing down yet.
	async nextId() {
		const next = ((await this.ctx.storage.get("nextId")) ?? 2) + 1;
		await this.ctx.storage.put("nextId", next);
		return next - 1;
	}

	async webSocketMessage(ws, message) {
		if (typeof message === "string") return; // text frames are not ours
		const view = new DataView(message);
		if (view.byteLength < DATA_HEADER || view.getUint8(0) !== T_DATA) return;

		const me = attach(ws);
		if (!me) return;

		// The sender does not get to say who it is. Rewriting `from` here is the
		// only security property this relay has, and it is worth the two lines:
		// without it any peer can post as the host, and the host is the authority.
		const out = message.slice(0);
		new DataView(out).setInt32(1, me.id, true);
		const to = view.getInt32(5, true);

		for (const peer of this.ctx.getWebSockets()) {
			const a = attach(peer);
			if (!a || peer === ws) continue;
			// Godot's targeting: 0 is everyone, a positive id is one peer, and a
			// negative id is everyone except that one.
			if (to > 0 && a.id !== to) continue;
			if (to < 0 && a.id === -to) continue;
			trySend(peer, out);
		}
	}

	async webSocketClose(ws) {
		this.departed(ws);
	}

	async webSocketError(ws) {
		this.departed(ws);
	}

	// When the host goes, the party goes. Migration is a real design question
	// and `docs/netcode.md` ruling N3 has not answered it — so the honest behaviour
	// for now is to end the dive loudly rather than to leave three ships
	// connected to a room with no authority in it, silently doing nothing.
	departed(ws) {
		const who = attach(ws);
		if (!who) return;
		if (who.role === "host") {
			for (const peer of this.ctx.getWebSockets()) {
				if (peer === ws) continue;
				try {
					peer.close(CLOSE_HOST_LEFT, "host left");
				} catch (e) {
					// Already gone. Nothing to do and nothing worth logging.
				}
			}
			return;
		}
		this.broadcast(u32Frame(T_LEAVE, who.id), ws);
	}

	broadcast(frame, except) {
		for (const peer of this.ctx.getWebSockets()) {
			if (peer === except) continue;
			trySend(peer, frame);
		}
	}
}

function attach(ws) {
	try {
		return ws.deserializeAttachment();
	} catch (e) {
		return null;
	}
}

function trySend(ws, data) {
	try {
		ws.send(data);
	} catch (e) {
		// A socket that closed between getWebSockets() and here. The close
		// handler will deal with it; throwing would abandon the rest of the room.
	}
}

function u32Frame(type, value) {
	const buf = new ArrayBuffer(5);
	const view = new DataView(buf);
	view.setUint8(0, type);
	view.setUint32(1, value, true);
	return buf;
}

function denyFrame(reason) {
	const body = new TextEncoder().encode(reason);
	const buf = new ArrayBuffer(1 + body.length);
	const view = new DataView(buf);
	view.setUint8(0, T_DENY);
	new Uint8Array(buf).set(body, 1);
	return buf;
}
