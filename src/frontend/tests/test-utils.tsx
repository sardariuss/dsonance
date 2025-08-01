import React from 'react';
import { render } from '@testing-library/react';
import { AgentProvider } from '@ic-reactor/react';
import { BackendActorProvider } from '../actors/BackendActor';
import { CkBtcActorProvider } from '../actors/CkBtcActor';
import { ProtocolActorProvider } from '../actors/ProtocolActor';
import { CkUsdtActorProvider } from '../actors/CkUsdtActor';
import { FaucetActorProvider } from '../actors/FaucetActor';
import { ProtocolProvider } from '../components/context/ProtocolContext';
import { FungibleLedgerProvider } from '../components/context/FungibleLedgerContext';
import { IcpCoinsActorProvider } from '../actors/IcpCoinsActor';

const AllTheProviders = ({ children }: { children: React.ReactNode }) => {
  return (
    <AgentProvider withProcessEnv>
      <BackendActorProvider>
        <CkBtcActorProvider>
          <CkUsdtActorProvider>
            <ProtocolActorProvider>
              <FaucetActorProvider>
                <IcpCoinsActorProvider>
                  <ProtocolProvider>
                    <FungibleLedgerProvider>{children}</FungibleLedgerProvider>
                  </ProtocolProvider>
                </IcpCoinsActorProvider>
              </FaucetActorProvider>
            </ProtocolActorProvider>
          </CkUsdtActorProvider>
        </CkBtcActorProvider>
      </BackendActorProvider>
    </AgentProvider>
  );
};

const customRender = (ui: React.ReactElement, options?: any) =>
  render(ui, { wrapper: AllTheProviders, ...options });

export * from '@testing-library/react';

export { customRender as render };
