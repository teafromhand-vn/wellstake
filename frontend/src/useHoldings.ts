import { useReadContracts } from "wagmi";
import { erc20Abi, liquidWalletAbi } from "./abi";
import { CONTRACTS } from "./config";

/// Reads the settlement (USDC) and share (wskBV) balances held by the manager, the LiquidWallet
/// contract, and the WellstakeVault contract.
export function useHoldings() {
  // Resolve the manager address.
  const { data: meta } = useReadContracts({
    contracts: [
      { abi: liquidWalletAbi, address: CONTRACTS.liquidWallet, functionName: "manager" },
      { abi: liquidWalletAbi, address: CONTRACTS.liquidWallet, functionName: "vaultWallet" },
    ],
    query: { refetchInterval: 8000 },
  });

  const managerAddr =
    (meta?.[0]?.result as `0x${string}` | undefined) ?? CONTRACTS.vault;
  const vaultWallet =
    (meta?.[1]?.result as `0x${string}` | undefined) ?? CONTRACTS.vault;

  const vaultAddr = CONTRACTS.vault;
  const liquidAddr = CONTRACTS.liquidWallet;

  const { data, refetch } = useReadContracts({
    contracts: [
      // USDC balances: manager, liquid, vault
      { abi: erc20Abi, address: CONTRACTS.usdc, functionName: "balanceOf", args: [managerAddr] },
      { abi: erc20Abi, address: CONTRACTS.usdc, functionName: "balanceOf", args: [liquidAddr] },
      { abi: erc20Abi, address: CONTRACTS.usdc, functionName: "balanceOf", args: [vaultAddr] },
      // wskBV balances: manager, liquid, vault
      { abi: erc20Abi, address: CONTRACTS.wsk, functionName: "balanceOf", args: [managerAddr] },
      { abi: erc20Abi, address: CONTRACTS.wsk, functionName: "balanceOf", args: [liquidAddr] },
      { abi: erc20Abi, address: CONTRACTS.wsk, functionName: "balanceOf", args: [vaultAddr] },
    ],
    query: { refetchInterval: 8000 },
  });

  return {
    manager: managerAddr,
    vaultWallet,
    vaultAddr,
    liquidAddr,
    usdc: {
      manager: data?.[0]?.result as bigint | undefined,
      liquid: data?.[1]?.result as bigint | undefined,
      vault: data?.[2]?.result as bigint | undefined,
    },
    wsk: {
      manager: data?.[3]?.result as bigint | undefined,
      liquid: data?.[4]?.result as bigint | undefined,
      vault: data?.[5]?.result as bigint | undefined,
    },
    refetch,
  };
}
