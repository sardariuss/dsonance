// Load environment variables from .env file
require('dotenv').config({ path: '../../.env' });

const { getActor } = require("./actor.cjs");
const { toNs } = require("./duration.cjs");
const { Ed25519KeyIdentity } = require("@dfinity/identity");
const { Principal } = require('@dfinity/principal');
// v4 from UUID
const { v4: uuidv4 } = require('uuid');
const seedrandom = require('seedrandom');
const avatar = require('boring-avatars');
const { renderToString } = require('react-dom/server');

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
const BTC_USER_BALANCE = 100_000_000n; // 8 decimals, so 1 BTC
const USDT_USER_BALANCE = 1_000_000_000_000n; // 6 decimals, so 1M USDT
const NUM_VOTES = 5;
const SCENARIO_DURATION = { 'DAYS': 18n };
const SCENARIO_TICK_DURATION = { 'DAYS': 3n };
const TARGET_LTV = 0.6; // 60% LTV
const RESERVE_LIQUIDITY = 0.0; // 20% reserve liquidity

const BTC_FEE = 10n;
const USDT_FEE = 10_000n; // 6 decimals, so 1 cent USDT

const sleep = (ms) => {
    return new Promise(resolve => setTimeout(resolve, ms));
}

const getThumbnail = (id) => {
    const svg = renderToString(avatar.default({name: id.toString()}, {
        variant: 'ring',
        size: 120
    }));
    const dataUri = `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
    return new Uint8Array(Buffer.from(dataUri, 'utf-8'));
};

const exponentialRandom = (mean) => {
    return -mean * Math.log(Math.random());
};

const generateDeterministicRandom = (voteId) => {
    const rng = seedrandom(voteId);
    return rng(); // Returns a number between 0 and 1
}

const getRandomUser = (userActors) => {
    let randomUser = Math.floor(Math.random() * NUM_USERS);
    let randomUserPrincipal = Array.from(userActors.keys())[randomUser];
    return {
        principal: randomUserPrincipal,
        actors: userActors.get(randomUserPrincipal)
    };
}
  
// Example function to call a canister method
async function callCanisterMethod() {
    
    // Import the IDL factory dynamically
    const { idlFactory: protocolFactory } = await import("../../.dfx/local/canisters/protocol/service.did.js");
    const { idlFactory: minterFactory } = await import("../../.dfx/local/canisters/minter/service.did.js");
    const { idlFactory: backendFactory } = await import("../../.dfx/local/canisters/backend/service.did.js");
    const { idlFactory: btcFactory } = await import("../../.dfx/local/canisters/ck_btc/service.did.js");
    const { idlFactory: usdtFactory } = await import("../../.dfx/local/canisters/ck_usdt/service.did.js");
    const { idlFactory: icpCoinsFactory } = await import("../../.dfx/local/canisters/icp_coins/service.did.js");

    // Retrieve canister ID from environment variables
    const protocolCanisterId = process.env.CANISTER_ID_PROTOCOL;
    const minterCanisterId = process.env.CANISTER_ID_MINTER;
    const backendCanisterId = process.env.CANISTER_ID_BACKEND;
    const btcCanisterId = process.env.CANISTER_ID_CK_BTC;
    const usdtCanisterId = process.env.CANISTER_ID_CK_USDT;
    const icpCoinsCanisterId = process.env.CANISTER_ID_ICP_COINS;

    if (!protocolCanisterId){
        throw new Error("Protocol canister ID is missing");
    }
    if (!minterCanisterId){
        throw new Error("Minter canister ID is missing");
    }
    if (!backendCanisterId){
        throw new Error("Backend canister ID is missing");
    }
    if (!btcCanisterId){
        throw new Error("ckBTC canister ID is missing");
    }
    if (!usdtCanisterId){
        throw new Error("ckUSDT canister ID is missing");
    }
    if (!icpCoinsCanisterId){
        throw new Error("ICP Coins canister ID is missing");
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

    let icpCoinsActor = await getActor(icpCoinsCanisterId, icpCoinsFactory, simIdentity);
    if (icpCoinsActor === null) {
        throw new Error("ICP Coins actor is null");
    }

    let lending_parameters = await protocolActor.get_lending_parameters();
    if (!lending_parameters) {
        throw new Error("Lending parameters are null");
    }
    const { supply_cap, borrow_cap } = lending_parameters;
    console.log(`USDT supply cap: ${supply_cap}, borrow cap: ${borrow_cap}`);

    const numTicks = BigInt(toNs(SCENARIO_DURATION)) / BigInt(toNs(SCENARIO_TICK_DURATION));
    // Target half the supply cap
    const meanBallotAmount = 0.5 * Number(supply_cap) / (NUM_USERS * NUM_VOTES * 0.2 * Number(numTicks));

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
        let btcActor = await getActor(btcCanisterId, btcFactory, identity);
        if (btcActor === null) {
            throw new Error("ckBTC actor is null");
        }
        let usdtActor = await getActor(usdtCanisterId, usdtFactory, identity);
        if (usdtActor === null) {
            throw new Error("USDT actor is null");
        }
        userActors.set(identity.getPrincipal(), { "protocol": protocolActor, "backend": backendActor, "btc": btcActor, "usdt": usdtActor });
    }

    // Mint ckBTC and USDT to each user
    let mintPromises = [];
    for (let [principal, _] of userActors) {
        mintPromises.push(minterActor.mint_btc({to: { owner: principal, subaccount: [] }, amount: BTC_USER_BALANCE}));
        mintPromises.push(minterActor.mint_usdt({to: { owner: principal, subaccount: [] }, amount: USDT_USER_BALANCE}));
    }
    await Promise.all(mintPromises);

    // Approve ckBTC and USDT for each user
    let approvePromises = [];
    for (let [_, actors] of userActors) {
        approvePromises.push(actors.btc.icrc2_approve({
            fee: [],
            memo: [],
            from_subaccount: [],
            created_at_time: [],
            amount: BTC_USER_BALANCE - BTC_FEE,
            expected_allowance: [],
            expires_at: [],
            spender: {
              owner: Principal.fromText(protocolCanisterId),
              subaccount: []
            },
        }));
        approvePromises.push(actors.usdt.icrc2_approve({
            fee: [],
            memo: [],
            from_subaccount: [],
            created_at_time: [],
            amount: USDT_USER_BALANCE - USDT_FEE,
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
        const id = uuidv4();
        const thumbnail = getThumbnail(id);
        const args = { text: VOTES_TO_OPEN[i], id, thumbnail, from_subaccount: [] };
        getRandomUser(userActors).actors.backend.new_vote(args).then((result) => {
            if ('ok' in result) {
                console.log('New vote added: ', args.text);
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
        let putBallotPromises = [];

        // Put ballots loop
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
                            amount: BigInt(Math.floor(exponentialRandom(meanBallotAmount))),
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

        // Borrow
        const { principal, actors } = getRandomUser(userActors);
        const utilization = (await actors.protocol.get_lending_index()).utilization;
        const price_btc = await icpCoinsActor.get_latest().then((latest) => {
            return Number(latest.at(0)[2]); // @todo: remove this hardcoded index
        });
        console.log(`BTC price: ${price_btc} USD`);

        const usdtAvailableFromLiquidity = Math.max((utilization.raw_supplied * (1.0 - RESERVE_LIQUIDITY) - utilization.raw_borrowed), 0.0);
        const usdtAvailableFromCap = Math.max(Number(borrow_cap) - utilization.raw_borrowed, 0.0);
        const usdtAvailableToBorrow = Math.min(usdtAvailableFromLiquidity, usdtAvailableFromCap) / 1_000_000; // e6s

        const btcCollateralRequired = (usdtAvailableToBorrow / price_btc) / TARGET_LTV;
        console.log(`Available to borrow: ${usdtAvailableToBorrow.toPrecision(6)} USDT, collateral required: ${btcCollateralRequired.toPrecision(8)} BTC`);
        const btcBalance = Number(await actors.btc.icrc1_balance_of({ owner: principal, subaccount: [] })) / 100_000_000; // e8s
        // Borrow up to the maximum available to borrow
        const collateralAmount =  (0.5 + Math.random() * 0.5) * Math.min(btcCollateralRequired, btcBalance);
        console.log(`Borrowing with collateral amount: ${collateralAmount} BTC`);
        const toBorrow = collateralAmount * TARGET_LTV * price_btc;
        console.log(`To borrow: ${toBorrow} USD`);
        
        if (collateralAmount > 0.0) {
            
            // Supply enough ckUSDT collateral to reach the target LTV
            await actors.protocol.run_borrow_operation({
                subaccount: [],
                amount: BigInt(Math.floor(collateralAmount * 100_000_000)),
                kind: { "PROVIDE_COLLATERAL" : null },
            }).then((result) => {
                if ('err' in result) {
                    console.error('Error supplying collateral:', result.err);
                } else {
                    console.log('Collateral supplied successfully');
                }
            })

            // Borrow ckBTC
            await actors.protocol.run_borrow_operation({
                subaccount: [],
                amount: BigInt(Math.floor(toBorrow * 1_000_000)),
                kind: { "BORROW_SUPPLY": null },
            }).then((result) => {
                if ('err' in result) {
                    console.error('Error borrowing:', result.err);
                } else {
                    console.log('Borrowed successfully');
                }
            })
        };

        await protocolActor.add_clock_offset(SCENARIO_TICK_DURATION);
        await protocolActor.run();
        tick++;
    }

    protocolActor.get_info().then((info) => {
        console.log('Scenario date:', Date(Number(info.current_time / 1_000_000n)));
    });
}

callCanisterMethod();
