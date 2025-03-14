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
})' --ic --mode=reinstall --yes

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
        account = principal "hkucx-jaaaa-aaaap-anxfq-cai";
        amount = 50_000_000_000_000_000;
      };
    };
    minting_account   = opt record { 
      owner = principal "h7tt2-iiaaa-aaaap-anxga-cai";
      subaccount = null; 
    };
    advanced_settings = null;
  };
  icrc2 = null;
  icrc3 = null;
  icrc4 = null;
})' --ic --mode=reinstall --yes

# Deploy protocol with dependencies
# Hundred million e8s contribution per day
# With a discernment factor of 9, it leads to max one trillion e8s per day (probably more 400 billions per day)
# minimum_ballot_amount shall be greater than 0
# https://www.desmos.com/calculator/8iww2wlp2t
# dissent_steepness be between 0 and 1, the closer to 1 the steepest (the less the majority is rewarded)
# consent_steepness be between 0 and 0.25, the closer to 0 the steepest
# 1 hour timer interval, with a 24x dilation factor, means 1 day in simulated time
dfx deploy protocol --argument '( variant { 
  init = record {
    btc = record {
      ledger = principal "hewp7-sqaaa-aaaap-anxeq-cai";
      fee = 10;
    };
    dsn = record {
      ledger  = principal "hnved-eyaaa-aaaap-anxfa-cai";
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
      timer_interval_s = 3600;
      clock = variant { SIMULATED = record { dilation_factor = 24.0; } };
    };
  }
})' --ic --mode=reinstall --yes

# Deploy other canisters
dfx deploy backend --ic --mode=reinstall --yes
dfx deploy minter --ic --mode=reinstall --yes

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
