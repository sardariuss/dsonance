import { Link, useLocation }      from "react-router-dom";
import { useEffect } from "react";
import { useAuth } from "@ic-reactor/react";
import { protocolActor } from "../actors/ProtocolActor";
import Select from "react-select";
import { SupportedCurrency, useCurrencyContext } from "./CurrencyContext";
import BitcoinIcon from "./icons/BitcoinIcon";
import ResonanceCoinIcon from "./icons/ResonanceCoinIcon";
import { RESONANCE_TOKEN_SYMBOL } from "../constants";
import { fromE8s } from "../utils/conversions/token";
import UserIcon from "./icons/UserIcon";
import LoginIcon from "./icons/LoginIcon";
import { computeMintingRate } from "./ProtocolInfo";

const Header = () => {

  const { login, authenticated, identity } = useAuth({});

  const { data: protocolInfo, call: refreshProtocolInfo } = protocolActor.useQueryCall({
    functionName: "get_protocol_info",
    args: [],
  });

  const location = useLocation();

  const { currency, setCurrency, currencySymbol, satoshisToCurrency } = useCurrencyContext();

  useEffect(() => {

    var themeToggleDarkIcon = document.getElementById('theme-toggle-dark-icon');
    var themeToggleLightIcon = document.getElementById('theme-toggle-light-icon');
    var themeToggleBtn = document.getElementById('theme-toggle');

    if (themeToggleDarkIcon == null || themeToggleLightIcon == null || themeToggleBtn == null) {
      return;
    };
  
    // Change the icons inside the button based on previous settings
    if (localStorage.getItem('color-theme') === 'dark' || (!('color-theme' in localStorage) && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
      themeToggleLightIcon.classList.remove('hidden');
    } else {
      themeToggleDarkIcon.classList.remove('hidden');
    }
  
    themeToggleBtn.addEventListener('click', function() {
  
      // toggle icons inside button
      if (themeToggleDarkIcon !== null) {
        themeToggleDarkIcon.classList.toggle('hidden');
      }
      if (themeToggleLightIcon !== null) {
        themeToggleLightIcon.classList.toggle('hidden');
      }

      // if set via local storage previously
      if (localStorage.getItem('color-theme')) {
        if (localStorage.getItem('color-theme') === 'light') {
          document.documentElement.classList.add('dark');
          localStorage.setItem('color-theme', 'dark');
        } else {
          document.documentElement.classList.remove('dark');
          localStorage.setItem('color-theme', 'light');
        }

      // if NOT set via local storage previously
      } else {
        if (document.documentElement.classList.contains('dark')) {
          document.documentElement.classList.remove('dark');
          localStorage.setItem('color-theme', 'light');
        } else {
          document.documentElement.classList.add('dark');
          localStorage.setItem('color-theme', 'dark');
        }
      }
    });

    refreshProtocolInfo();

  }, []);

  const mintingRate = protocolInfo && computeMintingRate(protocolInfo.ck_btc_locked.current.data, protocolInfo.minting_per_ns, satoshisToCurrency);

  return (
    <header className="bg-slate-100 dark:bg-gray-800 sticky top-0 z-30 flex flex-row items-center w-full xl:px-4 lg:px-3 md:px-2 px-2 xl:h-18 lg:h-16 md:h-14 h-14 relative">
      {/* Left-aligned RESONANCE Link */}
      
      <Link to="/" className="flex items-baseline 2xl:pt-6 xl:pt-5 lg:pt-4 md:pt-3 pt-2">
        <span className="text-xl md:text-2xl lg:text-3xl xl:text-4xl 2xl:text-5xl font-acelon whitespace-nowrap drop-shadow-lg shadow-white font-bold">
          RESONANCE
        </span>
        <span className="text-4xl md:text-5xl lg:text-6xl xl:text-7xl 2xl:text-8xl font-cafe whitespace-nowrap drop-shadow shadow-blue-800 neon-effect">
          .defi
        </span>
      </Link>

      {/* Spacer to center the second element */}
      <div className="flex-grow"></div>

      {/* Centered Minting Rate Info */}
      {mintingRate && location.pathname !== "/protocol_info" && (
        <Link
          className="absolute left-1/2 transform -translate-x-1/2 flex flex-row items-center justify-center space-x-1 text-gray-800 hover:text-black dark:text-gray-200 dark:hover:text-white hover:cursor-pointer"
          to={"/protocol_info"}
        >
          <ResonanceCoinIcon />
          <span>Minting rate:</span>
          <span className="text-lg">
            {`${fromE8s(BigInt(mintingRate)).toString()} ${RESONANCE_TOKEN_SYMBOL}/${currencySymbol}/day`}
          </span>
        </Link>
      )}
      
      {/* Right-aligned Profile and Theme Toggle */}
      <div className="flex flex-row items-center justify-end md:space-x-6 space-x-2">
        <div className="flex flex-row items-center space-x-1 mr-8">
          <span>View</span>
          <BitcoinIcon />
          <span className="pr-2">in</span>
          <Select
            options={Object.values(SupportedCurrency).map((currency) => ({
              value: currency,
              label: currency,
            }))}
            value={{ value: currency, label: currency }}
            onChange={(option) => {
              if (option !== null) setCurrency(option.value as SupportedCurrency);
            }}
            styles={{
              control: (provided, state) => ({
                ...provided,
                color: "#fff",
                backgroundColor: "#ddd",
                borderColor: state.isFocused ? "rgb(168 85 247) !important" : "#ccc !important", // Enforce purple border
                boxShadow: state.isFocused
                  ? "0 0 0 0.5px rgb(168, 85, 247) !important"
                  : "none !important", // Enforce purple focus ring
                outline: "none", // Remove browser default outline
              }),
              singleValue: (provided) => ({
                ...provided,
                color: "#000",
              }),
              option: (provided) => ({
                ...provided,
                color: "#000",
                backgroundColor: "#fff",
                "&:hover": {
                  backgroundColor: "#ddd",
                },
              }),
            }}
          />
        </div>
        <Link className="text-gray-800 hover:text-black dark:text-gray-200 dark:hover:text-white hover:cursor-pointer" to="https://sardarius-corp.gitbook.io/resonance-defi">
          Docs
        </Link>
        <div>
        { authenticated && identity ? 
          <Link className="flex stroke-gray-800 hover:stroke-black dark:stroke-gray-200 dark:hover:stroke-white rounded-lg hover:cursor-pointer" to={`/user/${identity.getPrincipal()}`}>
            <UserIcon />
          </Link> :
          <div className="flex fill-gray-800 hover:fill-black dark:fill-gray-200 dark:hover:fill-white rounded-lg hover:cursor-pointer" onClick={() => { login() }}>
            <LoginIcon /> 
          </div>
        }
        </div>
        <button id="theme-toggle" type="button" className="fill-indigo-600 hover:fill-indigo-900 dark:fill-yellow-400 dark:hover:fill-yellow-200 rounded-lg text-sm">
          <svg id="theme-toggle-dark-icon" className="hidden w-5 h-5" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M17.293 13.293A8 8 0 016.707 2.707a8.001 8.001 0 1010.586 10.586z"></path></svg>
          <svg id="theme-toggle-light-icon" className="hidden w-5 h-5" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M10 2a1 1 0 011 1v1a1 1 0 11-2 0V3a1 1 0 011-1zm4 8a4 4 0 11-8 0 4 4 0 018 0zm-.464 4.95l.707.707a1 1 0 001.414-1.414l-.707-.707a1 1 0 00-1.414 1.414zm2.12-10.607a1 1 0 010 1.414l-.706.707a1 1 0 11-1.414-1.414l.707-.707a1 1 0 011.414 0zM17 11a1 1 0 100-2h-1a1 1 0 100 2h1zm-7 4a1 1 0 011 1v1a1 1 0 11-2 0v-1a1 1 0 011-1zM5.05 6.464A1 1 0 106.465 5.05l-.708-.707a1 1 0 00-1.414 1.414l.707.707zm1.414 8.486l-.707.707a1 1 0 01-1.414-1.414l.707-.707a1 1 0 011.414 1.414zM4 11a1 1 0 100-2H3a1 1 0 000 2h1z" fillRule="evenodd" clipRule="evenodd"></path></svg>
        </button>
      </div>
    </header>
  );
}

export default Header;