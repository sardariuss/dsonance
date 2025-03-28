#!/bin/bash
set -ex

dfx canister create --all

# Fetch canister IDs dynamically
for canister in ck_btc dsn_ledger protocol minter; do
  export $(echo ${canister^^}_PRINCIPAL)=$(dfx canister id $canister)
done

# Parallel deployment for independent canisters
dfx deploy ck_btc --argument '(opt record {
  icrc1 = opt record {
    name              = opt "ckBTC";
    symbol            = opt "ckBTC";
    decimals          = 8;
    fee               = opt variant { Fixed = 10 };
    max_supply        = opt 2_100_000_000_000_000;
    min_burn_amount   = opt 1_000;
    initial_balances  = vec {};
    minting_account   = opt record { 
      owner = principal "'${MINTER_PRINCIPAL}'";
      subaccount = null; 
    };
    advanced_settings = null;
  };
  icrc2 = null;
  icrc3 = null;
  icrc4 = null;
})' &
dfx deploy dsn_ledger --argument '(opt record {
  icrc1 = opt record {
    name              = opt "Dsonance Coin";
    symbol            = opt "DSN";
    decimals          = 8;
    fee               = opt variant { Fixed = 1_000 };
    max_supply        = opt 100_000_000_000_000_000;
    min_burn_amount   = opt 1_000;
    initial_balances  = vec {
      record { 
        account = principal "'${PROTOCOL_PRINCIPAL}'";
        amount = 50_000_000_000_000_000;
      };
    };
    minting_account   = opt record { 
      owner = principal "'${MINTER_PRINCIPAL}'";
      subaccount = null; 
    };
    advanced_settings = null;
  };
  icrc2 = null;
  icrc3 = null;
  icrc4 = null;
})' &
wait

# Deploy protocol with dependencies
# Hundred million e8s contribution per day
# With a discernment factor of 9, it leads to max one trillion e8s per day (probably more 400 billions per day)
# minimum_ballot_amount shall be greater than 0
# https://www.desmos.com/calculator/8iww2wlp2t
# dissent_steepness be between 0 and 1, the closer to 1 the steepest (the less the majority is rewarded)
# consent_steepness be between 0 and 0.25, the closer to 0 the steepest
# 216 seconds timer interval, with a 100x dilation factor, means 6 hours in simulated time
dfx deploy protocol --argument '( variant { 
  init = record {
    btc = record {
      ledger = principal "'${CK_BTC_PRINCIPAL}'";
      fee = 10;
    };
    dsn = record {
      ledger  = principal "'${DSN_LEDGER_PRINCIPAL}'";
      fee = 10;
    };
    parameters = record {
      contribution_per_day = 100_000_000_000;
      age_coefficient = 0.25;
      max_age = variant { YEARS = 4 };
      ballot_half_life = variant { YEARS = 1 };
      nominal_lock_duration = variant { DAYS = 3 };
      minimum_ballot_amount = 100;
      dissent_steepness = 0.55;
      consent_steepness = 0.1;
      author_fee = 5_000_000_000;
      author_share = 0.2;
      timer_interval_s = 216;
      clock = variant { SIMULATED = record { dilation_factor = 100.0; } };
    };
  }
})'

# Deploy other canisters
dfx deploy backend &
dfx deploy minter &
dfx deploy icp_coins &
wait

# Internet Identity
dfx deps pull
dfx deps init
dfx deps deploy internet_identity

# Protocol initialization and frontend generation
dfx canister call protocol init_facade
dfx canister call backend add_categories '(
  vec {
    "🔬 Science";
    "⚕️ Health";
    "📊 Economics";
    "🌎 Geopolitics";
    "👫 Social";
  }
)'

dfx generate ck_btc
dfx generate dsn_ledger
dfx generate backend # Will generate protocol as well
dfx generate internet_identity
dfx generate minter
dfx generate icp_coins

dfx deploy frontend
