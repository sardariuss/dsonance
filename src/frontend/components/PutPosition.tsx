import { EYesNoChoice, toCandid } from '../utils/conversions/yesnochoice';
import { useEffect, useMemo, useRef, useState } from 'react';
import { v4 as uuidv4 } from 'uuid';
import { PositionInfo } from './types';
import { useAuth } from '@nfid/identitykit/react';
import { useProtocolContext } from './context/ProtocolContext';
import PutPositionPreview from './PutPositionPreview';
import { protocolActor } from "./actors/ProtocolActor";
import { useNavigate } from 'react-router-dom';
import { AmountOrigin, SPosition } from '@/declarations/protocol/protocol.did';
import { useFungibleLedgerContext } from './context/FungibleLedgerContext';
import { getTokenLogo, getTokenSymbol } from '../utils/metadata';
import { showErrorToast, showSuccessToast, extractErrorMessage } from '../utils/toasts';
import { SYesNoPool } from '@/declarations/backend/backend.did';
import PutPositionModal from './PutPositionModal';
import { TabButton } from './TabButton';
import { get_current } from '../utils/timeline';

const PREDEFINED_PERCENTAGES = [0.1, 0.25, 0.5, 1.0];

export enum EOrderType {
  Market = 'MARKET',
  Limit = 'LIMIT',
}

type Props = {
  id: string;
  position: PositionInfo;
  setPosition: (position: PositionInfo) => void;
  positionPreview: SPosition | undefined;
  positionPreviewWithoutImpact?: SPosition | undefined;
  limitOrderPreview?: SPosition | undefined;
  pool: SYesNoPool;
  limitConsensus: number;
  setLimitConsensus: (consensus: number) => void;
  initialConsensus: number;
};

const PutPosition = ({id, position, setPosition, positionPreview, positionPreviewWithoutImpact, limitOrderPreview, pool, limitConsensus, setLimitConsensus, initialConsensus}: Props) => {

  const { supplyLedger: { formatAmount, formatAmountUsd, metadata,
    convertToFixedPoint, approveIfNeeded, userBalance, refreshUserBalance } } = useFungibleLedgerContext();
  const { user, connect } = useAuth();
  const authenticated = !!user;
  const { parameters } = useProtocolContext();
  const [putPositionLoading, setPutPositionLoading] = useState(false);
  const [selectedPredefined, setSelectedPredefined] = useState<number | null>(null);
  const [showConfirmModal, setShowConfirmModal] = useState(false);
  const [orderType, setOrderType] = useState<EOrderType>(EOrderType.Market);
  const [isCustomActive, setIsCustomActive] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | undefined>(undefined);
  const customRef = useRef<HTMLInputElement>(null);

  const [limitConsensusInput, setLimitConsensusInput] = useState<string>(Math.round(limitConsensus).toString());
  const [isEditingLimitConsensus, setIsEditingLimitConsensus] = useState<boolean>(false);

  // Update limit consensus input when limitConsensus prop changes
  useEffect(() => {
    if (!isEditingLimitConsensus) {
      setLimitConsensusInput(Math.round(limitConsensus).toString());
    }
  }, [limitConsensus, isEditingLimitConsensus]);

  const navigate = useNavigate();

  const { call: putPosition } = protocolActor.authenticated.useUpdateCall({
    functionName: "put_position",
  });

  const { call: putLimitOrder } = protocolActor.authenticated.useUpdateCall({
    functionName: "put_limit_order",
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

  const executePool = (origin: AmountOrigin) => {

    setPutPositionLoading(true);

    // Only approve if pulling from wallet
    const needsApproval = 'FROM_WALLET' in origin;

    const executePut = (finalAmount: bigint) => {
      if (orderType === EOrderType.Limit) {
        // Execute limit order
        if (!user?.principal) {
          throw new Error("User principal not found");
        }
        putLimitOrder([{
          pool_id: id,
          order_id: uuidv4(),
          from: { owner: user.principal, subaccount: [] },
          amount: finalAmount,
          choice_type: { YES_NO: toCandid(position.choice) },
          limit_consensus: limitConsensus / 100, // Convert from percentage (0-100) to decimal (0-1)
          from_origin: origin
        }]).then((result) => {
          if (result === undefined) {
            throw new Error("Place limit order returned undefined result");
          }
          if ('err' in result) {
            console.error("Place limit order failed:", result.err);
            showErrorToast(extractErrorMessage(result.err), "Place limit order");
            throw new Error(`Place limit order failed: ${result.err.toString()}`);
          }
          refreshUserBalance();
          showSuccessToast("Limit order placed successfully", "Place limit order");
          setPutPositionLoading(false);
          // Navigate to the user's profile page
          navigate(`/user/${user?.principal.toString()}`);
        }).catch((error) => {
          console.error("Error during place limit order:", error);
          showErrorToast(extractErrorMessage(error), "Place limit order");
          setPutPositionLoading(false);
        });
      } else {
        // Execute market order (normal position)
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
      }
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
      {/* Order Type Tabs */}
      <ul className="flex flex-wrap gap-x-6 gap-y-2 w-full mb-2">
        <li className="min-w-max text-center">
          <TabButton
            label="Market"
            setIsCurrent={() => setOrderType(EOrderType.Market)}
            isCurrent={orderType === EOrderType.Market}
          />
        </li>
        <li className="min-w-max text-center">
          <TabButton
            label="Limit"
            setIsCurrent={() => setOrderType(EOrderType.Limit)}
            isCurrent={orderType === EOrderType.Limit}
          />
        </li>
      </ul>

      <div className="flex flex-row w-full justify-between space-x-2">
        <button className={`w-1/2 h-10 text-lg rounded-lg 
          ${position.choice === EYesNoChoice.Yes ? 
            "bg-brand-true dark:bg-brand-true-dark text-white" : 
            "bg-gray-100 dark:bg-gray-900 text-gray-700 dark:text-gray-300"}`
          } onClick={() => setPosition({ amount: position.amount, choice: EYesNoChoice.Yes })}
        >
          True
        </button>
        <button className={`w-1/2 h-10 text-lg rounded-lg 
          ${position.choice === EYesNoChoice.No ? 
            "bg-brand-false text-white" : 
            "bg-gray-100 dark:bg-gray-900 text-gray-700 dark:text-gray-300"}`
          } onClick={() => setPosition({ amount: position.amount, choice: EYesNoChoice.No })}
        >
          False
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

        {orderType === EOrderType.Limit && <span className="w-full border-b border-gray-300 dark:border-gray-700">
          {/* Divider */}
        </span>}

        {/* Limit Consensus Input - Only show for limit orders */}
        {orderType === EOrderType.Limit && (
          <div className="flex flex-col w-full mt-2">
            <div className="flex justify-between items-center mb-1">
              <label className="text-base">
                Limit Consensus
              </label>
              <div className="flex items-center gap-1">
                <input
                  type="text"
                  inputMode="decimal"
                  value={limitConsensusInput}
                  onFocus={() => setIsEditingLimitConsensus(true)}
                  onChange={(e) => {
                    const value = e.target.value.replace(/[^0-9]/g, '');

                    // Handle empty
                    if (value === '') {
                      setLimitConsensusInput(value);
                      setLimitConsensus(0);
                      return;
                    }

                    // Prevent values > 100
                    const numValue = Number(value);
                    if (!isNaN(numValue) && numValue > 100) {
                      return; // Don't update if value exceeds 100
                    }

                    // Update input field with validated value
                    setLimitConsensusInput(value);

                    // Update the actual consensus value if valid
                    if (!isNaN(numValue) && numValue >= 0 && numValue <= 100) {
                      setLimitConsensus(numValue);
                    }
                  }}
                  onBlur={(e) => {
                    setIsEditingLimitConsensus(false);
                    // Ensure value is within bounds and properly formatted on blur
                    let numValue = Number(e.target.value);

                    if (isNaN(numValue) || numValue < 0) {
                      numValue = 0;
                    } else if (numValue > 100) {
                      numValue = 100;
                    }

                    // Round to integer
                    const roundedValue = Math.round(numValue);
                    setLimitConsensus(roundedValue);
                    setLimitConsensusInput(roundedValue.toString());
                  }}
                  className="w-16 text-right text-3xl bg-transparent text-gray-900 dark:text-white outline-none focus:border-blue-500 dark:focus:border-blue-400"
                  disabled={putPositionLoading}
                />
                <span className="text-base text-gray-700 dark:text-gray-300">%</span>
              </div>
            </div>
            <div className="relative w-full">
              <style>
                {`
                  .limit-consensus-range-yes {
                    background: linear-gradient(to right, oklch(62.7% 0.194 149.214) 0%, oklch(62.7% 0.194 149.214) ${limitConsensus}%, #d1d5db ${limitConsensus}%, #d1d5db 100%) !important;
                  }
                  .limit-consensus-range-no {
                    background: linear-gradient(to right, #d1d5db 0%, #d1d5db ${limitConsensus}%, oklch(63.7% 0.237 25.331) ${limitConsensus}%, oklch(63.7% 0.237 25.331) 100%) !important;
                  }
                  .dark .limit-consensus-range-yes {
                    background: linear-gradient(to right, oklch(72.3% 0.219 149.579) 0%, oklch(72.3% 0.219 149.579) ${limitConsensus}%, #d1d5db ${limitConsensus}%, #d1d5db 100%) !important;
                  }
                `}
              </style>
              <input
                type="range"
                min="0"
                max="100"
                step="1"
                value={limitConsensus}
                onMouseDown={() => {
                  // Commit text input value before interacting with slider
                  setIsEditingLimitConsensus(false);
                }}
                onChange={(e) => {
                  const roundedValue = Math.round(Number(e.target.value));
                  setLimitConsensus(roundedValue);
                  setLimitConsensusInput(roundedValue.toString());
                }}
                className={`limit-consensus-range w-full rounded-lg cursor-pointer ${
                  position.choice === EYesNoChoice.Yes ? 'limit-consensus-range-yes' : 'limit-consensus-range-no'
                }`}
                disabled={putPositionLoading}
              />
            </div>
          </div>
        )}
      </div>
      <span className="w-full border-b border-gray-300 dark:border-gray-700">
        {/* Divider */}
      </span>
      {(orderType === EOrderType.Market ? positionPreview : limitOrderPreview) && (
        <div className="animate-in slide-in-from-top-4 fade-in-0 duration-300 w-full">
          <PutPositionPreview
            positionPreview={orderType === EOrderType.Market ? positionPreview : limitOrderPreview}
            positionPreviewWithoutImpact={positionPreviewWithoutImpact}
            isLimitOrder={orderType === EOrderType.Limit}
          />
        </div>
      )}
      <button
        className="button-simple w-full h-9 justify-center items-center text-base mt-2 flex space-x-2"
        disabled={authenticated && (putPositionLoading || errorMsg !== undefined || position.amount === 0n)}
        onClick={() => { if (!authenticated) { connect() } else { showConfirmation() } }}
      >
        <span>{orderType === EOrderType.Limit ? 'Place Order' : 'Lock Position'}</span>
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
        orderType={orderType}
        limitConsensus={limitConsensus}
      />
    </div>

	);
};

export default PutPosition;