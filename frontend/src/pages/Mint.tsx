import { MintRedeem } from "../components/MintRedeem";
import { Requests } from "../components/Requests";

export function Mint() {
  return (
    <div className="grid gap-4 md:grid-cols-2">
      <MintRedeem mode="mint" onDone={() => {}} />
      <Requests />
    </div>
  );
}
