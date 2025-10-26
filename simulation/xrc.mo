

shared persistent actor class ExchangeRate({ 
    ck_usdt: {
        usd_price: Nat64;
        decimals: Nat32;
    };
    ck_btc: {
        usd_price: Nat64;
        decimals: Nat32;
    };
}) {

  // === Types from the XRC IDL ===

  public type AssetClass = {
    #Cryptocurrency;
    #FiatCurrency;
  };

  public type Asset = {
    symbol : Text;
    class_ : AssetClass;
  };

  public type GetExchangeRateRequest = {
    base_asset : Asset;
    quote_asset : Asset;
    timestamp : ?Nat64;
  };

  public type ExchangeRateMetadata = {
    decimals : Nat32;
    base_asset_num_received_rates : Nat64;
    base_asset_num_queried_sources : Nat64;
    quote_asset_num_received_rates : Nat64;
    quote_asset_num_queried_sources : Nat64;
    standard_deviation : Nat64;
    forex_timestamp : ?Nat64;
  };

  public type ExchangeRate = {
    base_asset : Asset;
    quote_asset : Asset;
    timestamp : Nat64;
    rate : Nat64;
    metadata : ExchangeRateMetadata;
  };

  public type ExchangeRateError = {
    #AnonymousPrincipalNotAllowed;
    #Pending;
    #CryptoBaseAssetNotFound;
    #CryptoQuoteAssetNotFound;
    #StablecoinRateNotFound;
    #StablecoinRateTooFewRates;
    #StablecoinRateZeroRate;
    #ForexInvalidTimestamp;
    #ForexBaseAssetNotFound;
    #ForexQuoteAssetNotFound;
    #ForexAssetsNotFound;
    #RateLimited;
    #NotEnoughCycles;
    #FailedToAcceptCycles;
    #InconsistentRatesReceived;
    #Other : { code : Nat32; description : Text };
  };

  public type GetExchangeRateResult = {
    #Ok : ExchangeRate;
    #Err : ExchangeRateError;
  };

  // === Mock Implementation ===

  public query func get_exchange_rate(req : GetExchangeRateRequest) : async GetExchangeRateResult {
    
    if (req.quote_asset.symbol != "USD") {
      return #Err(#CryptoQuoteAssetNotFound);
    };

    let { rate; decimals; } = switch (req.base_asset.symbol) {
      case ("ckUSDT") { { rate = ck_usdt.usd_price; decimals = ck_usdt.decimals; }; };
      case ("ckBTC") { { rate = ck_btc.usd_price; decimals = ck_btc.decimals; }; };
      case (_) {
        return #Err(#CryptoBaseAssetNotFound);
      };
    };

    // Return a dummy success response
    #Ok({
      base_asset = req.base_asset;
      quote_asset = req.quote_asset;
      timestamp = switch (req.timestamp) {
        case (?t) t;
        case null 0;
      };
      rate;
      metadata = {
        decimals;
        base_asset_num_received_rates = 3;
        base_asset_num_queried_sources = 3;
        quote_asset_num_received_rates = 3;
        quote_asset_num_queried_sources = 3;
        standard_deviation = 0;
        forex_timestamp = null;
      };
    });
  };
};
