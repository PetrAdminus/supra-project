import "react-i18next";
import type { Messages } from "./messages";

declare module "react-i18next" {
  interface CustomTypeOptions {
    defaultNS: "translation";
    resources: {
      translation: Messages;
    };
  }
}
