import { EYesNoChoice } from '../utils/conversions/yesnochoice';
import { PositionInfo } from './types';
import PutPositionPreview from './PutPositionPreview';
import { AmountOrigin, SPosition } from '@/declarations/protocol/protocol.did';
import { useFungibleLedgerContext } from './context/FungibleLedgerContext';
import { getTokenSymbol } from '../utils/metadata';
import Modal from './common/Modal';
import { HiOutlineExclamationTriangle, HiCircleStack } from 'react-icons/hi2';
import { MdOutlineAccountBalanceWallet } from 'react-icons/md';
import { SYesNoPool } from '@/declarations/backend/backend.did';
import { createThumbnailUrl } from '../utils/thumbnail';
import { useEffect, useMemo, useState } from 'react';
import { useAuth } from '@nfid/identitykit/react';
import { protocolActor } from './actors/ProtocolActor';

type Props = {
  isVisible: boolean;
  onClose: () => void;
  onConfirm: (origin: AmountOrigin) => void;
  position: PositionInfo;
  positionPreview: SPosition | undefined;
  pool: SYesNoPool;
  putPositionLoading: boolean;
};

type OriginType = 'wallet' | 'supply';

const PutPositionModal = ({
  isVisible,
  onClose,
  onConfirm,
  position,
  positionPreview,
  pool,
  putPositionLoading,
}: Props) => {
  const { supplyLedger: { formatAmount, formatAmountUsd, metadata, userBalance } } = useFungibleLedgerContext();
  const { user } = useAuth();
  const [step, setStep] = useState<1 | 2>(1);
  const [selectedOrigin, setSelectedOrigin] = useState<OriginType>('wallet');

  const thumbnail = useMemo(() => createThumbnailUrl(pool.info.thumbnail), [pool]);

  // Fetch user's supply info (only if user is authenticated)
  const account = user?.principal ? { owner: user.principal, subaccount: [] as [] } : undefined;
  const { data: supplyInfo } = protocolActor.authenticated.useQueryCall({
    functionName: "get_supply_info",
    args: account ? [account] : undefined as any,
  });

  const supplyBalance = supplyInfo?.accrued_amount ? BigInt(Math.floor(supplyInfo.accrued_amount)) : 0n;

  // Reset to step 1 when modal opens/closes
  useEffect(() => {
    if (isVisible) {
      setStep(1);
      setSelectedOrigin('wallet');
    }
  }, [isVisible]);

  const handleClose = () => {
    setStep(1);
    setSelectedOrigin('wallet');
    onClose();
  };

  const handleNext = () => {
    if (step === 1) {
      setStep(2);
    }
  };

  const handlePrevious = () => {
    if (step === 2) {
      setStep(1);
    }
  };

  const handleConfirm = () => {
    const origin: AmountOrigin = selectedOrigin === 'wallet'
      ? { FROM_WALLET: null }
      : { FROM_SUPPLY: { max_slippage_amount: BigInt(Math.floor(Number(position.amount) * 0.01)) } };
    onConfirm(origin);
  };

  // Check if user has enough balance for selected origin
  const hasEnoughBalance = selectedOrigin === 'wallet'
    ? (userBalance ?? 0n) >= position.amount
    : supplyBalance >= position.amount;

  const canProceed = hasEnoughBalance && position.amount > 0n;

  return (
    <Modal
      isVisible={isVisible}
      onClose={handleClose}
      title={step === 1 ? "Choose Funding Source" : "Confirm Lock Position"}
    >
      <div className="flex flex-col w-full text-black dark:text-white space-y-4">

        {/* STEP 1: Choose Origin */}
        {step === 1 && (
          <>
            <div className="text-sm text-gray-600 dark:text-gray-400">
              Select where to pull tokens from for this position
            </div>

            <div className="flex flex-col gap-3">
              {/* From Wallet Option */}
              <button
                onClick={() => setSelectedOrigin('wallet')}
                className={`relative flex flex-col p-4 rounded-lg border-2 transition-all ${
                  selectedOrigin === 'wallet'
                    ? 'border-blue-600 bg-blue-50 dark:bg-blue-900/20'
                    : 'border-gray-300 dark:border-gray-600 hover:border-gray-400 dark:hover:border-gray-500'
                }`}
              >
                <div className="flex items-center gap-3">
                  <MdOutlineAccountBalanceWallet className={`w-8 h-8 ${selectedOrigin === "wallet" ? "text-blue-600" : "text-gray-800 dark:text-gray-200"}`} />
                  <div className="flex-grow text-left">
                    <div className="font-semibold text-lg">From Wallet</div>
                    <div className="text-sm text-gray-600 dark:text-gray-400">
                      Pull tokens directly from your wallet
                    </div>
                  </div>
                  {selectedOrigin === 'wallet' && (
                    <div className="w-6 h-6 rounded-full bg-blue-600 flex items-center justify-center">
                      <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                      </svg>
                    </div>
                  )}
                </div>
                <div className="mt-2 text-sm">
                  <span className="text-gray-600 dark:text-gray-400">Available: </span>
                  <span className="font-semibold">
                    {formatAmount(userBalance ?? 0n)} {getTokenSymbol(metadata)}
                  </span>
                </div>
                {selectedOrigin === 'wallet' && (userBalance ?? 0n) < position.amount && (
                  <div className="mt-2 text-sm text-red-600 dark:text-red-400">
                    Insufficient wallet balance
                  </div>
                )}
              </button>

              {/* From Supply Option */}
              <button
                onClick={() => setSelectedOrigin('supply')}
                className={`relative flex flex-col p-4 rounded-lg border-2 transition-all ${
                  selectedOrigin === 'supply'
                    ? 'border-blue-600 bg-blue-50 dark:bg-blue-900/20'
                    : 'border-gray-300 dark:border-gray-600 hover:border-gray-400 dark:hover:border-gray-500'
                }`}
              >
                <div className="flex items-center gap-3">
                  <HiCircleStack className={`w-8 h-8 ${selectedOrigin === "supply" ? "text-blue-600" : "text-gray-800 dark:text-gray-200"}`} />
                  <div className="flex-grow text-left">
                    <div className="font-semibold text-lg">From Supply</div>
                    <div className="text-sm text-gray-600 dark:text-gray-400">
                      Use tokens from your existing supply position
                    </div>
                  </div>
                  {selectedOrigin === 'supply' && (
                    <div className="w-6 h-6 rounded-full bg-blue-600 flex items-center justify-center">
                      <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                      </svg>
                    </div>
                  )}
                </div>
                <div className="mt-2 text-sm">
                  <span className="text-gray-600 dark:text-gray-400">Available: </span>
                  <span className="font-semibold">
                    {formatAmount(supplyBalance)} {getTokenSymbol(metadata)}
                  </span>
                </div>
                {selectedOrigin === 'supply' && supplyBalance < position.amount && (
                  <div className="mt-2 text-sm text-red-600 dark:text-red-400">
                    Insufficient supply balance
                  </div>
                )}
              </button>
            </div>

            <div className="flex gap-3 pt-2">
              <button
                className="flex-1 px-4 py-2 bg-gray-300 dark:bg-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-400 dark:hover:bg-gray-500 transition-colors"
                onClick={handleClose}
              >
                Cancel
              </button>
              <button
                className="flex-1 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors
                disabled:bg-gray-400 disabled:dark:bg-gray-600 disabled:cursor-not-allowed"
                onClick={handleNext}
                disabled={!canProceed}
              >
                Next
              </button>
            </div>
          </>
        )}

        {/* STEP 2: Confirm */}
        {step === 2 && (
          <>
            {/* Pool Information */}
            <div className="w-full flex flex-row items-center gap-4">
              <img
                className="w-16 h-16 bg-contain bg-no-repeat bg-center rounded-md flex-shrink-0"
                src={thumbnail}
              />
              <div className="flex-grow text-gray-800 dark:text-gray-200 text-lg font-bold line-clamp-3 overflow-hidden">
                {pool.info.text}
              </div>
            </div>

            <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4 space-y-3">
              {/* Choice */}
              <div className="flex justify-between items-center">
                <span className="text-gray-700 dark:text-gray-300">Choice</span>
                <span className={`font-semibold px-2 rounded text-white ${
                  position.choice === EYesNoChoice.Yes
                    ? 'bg-brand-true dark:bg-brand-true-dark'
                    : 'bg-brand-false'
                }`}>
                  {position.choice === EYesNoChoice.Yes ? 'True' : 'False'}
                </span>
              </div>

              {/* Amount */}
              <div className="flex justify-between items-center">
                <span className="text-gray-700 dark:text-gray-300">Amount</span>
                <div className="text-right flex flex-row space-x-1 items-center">
                  <div className="font-semibold">
                    {formatAmount(position.amount)} {getTokenSymbol(metadata)}
                  </div>
                  <div className="text-sm text-gray-500">
                    {`(${formatAmountUsd(position.amount)})`}
                  </div>
                </div>
              </div>

              {/* Dissent */}
              {positionPreview && (
                <div className="flex justify-between items-center">
                  <span className="text-gray-700 dark:text-gray-300">Dissent</span>
                  <span className="font-semibold px-2 rounded">
                    {positionPreview.dissent.toFixed(2)}
                  </span>
                </div>
              )}

              <div className="border-t border-gray-300 dark:border-gray-600"></div>

              {/* Position Preview */}
              <PutPositionPreview
                positionPreview={positionPreview}
                labelSize="text-sm"
                valueSize="text-base"
              />
            </div>

            {/* Warning */}
            <div className="flex flex-row items-center space-x-2">
              <HiOutlineExclamationTriangle className="w-6 h-6 text-orange-500 flex-shrink-0" />
              <div className="text-xs text-gray-500 dark:text-gray-400">
                By confirming, your tokens will be locked for a duration that can be no less than the minimum duration shown above.
              </div>
            </div>

            {/* Action Buttons */}
            <div className="flex gap-3 pt-2">
              <button
                className="flex-1 px-4 py-2 bg-gray-300 dark:bg-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-400 dark:hover:bg-gray-500 transition-colors"
                onClick={handlePrevious}
                disabled={putPositionLoading}
              >
                Previous
              </button>
              <button
                className="flex-1 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors
                disabled:bg-gray-500 disabled:dark:bg-gray-700 disabled:bg-none"
                onClick={handleConfirm}
                disabled={putPositionLoading}
              >
                {putPositionLoading ? 'Processing...' : 'Confirm Lock'}
              </button>
            </div>
          </>
        )}
      </div>
    </Modal>
  );
};

export default PutPositionModal;
