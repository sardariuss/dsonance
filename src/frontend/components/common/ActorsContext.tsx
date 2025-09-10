import { Actor, ActorSubclass, Agent, HttpAgent }                         from "@dfinity/agent";
import { useAgent }                                                       from "@nfid/identitykit/react";
import React, { createContext, useContext, useEffect, useMemo, useState } from "react";

import { idlFactory as backendIdlFactory,      canisterId as backendId      } from "../../../declarations/backend/index";
import { idlFactory as protocolIdlFactory,     canisterId as protocolId     } from "../../../declarations/protocol/index";
import { idlFactory as ckBtcLedgerIdlFactory,  canisterId as ckBtcLedgerId  } from "../../../declarations/ckbtc_ledger/index";
import { idlFactory as ckUsdtLedgerIdlFactory, canisterId as ckUsdtLedgerId } from "../../../declarations/ckusdt_ledger/index";
import { idlFactory as dsnLedgerIdlFactory,    canisterId as dsnLedgerId    } from "../../../declarations/dsn_ledger/index";
import { idlFactory as faucetIdlFactory,       canisterId as faucetId       } from "../../../declarations/faucet/index";
import { idlFactory as icpCoinsIdlFactory,     canisterId as icpCoinsId     } from "../../../declarations/icp_coins/index";
import { _SERVICE as BackendService      } from "../../../declarations/backend/backend.did";
import { _SERVICE as ProtocolService     } from "../../../declarations/protocol/protocol.did";
import { _SERVICE as CkBtcLedgerService  } from "../../../declarations/ckbtc_ledger/ckbtc_ledger.did";
import { _SERVICE as CkUsdtLedgerService } from "../../../declarations/ckusdt_ledger/ckusdt_ledger.did";
import { _SERVICE as DsnLedgerService    } from "../../../declarations/dsn_ledger/dsn_ledger.did";
import { _SERVICE as FaucetService       } from "../../../declarations/faucet/faucet.did";
import { _SERVICE as IcpCoinsService     } from "../../../declarations/icp_coins/icp_coins.did";

const createBackendActor = (agent: any) => {
  return Actor.createActor<BackendService>(backendIdlFactory, {
    agent: agent as Agent,
    canisterId: backendId,
  });
}

const createProtocolActor = (agent: any) => {
  return Actor.createActor<ProtocolService>(protocolIdlFactory, {
    agent: agent as Agent,
    canisterId: protocolId,
  });
}

const createCkBtcLedgerActor = (agent: any) => {
  return Actor.createActor<CkBtcLedgerService>(ckBtcLedgerIdlFactory, {
    agent: agent as Agent,
    canisterId: ckBtcLedgerId,
  });
}

const createCkUsdtLedgerActor = (agent: any) => {
  return Actor.createActor<CkUsdtLedgerService>(ckUsdtLedgerIdlFactory, {
    agent: agent as Agent,
    canisterId: ckUsdtLedgerId,
  });
}

const createDsnLedgerActor = (agent: any) => {
  return Actor.createActor<DsnLedgerService>(dsnLedgerIdlFactory, {
    agent: agent as Agent,
    canisterId: dsnLedgerId,
  });
}

const createFaucetActor = (agent: any) => {
  return Actor.createActor<FaucetService>(faucetIdlFactory, {
    agent: agent as Agent,
    canisterId: faucetId,
  });
}

const createIcpCoinsActor = (agent: any) => {
  return Actor.createActor<IcpCoinsService>(icpCoinsIdlFactory, {
    agent: agent as Agent,
    canisterId: icpCoinsId,
  });
}

interface ActorsContextType {
  unauthenticated?: {
    backend: ActorSubclass<BackendService>;
    protocol: ActorSubclass<ProtocolService>;
    ckBtcLedger: ActorSubclass<CkBtcLedgerService>;
    ckUsdtLedger: ActorSubclass<CkUsdtLedgerService>;
    dsnLedger: ActorSubclass<DsnLedgerService>;
    faucet: ActorSubclass<FaucetService>;
    icpCoins: ActorSubclass<IcpCoinsService>;
  };
  authenticated?: {
    backend: ActorSubclass<BackendService>;
    protocol: ActorSubclass<ProtocolService>;
    ckBtcLedger: ActorSubclass<CkBtcLedgerService>;
    ckUsdtLedger: ActorSubclass<CkUsdtLedgerService>;
    dsnLedger: ActorSubclass<DsnLedgerService>;
    faucet: ActorSubclass<FaucetService>;
    icpCoins: ActorSubclass<IcpCoinsService>;
  };
}

const ActorsContext = createContext<ActorsContextType | undefined>(undefined);

export const ActorsProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {

  // identitykit does not work in local environment yet
  const isLocal = process.env.DFX_NETWORK === "local"
  const host = isLocal ? "http://127.0.0.1:4943" : 'https://icp-api.io';

  // UnauthenticatedAgent (aka anonymous agent)
  const [unauthenticatedAgent, setUnauthenticatedAgent] = useState<HttpAgent | undefined>()
  useEffect(() => {
    HttpAgent.create({ host })
      .then((agent => {
        console.log("Unauthenticated agent created successfully:", agent);
        setUnauthenticatedAgent(agent);
        if (isLocal) {
          agent.fetchRootKey().then(() => {
            console.log("Root key fetched for unauthenticated agent");
          }).catch((err) => {
            console.error("Failed to fetch root key for unauthenticated agent:", err);
          });
        }
      }))
      .catch((err) => console.error("Failed to create unauthenticated agent:", err));
  }, [host]);

  // Authenticated agent
  const authenticatedAgent = useAgent({ 
    host
  });

  useEffect(() => {
    if (authenticatedAgent) {
      console.log("Authenticated agent created successfully:", authenticatedAgent);
      if (isLocal) {
        authenticatedAgent.fetchRootKey().then(() => {
          console.log("Root key fetched for authenticated agent");
        }).catch((err: any) => {
          console.error("Failed to fetch root key for authenticated agent:", err);
        });
      }
    }
  }, [authenticatedAgent, isLocal]);

  // Memoized actors
  const { unauthenticated, authenticated } = useMemo(() => {
    const unauthenticatedActors = unauthenticatedAgent
      ? {
          backend: createBackendActor(unauthenticatedAgent),
          protocol: createProtocolActor(unauthenticatedAgent),
          ckBtcLedger: createCkBtcLedgerActor(unauthenticatedAgent),
          ckUsdtLedger: createCkUsdtLedgerActor(unauthenticatedAgent),
          dsnLedger: createDsnLedgerActor(unauthenticatedAgent),
          faucet: createFaucetActor(unauthenticatedAgent),
          icpCoins: createIcpCoinsActor(unauthenticatedAgent),
        }
      : undefined;

    const authenticatedActors = authenticatedAgent
      ? {
          backend: createBackendActor(authenticatedAgent),
          protocol: createProtocolActor(authenticatedAgent),
          ckBtcLedger: createCkBtcLedgerActor(authenticatedAgent),
          ckUsdtLedger: createCkUsdtLedgerActor(authenticatedAgent),
          dsnLedger: createDsnLedgerActor(authenticatedAgent),
          faucet: createFaucetActor(authenticatedAgent),
          icpCoins: createIcpCoinsActor(authenticatedAgent),
        }
      : undefined;

    return { unauthenticated: unauthenticatedActors, authenticated: authenticatedActors };
  }, [unauthenticatedAgent, authenticatedAgent]);

  return (
    <ActorsContext.Provider value={{ unauthenticated, authenticated }}>
      {children}
    </ActorsContext.Provider>
  );
};

export const useActors = (): ActorsContextType => {
  const context = useContext(ActorsContext);
  if (context === undefined) {
    throw new Error("useActors must be used within a ActorsProvider");
  }
  return context;
};