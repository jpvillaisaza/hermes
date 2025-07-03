import { parseArgs } from "node:util";
import { Result } from "./utils";

export interface Options {
  check: boolean;
  guess: boolean;
  help: boolean;
  url: string;
};

export const parseOptions = (args: string[]): Result<Options> => {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    args,
    options: {
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
    },
  });
  const url = positionals[0];
  if (!url) {
    return { ok: false, error: "" };
  } else {
    return { ok: true, value: { ...values, url } };
  }
}
