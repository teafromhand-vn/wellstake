import { useReadContracts, useAccount } from "wagmi";
import { erc20Abi, liquidWalletAbi } from "./abi";
import { CONTRACTS, SHARE, QUOTE } from "./config";

export function useVaultData() {
  const { address } = useAccount();

  const { data, refetch, isLoading } = useReadContracts({
    contracts: [
      { abi: liquidWalletAbi, address: CONTRACTS.liquidWallet, functionName: "totalNav" },
      { abi: liquidWalletAbi, address: CONTRACTS.liquidWallet, functionName: "rate" },
      { abi: liquidWalletAbi, address: CONTRACTS.liquidWallet, functionName: "nextRequestId" },
      { abi: liquidWalletAbi, address: CONTRACTS.liquidWallet, functionName: "manager" },
      { abi: liquidWalletAbi, address: CONTRACTS.liquidWallet, functionName: "vault" },
      { abi: liquidWalletAbi, address: CONTRACTS.liquidWallet, functionName: "woundDown" },
      {
        abi: erc20Abi,
        address: CONTRACTS.wsk,
        functionName: "totalSupply",
      },
      {
        abi: erc20Abi,
        address: CONTRACTS.usdc,
        functionName: "balanceOf",
        args: [CONTRACTS.liquidWallet],
      },
      { abi: liquidWalletAbi, address: CONTRACTS.liquidWallet, functionName: "currentEpoch" },
    ],
    query: { refetchInterval: 8000 },
  });

  const manager = data?.[3]?.result as `0x${string}` | undefined;
  const liquidVault = data?.[4]?.result as `0x${string}` | undefined;

  const balances = useReadContracts({
    contracts: address
      ? [
          {
            abi: erc20Abi,
            address: CONTRACTS.usdc,
            functionName: "balanceOf",
            args: [address],
          },
          {
            abi: erc20Abi,
            address: CONTRACTS.wsk,
            functionName: "balanceOf",
            args: [address],
          },
          {
            abi: erc20Abi,
            address: CONTRACTS.usdc,
            functionName: "allowance",
            args: [address, CONTRACTS.liquidWallet],
          },
          {
            abi: erc20Abi,
            address: CONTRACTS.wsk,
            functionName: "allowance",
            args: [address, CONTRACTS.liquidWallet],
          },
        ]
      : [],
    query: { refetchInterval: 8000, enabled: !!address },
  });

  return {
    isLoading,
    refetch: () => {
      refetch();
      balances.refetch();
    },
    totalNav: data?.[0]?.result as bigint | undefined,
    rate: data?.[1]?.result as bigint | undefined,
    nextRequestId: (data?.[2]?.result as bigint | undefined) ?? 1n,
    manager,
    liquidVault,
    woundDown: (data?.[5]?.result as boolean | undefined) ?? false,
    totalSupply: data?.[6]?.result as bigint | undefined,
    liquidUsdc: data?.[7]?.result as bigint | undefined,
    currentEpoch: (data?.[8]?.result as bigint | undefined) ?? 1n,
    usdcBalance: balances.data?.[0]?.result as bigint | undefined,
    wskBalance: balances.data?.[1]?.result as bigint | undefined,
    usdcAllowance: balances.data?.[2]?.result as bigint | undefined,
    wskAllowance: balances.data?.[3]?.result as bigint | undefined,
    meta: { share: SHARE, quote: QUOTE },
  };
}
