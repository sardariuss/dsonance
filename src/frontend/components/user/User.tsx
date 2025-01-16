import { Principal } from "@dfinity/principal";
import { useParams } from "react-router-dom";
import { useEffect, useState } from "react";
import LockChart from "../charts/LockChart";
import { protocolActor } from "../../actors/ProtocolActor";
import Wallet from "../Wallet";
import { useCurrencyContext } from "../CurrencyContext";
import BitcoinIcon from "../icons/BitcoinIcon";

import BallotView from "./BallotView";

const User = () => {
  
  const { principal } = useParams();

  if (!principal) {
    return <div>Invalid principal</div>;
  }

  const { formatSatoshis } = useCurrencyContext();

  const [selected, setSelected] = useState<number | undefined>(undefined);

  const selectBallot = (index: number | undefined) => {
    setSelected(index === undefined ? undefined : index === selected ? undefined : index);
  }

  const { data: ballots, call: refreshBallots } = protocolActor.useQueryCall({
    functionName: "get_ballots",
    args: [{ owner: Principal.fromText(principal), subaccount: [] }],
  });

  useEffect(() => {
    refreshBallots();
  }, []);

  const totalLocked = ballots?.reduce((acc, ballot) =>
    acc + ballot.YES_NO.amount, 0n);
  
  return (
    <div className="flex flex-col items-center w-2/3 border-x dark:border-gray-700">
      <div className="flex flex-col items-center w-full border-b dark:border-gray-700">
        <Wallet/>
      </div>
      { ballots && ballots?.length > 0 && 
        <div className="flex flex-col items-center w-full border-b dark:border-gray-700 py-2">
          <div className="flex flex-row w-full space-x-1 justify-center items-baseline">
            <span>Total locked:</span>
            <span className="text-lg">{ totalLocked ? formatSatoshis(totalLocked) : "N/A" }</span>
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
              <BallotView ballot={ballot} isSelected={index === selected} selectBallot={() => selectBallot(index)}/>
            </li>
          ))
        }
      </ul>
    </div>
  );
}

export default User;