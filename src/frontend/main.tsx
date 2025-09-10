import                                  './styles.css';
import                                  './styles.scss';
import App                              from './components/App';

import ReactDOM                         from 'react-dom/client';
import { StrictMode }                   from 'react';
import { ProtocolProvider }             from './components/context/ProtocolContext';
import { FungibleLedgerProvider }       from './components/context/FungibleLedgerContext';
import { IdentityKitProvider } from "@nfid/identitykit/react";
import { IdentityKitAuthType, IdentityKitTransportType, InternetIdentity, NFIDW } from "@nfid/identitykit";
import { ActorsProvider } from './components/common/ActorsContext';
import "@nfid/identitykit/react/styles.css";

const isLocal = process.env.DFX_NETWORK === "local";
const backendId = process.env.CANISTER_ID_BACKEND;
const frontendId = process.env.CANISTER_ID_FRONTEND;

// Local II configuration for local development
const localInternetIdentity = {
  id: "LocalInternetIdentity",
  providerUrl: `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943/`,
  transportType: IdentityKitTransportType.INTERNET_IDENTITY,
  label: "Internet Identity",
  icon: undefined,
};

const signers = isLocal ? [localInternetIdentity] : [InternetIdentity, NFIDW];

const signerClientOptions = {
  targets: backendId ? [backendId] : [],
  derivationOrigin: isLocal ? undefined: `https://${frontendId}.icp0.io`,
};

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <StrictMode>
    <IdentityKitProvider
      signerClientOptions={signerClientOptions}
      signers={signers}
      authType={IdentityKitAuthType.DELEGATION}
    >
      <ActorsProvider>
        <ProtocolProvider>
          <FungibleLedgerProvider>
            <App/>
          </FungibleLedgerProvider>
        </ProtocolProvider>
      </ActorsProvider>
    </IdentityKitProvider>
  </StrictMode>
);
