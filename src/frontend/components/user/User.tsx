import { Principal } from "@dfinity/principal";
import { useParams } from "react-router-dom";
import { useEffect, useState } from "react";
import LockChart from "../charts/LockChart";
import { protocolActor } from "../../actors/ProtocolActor";
import Wallet from "../Wallet";
import { useCurrencyContext } from "../CurrencyContext";
import BitcoinIcon from "../icons/BitcoinIcon";

import BallotView from "./BallotView";
import { unwrapLock } from "../../utils/conversions/ballot";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../../../frontend/constants";
import CurrencyConverter from "../CurrencyConverter";
import ThemeToggle from "../ThemeToggle";

const User = () => {
  
  const { principal } = useParams();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  if (!principal) {
    return <div>Invalid principal</div>;
  }

  const { formatSatoshis } = useCurrencyContext();

  const [selected, setSelected] = useState<number | undefined>(undefined);

  const selectBallot = (index: number | undefined) => {
    setSelected(index === undefined ? undefined : index === selected ? undefined : index);
  }

  const { call: refreshNow, data: now } = protocolActor.useQueryCall({
    functionName: "get_time",
  });

  const { data: ballots, call: refreshBallots } = protocolActor.useQueryCall({
    functionName: "get_ballots",
    args: [{ owner: Principal.fromText(principal), subaccount: [] }],
  });

  useEffect(() => {
    refreshNow();
    refreshBallots();
  }, []);

  const totalLocked = now && ballots?.reduce((acc, ballot) =>
    acc + ((ballot.YES_NO.timestamp + unwrapLock(ballot).duration_ns.current.data) > now ? ballot.YES_NO.amount : 0n)
  , 0n);
  
  return (
    <div className="flex flex-col items-center border-x dark:border-gray-700 border-t w-full sm:w-4/5 md:w-3/4 lg:w-2/3">
      <div className="flex flex-col items-center w-full border-b dark:border-gray-700">
        <Wallet/>
      </div>
      {
        isMobile && 
          <div className="flex flex-row justify-center w-full border-b dark:border-gray-700 py-2">
            <CurrencyConverter/>
            <ThemeToggle/>
          </div>
      }
      { ballots && ballots?.length > 0 && 
        <div className="flex flex-col items-center w-full border-b dark:border-gray-700 py-2">
          <div className="flex flex-row w-full space-x-1 justify-center items-baseline">
            <span>Total locked:</span>
            <span className="text-lg">{ totalLocked !== undefined ? formatSatoshis(totalLocked) : "N/A" }</span>
            <div className="flex self-center">
              <BitcoinIcon/>
            </div>
          </div>
          <LockChart ballots={ballots} select_ballot={selectBallot} selected={selected}/>
        </div>
      }
      <ul className="w-full">
        {
          ballots?.map((ballot, index) => (
            <li key={index} className="w-full">
              <BallotView ballot={ballot} isSelected={index === selected} selectBallot={() => selectBallot(index)} now={now}/>
            </li>
          ))
        }
      </ul>
    </div>
  );
}

export default User;