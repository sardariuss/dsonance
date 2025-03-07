import { useMediaQuery } from 'react-responsive';
import icLogo from '../assets/ic-logo.svg';
import { DOCS_URL, MOBILE_MAX_WIDTH_QUERY, OPENCHAT_URL, GITHUB_URL, X_URL, TELEGRAM_URL } from '../constants';
import XIcon from './icons/XIcon';
import { Link } from 'react-router-dom';
import GitbookIcon from './icons/GitbookIcon';
import GithubIcon from './icons/GithubIcon';
import OpenChatIcon from './icons/OpenChatIcon';
import TelegramIcon from './icons/TelegramIcon';

const DesktopFooter: React.FC = () => {

  return (
    <footer className="w-full bg-slate-200 dark:bg-gray-800 shadow flex flex-row items-center justify-between px-4 h-16 min-h-16">
      <a href="https://internetcomputer.org/">
      <div className="flex flex-row items-center">
        <div className="sm:text-center text-l font-semibold dark:text-gray-200 dark:hover:text-white">
          Powered by
        </div>
        <div className="w-2"/>
        <img src={icLogo} className="flex h-5" alt="the IC"/>
      </div>
      </a>
      <div className="flex flex-row justify-end items-center gap-x-4">
        <Link to={DOCS_URL} className="hover:cursor-pointer" target="_blank" rel="noopener">
          <GitbookIcon/>
        </Link>
        <Link to={GITHUB_URL} className="hover:cursor-pointer" target="_blank" rel="noopener">
          <GithubIcon/>
        </Link>
        <Link to={X_URL} className="hover:cursor-pointer" target="_blank" rel="noopener">
          <XIcon/>
        </Link>
        <Link to={OPENCHAT_URL} className="hover:cursor-pointer" target="_blank" rel="noopener">
          <OpenChatIcon/>
        </Link>
        <Link to={TELEGRAM_URL} className="hover:cursor-pointer" target="_blank" rel="noopener">
          <TelegramIcon/>
        </Link>
      </div>
    </footer>
  );
}

const MobileFooter: React.FC = () => {

  return (
    <footer className="w-full bg-slate-200 dark:bg-gray-800 shadow flex flex-row items-center justify-between px-4 h-20 min-h-20">
      <a href="https://internetcomputer.org/">
        <img src={icLogo} className="flex h-5" alt="the IC"/>
      </a>
      <div className="flex flex-row justify-end items-center gap-x-4">
        <Link to={DOCS_URL} className="hover:cursor-pointer" target="_blank" rel="noopener">
          <GitbookIcon/>
        </Link>
        <Link to={GITHUB_URL} className="hover:cursor-pointer" target="_blank" rel="noopener">
          <GithubIcon/>
        </Link>
        <Link to={X_URL} className="hover:cursor-pointer" target="_blank" rel="noopener">
          <XIcon/>
        </Link>
        <Link to={OPENCHAT_URL} className="hover:cursor-pointer" target="_blank" rel="noopener">
          <OpenChatIcon/>
        </Link>
        <Link to={TELEGRAM_URL} className="hover:cursor-pointer" target="_blank" rel="noopener">
          <TelegramIcon/>
        </Link>
      </div>
    </footer>
  );
}

const Footer: React.FC = () => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  return isMobile ? <MobileFooter/> : <DesktopFooter/>;
}

export default Footer;