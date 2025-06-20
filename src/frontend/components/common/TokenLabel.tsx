import { MetaDatum } from "../../../declarations/ck_btc/ck_btc.did";
import { getTokenLogo, getTokenName } from "../../utils/metadata";

interface TokenLabelProps {
  metadata: MetaDatum[] | undefined;
};

const TokenLabel: React.FC<TokenLabelProps> = ({ metadata }) => {

  return (
    <div className="flex flex-row items-center gap-2">
      <img src={getTokenLogo(metadata)} alt="Logo" className="size-[24px]" />
      <span className="text-gray-700 dark:text-white text-lg">{getTokenName(metadata) ?? "Name"}</span>
    </div>
  );

}

export default TokenLabel;