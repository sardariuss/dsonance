import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Text "mo:base/Text";

module {
    /// Simple deterministic 64-bit PRNG (XorShift64*)
    /// Must store seed in stable var if you want continuity across upgrades.
    public class PRNG(stableSeed: { var seed: Nat64 }) {

        public func next64() : Nat64 {
            var x = stableSeed.seed;
            x ^= x >> 12;
            x ^= x << 25;
            x ^= x >> 27;
            stableSeed.seed := x;
            return x * 2685821657736338717;
        };

        public func nextBytes(n : Nat) : [Nat8] {
            let buf = Array.init<Nat8>(n, 0);
            var i = 0;

            while (i < n) {
                let r = next64();
                var j : Nat64 = 0;
                while (j < 8 and i < n) {
                    buf[i] := Nat8.fromNat(Nat64.toNat((r >> (j*8)) & 0xFF));
                    i += 1;
                    j += 1;
                };
            };

            Array.freeze(buf);
        };
    };

    /// UUIDv7 generator
    public class UUIDv7(prng : PRNG) {

        /// Generates a UUIDv7 string
        public func new() : Text {
            let timestamp_ms = Nat64.fromNat(Int.abs(Time.now())) / 1_000_000;
            let ts48 = timestamp_ms & 0xFFFFFFFFFFFF;

            // Extract timestamp parts
            let time_low = Nat32.fromNat(Nat64.toNat(ts48 & 0xFFFFFFFF));
            let time_mid = Nat16.fromNat(Nat64.toNat((ts48 >> 32) & 0xFFFF));
            let time_hi = (ts48 >> 48) & 0xFFF; // top 12 bits

            // Version 7 in high nibble of time_hi_and_version
            let time_hi_and_version : Nat16 = Nat16.fromNat(Nat64.toNat((time_hi & 0xFFF) | 0x7000));

            // rand_a: 12 bits, rand_b: 62 bits
            let rand_a = prng.next64() & 0xFFF;
            let rand_b = prng.next64() & 0x3FFFFFFFFFFFFFFF;

            // clock_seq: variant (10) + rand_a (12 bits) = 14 bits, top 2 bits = 10
            let clock_seq : Nat16 = Nat16.fromNat(Nat64.toNat((rand_a & 0x3FFF) | 0x8000));

            // node: 48 bits → 6 bytes, big-endian
            let node_bytes = Array.tabulate<Nat8>(6, func(i) {
                let shift = Nat64.fromNat((5 - i) * 8);
                Nat8.fromNat(Nat64.toNat((rand_b >> shift) & 0xFF))
            });

            // Build string
            toHex32(time_low) #
            "-" #
            toHex16(time_mid) #
            "-" #
            toHex16(time_hi_and_version) #
            "-" #
            toHex16(clock_seq) #
            "-" #
            Array.foldLeft(Array.map(node_bytes, toHex8), "", func(a: Text, b: Text): Text { a # b })
        };
    };

    func toHex8(n : Nat8) : Text {
        let hex = "0123456789abcdef";
        let hexArray = Text.toArray(hex);
        let hi = Nat8.toNat((n >> 4) & 0xF);
        let lo = Nat8.toNat(n & 0xF);
        Text.fromChar(hexArray[hi]) # Text.fromChar(hexArray[lo])
    };

    func toHex16(n : Nat16) : Text {
        let b1 = Nat8.fromNat(Nat16.toNat((n >> 8) & 0xFF));
        let b2 = Nat8.fromNat(Nat16.toNat(n & 0xFF));
        toHex8(b1) # toHex8(b2)
    };

    func toHex32(n : Nat32) : Text {
        let hi = Nat16.fromNat(Nat32.toNat((n >> 16) & 0xFFFF));
        let lo = Nat16.fromNat(Nat32.toNat(n & 0xFFFF));
        toHex16(hi) # toHex16(lo)
    }

};
