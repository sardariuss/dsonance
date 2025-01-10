import { formatDuration } from "../../utils/conversions/duration";
import { dateToTime } from "../../utils/conversions/date";
import { backendActor } from "../../actors/BackendActor";

import { Principal } from "@dfinity/principal";
import { useParams } from "react-router-dom";
import { useEffect, useState } from "react";
import LockChart from "../charts/LockChart";
import { LOCK_EMOJI, RESONANCE_TOKEN_SYMBOL, DISSENT_EMOJI, PARTICIPATION_EMOJI, REWARD_EMOJI } from "../../constants";
import { get_current, to_number_timeline } from "../../utils/timeline";
import DurationChart from "../charts/DurationChart";
import { protocolActor } from "../../actors/ProtocolActor";
import { SBallotType } from "../../../declarations/protocol/protocol.did";
import { fromNullable } from "@dfinity/utils";
import Wallet from "../Wallet";
import { computeResonance, unwrapLock } from "../../utils/conversions/ballot";
import { useCurrencyContext } from "../CurrencyContext";
import { formatBalanceE8s } from "../../utils/conversions/token";
import ChoiceView from "../ChoiceView";
import ConsensusView from "../ConsensusView";
import DateSpan from "../DateSpan";

interface VoteConsensusProps {
  vote_id: string;
}

const VoteConsensus = ({ vote_id }: VoteConsensusProps) => {

  const { data: opt_vote } = backendActor.useQueryCall({
    functionName: "get_vote",
    args: [{ vote_id }],
  });

  const vote = opt_vote ? fromNullable(opt_vote) : undefined;
  if (!vote) {
    return <div>Invalid vote</div>;
  }

  return <ConsensusView vote={vote} />;
}

enum DetailToggle {
  DURATION,
  PARTICIPATION,
  REWARD,
};

const User = () => {
  
  const { principal } = useParams();

  if (!principal) {
    return <div>Invalid principal</div>;
  }

  const { formatSatoshis } = useCurrencyContext();

  const [selected, setSelected] = useState<number | undefined>(undefined);
  const [detailToggle, setDetailToggle] = useState<DetailToggle | undefined>(undefined);

  const selectBallot = (index: number | undefined) => {
    setSelected(index === undefined ? undefined : index === selected ? undefined : index);
    setDetailToggle(undefined);
  }

  const toggleDetail = (e: React.MouseEvent<HTMLDivElement, MouseEvent>, detail: DetailToggle) => {
    e.stopPropagation();
    setDetailToggle(detail);
  };

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
            <span>Total BTC locked:</span>
            <span className="text-lg">{ totalLocked ? formatSatoshis(totalLocked) : "N/A" }</span>
          </div>
          <LockChart ballots={ballots} select_ballot={selectBallot} selected={selected}/>
        </div>
      }
      <ul className="w-full">
        {
          ballots?.map((ballot, index) => (
            <li 
              key={index} 
              className="border-b dark:border-gray-700 border-gray-200 p-2 hover:bg-slate-50 dark:hover:bg-slate-850 hover:cursor-pointer"
              onClick={() => selectBallot(index)}
            >
              
              {/* Row 0: Ballot */}
              <div className="flex flex-row space-x-1 items-baseline">
                <span className="text-gray-400 text-sm">Locked</span>
                <span>{formatSatoshis(ballot.YES_NO.amount)}</span>
                <span className="text-gray-400 text-sm">on</span>
                <ChoiceView ballot={ballot}/>
                <span className="text-gray-400 text-sm">{" · "}</span>
                <DateSpan timestamp={ballot.YES_NO.timestamp}/>
              </div>

              {/* Row 1: Consensus */}
              <div className="w-full">
                <VoteConsensus vote_id={ballot.YES_NO.vote_id}/>
              </div>

              { index === selected && 
                <div className="grid grid-cols-2 gap-x-4 gap-y-2 justify-items-center w-full">

                  <div 
                    className={`flex justify-center items-baseline space-x-1 hover:bg-slate-800 w-full hover:cursor-pointer rounded ${detailToggle === DetailToggle.DURATION ? "bg-slate-800" : ""}`}
                    onClick={(e) => toggleDetail(e, DetailToggle.DURATION) }
                  >
                    <span>{LOCK_EMOJI}</span>
                    <div className="flex flex-row space-x-1 items-baseline">
                      <span className="italic text-gray-400 text-sm">Duration:</span> 
                      <span>{formatDuration(ballot.YES_NO.timestamp + get_current(unwrapLock(ballot).duration_ns).data - dateToTime(new Date(Number(ballot.YES_NO.timestamp)/ 1_000_000))) }</span>
                    </div>
                  </div>

                  <div 
                    className="flex justify-center items-baseline space-x-1 w-full rounded hover:cursor-default" 
                    onClick={(e) => e.stopPropagation()}
                  >
                    <span>{DISSENT_EMOJI}</span>
                    <div className="flex flex-row space-x-1 items-baseline">
                      <span className="italic text-gray-400 text-sm">Dissent:</span> 
                      <span>{ ballot.YES_NO.dissent.toFixed(3) }</span>
                    </div>
                  </div>
                  
                  <div 
                   className={`flex justify-center items-baseline space-x-1 hover:bg-slate-800 w-full hover:cursor-pointer rounded ${detailToggle === DetailToggle.PARTICIPATION ? "bg-slate-800" : ""}`}
                    onClick={(e) => toggleDetail(e, DetailToggle.PARTICIPATION)}
                  >
                    <span>{PARTICIPATION_EMOJI}</span>
                    <div className="flex flex-row space-x-1 items-baseline">
                      <span className="italic text-gray-400 text-sm">Participation:</span>
                      <span>{ formatBalanceE8s(BigInt(Math.floor(unwrapLock(ballot).participation)), RESONANCE_TOKEN_SYMBOL) }</span>
                    </div>
                  </div>
                  
                  <div 
                    className={`flex justify-center items-baseline space-x-1 hover:bg-slate-800 w-full hover:cursor-pointer rounded ${detailToggle === DetailToggle.REWARD ? "bg-slate-800" : ""}`}
                    onClick={(e) => toggleDetail(e, DetailToggle.REWARD)}
                  >
                    <span>{REWARD_EMOJI}</span>
                    <div className="flex flex-row space-x-1 items-baseline">
                      <span className="italic text-gray-400 text-sm">Reward:</span>
                      <span>{ formatBalanceE8s(computeResonance(ballot), RESONANCE_TOKEN_SYMBOL) + " (forecast)"}</span>
                    </div>
                  </div>

                  { detailToggle === DetailToggle.DURATION &&
                    <div className="col-span-2 w-full flex flex-col">
                      <DurationChart duration_timeline={to_number_timeline(unwrapLock(ballot).duration_ns)} format_value={ (value: number) => formatDuration(BigInt(value)) }/>
                    </div>
                  }
                  { detailToggle === DetailToggle.PARTICIPATION &&
                    <div className="col-span-2 w-full flex flex-col">
                      <DurationChart duration_timeline={ballot.YES_NO.resonance.amount} format_value={ (value: number) => (formatBalanceE8s(BigInt(value), RESONANCE_TOKEN_SYMBOL)) }/>
                    </div>
                  }
                  { detailToggle === DetailToggle.REWARD &&
                    <div className="col-span-2 w-full flex flex-col">
                      <DurationChart duration_timeline={ballot.YES_NO.consent} format_value={ (value: number) => value.toString() }/>
                    </div>
                  }
                  <div className="col-span-2 w-full flex flex-col hidden">
                    { ballot.YES_NO.ballot_id }
                  </div>
                </div>
              }
            </li>
          ))
        }
      </ul>
    </div>
  );
}

export default User;