import { Link, useLocation, useNavigate }      from "react-router-dom";
import React, { useContext, useEffect, useRef, useState } from "react";
import { useAuth } from "@ic-reactor/react";
import Select from "react-select";
import { SupportedCurrency, useCurrencyContext } from "./CurrencyContext";
import BitcoinIcon from "./icons/BitcoinIcon";
import { DOCS_URL, MOBILE_MAX_WIDTH_QUERY, PARTICIPATION_EMOJI, RESONANCE_TOKEN_SYMBOL } from "../constants";
import { fromE8s } from "../utils/conversions/token";
import UserIcon from "./icons/UserIcon";
import LoginIcon from "./icons/LoginIcon";
import { computeMintingRate } from "./ProtocolInfo";
import BtcBalance from "./BtcBalance";
import { ThemeContext } from "./App";
import { useProtocolInfoContext } from "./ProtocolInfoContext";
import Logo from "./icons/Logo";
import { useMediaQuery } from "react-responsive";
import { Identity } from "@dfinity/agent";
import LinkIcon from "./icons/LinkIcon";

interface HeaderProps {
  mintingRate?: number;
  currency: SupportedCurrency;
  setCurrency: (currency: SupportedCurrency) => void;
  currencySymbol: string;
  toggleTheme: () => void;
  theme: string;
  authenticated: boolean;
  identity: Identity | null;
  login: () => void;
}

const ThemeToggle: React.FC<{ theme: string, toggleTheme: () => void }> = ({ theme, toggleTheme }) => {
  return (
    <button
      id="theme-toggle"
      type="button"
      className="rounded-lg text-sm"
      onClick={toggleTheme}
    >
      {theme === "dark" ? (
        <svg
          id="theme-toggle-light-icon"
          className="w-5 h-5 fill-yellow-400 hover:fill-yellow-300"
          viewBox="0 0 20 20"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            d="M10 2a1 1 0 011 1v1a1 1 0 11-2 0V3a1 1 0 011-1zm4 8a4 4 0 11-8 0 4 4 0 018 0zm-.464 4.95l.707.707a1 1 0 001.414-1.414l-.707-.707a1 1 0 00-1.414 1.414zm2.12-10.607a1 1 0 010 1.414l-.706.707a1 1 0 11-1.414-1.414l.707-.707a1 1 0 011.414 0zM17 11a1 1 0 100-2h-1a1 1 0 100 2h1zm-7 4a1 1 0 011 1v1a1 1 0 11-2 0v-1a1 1 0 011-1zM5.05 6.464A1 1 0 106.465 5.05l-.708-.707a1 1 0 00-1.414 1.414l.707.707zm1.414 8.486l-.707.707a1 1 0 01-1.414-1.414l.707-.707a1 1 0 011.414 1.414zM4 11a1 1 0 100-2H3a1 1 0 000 2h1z"
            fillRule="evenodd"
            clipRule="evenodd"
          />
        </svg>
      ) : (
        <svg
          id="theme-toggle-dark-icon"
          className="w-5 h-5 fill-purple-700 hover:fill-purple-800"
          viewBox="0 0 20 20"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path d="M17.293 13.293A8 8 0 016.707 2.707a8.001 8.001 0 1010.586 10.586z"></path>
        </svg>
      )}
    </button>
  );
};

const DesktopHeader: React.FC<HeaderProps> = ({ mintingRate, currency, setCurrency, currencySymbol, toggleTheme, theme, authenticated, identity, login }) => {
  return (
    <header className="sticky top-0 z-30 flex flex-col relative w-full">
      
      <div className="flex flex-row bg-slate-200 dark:bg-gray-800 sticky top-0 z-30 flex flex-row items-center w-full xl:px-4 lg:px-3 md:px-2 px-2 xl:h-18 lg:h-16 md:h-14 h-14 relative">
        {/* Left-aligned RESONANCE Link */}
        <Link to="/" className="flex flex-row items-baseline 2xl:pt-6 xl:pt-5 lg:pt-4 md:pt-3 pt-2">
          <div className="h-8 sm:h-9 md:h-10 lg:h-11 xl:h-12 w-16 sm:w-18 md:w-20 lg:w-22 xl:w-24 pt-1 lg:pt-2 pr-1 lg:pr-2">
            <Logo />
          </div>
          <span className="text-xl md:text-2xl lg:text-3xl xl:text-4xl 2xl:text-5xl font-acelon whitespace-nowrap drop-shadow-lg shadow-white font-bold">
            RESONANCE
          </span>
          <span className="text-4xl md:text-5xl lg:text-6xl xl:text-7xl 2xl:text-8xl font-cafe whitespace-nowrap drop-shadow shadow-red-500 neon-effect">
            .defi
          </span>
        </Link>

        {/* Spacer to center the second element */}
        <div className="flex-grow"></div>

        {/* Centered Minting Rate Info */}
        { mintingRate && location.pathname !== "/protocol_info" && (
          <Link
            className="absolute left-1/2 transform -translate-x-1/2 flex flex-row items-center justify-center space-x-1 hover:text-black dark:text-gray-200 dark:hover:text-white hover:cursor-pointer"
            to="/protocol_info"
          >
            <span>{PARTICIPATION_EMOJI}</span>
            <span>Participation rate:</span>
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
          <Link className="text-gray-800 hover:text-black dark:text-gray-200 dark:hover:text-white hover:cursor-pointer" to={DOCS_URL}>
            Docs
          </Link>
          { authenticated && identity && <BtcBalance/> }
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
          <ThemeToggle theme={theme} toggleTheme={toggleTheme} />
        </div>
      </div>
      <span className="flex flex-row w-full bg-purple-700 dark:bg-purple-700 items-center justify-center text-white">
        ⚠️ This is a simulated version. All coins and transactions have no real monetary value.
      </span>
    </header>
  );
}

const MobileHeader: React.FC<HeaderProps> = ({ mintingRate, currency, setCurrency, currencySymbol, toggleTheme, theme, authenticated, identity, login }) => {

  const [showMenu, setShowMenu] = useState(false);
  const menuRef = useRef<HTMLDivElement | null>(null); // Reference to the menu
  const menuButtonRef = useRef<HTMLDivElement | null>(null); // Reference to the menu button
  const location = useLocation(); // Current location/path

  // Hide the menu if the user clicks outside of it
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node) 
        && menuButtonRef.current && !menuButtonRef.current.contains(event.target as Node)) {
        setShowMenu(false); // Close the menu
      }
    };

    // Add event listener for clicks outside
    document.addEventListener('mousedown', handleClickOutside);

    // Cleanup the event listener when the component unmounts or showMenu changes
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  useEffect(() => {
    console.log("showMenu:", showMenu);
  }
  , [showMenu]);

  return (
    <header className="sticky top-0 z-30 flex flex-col relative w-full">
      <nav className="flex flex-row items-center bg-slate-200 dark:bg-gray-800 sticky top-0 z-30 w-full h-20 relative">
        {/* Centered RESONANCE Link */}
        <div className="flex flex-grow justify-center pt-4">
          <span className="flex flex-row items-baseline">
            <div className="h-10 w-20 pt-1 pr-1">
              <Logo />
            </div>
            <span className="text-4xl font-acelon whitespace-nowrap drop-shadow-lg shadow-white font-bold">
              RESONANCE
            </span>
            <span className="text-7xl font-cafe whitespace-nowrap drop-shadow shadow-red-500 neon-effect">
              .defi
            </span>
          </span>
        </div>

        {/* Right-aligned Button */}
        <div ref={menuButtonRef}>
          <button
            type="button"
            className="flex p-2 mr-2 w-10 h-10 items-center justify-center rounded-lg hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-gray-200 dark:hover:bg-gray-700 dark:focus:ring-gray-600 ml-auto"
            onClick={(e) => { setShowMenu(!showMenu); }}
          >
            <svg className="w-5 h-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 17 14">
              <path stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M1 1h15M1 7h15M1 13h15"/>
            </svg>
          </button>
        </div>
      </nav>
      <span className="flex flex-row w-full bg-purple-700 dark:bg-purple-700 items-center justify-center text-white">
        ⚠️ This is a simulated version.
      </span>
      {
         showMenu && (
          <div ref={menuRef} className="absolute top-20 left-0 flex flex-col w-full bg-slate-200 dark:bg-gray-800 text-lg py-2 px-4">
            <div className={`grid grid-cols-12 py-2 px-4 rounded-lg ${location.pathname === '/' ? 'bg-purple-700' : ''}`}>
              <span />
              <Link
                className="cols-span-11 overflow-visible whitespace-nowrap"
                to="/"
                onClick={() => setShowMenu(false)}
              >
                Home
              </Link>
            </div>
            <div className={`grid grid-cols-12 py-2 px-4 rounded-lg ${location.pathname === '/protocol_info' ? 'bg-purple-700' : ''}`}>
              <span />
              <Link
                className="cols-span-11 overflow-visible whitespace-nowrap"
                to="/protocol_info"
                onClick={() => setShowMenu(false)}
              >
                Protocol Info
              </Link>
            </div>
            <div className={`grid grid-cols-12 py-2 px-4 rounded-lg items-center ${location.pathname === DOCS_URL ? 'bg-purple-700' : ''}`}>
              <LinkIcon/>
              <Link
                className="cols-span-11 overflow-visible whitespace-nowrap"
                to={DOCS_URL}
                onClick={() => setShowMenu(false)}
              >
                Docs
              </Link>
            </div>
            <span />
            {authenticated && identity ? (
              <Link
                className={`grid grid-cols-12 py-2 px-4 rounded-lg flex flex-row items-center stroke-gray-800 hover:stroke-black dark:stroke-gray-200 dark:hover:stroke-white rounded-lg hover:cursor-pointer ${
                  location.pathname === `/user/${identity.getPrincipal()}` ? 'bg-purple-700' : ''
                }`}
                to={`/user/${identity.getPrincipal()}`}
                onClick={() => setShowMenu(false)}
              >
                <UserIcon />
                <span className="cols-span-11">Profile</span>
              </Link>
            ) : (
              <div
                className="grid grid-cols-12 py-2 px-4 rounded-lg flex flex-row items-center fill-gray-800 hover:fill-black dark:fill-gray-200 dark:hover:fill-white rounded-lg hover:cursor-pointer"
                onClick={() => { setShowMenu(false); login(); }}
              >
                <LoginIcon />
                <span className="cols-span-11">Login</span>
              </div>
            )}
          </div>
        )
      }
    </header>
  );
}

const Header = () => {

  const navigate = useNavigate();

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const { login, authenticated, identity } = useAuth({ 
    onLoginSuccess: (principal) => {
      navigate(`/user/${principal.toText()}`)
    },
  });

  const { info: { protocolParameters, totalLocked }, refreshInfo } = useProtocolInfoContext();

  const { currency, setCurrency, currencySymbol, satoshisToCurrency } = useCurrencyContext();

  useEffect(() => {
    refreshInfo();
  }, []);

  const mintingRate = protocolParameters && totalLocked && computeMintingRate(totalLocked.current.data, protocolParameters.participation_per_ns, satoshisToCurrency);

  const { theme, setTheme } = useContext(ThemeContext);

  const toggleTheme = () => {
    setTheme(theme === "dark" ? "light" : "dark");
  };

  return (
    isMobile ? 
      <MobileHeader mintingRate={mintingRate} currency={currency} setCurrency={setCurrency} currencySymbol={currencySymbol} toggleTheme={toggleTheme} theme={theme} authenticated={authenticated} identity={identity} login={login} /> :
      <DesktopHeader mintingRate={mintingRate} currency={currency} setCurrency={setCurrency} currencySymbol={currencySymbol} toggleTheme={toggleTheme} theme={theme} authenticated={authenticated} identity={identity} login={login} />
  );
}

export default Header;