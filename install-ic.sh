#!/bin/bash
set -ex

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
      owner = principal "h7tt2-iiaaa-aaaap-anxga-cai";
      subaccount = null; 
    };
    advanced_settings = null;
  };
  icrc2 = null;
  icrc3 = null;
  icrc4 = null;
})' --ic

dfx deploy dsonance_ledger --argument '(opt record {
  icrc1 = opt record {
    name              = opt "Dsonance Token";
    symbol            = opt "RSN";
    decimals          = 8;
    fee               = opt variant { Fixed = 10 };
    max_supply        = opt 2_100_000_000_000_000;
    min_burn_amount   = opt 1_000;
    initial_balances  = vec {};
    minting_account   = opt record { 
      owner = principal "hkucx-jaaaa-aaaap-anxfq-cai";
      subaccount = null; 
    };
    advanced_settings = null;
  };
  icrc2 = null;
  icrc3 = null;
  icrc4 = null;
})' --ic

# Deploy protocol with dependencies
# Hundred million e8s participation per day
# With a discernment factor of 9, it leads to max one trillion e8s per day (probably more 400 billions per day)
# minimum_ballot_amount shall be greater than 0
# https://www.desmos.com/calculator/8iww2wlp2t
# dissent_steepness be between 0 and 1, the closer to 1 the steepest (the less the majority is rewarded)
# consent_steepness be between 0 and 0.25, the closer to 0 the steepest
# 216 seconds timer interval, with a 100x dilation factor, means 6 hours in simulated time
dfx deploy protocol --argument '( variant { 
  init = record {
    deposit = record {
      ledger = principal "hewp7-sqaaa-aaaap-anxeq-cai";
      fee = 10;
    };
    dsonance = record {
      ledger  = principal "hnved-eyaaa-aaaap-anxfa-cai";
      fee = 10;
    };
    parameters = record {
      participation_per_day = 100_000_000_000;
      discernment_factor = 9.0;
      ballot_half_life = variant { YEARS = 1 };
      nominal_lock_duration = variant { DAYS = 3 };
      minimum_ballot_amount = 100;
      dissent_steepness = 0.55;
      consent_steepness = 0.1;
      opening_vote_fee = 30;
      timer_interval_s = 216;
      clock = variant { SIMULATED = record { dilation_factor = 100.0; } };
    };
  }
})' --ic

# Deploy other canisters
dfx deploy backend --ic
dfx deploy minter --ic

# Protocol initialization and frontend generation
dfx canister call protocol init_facade --ic
dfx canister call backend add_categories '(
  vec {
    "🔬 Science";
    "⚕️ Health";
    "📊 Economics";
    "🌎 Geopolitics";
    "👫 Social";
  }
)' --ic

dfx deploy frontend --ic
