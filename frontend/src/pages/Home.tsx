import { Overview } from "../components/Overview";
import { MintRedeem } from "../components/MintRedeem";
import { Requests } from "../components/Requests";
import { History } from "../components/History";

export function Home() {
  return (
    <>
      <div className="grid gap-4 md:grid-cols-2">
        <div className="space-y-4">
          <Overview />
          <History />
        </div>
        <div className="space-y-4">
          <MintRedeem onDone={() => {}} />
        </div>
      </div>
      <div className="mt-4">
        <Requests />
      </div>
    </>
  );
}
