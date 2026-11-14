// Three Kelvin — party relay: what it lets through.
//
// The pure half of the door: nothing here touches a socket, a clock or
// storage, so `relay/test/relay.test.js` runs it under plain Node. `index.js`
// supplies the time and the sockets.
//
// Every number is the game's own, with the file it was read from beside it.
// One that drifts below what the game really sends cuts a real party off, so
// change the game's constant and the one here together.

// --- the lobby code ---------------------------------------------------------
// `tkg/scripts/net/LobbyCode.gd`, the ROOM kind: R, five characters of Crockford
// base 32 (25 bits, so every body is a room), and a check character.
// `RelayTransport._open` sends it normalised: upper case, no separators, none
// of the four letters the alphabet leaves out.

export const ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
export const ROOM_HEAD = "R";
export const ROOM_CODE_LENGTH = 7;

// LobbyCode._check_char: the kind's own letter, then each body value times its
// place counted from one, mod 32.
export function checkChar(head, values) {
	const at = ALPHABET.indexOf(head);
	let sum = at >= 0 ? at : 7;
	for (let i = 0; i < values.length; i++) sum += values[i] * (i + 1);
	return ALPHABET[sum % 32];
}

// True for a code `LobbyCode.encode_room` can make, written as the game sends
// it. The caller folds case first; nothing else is forgiven here, because the
// game has already normalised what a player typed before it opens a socket.
export function isRoomCode(code) {
	if (typeof code !== "string" || code.length !== ROOM_CODE_LENGTH) return false;
	if (code[0] !== ROOM_HEAD) return false;
	const values = [];
	for (let i = 1; i < ROOM_CODE_LENGTH - 1; i++) {
		const v = ALPHABET.indexOf(code[i]);
		if (v < 0) return false;
		values.push(v);
	}
	return checkChar(ROOM_HEAD, values) === code[ROOM_CODE_LENGTH - 1];
}

// --- one frame --------------------------------------------------------------

export const T_DATA = 16;
export const DATA_HEADER = 11;

// `RelayPeer.BUFFER_BYTES`. The game gives its socket this much room each way,
// and the engine measures a WHOLE frame against it, header included: it will
// not send a larger one, and it hangs up on receiving one. So nothing a ship
// sends is over this, and a frame that is would cost every receiver its
// connection. The most payload a frame carries is MAX_FRAME - DATA_HEADER.
export const MAX_FRAME = 65536;

// A frame the relay passes on: binary, a whole DATA header, no larger than the
// game's buffer. `message` is what `webSocketMessage` was handed.
export function isDataFrame(message) {
	if (typeof message === "string") return false;
	if (message.byteLength < DATA_HEADER || message.byteLength > MAX_FRAME) return false;
	return new DataView(message).getUint8(0) === T_DATA;
}

// --- how fast one socket may talk -------------------------------------------
// A token bucket for each socket, kept in its attachment (`n` tokens, last
// topped up at `t` ms). Every frame that arrives takes one token, whatever it
// holds, because every frame wakes the object. A socket with none left is
// closed.
//
// What a real party of eight sends, from `tkg/scripts/net/NetSession.gd`:
//
//   A ship on a map says where it is at most once every 150 ms
//   (SPOT_EVERY_MS): 6.7 frames a second. The rest is one frame for each
//   thing a player does (a card, a jump, a part fitted, a flight leaving) and
//   at most one presence report a drawn frame.
//
//   A GUEST talks only to the host: about 7 frames a second while it flies.
//
//   The HOST passes every ship's spot on to every guest, and the engine sends
//   a broadcast as one frame to each receiver: 8 ships x 6.7 x 7 guests is
//   373 frames a second with all eight flying at once.
//
// The limits are far above both, and `burst` is ten seconds of `perSecond`,
// so a connection that stalls and then delivers what it queued is not taken
// for a fast one.
export const RATE = {
	host: { perSecond: 2000, burst: 20000 },
	client: { perSecond: 200, burst: 2000 },
};

export function rateFor(role) {
	return role === "host" ? RATE.host : RATE.client;
}

// Takes one token for a frame arriving at `now` (ms). Returns false, and
// changes nothing, when the bucket is empty. An attachment written before the
// bucket existed has no `n` and starts full.
export function takeToken(a, now, rate) {
	const had = typeof a.n === "number" ? a.n : rate.burst;
	const since = typeof a.t === "number" ? Math.max(0, now - a.t) : 0;
	const n = Math.min(rate.burst, had + (since * rate.perSecond) / 1000);
	if (n < 1) return false;
	a.n = n - 1;
	a.t = now;
	return true;
}

// --- a guest that never speaks ----------------------------------------------
// A joining ship says hello to the host the moment the relay admits it, and
// gives up by itself if the host has not answered in ten seconds
// (`NetSession.HANDSHAKE_TIMEOUT`). A guest's socket that has sent no DATA
// frame fifteen seconds after it was admitted is therefore not a ship, and its
// seat goes back to the party. There is no timer: `index.js` asks this when a
// frame or a connection arrives, so the object still sleeps between them.
export const SILENT_MS = 15000;

export function isSilent(a, now) {
	if (!a || a.role === "host" || a.spoke) return false;
	return typeof a.at === "number" && now - a.at > SILENT_MS;
}

// What an admitted socket's attachment holds. About 70 bytes serialised,
// against the 16,384 an attachment may be.
export function admitted(id, role, now) {
	return { id, role, at: now, spoke: false, n: rateFor(role).burst, t: now };
}
