import Debug "mo:base/Debug";

shared({caller = admin}) actor class IcpCoins({ btc_price_usd: Float}) {

    type TokenId = Nat;
    type LatestTokenRow = ( (TokenId, TokenId), Text, Float );

    stable var btc_price = btc_price_usd;

    public shared query func get_latest(): async [LatestTokenRow] {
        // Somehow, the live neutrinite canister returns a pair BTC/USD and ckBTC/USD (not ckBTC/ckUSD)
        // This might be a problem when querying prices from token name
        [
            ((1, 0), "BTC/USD", btc_price)
        ];
    };

    public shared({caller}) func set_btc_price(price: Float) : async () {
        if (caller != admin) {
            Debug.trap("Only the admin can set the BTC price");
        };
        btc_price := price;
    };

};