// Load environment variables from .env file
require('dotenv').config({ path: '../../.env' });

const { getActor } = require("./actor.cjs");
const { toNs } = require("./duration.cjs");
const { Ed25519KeyIdentity } = require("@dfinity/identity");
const { Principal } = require('@dfinity/principal');
// v4 from UUID
const { v4: uuidv4 } = require('uuid');
const seedrandom = require('seedrandom');

const VOTES_TO_OPEN = [
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
    "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
    "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
    "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",
    "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
    "Curabitur pretium tincidunt lacus, a suscipit velit luctus id.",
    "Integer in diam a magna pharetra venenatis eget at urna.",
    "Etiam at ante auctor, vehicula purus at, aliquet mauris.",
    "Nullam ac sem a purus fringilla vehicula non at urna.",
    "Cras vulputate nulla ut turpis facilisis, eget ultricies odio scelerisque.",
    "Nam consectetur, est id vulputate viverra, felis metus suscipit leo, nec luctus justo elit nec lectus.",
    "In quis lorem at nisl mattis condimentum a non ligula.",
    "Vestibulum tincidunt orci eget erat ultricies, sed lobortis urna vehicula.",
    "Praesent feugiat quam ut turpis finibus, et scelerisque orci lobortis.",
    "Suspendisse faucibus eros et ligula suscipit fermentum.",
    "Donec ultricies justo vitae fermentum sagittis.",
    "Vivamus convallis dui id turpis porttitor, a egestas libero elementum.",
    "Aliquam erat volutpat, suspendisse scelerisque metus at metus suscipit aliquam.",
    "Mauris efficitur purus eget enim finibus, non eleifend velit convallis.",
    "Ut sagittis lacus a ipsum suscipit, nec facilisis lorem faucibus."
];

const NUM_USERS = 10;
const BTC_USER_BALANCE = 100_000_000n;
const DSN_USER_BALANCE = 100_000_000_000n;
const MEAN_BALLOT_AMOUNT = 20_000;
const NUM_VOTES = 5;
const SCENARIO_DURATION = { 'DAYS': 18n };
const SCENARIO_TICK_DURATION = { 'DAYS': 3n };

const CKBTC_FEE = 10n;
const DSN_FEE = 1_000n;

const sleep = (ms) => {
    return new Promise(resolve => setTimeout(resolve, ms));
}

const exponentialRandom = (mean) => {
    return -mean * Math.log(Math.random());
};

const generateDeterministicRandom = (voteId) => {
    const rng = seedrandom(voteId);
    return rng(); // Returns a number between 0 and 1
}

const getRandomUserActor = (userActors) => {
    let randomUser = Math.floor(Math.random() * NUM_USERS);
    let randomUserPrincipal = Array.from(userActors.keys())[randomUser];
    return userActors.get(randomUserPrincipal);
}
  
// Example function to call a canister method
async function callCanisterMethod() {
    
    // Import the IDL factory dynamically
    const { idlFactory: protocolFactory } = await import("../../.dfx/local/canisters/protocol/service.did.js");
    const { idlFactory: minterFactory } = await import("../../.dfx/local/canisters/minter/service.did.js");
    const { idlFactory: backendFactory } = await import("../../.dfx/local/canisters/backend/service.did.js");
    const { idlFactory: ckBtcFactory } = await import("../../.dfx/local/canisters/ck_btc/service.did.js");
    const { idlFactory: dsnLedgerFactory } = await import("../../.dfx/local/canisters/dsn_ledger/service.did.js");

    // Retrieve canister ID from environment variables
    const protocolCanisterId = process.env.CANISTER_ID_PROTOCOL;
    const minterCanisterId = process.env.CANISTER_ID_MINTER;
    const backendCanisterId = process.env.CANISTER_ID_BACKEND;
    const ckBtcCanisterId = process.env.CANISTER_ID_CK_BTC;
    const dsnLedgerCanisterId = process.env.CANISTER_ID_DSN_LEDGER;

    if (!protocolCanisterId){
        throw new Error("Protocol canister ID is missing");
    }
    if (!minterCanisterId){
        throw new Error("Minter canister ID is missing");
    }
    if (!backendCanisterId){
        throw new Error("Backend canister ID is missing");
    }
    if (!ckBtcCanisterId){
        throw new Error("ckBTC canister ID is missing");
    }
    if (!dsnLedgerCanisterId){
        throw new Error("DSN Ledger canister ID is missing");
    }

    // Simulation actors

    let simIdentity = Ed25519KeyIdentity.generate();

    let protocolActor = await getActor(protocolCanisterId, protocolFactory, simIdentity);
    if (protocolActor === null) {
        throw new Error("Protocol actor is null");
    }

    let backendSimActor = await getActor(backendCanisterId, backendFactory, simIdentity);
    if (backendSimActor === null) {
        throw new Error("BackendSim actor is null");
    }

    let minterActor = await getActor(minterCanisterId, minterFactory, simIdentity);
    if (minterActor === null) {
        throw new Error("ckBTC actor is null");
    }

    // Get user actors for each principal in a Map<Principal, Map<string, Actor>>

    let userActors = new Map();

    for (let i = 0; i < NUM_USERS; i++) {
        let identity = Ed25519KeyIdentity.generate();
        let protocolActor = await getActor(protocolCanisterId, protocolFactory, identity);
        if (protocolActor === null) {
            throw new Error("Protocol actor is null");
        }
        let backendActor = await getActor(backendCanisterId, backendFactory, identity);
        if (backendActor === null) {
            throw new Error("Backend actor is null");
        }
        let ckbtcActor = await getActor(ckBtcCanisterId, ckBtcFactory, identity);
        if (ckbtcActor === null) {
            throw new Error("ckBTC actor is null");
        }
        let dsnLedgerActor = await getActor(dsnLedgerCanisterId, dsnLedgerFactory, identity);
        if (dsnLedgerActor === null) {
            throw new Error("DSN Ledger actor is null");
        }
        userActors.set(identity.getPrincipal(), { "protocol": protocolActor, "backend": backendActor, "ckbtc": ckbtcActor, "dsn_ledger": dsnLedgerActor });
    }

    // Mint ckBTC and DSN to each user
    let mintPromises = [];
    for (let [principal, _] of userActors) {
        mintPromises.push(minterActor.mint_btc({to: { owner: principal, subaccount: [] }, amount: BTC_USER_BALANCE}));
        mintPromises.push(minterActor.mint_dsn({to: { owner: principal, subaccount: [] }, amount: DSN_USER_BALANCE}));
    }
    await Promise.all(mintPromises);

    // Approve ckBTC and DSN for each user
    let approvePromises = [];
    for (let [_, actors] of userActors) {
        approvePromises.push(actors.ckbtc.icrc2_approve({
            fee: [],
            memo: [],
            from_subaccount: [],
            created_at_time: [],
            amount: BTC_USER_BALANCE - CKBTC_FEE,
            expected_allowance: [],
            expires_at: [],
            spender: {
              owner: Principal.fromText(protocolCanisterId),
              subaccount: []
            },
        }));
        approvePromises.push(actors.dsn_ledger.icrc2_approve({
            fee: [],
            memo: [],
            from_subaccount: [],
            created_at_time: [],
            amount: DSN_USER_BALANCE - DSN_FEE,
            expected_allowance: [],
            expires_at: [],
            spender: {
              owner: Principal.fromText(protocolCanisterId),
              subaccount: []
            },
        }));
    }
    await Promise.all(approvePromises).then(() => {
        console.log('All approvals completed successfully');
    }).catch((error) => {
        console.error('Error during approvals:', error);
    });

    // A random user opens up a new vote
    for (let i = 0; i < NUM_VOTES; i++) {
        const args = { text: VOTES_TO_OPEN[i], id: uuidv4(), thumbnail: new Uint8Array(), from_subaccount: [] };
        getRandomUserActor(userActors).backend.new_vote(args).then((result) => {
            if ('ok' in result) {
                console.log('New vote added successfully');
            } else {
                console.error('Error adding new vote:', result.err);
            }
        });
    }

    // Scenario loop

    var tick = 0n;

    while(tick * toNs(SCENARIO_TICK_DURATION) < toNs(SCENARIO_DURATION)) {

        console.log("Scenario tick: ", tick);

        // Retrieve all votes
        let votes = await backendSimActor.get_votes( { previous: [], limit: 100 } );
        console.log(votes);

        let putBallotPromises = [];

        for (let [_, actors] of userActors) {

            for (let vote of votes) {

                // 20% chance that this user vote by calling protocolActor.put_ballot
                if (Math.random() < 0.20) {
                    await sleep(250);

                    const vote_id = vote.vote_id;

                    // Generate a deterministic probability for YES based on vote_id
                    const yesProbability = generateDeterministicRandom(vote_id);
                    
                    putBallotPromises.push(
                        actors.protocol.put_ballot({
                            vote_id,
                            id: uuidv4(),
                            from_subaccount: [],
                            amount: BigInt(Math.floor(exponentialRandom(MEAN_BALLOT_AMOUNT))),
                            choice_type: { 'YES_NO': Math.random() < yesProbability ? { 'YES': null } : { 'NO': null } }
                        }).then((result) => {
                            if (!result) {
                                console.error('Put ballot result is null');
                            } else if ('err' in result) {
                                console.error('Error putting ballot: ', result.err);
                            }
                        })
                        .catch((error) => {
                            console.error('Error putting ballot: ', error);
                        })
                    );
                }
            }
        }

        await Promise.all(putBallotPromises);
        await protocolActor.add_clock_offset(SCENARIO_TICK_DURATION);
        await protocolActor.run();
        tick++;
    }

    protocolActor.get_info().then((info) => {
        console.log('Scenario date:', Date(Number(info.current_time / 1_000_000n)));
    });
}

callCanisterMethod();
