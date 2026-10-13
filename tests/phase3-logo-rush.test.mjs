import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import test from "node:test";

const display = readFileSync(new URL("../app/display/[code]/page.tsx", import.meta.url), "utf8");
const logoDirectory = new URL("../public/logos/", import.meta.url);

test("Logo Rush uses a clipped, fixed frame with contained artwork", () => {
  const logoBlock = display.match(
    /\{isLogoQuiz && round\?\.media\?\.type === "logo"[\s\S]*?\n\s*\)\}/,
  )?.[0];

  assert.ok(logoBlock, "Logo Rush display block should exist");
  assert.match(logoBlock, /data-testid="logo-rush-media-frame"/);
  assert.match(logoBlock, /className="[^"]*relative[^"]*overflow-hidden[^"]*"/);
  assert.match(logoBlock, /<Image[\s\S]*?\bfill\b/);
  assert.match(logoBlock, /className="[^"]*object-contain[^"]*"/);
  assert.doesNotMatch(logoBlock, /object-cover/);
});

test("every Logo Rush SVG has scalable view-box geometry", () => {
  const logos = readdirSync(logoDirectory).filter((name) => name.endsWith(".svg"));

  assert.ok(logos.length >= 100, "the full Logo Rush asset library should be present");

  for (const logo of logos) {
    const source = readFileSync(new URL(logo, logoDirectory), "utf8");
    const viewBox = source.match(
      /viewBox=["']\s*[\d.+-]+[ ,]+[\d.+-]+[ ,]+([\d.+-]+)[ ,]+([\d.+-]+)\s*["']/i,
    );

    assert.ok(viewBox, `${logo} should define a viewBox`);
    assert.ok(Number(viewBox[1]) > 0, `${logo} should have a positive viewBox width`);
    assert.ok(Number(viewBox[2]) > 0, `${logo} should have a positive viewBox height`);
  }
});
