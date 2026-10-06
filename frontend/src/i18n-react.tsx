import React, { createContext, useContext, useState } from "react";
import { Lang, t } from "./i18n";

type Ctx = { lang: Lang; setLang: (l: Lang) => void; tr: (k: keyof typeof t) => string };

const I18nContext = createContext<Ctx>({ lang: "en", setLang: () => {}, tr: () => "" });

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const [lang, setLang] = useState<Lang>("en");
  const tr = (k: keyof typeof t) => t[k][lang];
  return <I18nContext.Provider value={{ lang, setLang, tr }}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  return useContext(I18nContext);
}
