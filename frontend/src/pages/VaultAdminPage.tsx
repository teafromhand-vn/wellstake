import { Link } from "react-router-dom";
import { VaultPanel } from "../components/VaultPanel";
import { useI18n } from "../i18n-react";
import { useNoindex } from "../useNoindex";

export function VaultAdminPage() {
  useNoindex();
  const { tr } = useI18n();

  return (
    <div className="space-y-4">
      <div className="text-xs text-muted">
        <Link className="text-accent underline" to="/admin">
          ← {tr("admin")}
        </Link>
      </div>
      <VaultPanel />
    </div>
  );
}
