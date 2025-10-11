import                                  './styles.css';
import                                  './styles.scss';
import App                              from './components/App';

import ReactDOM                         from 'react-dom/client';
import { StrictMode }                   from 'react';
import IcLogo                           from './assets/ic-logo.svg';
import { ProtocolProvider }             from './components/context/ProtocolContext';
import { MiningRatesProvider }          from './components/context/MiningRatesContext';
import { FungibleLedgerProvider }       from './components/context/FungibleLedgerContext';
import { IdentityKitProvider } from "@nfid/identitykit/react";
import { IdentityKitAuthType, IdentityKitTransportType, InternetIdentity, NFIDW } from "@nfid/identitykit";
import { ActorsProvider } from './components/common/ActorsContext';
import "@nfid/identitykit/react/styles.css";

const isLocal = process.env.DFX_NETWORK === "local";
const backendId = process.env.CANISTER_ID_BACKEND;
const protocolId = process.env.CANISTER_ID_PROTOCOL;
const frontendId = process.env.CANISTER_ID_FRONTEND;

// Local II configuration for local development
const localInternetIdentity = {
  id: "LocalInternetIdentity",
  providerUrl: `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943/`,
  transportType: IdentityKitTransportType.INTERNET_IDENTITY,
  label: "Internet Identity",
  icon: IcLogo,
};

const signers = isLocal ? [localInternetIdentity] : [InternetIdentity, NFIDW];

let targets : string[] = [];
if (backendId) {
  targets = targets.concat(backendId);
}
if (protocolId) {
  targets = targets.concat(protocolId);
}

const signerClientOptions = {
  targets,
  derivationOrigin: isLocal ? undefined: `https://${frontendId}.icp0.io`,
  maxTimeToLive: BigInt(7) * BigInt(24) * BigInt(3_600_000_000_000), // 1 week in nanoseconds
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
          <MiningRatesProvider>
            <FungibleLedgerProvider>
              <App/>
            </FungibleLedgerProvider>
          </MiningRatesProvider>
        </ProtocolProvider>
      </ActorsProvider>
    </IdentityKitProvider>
  </StrictMode>
);
