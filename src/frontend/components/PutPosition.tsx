import { EYesNoChoice, toCandid } from '../utils/conversions/yesnochoice';
import { useEffect, useMemo, useRef, useState } from 'react';
import { v4 as uuidv4 } from 'uuid';
import { PositionInfo } from './types';
import { useAuth } from '@nfid/identitykit/react';
import { useProtocolContext } from './context/ProtocolContext';
import PutPositionPreview from './PutPositionPreview';
import { protocolActor } from "./actors/ProtocolActor";
import { useNavigate } from 'react-router-dom';
import { PutPositionPreview as PreviewArgs, SPosition } from '@/declarations/protocol/protocol.did';
import { useFungibleLedgerContext } from './context/FungibleLedgerContext';
import { getTokenLogo, getTokenSymbol } from '../utils/metadata';
import { showErrorToast, showSuccessToast, extractErrorMessage } from '../utils/toasts';
import { SYesNoPool } from '@/declarations/backend/backend.did';
import PutPositionModal from './PutPositionModal';

const PREDEFINED_PERCENTAGES = [0.1, 0.25, 0.5, 1.0];

type Props = {
  id: string;
  position: PositionInfo;
  setPosition: (position: PositionInfo) => void;
  positionPreview: SPosition | undefined;
  positionPreviewWithoutImpact?: SPosition | undefined;
  pool: SYesNoPool;
};

const PutPosition = ({id, position, setPosition, positionPreview, positionPreviewWithoutImpact, pool}: Props) => {

  const { supplyLedger: { formatAmount, formatAmountUsd, metadata, 
    convertToFixedPoint, approveIfNeeded, userBalance, refreshUserBalance, tokenDecimals } } = useFungibleLedgerContext();
  const { user, connect } = useAuth();
  const authenticated = !!user;
  const { parameters } = useProtocolContext();
  const [putPositionLoading, setPutPositionLoading] = useState(false);
  const [selectedPredefined, setSelectedPredefined] = useState<number | null>(null);
  const [showConfirmModal, setShowConfirmModal] = useState(false);

  const yesArgs : PreviewArgs = useMemo(() => ({
    id: uuidv4(),
    pool_id: id,
    from_subaccount: [],
    amount: 1_000_000n,
    choice_type: { YES_NO: toCandid(EYesNoChoice.Yes) },
    with_supply_apy_impact: false,
    origin: { FROM_WALLET: null }
  }), [id]);
  const { data: yesPositionPreview } = protocolActor.unauthenticated.useQueryCall({
    functionName: "preview_position",
    args: [ yesArgs ]
  });
  const noArgs : PreviewArgs = useMemo(() => ({
    id: uuidv4(),
    pool_id: id,
    from_subaccount: [],
    amount: 1_000_000n,
    choice_type: { YES_NO: toCandid(EYesNoChoice.No) },
    with_supply_apy_impact: false,
    origin: { FROM_WALLET: null }
  }), [id]);
  const { data: noPositionPreview } = protocolActor.unauthenticated.useQueryCall({
    functionName: "preview_position",
    args: [ noArgs ]
  });
  const navigate = useNavigate();

  const { call: putPosition } = protocolActor.authenticated.useUpdateCall({
    functionName: "put_position",
  });

  const showConfirmation = () => {
    if (!authenticated) {
      connect();
      return;
    }
    if (putPositionLoading) {
      console.warn("Lock position is already in progress");
      return;
    }
    setShowConfirmModal(true);
  };

  const executePool = (origin: import('@/declarations/protocol/protocol.did').AmountOrigin) => {

    setPutPositionLoading(true);

    // Only approve if pulling from wallet
    const needsApproval = 'FROM_WALLET' in origin;

    const executePut = (finalAmount: bigint) => {
      putPosition([{
        pool_id: id,
        id: uuidv4(),
        from_subaccount: [],
        amount: finalAmount,
        choice_type: { YES_NO: toCandid(position.choice) },
        origin
      }]).then((result) => {
        if (result === undefined) {
          throw new Error("Lock position returned undefined result");
        }
        if ('err' in result) {
          console.error("Lock position failed:", result.err);
          showErrorToast(extractErrorMessage(result.err), "Lock position");
          throw new Error(`Lock position failed: ${result.err.toString()}`);
        }
        refreshUserBalance();
        showSuccessToast("View locked successfully", "Lock position");
        setPutPositionLoading(false);
        // Position successfully put, navigate to the user's profile page
        navigate(`/user/${user?.principal.toString()}`);
      }).catch((error) => {
        console.error("Error during Lock position:", error);
        showErrorToast(extractErrorMessage(error), "Lock position");
        setPutPositionLoading(false);
      });
    };

    if (needsApproval) {
      approveIfNeeded(position.amount).then(({tokenFee, approveCalled}) => {
        // Subtract the token fee from the amount if an approval was executed.
        // Second token fee is for the tranfer_from operation that will be executed by the protocol.
        const finalAmount = position.amount - tokenFee * (approveCalled ? 2n : 1n);
        executePut(finalAmount);
      }).catch((error) => {
        console.error("Error during approval:", error);
        showErrorToast(extractErrorMessage(error), "Approval");
        setPutPositionLoading(false);
      });
    } else {
      // No approval needed when using supply
      executePut(position.amount);
    }
  };

  useEffect(() => {
    // Only update if input is not focused, meaning that it comes from an external stimulus
    if (customRef.current && !isCustomActive) {
      let amount = formatAmount(position.amount, "standard");
      if (amount !== undefined) {
        // If amount is 0, clear the input to show placeholder
        customRef.current.value = position.amount === 0n ? "" : amount;
      }
    }
  },
  [position]);

  const customRef = useRef<HTMLInputElement>(null);
  const [isCustomActive, setIsCustomActive] = useState(false);

  const [errorMsg, setErrorMsg] = useState<string | undefined>(undefined);

  useEffect(() => {
    if (parameters === undefined) {
      setErrorMsg(undefined);
      return;
    }
    const tokenSymbol = getTokenSymbol(metadata);
    const tooSmall = position.amount < parameters.minimum_position_amount;
    if (tooSmall) {
      setErrorMsg(`Minimum ${formatAmount(parameters.minimum_position_amount)} ${tokenSymbol}`);
    } else {
      setErrorMsg(undefined);
    }
  }
  , [position, parameters]);

	return (
    <div className="flex flex-col items-center w-full gap-y-2 rounded-lg shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800 p-4">
      <div className="flex flex-row w-full justify-between space-x-2">
        <button className={`w-1/2 h-10 text-lg rounded-lg 
          ${position.choice === EYesNoChoice.Yes ? 
            "bg-brand-true dark:bg-brand-true-dark text-white" : 
            "bg-gray-100 dark:bg-gray-900 text-gray-700 dark:text-gray-300"}`
          } onClick={() => setPosition({ amount: position.amount, choice: EYesNoChoice.Yes })}
        >
          {`True ${(yesPositionPreview && "ok" in yesPositionPreview) ? `${yesPositionPreview.ok.new.YES_NO.dissent.toFixed(2)}` : ''}`}
        </button>
        <button className={`w-1/2 h-10 text-lg rounded-lg 
          ${position.choice === EYesNoChoice.No ? 
            "bg-brand-false text-white" : 
            "bg-gray-100 dark:bg-gray-900 text-gray-700 dark:text-gray-300"}`
          } onClick={() => setPosition({ amount: position.amount, choice: EYesNoChoice.No })}
        >
          {`False ${(noPositionPreview && "ok" in noPositionPreview) ? `${noPositionPreview.ok.new.YES_NO.dissent.toFixed(2)}` : ''}`}
        </button>
      </div>
      <div className={`flex flex-col items-center w-full space-y-2`}>
        <div className="flex flex-col w-full">
          <div className="grid grid-cols-[auto_auto_1fr] items-center space-x-1 w-full">
            <img src={getTokenLogo(metadata)} alt="Logo" className="size-[24px] pr-1" />
            <span className="">Amount</span>
            <input
              ref={customRef}
              type="text"
              inputMode="decimal"
              placeholder="0"
              onFocus={() => setIsCustomActive(true)}
              onBlur={() => setIsCustomActive(false)}
              className="w-full flex-grow h-9 rounded appearance-none bg-transparent text-right text-3xl outline-none focus:outline-none placeholder:text-gray-400 dark:placeholder:text-gray-500"
              onKeyDown={(e) => {
                // Allow: backspace, delete, tab, escape, enter, decimal point
                if ([8, 9, 27, 13, 46, 110, 190].includes(e.keyCode) ||
                    // Allow: Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X
                    (e.keyCode === 65 && e.ctrlKey === true) ||
                    (e.keyCode === 67 && e.ctrlKey === true) ||
                    (e.keyCode === 86 && e.ctrlKey === true) ||
                    (e.keyCode === 88 && e.ctrlKey === true) ||
                    // Allow: home, end, left, right
                    (e.keyCode >= 35 && e.keyCode <= 39)) {
                  return;
                }
                // Ensure that it is a number and stop the keypress if not
                if ((e.shiftKey || (e.keyCode < 48 || e.keyCode > 57)) && (e.keyCode < 96 || e.keyCode > 105)) {
                  e.preventDefault();
                }
              }}
              onChange={(e) => {
                if (isCustomActive) {
                  // Remove commas and any non-numeric characters except decimal point
                  const rawValue = e.target.value.replace(/[^0-9.]/g, '');
                  // Prevent multiple decimal points
                  const parts = rawValue.split('.');
                  const sanitizedValue = parts.length > 2 ? `${parts[0]}.${parts.slice(1).join('')}` : rawValue;

                  const amount = convertToFixedPoint(Number(sanitizedValue)) ?? 0n;
                  setPosition({
                    choice: position.choice,
                    amount: amount,
                  });
                  setSelectedPredefined(null);
                  // Format the value with commas and update the input
                  if (customRef.current) {
                    const formattedValue = formatAmount(amount, "standard");
                    if (formattedValue !== undefined && amount !== 0n) {
                      customRef.current.value = formattedValue;
                    }
                  }
                }
              }}
            />
          </div>
          <div className="text-gray-500 text-sm text-right self-end">
            {formatAmountUsd(position.amount)}
          </div>
        </div>
        <div className="flex flex-row items-center self-end space-x-1 w-3/4">
          {
            PREDEFINED_PERCENTAGES.map((percentage, index) => (
              <button 
                key={percentage} 
                className={`rounded-lg h-8 text-base justify-center flex-grow ${selectedPredefined === index ? "bg-blue-700 text-white font-bold" : "bg-gray-100 dark:bg-gray-900 text-gray-700 dark:text-gray-300"}`} 
                onClick={() => { if(!authenticated) { connect() } else { setPosition({ amount: BigInt(Math.floor(percentage * Number(userBalance))), choice: position.choice }), setSelectedPredefined(index); }}}
                disabled={putPositionLoading}
              >
                {percentage * 100}%
              </button>
            ))
          }
        </div>
      </div>
      <span className="w-full border-b border-gray-300 dark:border-gray-700">
        {/* Divider */}
      </span>
      {positionPreview && (
        <div className="animate-in slide-in-from-top-4 fade-in-0 duration-300 w-full">
          <PutPositionPreview
            positionPreview={positionPreview}
            positionPreviewWithoutImpact={positionPreviewWithoutImpact}
          />
        </div>
      )}
      <button
        className="button-simple w-full h-9 justify-center items-center text-base mt-2 flex space-x-2"
        disabled={authenticated && (putPositionLoading || errorMsg !== undefined || position.amount === 0n)}
        onClick={() => { if (!authenticated) { connect() } else { showConfirmation() } }}
      >
        <span>Lock Position</span>
      </button>

      {/* Confirmation Modal */}
      <PutPositionModal
        isVisible={showConfirmModal}
        onClose={() => setShowConfirmModal(false)}
        onConfirm={executePool}
        position={position}
        positionPreview={positionPreview}
        pool={pool}
        putPositionLoading={putPositionLoading}
      />
    </div>

	);
};

export default PutPosition;