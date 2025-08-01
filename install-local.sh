#!/bin/bash
set -ex

dfx identity use default
export DEFAULT_USER=$(dfx identity get-principal)
export DSN_LOGO=$(base64 -w 0 logo_coin_xs.png)

# Create the canisters
dfx canister create --all

# Fetch canister IDs dynamically
for canister in ckbtc_ledger ckusdt_ledger dsn_ledger kong_backend protocol faucet; do
  export $(echo ${canister^^}_PRINCIPAL)=$(dfx canister id $canister)
done

# Parallel deployment for independent canisters
dfx deploy ckbtc_ledger --argument '(
  variant {
    Init = record {
      decimals = opt (8 : nat8);
      token_symbol = "ckBTC";
      token_name = "ckBTC";
      max_memo_length = null;
      feature_flags = null;
      transfer_fee = 10 : nat;
      metadata = (
        vec {
          record {
            "icrc1:logo";
            variant {
              Text = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzYwIiBoZWlnaHQ9IjM2MCIgdmlld0JveD0iMCAwIDM2MCAzNjAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxnIGNsaXAtcGF0aD0idXJsKCNjbGlwMF84NzZfNzEpIj4KPHBhdGggZD0iTTE4MCAwQzI3OS40IDAgMzYwIDgwLjYgMzYwIDE4MEMzNjAgMjc5LjQgMjc5LjQgMzYwIDE4MCAzNjBDODAuNiAzNjAgMCAyNzkuNCAwIDE4MEMwIDgwLjYgODAuNiAwIDE4MCAwWiIgZmlsbD0iIzNCMDBCOSIvPgo8cGF0aCBmaWxsLXJ1bGU9ImV2ZW5vZGQiIGNsaXAtcnVsZT0iZXZlbm9kZCIgZD0iTTQwLjQwMDEgMTkwLjQwMkM0NS40MDAxIDI1OS40MDIgMTAwLjYgMzE0LjYwMiAxNjkuNiAzMTkuNjAyVjMzNS4yMDJDOTIuMDAwMSAzMzAuMDAyIDMwIDI2OC4wMDIgMjQuOCAxOTAuNDAySDQwLjQwMDFaIiBmaWxsPSJ1cmwoI3BhaW50MF9saW5lYXJfODc2XzcxKSIvPgo8cGF0aCBmaWxsLXJ1bGU9ImV2ZW5vZGQiIGNsaXAtcnVsZT0iZXZlbm9kZCIgZD0iTTE2OS42IDQwLjQwMDhDMTAwLjYgNDUuNDAwOCA0NS40MDAxIDEwMC42MDEgNDAuNDAwMSAxNjkuNjAxSDI0LjhDMjkuOCA5Mi4wMDA4IDkyLjAwMDEgMjkuODAwOCAxNjkuNiAyNC44MDA4VjQwLjQwMDhaIiBmaWxsPSIjMjlBQkUyIi8+CjxwYXRoIGZpbGwtcnVsZT0iZXZlbm9kZCIgY2xpcC1ydWxlPSJldmVub2RkIiBkPSJNMzE5LjYgMTY5LjQwMkMzMTQuNiAxMDAuNDAyIDI1OS40IDQ1LjIwMTYgMTkwLjQgNDAuMjAxNlYyNC42MDE2QzI2OCAyOS44MDE2IDMzMC4yIDkxLjgwMTYgMzM1LjIgMTY5LjQwMkgzMTkuNloiIGZpbGw9InVybCgjcGFpbnQxX2xpbmVhcl84NzZfNzEpIi8+CjxwYXRoIGZpbGwtcnVsZT0iZXZlbm9kZCIgY2xpcC1ydWxlPSJldmVub2RkIiBkPSJNMTkwLjQgMzE5LjYwMkMyNTkuNCAzMTQuNjAyIDMxNC42IDI1OS40MDIgMzE5LjYgMTkwLjQwMkgzMzUuMkMzMzAuMiAyNjguMDAyIDI2OCAzMzAuMDAyIDE5MC40IDMzNS4yMDJWMzE5LjYwMloiIGZpbGw9IiMyOUFCRTIiLz4KPHBhdGggZmlsbC1ydWxlPSJldmVub2RkIiBjbGlwLXJ1bGU9ImV2ZW5vZGQiIGQ9Ik0xOTUuODAxIDE4NS40MDdDMTk0LjkxNCAxODUuNDc0IDE5MC4zMzQgMTg1Ljc0OCAxODAuMTE5IDE4NS43NDhDMTcxLjk5MyAxODUuNzQ4IDE2Ni4yMjQgMTg1LjUwNCAxNjQuMiAxODUuNDA3QzEzMi43OTkgMTg0LjAyMyAxMDkuMzYxIDE3OC41NDUgMTA5LjM2MSAxNzEuOTg3QzEwOS4zNjEgMTY1LjQyOCAxMzIuNzk5IDE1OS45NTggMTY0LjIgMTU4LjU1MVYxNzkuOTUyQzE2Ni4yNTQgMTgwLjEgMTcyLjEzMyAxODAuNDQ4IDE4MC4yNTkgMTgwLjQ0OEMxOTAuMDA5IDE4MC40NDggMTk0Ljg5MiAxODAuMDQxIDE5NS43NzEgMTc5Ljk1OVYxNTguNTY2QzIyNy4xMDUgMTU5Ljk2NSAyNTAuNDkyIDE2NS40NDMgMjUwLjQ5MiAxNzEuOTg3QzI1MC40OTIgMTc4LjUzMSAyMjcuMTEzIDE4NC4wMDggMTk1Ljc3MSAxODUuNEwxOTUuODAxIDE4NS40MDdaTTE5NS44MDEgMTU2LjM1M1YxMzcuMjAzSDIzOS41M1YxMDhIMTIwLjQ3MVYxMzcuMjAzSDE2NC4xOTNWMTU2LjM0NUMxMjguNjU1IDE1Ny45ODEgMTAxLjkzIDE2NS4wMzYgMTAxLjkzIDE3My40OUMxMDEuOTMgMTgxLjk0MyAxMjguNjU1IDE4OC45OSAxNjQuMTkzIDE5MC42MzRWMjUySDE5NS43OTNWMTkwLjYxMUMyMzEuMjQ5IDE4OC45NzUgMjU3LjkzIDE4MS45MjggMjU3LjkzIDE3My40ODJDMjU3LjkzIDE2NS4wMzYgMjMxLjI3MiAxNTcuOTg5IDE5NS43OTMgMTU2LjM0NUwxOTUuODAxIDE1Ni4zNTNaIiBmaWxsPSJ3aGl0ZSIvPgo8L2c+CjxkZWZzPgo8bGluZWFyR3JhZGllbnQgaWQ9InBhaW50MF9saW5lYXJfODc2XzcxIiB4MT0iMTMwLjcyIiB5MT0iMzA0LjEyMiIgeDI9IjMzLjQ4IiB5Mj0iMjIyLjIyMiIgZ3JhZGllbnRVbml0cz0idXNlclNwYWNlT25Vc2UiPgo8c3RvcCBvZmZzZXQ9IjAuMjEiIHN0b3AtY29sb3I9IiNFRDFFNzkiLz4KPHN0b3Agb2Zmc2V0PSIxIiBzdG9wLWNvbG9yPSIjNTIyNzg1Ii8+CjwvbGluZWFyR3JhZGllbnQ+CjxsaW5lYXJHcmFkaWVudCBpZD0icGFpbnQxX2xpbmVhcl84NzZfNzEiIHgxPSIzMDkuMzIiIHkxPSIxMjMuMDYyIiB4Mj0iMjEyLjA4IiB5Mj0iNDEuMTYxNSIgZ3JhZGllbnRVbml0cz0idXNlclNwYWNlT25Vc2UiPgo8c3RvcCBvZmZzZXQ9IjAuMjEiIHN0b3AtY29sb3I9IiNGMTVBMjQiLz4KPHN0b3Agb2Zmc2V0PSIwLjY4IiBzdG9wLWNvbG9yPSIjRkJCMDNCIi8+CjwvbGluZWFyR3JhZGllbnQ+CjxjbGlwUGF0aCBpZD0iY2xpcDBfODc2XzcxIj4KPHJlY3Qgd2lkdGg9IjM2MCIgaGVpZ2h0PSIzNjAiIGZpbGw9IndoaXRlIi8+CjwvY2xpcFBhdGg+CjwvZGVmcz4KPC9zdmc+Cg=="
            };
          };
          record { "icrc103:public_allowances"; variant { Text = "true" } };
          record { "icrc103:max_take_value"; variant { Nat = 500 : nat } };
        }
      );
      minting_account = record {
        owner = principal "'${FAUCET_PRINCIPAL}'";
        subaccount = null;
      };
      initial_balances = vec {};
      fee_collector_account = null;
      archive_options = record {
        num_blocks_to_archive = 5_000 : nat64;
        max_transactions_per_response = null;
        trigger_threshold = 10_000 : nat64;
        more_controller_ids = null;
        max_message_size_bytes = null;
        cycles_for_archive_creation = null;
        node_max_memory_size_bytes = null;
        controller_id = principal "'${DEFAULT_USER}'";
      };
    }
  }
)' &
dfx deploy ckusdt_ledger --argument '(
  variant {
    Init = record {
      decimals = opt (6 : nat8);
      token_symbol = "ckUSDT";
      token_name = "ckUSDT";
      transfer_fee = 10_000 : nat;
      max_memo_length = null;
      feature_flags = null;
      metadata = (
        vec {
          record {
            "icrc1:logo";
            variant {
              Text = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzYwIiBoZWlnaHQ9IjM2MCIgdmlld0JveD0iMCAwIDM2MCAzNjAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxnIGNsaXAtcGF0aD0idXJsKCNjbGlwMF84NzZfNzEpIj4KPHBhdGggZD0iTTE4MCAwQzI3OS40IDAgMzYwIDgwLjYgMzYwIDE4MEMzNjAgMjc5LjQgMjc5LjQgMzYwIDE4MCAzNjBDODAuNiAzNjAgMCAyNzkuNCAwIDE4MEMwIDgwLjYgODAuNiAwIDE4MCAwWiIgZmlsbD0iIzNCMDBCOSIvPgo8cGF0aCBmaWxsLXJ1bGU9ImV2ZW5vZGQiIGNsaXAtcnVsZT0iZXZlbm9kZCIgZD0iTTQwLjQwMDEgMTkwLjQwMkM0NS40MDAxIDI1OS40MDIgMTAwLjYgMzE0LjYwMiAxNjkuNiAzMTkuNjAyVjMzNS4yMDJDOTIuMDAwMSAzMzAuMDAyIDMwIDI2OC4wMDIgMjQuOCAxOTAuNDAySDQwLjQwMDFaIiBmaWxsPSJ1cmwoI3BhaW50MF9saW5lYXJfODc2XzcxKSIvPgo8cGF0aCBmaWxsLXJ1bGU9ImV2ZW5vZGQiIGNsaXAtcnVsZT0iZXZlbm9kZCIgZD0iTTE2OS42IDQwLjQwMDhDMTAwLjYgNDUuNDAwOCA0NS40MDAxIDEwMC42MDEgNDAuNDAwMSAxNjkuNjAxSDI0LjhDMjkuOCA5Mi4wMDA4IDkyLjAwMDEgMjkuODAwOCAxNjkuNiAyNC44MDA4VjQwLjQwMDhaIiBmaWxsPSIjMjlBQkUyIi8+CjxwYXRoIGZpbGwtcnVsZT0iZXZlbm9kZCIgY2xpcC1ydWxlPSJldmVub2RkIiBkPSJNMzE5LjYgMTY5LjQwMkMzMTQuNiAxMDAuNDAyIDI1OS40IDQ1LjIwMTYgMTkwLjQgNDAuMjAxNlYyNC42MDE2QzI2OCAyOS44MDE2IDMzMC4yIDkxLjgwMTYgMzM1LjIgMTY5LjQwMkgzMTkuNloiIGZpbGw9InVybCgjcGFpbnQxX2xpbmVhcl84NzZfNzEpIi8+CjxwYXRoIGZpbGwtcnVsZT0iZXZlbm9kZCIgY2xpcC1ydWxlPSJldmVub2RkIiBkPSJNMTkwLjQgMzE5LjYwMkMyNTkuNCAzMTQuNjAyIDMxNC42IDI1OS40MDIgMzE5LjYgMTkwLjQwMkgzMzUuMkMzMzAuMiAyNjguMDAyIDI2OCAzMzAuMDAyIDE5MC40IDMzNS4yMDJWMzE5LjYwMloiIGZpbGw9IiMyOUFCRTIiLz4KPHBhdGggZmlsbC1ydWxlPSJldmVub2RkIiBjbGlwLXJ1bGU9ImV2ZW5vZGQiIGQ9Ik0xOTUuODAxIDE4NS40MDdDMTk0LjkxNCAxODUuNDc0IDE5MC4zMzQgMTg1Ljc0OCAxODAuMTE5IDE4NS43NDhDMTcxLjk5MyAxODUuNzQ4IDE2Ni4yMjQgMTg1LjUwNCAxNjQuMiAxODUuNDA3QzEzMi43OTkgMTg0LjAyMyAxMDkuMzYxIDE3OC41NDUgMTA5LjM2MSAxNzEuOTg3QzEwOS4zNjEgMTY1LjQyOCAxMzIuNzk5IDE1OS45NTggMTY0LjIgMTU4LjU1MVYxNzkuOTUyQzE2Ni4yNTQgMTgwLjEgMTcyLjEzMyAxODAuNDQ4IDE4MC4yNTkgMTgwLjQ0OEMxOTAuMDA5IDE4MC40NDggMTk0Ljg5MiAxODAuMDQxIDE5NS43NzEgMTc5Ljk1OVYxNTguNTY2QzIyNy4xMDUgMTU5Ljk2NSAyNTAuNDkyIDE2NS40NDMgMjUwLjQ5MiAxNzEuOTg3QzI1MC40OTIgMTc4LjUzMSAyMjcuMTEzIDE4NC4wMDggMTk1Ljc3MSAxODUuNEwxOTUuODAxIDE4NS40MDdaTTE5NS44MDEgMTU2LjM1M1YxMzcuMjAzSDIzOS41M1YxMDhIMTIwLjQ3MVYxMzcuMjAzSDE2NC4xOTNWMTU2LjM0NUMxMjguNjU1IDE1Ny45ODEgMTAxLjkzIDE2NS4wMzYgMTAxLjkzIDE3My40OUMxMDEuOTMgMTgxLjk0MyAxMjguNjU1IDE4OC45OSAxNjQuMTkzIDE5MC42MzRWMjUySDE5NS43OTNWMTkwLjYxMUMyMzEuMjQ5IDE4OC45NzUgMjU3LjkzIDE4MS45MjggMjU3LjkzIDE3My40ODJDMjU3LjkzIDE2NS4wMzYgMjMxLjI3MiAxNTcuOTg5IDE5NS43OTMgMTU2LjM0NUwxOTUuODAxIDE1Ni4zNTNaIiBmaWxsPSJ3aGl0ZSIvPgo8L2c+CjxkZWZzPgo8bGluZWFyR3JhZGllbnQgaWQ9InBhaW50MF9saW5lYXJfODc2XzcxIiB4MT0iMTMwLjcyIiB5MT0iMzA0LjEyMiIgeDI9IjMzLjQ4IiB5Mj0iMjIyLjIyMiIgZ3JhZGllbnRVbml0cz0idXNlclNwYWNlT25Vc2UiPgo8c3RvcCBvZmZzZXQ9IjAuMjEiIHN0b3AtY29sb3I9IiNFRDFFNzkiLz4KPHN0b3Agb2Zmc2V0PSIxIiBzdG9wLWNvbG9yPSIjNTIyNzg1Ii8+CjwvbGluZWFyR3JhZGllbnQ+CjxsaW5lYXJHcmFkaWVudCBpZD0icGFpbnQxX2xpbmVhcl84NzZfNzEiIHgxPSIzMDkuMzIiIHkxPSIxMjMuMDYyIiB4Mj0iMjEyLjA4IiB5Mj0iNDEuMTYxNSIgZ3JhZGllbnRVbml0cz0idXNlclNwYWNlT25Vc2UiPgo8c3RvcCBvZmZzZXQ9IjAuMjEiIHN0b3AtY29sb3I9IiNGMTVBMjQiLz4KPHN0b3Agb2Zmc2V0PSIwLjY4IiBzdG9wLWNvbG9yPSIjRkJCMDNCIi8+CjwvbGluZWFyR3JhZGllbnQ+CjxjbGlwUGF0aCBpZD0iY2xpcDBfODc2XzcxIj4KPHJlY3Qgd2lkdGg9IjM2MCIgaGVpZ2h0PSIzNjAiIGZpbGw9IndoaXRlIi8+CjwvY2xpcFBhdGg+CjwvZGVmcz4KPC9zdmc+Cg=="
            };
          };
          record { "icrc103:public_allowances"; variant { Text = "true" } };
          record { "icrc103:max_take_value"; variant { Nat = 500 : nat } };
        }
      );
      minting_account = record {
        owner = principal "'${FAUCET_PRINCIPAL}'";
        subaccount = null;
      };
      initial_balances = vec {};
      fee_collector_account = null;
      archive_options = record {
        num_blocks_to_archive = 5_000 : nat64;
        max_transactions_per_response = null;
        trigger_threshold = 10_000 : nat64;
        more_controller_ids = null;
        max_message_size_bytes = null;
        cycles_for_archive_creation = null;
        node_max_memory_size_bytes = null;
        controller_id = principal "'${DEFAULT_USER}'";
      };
    }
  }
)' &
dfx deploy dsn_ledger --argument '(
  variant {
    Init = record {
      decimals = opt (6 : nat8);
      token_symbol = "DSN";
      token_name = "DSN";
      transfer_fee = 1000 : nat;
      max_memo_length = null;
      feature_flags = null;
      metadata = (
        vec {
          record {
            "icrc1:logo";
            variant {
              Text = "data:image/png;base64,'${DSN_LOGO}'"
            };
          };
          record { "icrc103:public_allowances"; variant { Text = "true" } };
          record { "icrc103:max_take_value"; variant { Nat = 500 : nat } };
        }
      );
      minting_account = record {
        owner = principal "'${FAUCET_PRINCIPAL}'";
        subaccount = null;
      };
      initial_balances = vec {};
      fee_collector_account = null;
      archive_options = record {
        num_blocks_to_archive = 5_000 : nat64;
        max_transactions_per_response = null;
        trigger_threshold = 10_000 : nat64;
        more_controller_ids = null;
        max_message_size_bytes = null;
        cycles_for_archive_creation = null;
        node_max_memory_size_bytes = null;
        controller_id = principal "'${DEFAULT_USER}'";
      };
    }
  }
)' &
dfx deploy kong_backend &
dfx deploy faucet --argument '( record {
  canister_ids = record {
    ckbtc_ledger = principal "'${CKBTC_LEDGER_PRINCIPAL}'";
    ckusdt_ledger = principal "'${CKUSDT_LEDGER_PRINCIPAL}'";
    dsn_ledger = principal "'${DSN_LEDGER_PRINCIPAL}'";
  }; 
})' &
# Prices taken from the neutrinite canister on 2025-07-01
# https://dashboard.internetcomputer.org/canister/u45jl-liaaa-aaaam-abppa-cai#get_latest
dfx deploy icp_coins --argument '( record {
  initial_prices =  record {
    ck_btc = 106075.52614260835;
    ck_usdt = 0.9937106157584112;
  };
})' &
wait

# Deploy protocol canister
#
# Dissent and consent parameters (see https://www.desmos.com/calculator/8iww2wlp2t)
# { dissent_steepness = 0.55; consent_steepness = 0.1; }
# dissent_steepness be in [0; 1[ - the closer to 1 the steepest (the less the majority is rewarded)
# consent_steepness be in [0; 0.25] - the closer to 0 the steepest
#
# Duration scaler parameters (see https://www.desmos.com/calculator/ywe3znxzje)
# { a = 72800000000.0; b = 3.25; }
# Gives a duration of 1 day for 1 USDT and 1 year for 100k USDT
#
# 216 seconds timer interval, with a 100x dilation factor, means 6 hours in simulated time
#
# Supply cap is set to 1M ckUSDT and borrow cap to 800k ckUSDT
#
dfx deploy protocol --argument '( variant { 
  init = record {
    canister_ids = record {
      supply_ledger = principal "'${CKUSDT_LEDGER_PRINCIPAL}'";
      collateral_ledger = principal "'${CKBTC_LEDGER_PRINCIPAL}'";
      kong_backend = principal "'${KONG_BACKEND_PRINCIPAL}'";
      participation_ledger = principal "'${DSN_LEDGER_PRINCIPAL}'";
    };
    parameters = record {
      age_coefficient = 0.25;
      max_age = variant { YEARS = 4 };
      ballot_half_life = variant { YEARS = 1 };
      duration_scaler = record { a = 72800000000.0; b = 3.25; };
      minimum_ballot_amount = 1_000_000;
      dissent_steepness = 0.55;
      consent_steepness = 0.1;
      timer_interval_s = 300;
      clock = variant { SIMULATED = record { dilation_factor = 100.0; } };
      twap_config = record {
        window_duration = variant { HOURS = 6 };
        max_observations = 1000;
      };
      lending = record {
        supply_cap = 1_000_000_000_000;
        borrow_cap = 800_000_000_000;
        lending_fee_ratio = 0.35;
        reserve_liquidity = 0.0;
        target_ltv = 0.60;
        max_ltv = 0.70;
        liquidation_threshold = 0.75;
        liquidation_penalty = 0.03;
        close_factor = 0.5;
        max_slippage = 0.05;
        interest_rate_curve = vec {
          record { utilization = 0.0; rate = 0.02; };
          record { utilization = 0.8; rate = 0.15; };
          record { utilization = 1.0; rate = 1.00; };
        };
      };
      participation = record {
        emission_half_life = variant { YEARS = 2 };
        emission_total_amount = 550_000_000_000_000;
        borrowers_share = 0.75;
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

# Create ckBTC/ckUSDT pool
# ⚠️ ckUSDT SHALL BE ADDED FIRST, then ckBTC. 
# OTHERWISE THE POOL WILL NOT BE CREATED
# THIS IS A LIMITATION FROM THE KONG BACKEND
dfx canister call kong_backend add_token '(
  record {
    token = "IC.'${CKUSDT_LEDGER_PRINCIPAL}'";
  },
)'
dfx canister call kong_backend add_token '(
  record {
    token = "IC.'${CKBTC_LEDGER_PRINCIPAL}'";
  },
)'
dfx canister call faucet mint_btc '(
  record {
    to = record {
      owner = principal "'${DEFAULT_USER}'";
      subaccount = null;
    };
    amount = 100_000_020 : nat;
  },
)'
dfx canister call faucet mint_usdt '(
  record {
    to = record {
      owner = principal "'${DEFAULT_USER}'";
      subaccount = null;
    };
    amount = 100_000_020_000 : nat;
  },
)'
dfx canister call ckbtc_ledger icrc2_approve '(
  record {
    fee = null;
    memo = null;
    from_subaccount = null;
    created_at_time = null;
    amount = 100_000_010 : nat;
    expected_allowance = null;
    expires_at = null;
    spender = record {
      owner = principal "'${KONG_BACKEND_PRINCIPAL}'";
      subaccount = null;
    };
  },
)'
dfx canister call ckusdt_ledger icrc2_approve '(
  record {
    fee = null;
    memo = null;
    from_subaccount = null;
    created_at_time = null;
    amount = 100_000_010_000 : nat;
    expected_allowance = null;
    expires_at = null;
    spender = record {
      owner = principal "'${KONG_BACKEND_PRINCIPAL}'";
      subaccount = null;
    };
  },
)'
dfx canister call kong_backend add_pool '(
  record {
    token_0 = "IC.'${CKBTC_LEDGER_PRINCIPAL}'";
    token_1 = "IC.'${CKUSDT_LEDGER_PRINCIPAL}'";
    amount_0 = 100_000_000 : nat;
    amount_1 =  100_000_000_000 : nat;
    tx_id_0 = null;
    tx_id_1 = null;
    lp_fee_bps = null;
  },
)'

# Protocol initialization and frontend generation
dfx canister call protocol init_facade

dfx generate ckbtc_ledger &
dfx generate ckusdt_ledger &
dfx generate dsn_ledger &
dfx generate kong_backend &
dfx generate backend & # Will generate protocol as well
dfx generate internet_identity &
dfx generate faucet &
dfx generate icp_coins &
wait

dfx deploy frontend
