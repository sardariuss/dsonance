#!/bin/bash
set -ex

export DEPLOYEMENT_PRINCIPAL=$(dfx identity get-principal)
export TOWER_COIN=$(base64 -w 0 ./src/frontend/assets/tower_coin.png)

# Exchange rate for ckUSDT/USD with 9 decimals (typical format from exchange_rate canister)
# 1_000_000_000 = 1.0 USD (with 9 decimals)
CKUSDT_USD_PRICE=1_000_000_000
CKUSDT_DECIMALS=9
# Exchange rate for ckBTC/USD with 9 decimals (typical format from exchange_rate canister)
CKBTC_USD_PRICE=108_702_000_000_000
CKBTC_DECIMALS=9

# Fetch canister IDs dynamically
for canister in ckbtc_ledger ckusdt_ledger twv_ledger kong_backend protocol faucet xrc_stub; do
  export $(echo ${canister^^}_PRINCIPAL)=$(dfx canister id $canister --ic)
done

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
              Text = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTQ2IiBoZWlnaHQ9IjE0NiIgdmlld0JveD0iMCAwIDE0NiAxNDYiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIxNDYiIGhlaWdodD0iMTQ2IiByeD0iNzMiIGZpbGw9IiMzQjAwQjkiLz4KPHBhdGggZmlsbC1ydWxlPSJldmVub2RkIiBjbGlwLXJ1bGU9ImV2ZW5vZGQiIGQ9Ik0xNi4zODM3IDc3LjIwNTJDMTguNDM0IDEwNS4yMDYgNDAuNzk0IDEyNy41NjYgNjguNzk0OSAxMjkuNjE2VjEzNS45MzlDMzcuMzA4NyAxMzMuODY3IDEyLjEzMyAxMDguNjkxIDEwLjA2MDUgNzcuMjA1MkgxNi4zODM3WiIgZmlsbD0idXJsKCNwYWludDBfbGluZWFyXzExMF81NzIpIi8+CjxwYXRoIGZpbGwtcnVsZT0iZXZlbm9kZCIgY2xpcC1ydWxlPSJldmVub2RkIiBkPSJNNjguNzY0NiAxNi4zNTM0QzQwLjc2MzggMTguNDAzNiAxOC40MDM3IDQwLjc2MzcgMTYuMzUzNSA2OC43NjQ2TDEwLjAzMDMgNjguNzY0NkMxMi4xMDI3IDM3LjI3ODQgMzcuMjc4NSAxMi4xMDI2IDY4Ljc2NDYgMTAuMDMwMkw2OC43NjQ2IDE2LjM1MzRaIiBmaWxsPSIjMjlBQkUyIi8+CjxwYXRoIGZpbGwtcnVsZT0iZXZlbm9kZCIgY2xpcC1ydWxlPSJldmVub2RkIiBkPSJNMTI5LjYxNiA2OC43MzQzQzEyNy41NjYgNDAuNzMzNSAxMDUuMjA2IDE4LjM3MzQgNzcuMjA1MSAxNi4zMjMyTDc3LjIwNTEgMTBDMTA4LjY5MSAxMi4wNzI0IDEzMy44NjcgMzcuMjQ4MiAxMzUuOTM5IDY4LjczNDNMMTI5LjYxNiA2OC43MzQzWiIgZmlsbD0idXJsKCNwYWludDFfbGluZWFyXzExMF81NzIpIi8+CjxwYXRoIGZpbGwtcnVsZT0iZXZlbm9kZCIgY2xpcC1ydWxlPSJldmVub2RkIiBkPSJNNzcuMjM1NCAxMjkuNTg2QzEwNS4yMzYgMTI3LjUzNiAxMjcuNTk2IDEwNS4xNzYgMTI5LjY0NyA3Ny4xNzQ5TDEzNS45NyA3Ny4xNzQ5QzEzMy44OTcgMTA4LjY2MSAxMDguNzIyIDEzMy44MzcgNzcuMjM1NCAxMzUuOTA5TDc3LjIzNTQgMTI5LjU4NloiIGZpbGw9IiMyOUFCRTIiLz4KPHBhdGggZD0iTTk5LjgyMTcgNjQuNzI0NUMxMDEuMDE0IDU2Ljc1MzggOTQuOTQ0NyA1Mi40Njg5IDg2LjY0NTUgNDkuNjEwNEw4OS4zMzc2IDM4LjgxM0w4Mi43NjQ1IDM3LjE3NUw4MC4xNDM1IDQ3LjY4NzlDNzguNDE1NSA0Ny4yNTczIDc2LjY0MDYgNDYuODUxMSA3NC44NzcxIDQ2LjQ0ODdMNzcuNTE2OCAzNS44NjY1TDcwLjk0NzQgMzQuMjI4NUw2OC4yNTM0IDQ1LjAyMjJDNjYuODIzIDQ0LjY5NjUgNjUuNDE4OSA0NC4zNzQ2IDY0LjA1NiA0NC4wMzU3TDY0LjA2MzUgNDQuMDAyTDU0Ljk5ODUgNDEuNzM4OEw1My4yNDk5IDQ4Ljc1ODZDNTMuMjQ5OSA0OC43NTg2IDU4LjEyNjkgNDkuODc2MiA1OC4wMjM5IDQ5Ljk0NTRDNjAuNjg2MSA1MC42MSA2MS4xNjcyIDUyLjM3MTUgNjEuMDg2NyA1My43NjhDNTguNjI3IDYzLjYzNDUgNTYuMTcyMSA3My40Nzg4IDUzLjcxMDQgODMuMzQ2N0M1My4zODQ3IDg0LjE1NTQgNTIuNTU5MSA4NS4zNjg0IDUwLjY5ODIgODQuOTA3OUM1MC43NjM3IDg1LjAwMzQgNDUuOTIwNCA4My43MTU1IDQ1LjkyMDQgODMuNzE1NUw0Mi42NTcyIDkxLjIzODlMNTEuMjExMSA5My4zNzFDNTIuODAyNSA5My43Njk3IDU0LjM2MTkgOTQuMTg3MiA1NS44OTcxIDk0LjU4MDNMNTMuMTc2OSAxMDUuNTAxTDU5Ljc0MjYgMTA3LjEzOUw2Mi40MzY2IDk2LjMzNDNDNjQuMjMwMSA5Ni44MjEgNjUuOTcxMiA5Ny4yNzAzIDY3LjY3NDkgOTcuNjkzNEw2NC45OTAyIDEwOC40NDhMNzEuNTYzNCAxMTAuMDg2TDc0LjI4MzYgOTkuMTg1M0M4NS40OTIyIDEwMS4zMDYgOTMuOTIwNyAxMDAuNDUxIDk3LjQ2ODQgOTAuMzE0MUMxMDAuMzI3IDgyLjE1MjQgOTcuMzI2MSA3Ny40NDQ1IDkxLjQyODggNzQuMzc0NUM5NS43MjM2IDczLjM4NDIgOTguOTU4NiA3MC41NTk0IDk5LjgyMTcgNjQuNzI0NVpNODQuODAzMiA4NS43ODIxQzgyLjc3MiA5My45NDM4IDY5LjAyODQgODkuNTMxNiA2NC41NzI3IDg4LjQyNTNMNjguMTgyMiA3My45NTdDNzIuNjM4IDc1LjA2ODkgODYuOTI2MyA3Ny4yNzA0IDg0LjgwMzIgODUuNzgyMVpNODYuODM2NCA2NC42MDY2Qzg0Ljk4MyA3Mi4wMzA3IDczLjU0NDEgNjguMjU4OCA2OS44MzM1IDY3LjMzNEw3My4xMDYgNTQuMjExN0M3Ni44MTY2IDU1LjEzNjQgODguNzY2NiA1Ni44NjIzIDg2LjgzNjQgNjQuNjA2NloiIGZpbGw9IndoaXRlIi8+CjxkZWZzPgo8bGluZWFyR3JhZGllbnQgaWQ9InBhaW50MF9saW5lYXJfMTEwXzU3MiIgeDE9IjUzLjQ3MzYiIHkxPSIxMjIuNzkiIHgyPSIxNC4wMzYyIiB5Mj0iODkuNTc4NiIgZ3JhZGllbnRVbml0cz0idXNlclNwYWNlT25Vc2UiPgo8c3RvcCBvZmZzZXQ9IjAuMjEiIHN0b3AtY29sb3I9IiNFRDFFNzkiLz4KPHN0b3Agb2Zmc2V0PSIxIiBzdG9wLWNvbG9yPSIjNTIyNzg1Ii8+CjwvbGluZWFyR3JhZGllbnQ+CjxsaW5lYXJHcmFkaWVudCBpZD0icGFpbnQxX2xpbmVhcl8xMTBfNTcyIiB4MT0iMTIwLjY1IiB5MT0iNTUuNjAyMSIgeDI9IjgxLjIxMyIgeTI9IjIyLjM5MTQiIGdyYWRpZW50VW5pdHM9InVzZXJTcGFjZU9uVXNlIj4KPHN0b3Agb2Zmc2V0PSIwLjIxIiBzdG9wLWNvbG9yPSIjRjE1QTI0Ii8+CjxzdG9wIG9mZnNldD0iMC42ODQxIiBzdG9wLWNvbG9yPSIjRkJCMDNCIi8+CjwvbGluZWFyR3JhZGllbnQ+CjwvZGVmcz4KPC9zdmc+Cg=="
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
        controller_id = principal "'${DEPLOYEMENT_PRINCIPAL}'";
      };
    }
  }
)' --ic
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
        controller_id = principal "'${DEPLOYEMENT_PRINCIPAL}'";
      };
    }
  }
)' --ic
dfx deploy twv_ledger --argument '(
  variant {
    Init = record {
      decimals = opt (8 : nat8);
      token_symbol = "TWV";
      token_name = "TowerView";
      transfer_fee = 1000 : nat;
      max_memo_length = null;
      feature_flags = null;
      metadata = (
        vec {
          record {
            "icrc1:logo";
            variant {
              Text = "data:image/png;base64,'${TOWER_COIN}'"
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
        controller_id = principal "'${DEPLOYEMENT_PRINCIPAL}'";
      };
    }
  }
)' --ic
dfx deploy kong_backend --ic
dfx deploy xrc_stub --argument '( record {
  ck_usdt = record {
    usd_price = '${CKUSDT_USD_PRICE}' : nat64;
    decimals = '${CKUSDT_DECIMALS}' : nat32;
  };
  ck_btc = record {
    usd_price = '${CKBTC_USD_PRICE}' : nat64;
    decimals = '${CKBTC_DECIMALS}' : nat32;
  };
})' --ic
dfx deploy faucet --argument '( record {
  canister_ids = record {
    ckbtc_ledger = principal "'${CKBTC_LEDGER_PRINCIPAL}'";
    ckusdt_ledger = principal "'${CKUSDT_LEDGER_PRINCIPAL}'";
    twv_ledger = principal "'${TWV_LEDGER_PRINCIPAL}'";
  };
  ckbtc_mint_amount = 100_000_000 : nat;
  ckusdt_mint_amount = 100_000_000_000 : nat;
})' --ic

# Deploy protocol canister
#
# Dissent and consent parameters (see https://www.desmos.com/calculator/8iww2wlp2t)
# { dissent_steepness = 0.55; consent_steepness = 0.1; }
# dissent_steepness be in [0; 1[ - the closer to 1 the steepest (the less the majority is rewarded)
# consent_steepness be in [0; 0.25] - the closer to 0 the steepest
#
# Duration scaler parameters (see https://www.desmos.com/calculator/3xh0qbetki)
# { a = 72800000000.0; b = 3.25; }
# Gives a duration of 1 day for 1 USDT and 1 year for 100k USDT
#
# 216 seconds timer interval, with a 100x dilation factor, means 6 hours in simulated time
#
# Supply cap is set to 1M ckUSDT and borrow cap to 800k ckUSDT
dfx deploy protocol --argument '( variant { 
  init = record {
    canister_ids = record {
      supply_ledger = principal "'${CKUSDT_LEDGER_PRINCIPAL}'";
      collateral_ledger = principal "'${CKBTC_LEDGER_PRINCIPAL}'";
      kong_backend = principal "'${KONG_BACKEND_PRINCIPAL}'";
      participation_ledger = principal "'${TWV_LEDGER_PRINCIPAL}'";
      xrc = principal "'${XRC_STUB_PRINCIPAL}'";
    };
    parameters = record {
      foresight = record {
        dissent_steepness = 0.55;
        consent_steepness = 0.1;
      };
      position_half_life = variant { DAYS = 60 };
      duration_scaler = record { a = 1500000000000.0; b = 1.9; };
      minimum_position_amount = 1_000_000;
      timer_interval_s = 300;
      clock = variant { REAL };
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
      mining = record {
        emission_half_life = variant { YEARS = 2 };
        emission_total_amount_e8s = 6_700_000_000_000_000;
        borrowers_share = 0.75;
      };
    };
  }
})' --ic

dfx deploy backend --ic

# Transfer TWV tokens for the protocol to mint
dfx canister call faucet admin_mint_twv '(
  record {
    to = record {
      owner = principal "'${PROTOCOL_PRINCIPAL}'";
      subaccount = null;
    };
    amount = 6_700_000_000_000_000 : nat;
  },
)' --ic

# Create ckBTC/ckUSDT pool
# ⚠️ ckUSDT SHALL BE ADDED FIRST, then ckBTC. 
# OTHERWISE THE POOL WILL NOT BE CREATED
# THIS IS A LIMITATION FROM THE KONG BACKEND
dfx canister call kong_backend add_token '(
  record {
    token = "IC.'${CKUSDT_LEDGER_PRINCIPAL}'";
  },
)' --ic
dfx canister call kong_backend add_token '(
  record {
    token = "IC.'${CKBTC_LEDGER_PRINCIPAL}'";
  },
)' --ic
# 1K ckBTC and 108M ckUSDT liquidity
dfx canister call faucet admin_mint_btc '(
  record {
    to = record {
      owner = principal "'${DEPLOYEMENT_PRINCIPAL}'";
      subaccount = null;
    };
    amount = 100_000_000_020 : nat;
  },
)' --ic
dfx canister call faucet admin_mint_usdt '(
  record {
    to = record {
      owner = principal "'${DEPLOYEMENT_PRINCIPAL}'";
      subaccount = null;
    };
    amount = 108_702_000_020_000 : nat;
  },
)' --ic
dfx canister call ckbtc_ledger icrc2_approve '(
  record {
    fee = null;
    memo = null;
    from_subaccount = null;
    created_at_time = null;
    amount = 100_000_000_010 : nat;
    expected_allowance = null;
    expires_at = null;
    spender = record {
      owner = principal "'${KONG_BACKEND_PRINCIPAL}'";
      subaccount = null;
    };
  },
)' --ic
dfx canister call ckusdt_ledger icrc2_approve '(
  record {
    fee = null;
    memo = null;
    from_subaccount = null;
    created_at_time = null;
    amount = 108_702_000_010_000 : nat;
    expected_allowance = null;
    expires_at = null;
    spender = record {
      owner = principal "'${KONG_BACKEND_PRINCIPAL}'";
      subaccount = null;
    };
  },
)' --ic
dfx canister call kong_backend add_pool '(
  record {
    token_0 = "IC.'${CKBTC_LEDGER_PRINCIPAL}'";
    token_1 = "IC.'${CKUSDT_LEDGER_PRINCIPAL}'";
    amount_0 = 100_000_000_000 : nat;
    amount_1 =  108_702_000_000_000 : nat;
    tx_id_0 = null;
    tx_id_1 = null;
    lp_fee_bps = null;
  },
)' --ic

# Protocol initialization and frontend generation
dfx canister call protocol init_facade --ic

dfx deploy frontend --ic
