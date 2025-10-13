export const EMPTY_VALUE = "—";

export interface FormatSupraOptions {
  /**
   * Suffix appended to formatted number. Use empty string to omit.
   * Default: " $SUPRA".
   */
  suffix?: string;
  /** Locale used to format the number. Default: "en-US". */
  locale?: string;
  /** Maximum fraction digits to render. Default: 2. */
  maximumFractionDigits?: number;
}

export function parseSupraValue(value?: string | number | null): number | null {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  const numeric = Number(value);
  return Number.isNaN(numeric) ? null : numeric;
}

export function formatSupraValue(
  value?: string | number | null,
  { suffix = " $SUPRA", locale = "en-US", maximumFractionDigits = 2 }: FormatSupraOptions = {},
): string {
  if (value === null || value === undefined || value === "") {
    return EMPTY_VALUE;
  }
  const numeric = Number(value);
  if (Number.isNaN(numeric)) {
    return String(value);
  }
  return `${numeric.toLocaleString(locale, { maximumFractionDigits })}${suffix}`;
}

export interface FormatDateTimeOptions extends Intl.DateTimeFormatOptions {
  locale?: string;
}

export function formatDateTime(
  value?: string | null,
  { locale, ...formatOptions }: FormatDateTimeOptions = {},
): string {
  if (!value) {
    return EMPTY_VALUE;
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return EMPTY_VALUE;
  }
  return parsed.toLocaleString(locale, Object.keys(formatOptions).length ? formatOptions : undefined);
}
