#!/bin/bash
set -ex

dfx canister create --all

# Fetch canister IDs dynamically
for canister in ck_btc ck_usdt dex protocol minter; do
  export $(echo ${canister^^}_PRINCIPAL)=$(dfx canister id $canister)
done

# Parallel deployment for independent canisters
# https://dashboard.internetcomputer.org/canister/mxzaz-hqaaa-aaaar-qaada-cai
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
# https://dashboard.internetcomputer.org/canister/cngnf-vqaaa-aaaar-qag4q-cai
dfx deploy ck_usdt --argument '(opt record {
  icrc1 = opt record {
    name              = opt "ckUSDT";
    symbol            = opt "ckUSDT";
    decimals          = 6;
    fee               = opt variant { Fixed = 10_000 };
    max_supply        = opt 100_000_000_000_000_000;
    min_burn_amount   = opt 1_000;
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
dfx deploy dex --argument '( record {
  canister_ids = record {
    ck_btc = principal "'${CK_BTC_PRINCIPAL}'";
    ck_usdt = principal "'${CK_USDT_PRINCIPAL}'";
  };
})' &
dfx deploy minter --argument '( record {
  canister_ids = record {
    ck_btc = principal "'${CK_BTC_PRINCIPAL}'";
    ck_usdt = principal "'${CK_USDT_PRINCIPAL}'";
  }; 
})' &
dfx deploy icp_coins &
wait

# Deploy protocol with dependencies
# Hundred million e8s contribution per day
# With a discernment factor of 9, it leads to max one trillion e8s per day (probably more 400 billions per day)
# minimum_ballot_amount shall be greater than 0
# https://www.desmos.com/calculator/8iww2wlp2t
# dissent_steepness be between 0 and 1, the closer to 1 the steepest (the less the majority is rewarded)
# consent_steepness be between 0 and 0.25, the closer to 0 the steepest
# 216 seconds timer interval, with a 100x dilation factor, means 6 hours in simulated time
# @todo: fees should be queried by the protocol
dfx deploy protocol --argument '( variant { 
  init = record {
    canister_ids = record {
      supply_ledger = principal "'${CK_BTC_PRINCIPAL}'";
      collateral_ledger = principal "'${CK_USDT_PRINCIPAL}'";
      dex = principal "'${DEX_PRINCIPAL}'";
    };
    parameters = record {
      age_coefficient = 0.25;
      max_age = variant { YEARS = 4 };
      ballot_half_life = variant { YEARS = 1 };
      nominal_lock_duration = variant { DAYS = 3 };
      minimum_ballot_amount = 100;
      dissent_steepness = 0.55;
      consent_steepness = 0.1;
      author_fee = 5_000_000_000;
      timer_interval_s = 216;
      clock = variant { SIMULATED = record { dilation_factor = 100.0; } };
      lending = record {
        lending_fee_ratio = 0.01;
        reserve_liquidity = 0.0;
        target_ltv = 0.60;
        max_ltv = 0.70;
        liquidation_threshold = 0.75;
        liquidation_penalty = 0.03;
        close_factor = 0.5;
        max_slippage = 0.05;
        interest_rate_curve = vec {
          record { utilization = 0.0; percentage_rate = 2.0; };
          record { utilization = 0.8; percentage_rate = 20.0; };
          record { utilization = 1.0; percentage_rate = 100.0; };
        };
      };
    };
  }
})'

# Deploy other canisters
dfx deploy backend

# Internet Identity
dfx deps pull
dfx deps init
dfx deps deploy internet_identity

# Protocol initialization and frontend generation
dfx canister call protocol init_facade

dfx generate ck_btc --check &
dfx generate ck_usdt --check &
dfx generate backend --check & # Will generate protocol as well
dfx generate internet_identity --check &
dfx generate minter --check &
dfx generate icp_coins --check &
wait

dfx deploy frontend
