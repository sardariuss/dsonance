import React from 'react';
import { render } from '@testing-library/react';
import { AgentProvider } from '@ic-reactor/react';
import { BackendActorProvider } from '../actors/BackendActor';
import { CkBtcActorProvider } from '../actors/CkBtcActor';
import { ProtocolActorProvider } from '../actors/ProtocolActor';
import { CkUsdtActorProvider } from '../actors/CkUsdtActor';
import { MinterActorProvider } from '../actors/MinterActor';
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
              <MinterActorProvider>
                <IcpCoinsActorProvider>
                  <ProtocolProvider>
                    <FungibleLedgerProvider>{children}</FungibleLedgerProvider>
                  </ProtocolProvider>
                </IcpCoinsActorProvider>
              </MinterActorProvider>
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
