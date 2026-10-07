import { useReadContracts } from "wagmi";
import { erc20Abi, liquidWalletAbi, vaultAbi } from "./abi";
import { CONTRACTS } from "./config";

/// Reads the settlement (USDC) and share (wskBV) balances held by the LiquidWallet contract,
/// the WellstakeVault contract, and the vaultWallet EOA, plus the current owner addresses.
export function useHoldings() {
  // Resolve the vaultWallet address and the vault contract's own address.
  const { data: meta } = useReadContracts({
    contracts: [
      { abi: liquidWalletAbi, address: CONTRACTS.liquidWallet, functionName: "vaultWallet" },
      { abi: vaultAbi, address: CONTRACTS.vault, functionName: "vaultWallet" },
      { abi: vaultAbi, address: CONTRACTS.vault, functionName: "liquidWallet" },
    ],
    query: { refetchInterval: 8000 },
  });

  const vaultWallet =
    (meta?.[0]?.result as `0x${string}` | undefined) ??
    (meta?.[1]?.result as `0x${string}` | undefined);

  const vaultAddr = CONTRACTS.vault;
  const liquidAddr = CONTRACTS.liquidWallet;
  const operatorAddr = vaultWallet ?? CONTRACTS.vault;

  const { data, refetch } = useReadContracts({
    contracts: [
      // USDC balances
      { abi: erc20Abi, address: CONTRACTS.usdc, functionName: "balanceOf", args: [liquidAddr] },
      { abi: erc20Abi, address: CONTRACTS.usdc, functionName: "balanceOf", args: [vaultAddr] },
      { abi: erc20Abi, address: CONTRACTS.usdc, functionName: "balanceOf", args: [operatorAddr] },
      // wskBV balances
      { abi: erc20Abi, address: CONTRACTS.wsk, functionName: "balanceOf", args: [liquidAddr] },
      { abi: erc20Abi, address: CONTRACTS.wsk, functionName: "balanceOf", args: [vaultAddr] },
      { abi: erc20Abi, address: CONTRACTS.wsk, functionName: "balanceOf", args: [operatorAddr] },
    ],
    query: { refetchInterval: 8000 },
  });

  return {
    vaultWallet: operatorAddr,
    vaultAddr,
    liquidAddr,
    usdc: {
      liquid: data?.[0]?.result as bigint | undefined,
      vault: data?.[1]?.result as bigint | undefined,
      operator: data?.[2]?.result as bigint | undefined,
    },
    wsk: {
      liquid: data?.[3]?.result as bigint | undefined,
      vault: data?.[4]?.result as bigint | undefined,
      operator: data?.[5]?.result as bigint | undefined,
    },
    refetch,
  };
}
