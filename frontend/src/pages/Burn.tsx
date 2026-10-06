import { MintRedeem } from "../components/MintRedeem";
import { Requests } from "../components/Requests";

export function Burn() {
  return (
    <div className="grid gap-4 md:grid-cols-2">
      <MintRedeem mode="redeem" onDone={() => {}} />
      <Requests />
    </div>
  );
}
