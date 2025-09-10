import React from 'react';
import { render } from '@testing-library/react';
import { IdentityKitProvider } from '@nfid/identitykit/react';
import { ActorsProvider } from '../components/common/ActorsContext';
import { ProtocolProvider } from '../components/context/ProtocolContext';
import { FungibleLedgerProvider } from '../components/context/FungibleLedgerContext';

// Mock signers for tests  
const mockSigners = [{
  id: "LocalInternetIdentity",
  providerUrl: "http://localhost:4943",
  transportType: "II" as any,
  label: "Internet Identity",
}];

const AllTheProviders = ({ children }: { children: React.ReactNode }) => {
  return (
    <IdentityKitProvider
      signerClientOptions={{ targets: [] }}
      signers={mockSigners}
      authType="DELEGATION"
    >
      <ActorsProvider>
        <ProtocolProvider>
          <FungibleLedgerProvider>{children}</FungibleLedgerProvider>
        </ProtocolProvider>
      </ActorsProvider>
    </IdentityKitProvider>
  );
};

const customRender = (ui: React.ReactElement, options?: any) =>
  render(ui, { wrapper: AllTheProviders, ...options });

export * from '@testing-library/react';

export { customRender as render };
