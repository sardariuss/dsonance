import Debug "mo:base/Debug";

shared({caller = admin}) actor class IcpCoins() {

    type TokenId = Nat;

    type LatestTokenRow = ( (TokenId, TokenId), Text, Float );

    stable var btc_price = 100000.0;

    public shared query func get_latest(): async [LatestTokenRow] {
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