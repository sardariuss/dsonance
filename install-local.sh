#!/bin/bash
set -ex

#dfx canister create --all
#
## Fetch canister IDs dynamically
#for canister in ck_btc resonance_ledger protocol minter; do
#  export $(echo ${canister^^}_PRINCIPAL)=$(dfx canister id $canister)
#done
#
## Parallel deployment for independent canisters
#dfx deploy ck_btc --argument '(opt record {
#  icrc1 = opt record {
#    name              = opt "ckBTC";
#    symbol            = opt "ckBTC";
#    decimals          = 8;
#    fee               = opt variant { Fixed = 10 };
#    max_supply        = opt 2_100_000_000_000_000;
#    min_burn_amount   = opt 1_000;
#    initial_balances  = vec {};
#    minting_account   = opt record { 
#      owner = principal "'${MINTER_PRINCIPAL}'";
#      subaccount = null; 
#    };
#    advanced_settings = null;
#  };
#  icrc2 = null;
#  icrc3 = null;
#  icrc4 = null;
#})' &
#dfx deploy resonance_ledger --argument '(opt record {
#  icrc1 = opt record {
#    name              = opt "Carlson Resonance Token";
#    symbol            = opt "CRT";
#    decimals          = 8;
#    fee               = opt variant { Fixed = 10 };
#    max_supply        = opt 2_100_000_000_000_000;
#    min_burn_amount   = opt 1_000;
#    initial_balances  = vec {};
#    minting_account   = opt record { 
#      owner = principal "'${PROTOCOL_PRINCIPAL}'";
#      subaccount = null; 
#    };
#    advanced_settings = null;
#  };
#  icrc2 = null;
#  icrc3 = null;
#  icrc4 = null;
#})' &
#wait
#
## Deploy protocol with dependencies
## Hundred million e8s participation per day
## With a discernment factor of 9, it leads to max one trillion e8s per day (probably more 400 billions per day)
## minimum_ballot_amount shall be greater than 0
## https://www.desmos.com/calculator/8iww2wlp2t
## dissent_steepness be between 0 and 1, the closer to 1 the steepest (the less the majority is rewarded)
## consent_steepness be between 0 and 0.25, the closer to 0 the steepest
#dfx deploy protocol --argument '( variant { 
#  init = record {
#    deposit = record {
#      ledger = principal "'${CK_BTC_PRINCIPAL}'";
#      fee = 10;
#    };
#    resonance = record {
#      ledger  = principal "'${RESONANCE_LEDGER_PRINCIPAL}'";
#      fee = 10;
#    };
#    parameters = record {
#      participation_per_day = 100_000_000_000;
#      discernment_factor = 9.0;
#      ballot_half_life = variant { YEARS = 1 };
#      nominal_lock_duration = variant { DAYS = 3 };
#      minimum_ballot_amount = 100;
#      dissent_steepness = 0.55;
#      consent_steepness = 0.1;
#      opening_vote_fee = 30;
#      timer_interval_s = 60;
#      clock = variant { SIMULATED = record { dilation_factor = 100.0; } };
#    };
#  }
#})'
#
## Deploy other canisters
#dfx deploy backend &
#dfx deploy minter &
#dfx deploy icp_coins &
#wait
#
## Internet Identity
#dfx deps pull
#dfx deps init
#dfx deps deploy internet_identity
#
## Protocol initialization and frontend generation
#dfx canister call protocol init_facade
#dfx canister call backend add_categories '(
#  vec {
#    "🔬 Science";
#    "⚕️ Health";
#    "📊 Economics";
#    "🌎 Geopolitics";
#    "👫 Social";
#  }
#)'
#
#dfx generate ck_btc
dfx generate resonance_ledger
dfx generate backend # Will generate protocol as well
dfx generate internet_identity
dfx generate minter

dfx deploy frontend
