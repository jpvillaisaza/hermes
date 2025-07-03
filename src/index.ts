#!/usr/bin/env node

import { run } from "./feed";
import { parseOptions } from "./options";

const main = async () => {
  const options = parseOptions(process.argv.slice(2));
  if (!options.ok) {
    console.error(options.error);
    console.error('Usage: hermes URL');
    process.exit(1);
  }
  run(options.value);
}

main().catch((error) => {
  console.error("Error:", error.message);
  process.exit(1);
});
