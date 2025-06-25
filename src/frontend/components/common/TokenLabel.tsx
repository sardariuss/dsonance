import { MdOpenInNew } from "react-icons/md";
import { MetaDatum } from "../../../declarations/ck_btc/ck_btc.did";
import { getTokenLogo, getTokenName, getTokenSymbol } from "../../utils/metadata";
import { Link } from "react-router-dom";

interface TokenLabelProps {
  metadata: MetaDatum[] | undefined;
};

export const TokenLabel: React.FC<TokenLabelProps> = ({ metadata }) => {

  return (
    <div className="flex flex-row items-center gap-2">
      <img src={getTokenLogo(metadata)} alt="Logo" className="size-[24px]" />
      <span className="text-gray-700 dark:text-white text-lg">{getTokenSymbol(metadata) ?? ""}</span>
    </div>
  );
}

export const FullTokenLabel: React.FC<TokenLabelProps> = ({ metadata }) => {

  return (
    <div className="flex flex-row items-center gap-2">
      <img src={getTokenLogo(metadata)} alt="Logo" className="size-[44px]" />
      <div className="grid grid-rows-[2fr_3fr] place-items-start">
        <span className="text-gray-500 dark:text-gray-400 text-sm">{getTokenSymbol(metadata) ?? ""}</span>
        <div className="flex flex-row items-center space-x-1">
          <span className="text-gray-700 dark:text-white text-lg font-semibold">{getTokenName(metadata) ?? ""}</span>
          { /* TODO: fix hardcoded link to ckBTC ledger */ }
          <Link 
            to="https://dashboard.internetcomputer.org/canister/mxzaz-hqaaa-aaaar-qaada-cai"
            target="_blank"
            rel="noopener noreferrer"
            className="text-gray-500 hover:text-gray-700 dark:hover:text-white font-semibold"
          >
            <MdOpenInNew size={20}/>
          </Link>
        </div>
      </div>
    </div>
  );
}