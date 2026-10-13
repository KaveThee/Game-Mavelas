import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const display = readFileSync(new URL("../app/display/[code]/page.tsx", import.meta.url), "utf8");

test("the shared display is constrained to one viewport", () => {
  assert.match(display, /<main className="h-dvh overflow-hidden/);
  assert.match(display, /data-testid="display-shell"[\s\S]*?className="[^"]*h-full[^"]*min-h-0/);
  assert.match(display, /data-testid="display-stage"[\s\S]*?className="[^"]*min-h-0[^"]*overflow-hidden/);
  assert.doesNotMatch(display, /min-h-\[calc\(100vh-2rem\)\]/);
});

test("display chrome cannot force the game stage beyond the viewport", () => {
  assert.match(display, /<header className="[^"]*shrink-0/);
  assert.match(display, /<footer className="[^"]*shrink-0/);
  assert.match(display, /<aside className="[^"]*max-h-full[^"]*overflow-hidden/);
  assert.match(display, /max-h-\[calc\(100dvh-285px\)\]/);
});

test("media and answer layouts use the compact display rhythm", () => {
  assert.match(display, /className="h-48 w-auto[^"]*lg:h-60"/);
  assert.match(display, /data-testid="logo-rush-media-frame"[\s\S]*?className="[^"]*h-44[^"]*lg:h-56/);
  assert.match(display, /className="mt-5 grid max-w-4xl grid-cols-2 gap-3"/);
  assert.match(display, /min-h-20[^"]*sm:min-h-24/);
});

test("long production questions and options scale before they can overflow", () => {
  assert.match(display, /const promptLength = round\?\.prompt\?\.length \?\? 0/);
  assert.match(display, /promptLength > 220[\s\S]*?text-2xl sm:text-3xl lg:text-4xl/);
  assert.match(display, /const longestOptionLength = round\?\.options\.reduce/);
  assert.match(display, /longestOptionLength > 100[\s\S]*?text-xs sm:text-sm/);
  assert.match(display, /\$\{questionTitleSize\}/);
  assert.match(display, /\$\{answerTextSize\} font-black leading-tight/);
});

test("Trivia Dash board cells use capped heights instead of growing with width", () => {
  assert.match(display, /relative flex h-10 items-center[\s\S]*?sm:h-11/);
  assert.doesNotMatch(display, /relative flex aspect-square min-h-11/);
});
