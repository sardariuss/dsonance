import                                  './styles.css';
import                                  './styles.scss';
import App                              from './components/App';

import ReactDOM                         from 'react-dom/client';
import { StrictMode }                   from 'react';
import { AgentProvider }                from "@ic-reactor/react";
import { BackendActorProvider }         from "./actors/BackendActor"
import { CkBtcActorProvider }           from './actors/CkBtcActor';
import { ProtocolActorProvider }        from './actors/ProtocolActor';
import { CkUsdtActorProvider }          from './actors/CkUsdtActor';
import { MinterActorProvider }          from './actors/MinterActor';
import { ProtocolProvider }             from './components/context/ProtocolContext';
import { FungibleLedgerProvider }       from './components/context/FungibleLedgerContext';
import { IcpCoinsActorProvider }        from './actors/IcpCoinsActor';

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <StrictMode>
    <AgentProvider withProcessEnv>
      <BackendActorProvider>
        <CkBtcActorProvider>
          <CkUsdtActorProvider>
            <ProtocolActorProvider>
              <MinterActorProvider>
                <IcpCoinsActorProvider>
                  <ProtocolProvider>
                    <FungibleLedgerProvider>
                      <App/>
                    </FungibleLedgerProvider>
                  </ProtocolProvider>
                </IcpCoinsActorProvider>
              </MinterActorProvider>
            </ProtocolActorProvider>
          </CkUsdtActorProvider>
        </CkBtcActorProvider>
      </BackendActorProvider>
    </AgentProvider>
  </StrictMode>
);
