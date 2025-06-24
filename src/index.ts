#!/usr/bin/env node

import { parseArgs } from "node:util";
import { checkFeed, extractFeeds, guessFeeds } from "./hermes";
import { fetchWithUserAgent, filterAsync } from "./utils";

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
    guess: {
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
  const response = await fetchWithUserAgent(url);
  if (!response.ok) {
    throw Error(response.statusText);
  }
  const feeds = extractFeeds(url, await response.text());
  const checkedFeeds = values.check ? await filterAsync(checkFeed, feeds) : feeds;
  checkedFeeds.forEach(feed => {
    console.log(`- ${feed.href} (${feed.type})`);
  });
  if (values.guess && checkedFeeds.length === 0) {
    const guessed = await guessFeeds(url);
    guessed.forEach(feed => {
      console.log(`- ${feed.href} (${feed.type})`);
    });
  }
}

main().catch((error) => {
  console.error("Error:", error.message);
  process.exit(1);
});
