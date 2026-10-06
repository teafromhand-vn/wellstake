import { useEffect } from "react";

/// Sets a robots noindex meta tag for the lifetime of the component.
export function useNoindex() {
  useEffect(() => {
    const meta = document.createElement("meta");
    meta.name = "robots";
    meta.content = "noindex, nofollow";
    document.head.appendChild(meta);
    document.title = "Admin - Wellstake";
    return () => {
      document.head.removeChild(meta);
    };
  }, []);
}
