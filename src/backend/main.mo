import ProtocolTypes     "../protocol/Types";
import ProtocolInterface "../protocol/Interface";

import Map           "mo:map/Map";
import Array         "mo:base/Array";
import Principal     "mo:base/Principal";
import Result        "mo:base/Result";
import Option        "mo:base/Option";
import Debug         "mo:base/Debug";
import Time          "mo:base/Time";

shared({ caller = admin }) persistent actor class Backend({ protocol_id : Principal }) = this {

    type YesNoAggregate = ProtocolTypes.YesNoAggregate;
    type YesNoChoice = ProtocolTypes.YesNoChoice;
    type SPoolType = ProtocolTypes.SPoolType;
    type SPositionType = ProtocolTypes.SPositionType;
    type QueryDirection = ProtocolTypes.QueryDirection;
    type PoolInfo = {
        text: Text;
        visible: Bool;
        thumbnail: Blob;
    };
    type User = {
        principal: Principal;
        nickname: Text;
        joinedDate: Int;
    };
    type SYesNoPool = ProtocolTypes.SPool<YesNoAggregate, YesNoChoice> and { info: PoolInfo };
    type SYesNoPosition = ProtocolTypes.SPosition<YesNoChoice>;
    type SYesNoPositionWithUser = ProtocolTypes.SPosition<YesNoChoice> and { user: ?User };
    type Account = ProtocolTypes.Account;
    type UUID = ProtocolTypes.UUID;
    type GetPoolsByAuthorArgs = ProtocolTypes.GetPoolsByAuthorArgs;
    type SNewPoolResult = Result.Result<SYesNoPool, Text>;

    let protocol : ProtocolInterface.ProtocolActor = actor(Principal.toText(protocol_id));

    let _infos = Map.new<UUID, PoolInfo>();
    let _users = Map.new<Principal, User>();

    public shared({ caller }) func new_pool({
        text: Text;
        thumbnail: Blob;
        id: UUID;
        from_subaccount: ?Blob;
    }) : async SNewPoolResult {
        if (Principal.isAnonymous(caller)){
            return #err("Anonymous users cannot create a pool");
        };
        let new_result = await protocol.new_pool({ type_enum = #YES_NO; id; account = { owner = caller; subaccount = from_subaccount; } });
        Result.mapOk(new_result, func(pool_type: SPoolType) : SYesNoPool {
            switch(pool_type) {
                case(#YES_NO(pool)) {
                    let info = { text; thumbnail; visible = true; };
                    Map.set(_infos, Map.thash, pool.pool_id, info);
                    { pool with info; };
                };
            };
        });
    };

    public composite query func get_pool({ pool_id: UUID }) : async ?SYesNoPool {
        let pool = await protocol.find_pool({ pool_id; });
        Option.map(pool, func(pool_type: SPoolType) : SYesNoPool {
            with_info(pool_type);
        });
    };

    public composite query func get_pools({ previous: ?UUID; limit: Nat; direction: QueryDirection; }) : async [SYesNoPool] {

        // Fetch pools using the collected `filter_ids`
        let pools = await protocol.get_pools({ origin = Principal.fromActor(this); previous; limit; direction; });

        // Process and return pools
        Array.map(pools, func(pool_type: SPoolType) : SYesNoPool {
            with_info(pool_type);
        });
    };

    public composite query func get_pools_by_author(args: GetPoolsByAuthorArgs) : async [SYesNoPool] {
        let pools = await protocol.get_pools_by_author(args);
        Array.map(pools, func(pool_type: SPoolType) : SYesNoPool {
            with_info(pool_type);
        });
    };

    public shared({caller}) func set_pool_visible({pool_id: UUID; visible: Bool; }) : async Result.Result<(), Text> {

        if (caller != admin) {
            return #err("Only the admin can set or unset the visibility of a pool");
        };

        let info = switch(Map.get<UUID, PoolInfo>(_infos, Map.thash, pool_id)){
            case(null) { return #err("Pool not found"); };
            case(?i) { i; };
        };

        Map.set(_infos, Map.thash, pool_id, { info with visible; });
        #ok;
    };

    public shared func create_user({ principal: Principal; nickname: Text; }) : async Result.Result<User, Text> {
        if (Principal.isAnonymous(principal)) {
            return #err("Anonymous users cannot be created");
        };

        if (Map.has<Principal, User>(_users, Map.phash, principal)) {
            return #err("User already exists");
        };
        
        let user = { principal; nickname; joinedDate = Time.now(); };
        Map.set(_users, Map.phash, principal, user);
        #ok(user);
    };

    public query func get_user({ principal: Principal }) : async ?User {
        Map.get<Principal, User>(_users, Map.phash, principal);
    };

    public shared({ caller }) func set_user_nickname({ nickname: Text }) : async Result.Result<(), Text> {
        if (Principal.isAnonymous(caller)) {
            return #err("Anonymous users cannot set a nickname");
        };

        let user = switch(Map.get<Principal, User>(_users, Map.phash, caller)){
            case(null) { return #err("User not found"); };
            case(?u) { { u with nickname; }; };
        };

        Map.set(_users, Map.phash, caller, user);
        #ok;
    };

    public composite query func get_pool_positions(pool_id: Text) : async [SYesNoPositionWithUser] {
        let positions = await protocol.get_pool_positions(pool_id);
        Array.map(positions, func(position: ProtocolTypes.SPositionType) : SYesNoPositionWithUser {
            switch(position) {
                case(#YES_NO(b)) {
                    { b with user = Map.get<Principal, User>(_users, Map.phash, b.from.owner); };
                };
            };
        });
    };

    func with_info(pool_type: SPoolType) : SYesNoPool {
        switch(pool_type){
            case(#YES_NO(pool)) {
                switch(Map.get<UUID, PoolInfo>(_infos, Map.thash, pool.pool_id)){
                    case(null) { Debug.trap("Pool info not found"); };
                    case(?info) { { pool with info; }; };
                };
            };
        };
    };

    type SupportedStandard = {
        url: Text;
        name: Text;
    };

    public query func icrc10_supported_standards() : async [SupportedStandard] {
        return [
            {
                url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-10/ICRC-10.md";
                name = "ICRC-10";
            },
            {
                url = "https://github.com/dfinity/wg-identity-authentication/blob/main/topics/icrc_28_trusted_origins.md";
                name = "ICRC-28";
            }
        ];
    };

    type Icrc28TrustedOriginsResponse = {
        trusted_origins: [Text];
    };

    public func icrc28_trusted_origins() : async Icrc28TrustedOriginsResponse {
        let trusted_origins = [
            "https://hrr6s-tyaaa-aaaap-anxha-cai.icp0.io",
            "https://hrr6s-tyaaa-aaaap-anxha-cai.raw.icp0.io",
            "https://hrr6s-tyaaa-aaaap-anxha-cai.ic0.app",
            "https://hrr6s-tyaaa-aaaap-anxha-cai.raw.ic0.app",
            "https://hrr6s-tyaaa-aaaap-anxha-cai.icp0.icp-api.io",
            "https://hrr6s-tyaaa-aaaap-anxha-cai.icp-api.io",
            "https://app.dsonance.xyz",
        ];
        return { trusted_origins; };
    };

};