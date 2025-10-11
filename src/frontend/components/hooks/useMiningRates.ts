import { useMemo } from 'react';
import { LendingIndex } from '@/declarations/protocol/protocol.did';
import { useProtocolContext } from '../context/ProtocolContext';

interface MiningParameters {
  emission_total_amount_e8s: bigint;
  emission_half_life_s: number;
  borrowers_share: number;
}

export interface MiningRates {
  // Current rates in TWV/day
  currentSupplyRate: number;
  currentBorrowRate: number;

  // Current rates per ckUSDT in TWV/ckUSDT/day
  currentSupplyRatePerToken: number;
  currentBorrowRatePerToken: number;

  // Total emission rate in TWV/day
  totalEmissionRate: number;

  // Function to calculate emission rate at any time (in seconds since genesis)
  getEmissionRateAtTime: (timeInSeconds: number) => {
    emissionRatePerDay: number;
    emissionRatePerSecond: number;
  };

  // Function to calculate preview rates given an additional amount
  calculatePreviewRates: (params: {
    additionalSupply?: bigint;
    additionalBorrow?: bigint;
  }) => {
    previewSupplyRatePerToken: number;
    previewBorrowRatePerToken: number;
  };
}

const NS_IN_SECOND = 1_000_000_000;
const SECONDS_IN_DAY = 24 * 60 * 60;

/**
 * Calculates the emission rate at a given time using the exponential decay formula.
 * Formula: dE/dt = E0 * k * e^(-kt)
 * where k = ln(2) / half_life_s
 *
 * @param E0 - Total emission amount in e8s
 * @param k - Decay constant (ln(2) / half_life_s)
 * @param timeInSeconds - Time elapsed since genesis in seconds
 * @returns Emission rate per second at the given time
 */
export const calculateEmissionRatePerSecond = (
  E0: number,
  k: number,
  timeInSeconds: number
): number => {
  return E0 * k * Math.exp(-k * timeInSeconds);
};

/**
 * Hook to calculate mining emission rates based on the current state.
 * Mirrors the logic from Miner.mo for emission rate calculation.
 *
 * The emission rate follows an exponential decay: dE/dt = E0 * k * e^(-kt)
 * where k = ln(2) / half_life_s
 *
 * Now uses ProtocolContext internally instead of requiring parameters.
 */
export const useMiningRates = (): MiningRates | null => {
  const { info, parameters, lendingIndexTimeline } = useProtocolContext();

  return useMemo(() => {
    // Return null if any required data is missing
    if (!info || !parameters || !lendingIndexTimeline) {
      return null;
    }

    const genesisTime = info.genesis_time;
    const currentTime = info.current_time;
    const miningParams = parameters.mining;
    const lendingIndex = lendingIndexTimeline.current.data;

    const { emission_total_amount_e8s, emission_half_life_s, borrowers_share } = miningParams;
    const { raw_supplied, raw_borrowed } = lendingIndex.utilization;

    // Calculate k = ln(2) / half_life (in seconds)
    const k = Math.log(2) / emission_half_life_s;
    const E0 = Number(emission_total_amount_e8s);

    // Calculate time elapsed since genesis in seconds
    const timeElapsedNs = Number(currentTime - genesisTime);
    const timeElapsedSeconds = timeElapsedNs / NS_IN_SECOND;

    // Calculate emission rate at current time using the shared utility
    const emissionRatePerSecond = calculateEmissionRatePerSecond(E0, k, timeElapsedSeconds);
    const totalEmissionRate = emissionRatePerSecond * SECONDS_IN_DAY; // Convert to TWV/day

    // Split emission rate between suppliers and borrowers
    const currentBorrowRate = totalEmissionRate * borrowers_share;
    const currentSupplyRate = totalEmissionRate * (1 - borrowers_share);

    // Calculate per-token rates (avoid division by zero)
    const currentSupplyRatePerToken = raw_supplied > 0
      ? currentSupplyRate / raw_supplied
      : 0;

    const currentBorrowRatePerToken = raw_borrowed > 0
      ? currentBorrowRate / raw_borrowed
      : 0;

    // Function to calculate emission rate at any given time
    const getEmissionRateAtTime = (timeInSeconds: number) => {
      const emissionRatePerSecond = calculateEmissionRatePerSecond(E0, k, timeInSeconds);
      const emissionRatePerDay = emissionRatePerSecond * SECONDS_IN_DAY;

      return {
        emissionRatePerSecond,
        emissionRatePerDay,
      };
    };

    // Function to calculate preview rates with additional supply/borrow amounts
    const calculatePreviewRates = ({
      additionalSupply = 0n,
      additionalBorrow = 0n
    }: {
      additionalSupply?: bigint;
      additionalBorrow?: bigint;
    }) => {
      const previewRawSupplied = raw_supplied + Number(additionalSupply);
      const previewRawBorrowed = raw_borrowed + Number(additionalBorrow);

      const previewSupplyRatePerToken = previewRawSupplied > 0
        ? currentSupplyRate / previewRawSupplied
        : 0;

      const previewBorrowRatePerToken = previewRawBorrowed > 0
        ? currentBorrowRate / previewRawBorrowed
        : 0;

      return {
        previewSupplyRatePerToken,
        previewBorrowRatePerToken,
      };
    };

    return {
      currentSupplyRate,
      currentBorrowRate,
      currentSupplyRatePerToken,
      currentBorrowRatePerToken,
      totalEmissionRate,
      getEmissionRateAtTime,
      calculatePreviewRates,
    };
  }, [info, parameters, lendingIndexTimeline]);
};
