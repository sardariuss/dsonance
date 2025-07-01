import { MetaDatum } from "@/declarations/ck_btc/ck_btc.did";

export const getTokenLogo = (metadata: MetaDatum[] | undefined) : string | undefined => {
  if (!metadata) {
    return undefined;
  }
  const logo = metadata.find((item) => item[0] === "icrc1:logo");
  if (logo !== undefined && "Text" in logo?.[1]) {
    return logo?.[1].Text;
  }
  return undefined;
}

export const getTokenName = (metadata: MetaDatum[] | undefined) : string | undefined => {
  if (!metadata) {
    return undefined;
  }
  const name = metadata.find((item) => item[0] === "icrc1:name");
  if (name !== undefined && "Text" in name?.[1]) {
    return name?.[1].Text;
  }
  return undefined;
}

export const getTokenSymbol = (metadata: MetaDatum[] | undefined) : string | undefined => {
  if (!metadata) {
    return undefined;
  } 
  const symbol = metadata.find((item) => item[0] === "icrc1:symbol");
  if (symbol !== undefined && "Text" in symbol?.[1]) {
    return symbol?.[1].Text;
  }
  return undefined;
}

export const getTokenDecimals = (metadata: MetaDatum[] | undefined) : number | undefined => {
  if (!metadata) {
    return undefined;
  }
  const decimals = metadata.find((item) => item[0] === "icrc1:decimals");
  if (decimals !== undefined && "Nat" in decimals?.[1]) {
    return Number(decimals?.[1].Nat);
  }
  return undefined;
}