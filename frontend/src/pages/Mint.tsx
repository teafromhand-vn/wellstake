import { MintModule } from "../components/MintModule";
import { Requests } from "../components/Requests";

export function Mint() {
  return (
    <div className="mx-auto w-full max-w-[430px] space-y-5">
      <MintModule mode="mint" />
      <Requests />
    </div>
  );
}
