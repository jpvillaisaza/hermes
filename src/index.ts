#!/usr/bin/env node

import { parseArgs } from "node:util";
import { checkFeed, extractFeeds } from "./hermes";

const main = async () => {
  const options = {
    help: {
      short: 'h',
      type: 'boolean',
      default: false,
    },
    check: {
      type: 'boolean',
      default: false,
    },
  } as const;
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    args: process.argv.slice(2),
    options,
  });

  const url = positionals[0];
  if (!url) {
    console.error('Usage: hermes URL');
    process.exit(1);
  }
  const response = await fetch(url);
  if (!response.ok) {
    throw Error(response.statusText);
  }
  const feeds = extractFeeds(url, await response.text());
  feeds.forEach(async feed => {
    const checked = values.check ? await checkFeed(feed) : true;
    if (checked) {
      console.log(`- ${feed.href} (${feed.type})`);
    }
  });
}

main().catch((error) => {
  console.error("Error:", error.message);
  process.exit(1);
});
