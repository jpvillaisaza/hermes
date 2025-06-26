import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { extractFeeds } from '../src/hermes';

describe('extractFeeds', () => {
  it('no feeds', () => {
    const hello = `
      <!doctype html>
      <html>
      </html>
    `;
    const result = extractFeeds('https://www.example.com', hello);
    assert.strictEqual(result.length, 0);
  });

  it('alternate feed missing values', () => {
    const hello = `
    <!doctype html>
    <html>
        <head>
          <link rel="alternate">
        </head>
      </html>
    `;
    const result = extractFeeds('https://www.example.com', hello);
    assert.strictEqual(result.length, 0);
  });

  it('RSS', () => {
    const hello = `
      <!doctype html>
      <html>
        <head>
          <link rel="alternate" type="application/rss+xml" href="rss">
        </head>
      </html>
    `;
    const result = extractFeeds('https://www.example.com', hello);
    assert.strictEqual(result.length, 1);
    assert.strictEqual(result[0].href, 'https://www.example.com/rss');
    assert.strictEqual(result[0].title, undefined);
    assert.strictEqual(result[0].type, 'application/rss+xml');
  });

  it('Atom', () => {
    const hello = `
      <!doctype html>
      <html>
        <head>
          <link rel="alternate" type="application/atom+xml" href="atom">
        </head>
      </html>
    `;
    const result = extractFeeds('https://www.example.com', hello);
    assert.strictEqual(result.length, 1);
    assert.strictEqual(result[0].href, 'https://www.example.com/atom');
    assert.strictEqual(result[0].title, undefined);
    assert.strictEqual(result[0].type, 'application/atom+xml');
  });

  it('JSON', () => {
    const hello = `
      <!doctype html>
      <html>
        <head>
          <link rel="alternate" type="application/feed+json" href="json">
        </head>
      </html>
    `;
    const result = extractFeeds('https://www.example.com', hello);
    assert.strictEqual(result.length, 1);
    assert.strictEqual(result[0].href, 'https://www.example.com/json');
    assert.strictEqual(result[0].title, undefined);
    assert.strictEqual(result[0].type, 'application/feed+json');
  });

  it('accepts feed in body', () => {
    const hello = `
      <!doctype html>
      <html>
        <head></head>
        <body>
          <link rel="alternate" type="application/rss+xml" href="rss">
        </body>
      </html>
    `;
    const result = extractFeeds('https://www.example.com', hello);
    assert.strictEqual(result.length, 0);
  });

  it('hello test', () => {
    const hello = `
      <!doctype html>
      <html>
        <head></head>
        <body>
          <pre>
            <link rel="alternate" type="application/rss+xml" href="rss">
          </pre>
        </body>
      </html>
    `;
    const result = extractFeeds('https://www.example.com', hello);
    assert.strictEqual(result.length, 0);
  });

  it('accepts title', () => {
    const hello = `
      <!doctype html>
      <html>
        <head>
          <link rel="alternate" type="application/rss+xml" href="rss" title="a">
        </head>
      </html>
    `;
    const result = extractFeeds('https://www.example.com', hello);
    assert.strictEqual(result.length, 1);
    assert.strictEqual(result[0].href, 'https://www.example.com/rss');
    assert.strictEqual(result[0].title, 'a');
    assert.strictEqual(result[0].type, 'application/rss+xml');
  });

  it('accepts several', () => {
    const hello = `
      <!doctype html>
      <html>
        <head>
          <link rel="alternate" type="application/rss+xml" href="rss">
          <link rel="alternate" type="application/atom+xml" href="atom">
          <link rel="alternate" type="application/feed+json" href="json">
        </head>
      </html>
    `;
    const result = extractFeeds('https://www.example.com', hello);
    assert.strictEqual(result.length, 3);
    assert.strictEqual(result[0].href, 'https://www.example.com/rss');
    assert.strictEqual(result[0].title, undefined);
    assert.strictEqual(result[0].type, 'application/rss+xml');
    assert.strictEqual(result[1].href, 'https://www.example.com/atom');
    assert.strictEqual(result[1].title, undefined);
    assert.strictEqual(result[1].type, 'application/atom+xml');
    assert.strictEqual(result[2].href, 'https://www.example.com/json');
    assert.strictEqual(result[2].title, undefined);
    assert.strictEqual(result[2].type, 'application/feed+json');
  });
});
