import { createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";
import { opMainnet } from "./config";

export const wagmiConfig = createConfig({
  chains: [opMainnet],
  connectors: [injected()],
  transports: {
    [opMainnet.id]: http(),
  },
  ssr: false,
});

declare module "wagmi" {
  interface Register {
    config: typeof wagmiConfig;
  }
}
