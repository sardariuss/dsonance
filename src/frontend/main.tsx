import                                  './styles.css';
import                                  './styles.scss';
import App                              from './components/App';

import ReactDOM                         from 'react-dom/client';
import { StrictMode }                   from 'react';
import { AgentProvider }                from "@ic-reactor/react";
import { BackendActorProvider }         from "./actors/BackendActor"
import { CkBtcActorProvider }           from './actors/CkBtcActor';
import { ProtocolActorProvider }        from './actors/ProtocolActor';
import { ResonanceLedgerActorProvider } from './actors/ResonanceLedgerActor';
import { CurrencyProvider }             from './components/CurrencyContext';

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <StrictMode>
    <AgentProvider withProcessEnv>
      <BackendActorProvider>
        <CkBtcActorProvider>
          <ResonanceLedgerActorProvider>
            <ProtocolActorProvider>
              <CurrencyProvider>
                <App/>
              </CurrencyProvider>
            </ProtocolActorProvider>
          </ResonanceLedgerActorProvider>
        </CkBtcActorProvider>
      </BackendActorProvider>
    </AgentProvider>
  </StrictMode>
);
