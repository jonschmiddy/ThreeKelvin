- **Changed** — nothing a player will see; this is the co-op relay. It now answers a path that
  is not a party code without waking a party, drops a frame larger than the game's buffer,
  closes a socket that sends far faster than a ship can, and gives back the seat of a guest
  that joins and never says hello. Each limit is one of the game's own numbers, and a new test
  (`node --test relay/test/*.test.js`, in the gate) holds the two together.
