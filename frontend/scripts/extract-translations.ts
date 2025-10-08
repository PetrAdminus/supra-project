#!/usr/bin/env ts-node
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { dictionaries } from "../src/i18n/messages";
import { locales } from "../src/i18n/locales";

type Dictionary = (typeof dictionaries)[(typeof locales)[number]];

type PlainObject = Record<string, unknown>;

function sortObject(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => sortObject(item));
  }

  if (value && typeof value === "object") {
    const entries = Object.entries(value as PlainObject)
      .map(([key, nested]) => [key, sortObject(nested)] as const)
      .sort(([a], [b]) => a.localeCompare(b));

    return entries.reduce<PlainObject>((acc, [key, nested]) => {
      acc[key] = nested;
      return acc;
    }, {});
  }

  return value;
}

async function main() {
  const rootDir = path.dirname(fileURLToPath(import.meta.url));
  const localesDir = path.resolve(rootDir, "../public/locales");

  await mkdir(localesDir, { recursive: true });

  for (const locale of locales) {
    const dictionary: Dictionary = dictionaries[locale];
    const targetDir = path.join(localesDir, locale);
    await mkdir(targetDir, { recursive: true });
    const sorted = sortObject(dictionary);
    const outputPath = path.join(targetDir, "translation.json");
    await writeFile(outputPath, `${JSON.stringify(sorted, null, 2)}\n`, "utf8");
    console.log(`✔ Словарь для ${locale} сохранён в ${path.relative(rootDir, outputPath)}`);
  }
}

main().catch((error) => {
  console.error("Не удалось выгрузить переводы", error);
  process.exitCode = 1;
});
