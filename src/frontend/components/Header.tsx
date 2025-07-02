import { Link, useLocation, useNavigate }      from "react-router-dom";
import React, { useEffect, useRef, useState } from "react";
import { useAuth } from "@ic-reactor/react";
import { DOCS_URL, MOBILE_MAX_WIDTH_QUERY } from "../constants";
import UserIcon from "./icons/UserIcon";
import LoginIcon from "./icons/LoginIcon";
import BtcBalance from "./BtcBalance";
import Logo from "./icons/Logo";
import { useMediaQuery } from "react-responsive";
import { Identity } from "@dfinity/agent";
import LinkIcon from "./icons/LinkIcon";
import ThemeToggle from "./ThemeToggle";

interface HeaderProps {
  authenticated: boolean;
  identity: Identity | null;
  login: () => void;
}

const DesktopHeader: React.FC<HeaderProps> = ({ authenticated, identity, login }) => {
  // WATCHOUT: the size of the header is set to 22 (16 + 6), it is used in User.tsx as margin (see scroll-mt)
  return (
    <header className="sticky top-0 z-30 flex flex-col relative w-full">
      <nav className="flex flex-row bg-slate-200 dark:bg-gray-800 sticky top-0 z-30 flex flex-row items-center w-full xl:px-4 lg:px-3 md:px-2 px-2 h-16 min-h-16 relative">
        {/* Left-aligned Dsonance Link */}
        <Link to="/" className="flex flex-row items-baseline">
          <div className="w-16 sm:w-18 md:w-20 lg:w-22 xl:w-24 pr-2 pt-1 lg:pt-2">
            <Logo />
          </div>
          <span className="text-3xl md:text-4xl 2xl:text-5xl font-acelon whitespace-nowrap drop-shadow-lg shadow-white font-bold">
            DSONANCE
          </span>
          <span className="text-3xl md:text-4xl 2xl:text-5xl font-cafe whitespace-nowrap drop-shadow-lg shadow-white">
            .xyz
          </span>
        </Link>

        {/* Spacer to center the second element */}
        <div className="flex-grow"></div>
        
        {/* Right-aligned Profile and Theme Toggle */}
        <div className="flex flex-row items-center justify-end md:space-x-6 space-x-2">
          <Link className="text-gray-800 hover:text-black dark:text-gray-200 dark:hover:text-white hover:cursor-pointer" to={"/"}>
            Vote
          </Link>
          <Link className="text-gray-800 hover:text-black dark:text-gray-200 dark:hover:text-white hover:cursor-pointer" to={"/borrow"}>
            Borrow
          </Link>
          <Link className="text-gray-800 hover:text-black dark:text-gray-200 dark:hover:text-white hover:cursor-pointer" to={"/dashboard"}>
            Dashboard
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
          <ThemeToggle/>
        </div>
      </nav>
      <span className="flex flex-row w-full bg-purple-700 dark:bg-purple-700 items-center justify-center text-white h-6 min-h-6">
        ⚠️ This is a simulated version. All coins and transactions have no real monetary value.
      </span>
    </header>
  );
}

const MobileHeader: React.FC<HeaderProps> = ({ authenticated, identity, login }) => {

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

  // WATCHOUT: the size of the header is set to 26 (20 + 6), it is used in User.tsx as margin (see scroll-mt)
  return (
    <header className="sticky top-0 z-30 flex flex-col relative w-full">
      <nav className="flex flex-row items-center bg-slate-200 dark:bg-gray-800 sticky top-0 z-30 w-full h-20 min-h-20 relative">
        {/* Centered Dsonance Link */}
        <Link className="flex flex-grow justify-center pt-4" to="/">
          <span className="flex flex-row items-baseline">
            <div className="h-10 w-20 pt-1 pr-1">
              <Logo />
            </div>
            <span className="text-4xl font-acelon whitespace-nowrap drop-shadow-lg shadow-white font-bold ">
              DSONANCE
            </span>
            <span className="text-4xl font-cafe whitespace-nowrap drop-shadow-lg shadow-white">
              .xyz
            </span>
          </span>
        </Link>

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
      <span className="flex flex-row w-full bg-purple-700 dark:bg-purple-700 items-center justify-center text-white h-6 min-h-6">
        ⚠️ This is a simulated version.
      </span>
      {
         showMenu && (
          <div ref={menuRef} className="absolute top-20 left-0 flex flex-col w-full bg-slate-200 dark:bg-gray-800 text-lg py-2 px-4">
            <div className={`grid grid-cols-12 py-2 px-4 rounded-lg ${location.pathname === '/' ? 'bg-purple-700 text-white' : ''}`}>
              <span />
              <Link
                className="cols-span-11 overflow-visible whitespace-nowrap"
                to="/"
                onClick={() => setShowMenu(false)}
              >
                Vote
              </Link>
            </div>
            <div className={`grid grid-cols-12 py-2 px-4 rounded-lg ${location.pathname === '/borrow' ? 'bg-purple-700 text-white' : ''}`}>
              <span />
              <Link
                className="cols-span-11 overflow-visible whitespace-nowrap"
                to="/borrow"
                onClick={() => setShowMenu(false)}
              >
                Borrow
              </Link>
            </div>
            <div className={`grid grid-cols-12 py-2 px-4 rounded-lg ${location.pathname === '/dashboard' ? 'bg-purple-700 text-white' : ''}`}>
              <span />
              <Link
                className="cols-span-11 overflow-visible whitespace-nowrap"
                to="/dashboard"
                onClick={() => setShowMenu(false)}
              >
                Dashboard
              </Link>
            </div>
            <span />
            {authenticated && identity ? (
              <Link
                className={`grid grid-cols-12 py-2 px-4 rounded-lg flex flex-row items-center stroke-gray-800 hover:stroke-black dark:stroke-gray-200 dark:hover:stroke-white rounded-lg hover:cursor-pointer ${
                  location.pathname === `/user/${identity.getPrincipal()}` ? 'bg-purple-700 text-white' : ''
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

  return (
    isMobile ? 
      <MobileHeader authenticated={authenticated} identity={identity} login={login} /> :
      <DesktopHeader authenticated={authenticated} identity={identity} login={login} />
  );
}

export default Header;