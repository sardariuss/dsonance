import { Link, useLocation }      from "react-router-dom";
import React, { useEffect, useRef, useState } from "react";
import { useAuth } from "@nfid/identitykit/react";
import { MOBILE_MAX_WIDTH_QUERY } from "../constants";
import LoginIcon from "./icons/LoginIcon";
import Tower from "../assets/tower.png"
import { useMediaQuery } from "react-responsive";
import Avatar from "boring-avatars";
import { useUser } from "./hooks/useUser";
import { MdOutlineAccountBalanceWallet } from "react-icons/md";
import Wallet from "./wallet/Wallet";
import ThemeToggle from "./ThemeToggle";

const DesktopHeader: React.FC = () => {

  const { connect } = useAuth();
  const { user } = useUser();
  const [showWallet, setShowWallet] = useState(false);

  // WATCHOUT: the size of the header is set to 22 (16 + 6), it is used in User.tsx as margin (see scroll-mt)
  return (
    <header className="sticky top-0 z-30 flex flex-col relative w-full border-b border-gray-300 dark:border-gray-700">
      <nav className="flex flex-row bg-slate-100 dark:bg-slate-900 sticky top-0 z-30 flex flex-row items-center w-full xl:px-4 lg:px-3 md:px-2 px-2 h-16 min-h-16 relative">
        {/* Left-aligned Dsonance Link */}
        <Link to="/" className="flex flex-row items-baseline">
          <div className="h-10 pr-2">
            <img src={Tower} className="h-full w-full object-contain dark:invert"/>
          </div>
          <span className="text-5xl font-decoment whitespace-nowrap drop-shadow-lg shadow-white font-bold">
            TOWER
          </span>
          <span className="text-5xl font-decoment whitespace-nowrap drop-shadow-lg shadow-white font-bold dark:text-green-500 text-red-500">
            VIEW
          </span>
        </Link>

        {/* Spacer to center the second element */}
        <div className="flex-grow"></div>

        <ThemeToggle/>
        
        {/* Right-aligned Profile and Theme Toggle */}
        <div className="flex flex-row items-center justify-end md:space-x-6 space-x-2">
          <Link className="text-gray-800 hover:text-black dark:text-gray-200 dark:hover:text-white hover:cursor-pointer" to={"/"}>
            Markets
          </Link>
          <Link className="text-gray-800 hover:text-black dark:text-gray-200 dark:hover:text-white hover:cursor-pointer" to={"/borrow"}>
            Borrow
          </Link>
          <Link className="text-gray-800 hover:text-black dark:text-gray-200 dark:hover:text-white hover:cursor-pointer" to={"/dashboard"}>
            Dashboard
          </Link>
          <Link className="text-gray-800 hover:text-black dark:text-gray-200 dark:hover:text-white hover:cursor-pointer" to={"/faucet"}>
            Faucet
          </Link>
          { user ? 
            <Link className="flex items-center stroke-gray-800 hover:stroke-black dark:stroke-gray-200 dark:hover:stroke-white rounded-lg hover:cursor-pointer" to={`/user/${user.principal}`}>
              <Avatar
                size={32}
                name={user.principal.toString()}
                variant="marble"
              />
            </Link> :
            <div className="flex fill-gray-800 hover:fill-black dark:fill-gray-200 dark:hover:fill-white rounded-lg hover:cursor-pointer" onClick={() => { connect() }}>
              <LoginIcon /> 
            </div>
          }
          {/* Wallet Button */}
            { user && <button
                className="h-10 w-10 rounded-full bg-white p-2 text-xl text-black dark:bg-white/10 dark:text-white"
                onClick={() => setShowWallet(true)}
              >
                <MdOutlineAccountBalanceWallet size={22} />
              </button> 
            }
        </div>
      </nav>
      <Wallet
        isOpen={showWallet}
        onClose={() => setShowWallet(false)}
      />
    </header>
  );
}

const MobileHeader: React.FC = () => {

  const { connect } = useAuth();
  const { user } = useUser();
  const [showMenu, setShowMenu] = useState(false);
  const [showWallet, setShowWallet] = useState(false);
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
    <header className="sticky top-0 z-30 flex flex-col relative w-full border-b border-gray-300 dark:border-gray-700">
      <nav className="flex flex-row bg-slate-100 dark:bg-slate-900 items-center sticky top-0 z-30 w-full h-20 min-h-20 relative">
        {/* Centered Dsonance Link */}
        <Link className="flex flex-grow justify-center" to="/">
          <span className="flex flex-row items-baseline">
            <span className="h-12 pr-2">
              <img src={Tower} className="h-full w-full object-contain dark:invert"/>
            </span>
            <span className="text-[54px] font-decoment whitespace-nowrap drop-shadow-lg shadow-white font-bold leading-none flex items-center">
              TOWER
            </span>
            <span className="text-[54px] font-decoment whitespace-nowrap drop-shadow-lg shadow-white font-bold dark:text-green-500 text-red-500 h-12 leading-none flex items-center">
              VIEW
            </span>
          </span>
        </Link>

        {/* Right-aligned Button */}
        <div ref={menuButtonRef}>
          <button
            type="button"
            className="flex p-2 mr-2 w-10 h-10 items-center justify-center rounded-lg hover:bg-slate-200 focus:outline-none focus:ring-2 focus:ring-gray-200 dark:hover:bg-slate-800 dark:focus:ring-gray-600 ml-auto"
            onClick={(e) => { setShowMenu(!showMenu); }}
          >
            <svg className="w-5 h-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 17 14">
              <path stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M1 1h15M1 7h15M1 13h15"/>
            </svg>
          </button>
        </div>
      </nav>
      {
         showMenu && (
          <div ref={menuRef} className="absolute top-20 left-0 flex flex-col w-full bg-slate-100 dark:bg-slate-900 text-lg py-2 px-4">
            <div className={`grid grid-cols-12 py-2 px-4 rounded-lg ${location.pathname === '/' ? 'bg-blue-700 text-white' : ''}`}>
              <span />
              <Link
                className="cols-span-11 overflow-visible whitespace-nowrap"
                to="/"
                onClick={() => setShowMenu(false)}
              >
                Markets
              </Link>
            </div>
            <div className={`grid grid-cols-12 py-2 px-4 rounded-lg ${location.pathname === '/borrow' ? 'bg-blue-700 text-white' : ''}`}>
              <span />
              <Link
                className="cols-span-11 overflow-visible whitespace-nowrap"
                to="/borrow"
                onClick={() => setShowMenu(false)}
              >
                Borrow
              </Link>
            </div>
            <div className={`grid grid-cols-12 py-2 px-4 rounded-lg ${location.pathname === '/dashboard' ? 'bg-blue-700 text-white' : ''}`}>
              <span />
              <Link
                className="cols-span-11 overflow-visible whitespace-nowrap"
                to="/dashboard"
                onClick={() => setShowMenu(false)}
              >
                Dashboard
              </Link>
            </div>
            <div className={`grid grid-cols-12 py-2 px-4 rounded-lg ${location.pathname === '/faucet' ? 'bg-blue-700 text-white' : ''}`}>
              <span />
              <Link
                className="cols-span-11 overflow-visible whitespace-nowrap"
                to="/faucet"
                onClick={() => setShowMenu(false)}
              >
                Faucet
              </Link>
            </div>
            <span />
            {user ? (
              <Link
                className={`grid grid-cols-12 py-2 px-4 rounded-lg flex flex-row items-center stroke-gray-800 hover:stroke-black dark:stroke-gray-200 dark:hover:stroke-white rounded-lg hover:cursor-pointer ${
                  location.pathname === `/user/${user.principal}` ? 'bg-blue-700 text-white' : ''
                }`}
                to={`/user/${user.principal}`}
                onClick={() => setShowMenu(false)}
              >
                <Avatar
                  size={24}
                  name={user.principal.toString()}
                  variant="marble"
                />
                <span className="cols-span-11 ml-2">{user.nickname}</span>
              </Link>
            ) : (
              <div
                className="grid grid-cols-12 py-2 px-4 rounded-lg flex flex-row items-center fill-gray-800 hover:fill-black dark:fill-gray-200 dark:hover:fill-white rounded-lg hover:cursor-pointer"
                onClick={() => { setShowMenu(false); connect(); }}
              >
                <LoginIcon />
                <span className="cols-span-11">Login</span>
              </div>
            )}
            {/* Wallet Button */}
            { user && <button
                className="h-10 w-10 rounded-full bg-white p-2 text-xl text-black dark:bg-white/10 dark:text-white"
                onClick={() => setShowWallet(true)}
              >
                <MdOutlineAccountBalanceWallet size={22} />
              </button> 
            }
          </div>
        )
      }
      <Wallet
        isOpen={showWallet}
        onClose={() => setShowWallet(false)}
      />
    </header>
  );
}

const Header = () => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  return (
    isMobile ? 
      <MobileHeader /> :
      <DesktopHeader />
  );
}

export default Header;