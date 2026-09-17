import { mkdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const outputDir = join(root, "public", "celebrities");

const portraits = [
  { slug: "lupita-nyongo", name: "Lupita Nyong'o", skin: "#6f3d2b", hair: "crop", outfit: "#ef3340", accent: "#d7ff3f", earrings: true },
  { slug: "eliud-kipchoge", name: "Eliud Kipchoge", skin: "#70412f", hair: "short", outfit: "#c8102e", accent: "#ffffff", runner: true },
  { slug: "faith-kipyegon", name: "Faith Kipyegon", skin: "#754431", hair: "braids", outfit: "#00843d", accent: "#ef3340", runner: true },
  { slug: "wangari-maathai", name: "Wangari Maathai", skin: "#764735", hair: "wrap", outfit: "#2f7d32", accent: "#f4c542", glasses: true },
  { slug: "ferdinand-omanyala", name: "Ferdinand Omanyala", skin: "#693a2a", hair: "fade", outfit: "#111111", accent: "#d7ff3f", runner: true },
  { slug: "david-rudisha", name: "David Rudisha", skin: "#72412e", hair: "short", outfit: "#d71920", accent: "#ffffff", runner: true },
  { slug: "mwai-kibaki", name: "Mwai Kibaki", skin: "#865845", hair: "silver", outfit: "#26364a", accent: "#b91c1c", glasses: true, tie: true },
  { slug: "dedan-kimathi", name: "Dedan Kimathi", skin: "#633826", hair: "dread-cap", outfit: "#4d5a38", accent: "#c19a5b", beard: true },
  { slug: "mekatilili-wa-menza", name: "Mekatilili wa Menza", skin: "#75432f", hair: "headcloth", outfit: "#8b2f2f", accent: "#e9b949", earrings: true },
  { slug: "joy-adamson", name: "Joy Adamson", skin: "#e2b293", hair: "wave", outfit: "#b7834b", accent: "#f4e7ce" },
  { slug: "william-ruto", name: "William Ruto", skin: "#744633", hair: "short", outfit: "#243447", accent: "#f2b134", tie: true },
  { slug: "raila-odinga", name: "Raila Odinga", skin: "#71432f", hair: "silver", outfit: "#183153", accent: "#d11f2f", glasses: true, tie: true },
  { slug: "uhuru-kenyatta", name: "Uhuru Kenyatta", skin: "#895741", hair: "short", outfit: "#233449", accent: "#b91c1c", glasses: true, tie: true },
  { slug: "bien-aime-baraza", name: "Bien-Aimé Baraza", skin: "#603522", hair: "locs", outfit: "#161616", accent: "#f0c75e", beard: true },
  { slug: "nyashinski", name: "Nyashinski", skin: "#70402d", hair: "fade", outfit: "#202020", accent: "#ffffff", beard: true },
  { slug: "churchill-ndambuki", name: "Churchill Ndambuki", skin: "#724430", hair: "bald", outfit: "#8b1e2d", accent: "#ffffff", glasses: true },
  { slug: "victor-wanyama", name: "Victor Wanyama", skin: "#5d3324", hair: "short", outfit: "#c8102e", accent: "#ffffff", badge: "KEN" },
  { slug: "njugush", name: "Njugush", skin: "#754633", hair: "fade", outfit: "#f3a712", accent: "#101314" },
  { slug: "eric-omondi", name: "Eric Omondi", skin: "#633623", hair: "crop", outfit: "#111111", accent: "#d7ff3f" },
  { slug: "catherine-kamau", name: "Catherine Kamau", skin: "#85523c", hair: "braids", outfit: "#8f2d56", accent: "#f7c6d9", earrings: true },
  { slug: "nelson-mandela", name: "Nelson Mandela", skin: "#6d402e", hair: "silver", outfit: "#d4a84f", accent: "#244b7a" },
  { slug: "trevor-noah", name: "Trevor Noah", skin: "#9a644b", hair: "curls", outfit: "#222936", accent: "#ffffff", tie: true },
  { slug: "burna-boy", name: "Burna Boy", skin: "#633824", hair: "locs", outfit: "#181818", accent: "#e6bd55", beard: true },
  { slug: "diamond-platnumz", name: "Diamond Platnumz", skin: "#75422d", hair: "fade", outfit: "#f5f5f5", accent: "#d4af37", beard: true },
  { slug: "mohamed-salah", name: "Mohamed Salah", skin: "#a56848", hair: "curls", outfit: "#c8102e", accent: "#ffffff", beard: true, badge: "11" },
  { slug: "didier-drogba", name: "Didier Drogba", skin: "#56301f", hair: "bald", outfit: "#034694", accent: "#ffffff", badge: "11" },
  { slug: "davido", name: "Davido", skin: "#71402b", hair: "fade", outfit: "#202020", accent: "#d4af37", beard: true },
  { slug: "cristiano-ronaldo", name: "Cristiano Ronaldo", skin: "#c98b66", hair: "sidepart", outfit: "#ffffff", accent: "#111111", badge: "CR7" },
  { slug: "lionel-messi", name: "Lionel Messi", skin: "#d49a76", hair: "sidepart", outfit: "#75aadb", accent: "#ffffff", beard: true, badge: "10" },
  { slug: "barack-obama", name: "Barack Obama", skin: "#915f47", hair: "short", outfit: "#233449", accent: "#4b6fa9", tie: true },
];

const hair = {
  crop: '<path d="M164 213c9-78 57-119 92-119s84 41 92 119c-28-29-58-43-92-43s-64 14-92 43Z" fill="#14110f"/><circle cx="188" cy="144" r="14" fill="#14110f"/><circle cx="220" cy="115" r="17" fill="#14110f"/><circle cx="258" cy="106" r="18" fill="#14110f"/><circle cx="296" cy="116" r="17" fill="#14110f"/><circle cx="326" cy="147" r="14" fill="#14110f"/>',
  short: '<path d="M171 210c5-75 43-112 85-112s80 37 85 112c-27-27-55-40-85-40s-58 13-85 40Z" fill="#181411"/>',
  fade: '<path d="M173 205c8-71 43-105 83-105s75 34 83 105c-25-23-53-35-83-35s-58 12-83 35Z" fill="#0b0b0b"/><path d="M184 156c43-38 101-38 144 0" fill="none" stroke="#35302d" stroke-width="7"/>',
  braids: '<path d="M166 221c1-84 39-127 90-127s89 43 90 127c-27-36-57-54-90-54s-63 18-90 54Z" fill="#171210"/><path d="M183 175c-18 72-17 123-1 156M206 151c-18 87-14 152 0 190M306 151c18 87 14 152 0 190M329 175c18 72 17 123 1 156" fill="none" stroke="#171210" stroke-width="13" stroke-linecap="round"/>',
  wrap: '<path d="M158 210c5-83 45-127 98-127s93 44 98 127c-29-31-62-47-98-47s-69 16-98 47Z" fill="#2f7d32"/><path d="M184 117c44-51 109-50 151 2-58-15-105-16-151-2Z" fill="#f4c542"/><path d="M252 82c18-32 51-31 64 3-26-8-45-9-64-3Z" fill="#2f7d32"/>',
  silver: '<path d="M170 210c6-75 45-114 86-114s80 39 86 114c-27-27-56-41-86-41s-59 14-86 41Z" fill="#c6c1b8"/><path d="M187 150c41-27 96-27 138 0" fill="none" stroke="#f3f0e9" stroke-width="12" stroke-linecap="round"/>',
  'dread-cap': '<path d="M160 220c2-90 39-137 96-137s94 47 96 137c-29-38-61-57-96-57s-67 19-96 57Z" fill="#3e392c"/><path d="M170 137c55-38 112-38 172 0l-13-46H183Z" fill="#4d5a38"/><path d="M174 176c-18 60-13 105 0 139M198 153c-14 71-9 124 3 164M314 153c14 71 9 124-3 164M338 176c18 60 13 105 0 139" fill="none" stroke="#1b1713" stroke-width="12" stroke-linecap="round"/>',
  headcloth: '<path d="M157 218c3-87 45-134 99-134s96 47 99 134c-29-36-62-54-99-54s-70 18-99 54Z" fill="#8b2f2f"/><path d="M166 126c51-53 127-52 179 1-65-15-123-16-179-1Z" fill="#e9b949"/><path d="M315 103c37-35 55-18 44 17-15 17-29 31-45 43Z" fill="#8b2f2f"/>',
  wave: '<path d="M162 224c1-85 40-132 94-132s93 47 94 132c-29-40-60-59-94-59s-65 19-94 59Z" fill="#c99158"/><path d="M169 158c22-24 35-6 55-28 18-20 35 3 55-13 18-14 33-2 58 24" fill="none" stroke="#f0c287" stroke-width="14" stroke-linecap="round"/>',
  bald: '<path d="M177 202c10-68 43-101 79-101s69 33 79 101c-24-20-50-30-79-30s-55 10-79 30Z" fill="#3e281f" opacity=".32"/>',
  locs: '<path d="M161 218c4-86 42-132 95-132s91 46 95 132c-29-34-61-51-95-51s-66 17-95 51Z" fill="#15110f"/><path d="M177 147c-22 84-20 141-5 188M202 118c-17 94-13 164 0 214M310 118c17 94 13 164 0 214M335 147c22 84 20 141 5 188" fill="none" stroke="#15110f" stroke-width="15" stroke-linecap="round"/>',
  curls: '<path d="M162 213c6-83 44-128 94-128s88 45 94 128c-28-32-60-48-94-48s-66 16-94 48Z" fill="#171210"/><g fill="#29201c"><circle cx="188" cy="130" r="22"/><circle cx="226" cy="103" r="23"/><circle cx="269" cy="99" r="24"/><circle cx="310" cy="114" r="23"/><circle cx="333" cy="150" r="20"/></g>',
  sidepart: '<path d="M170 208c6-77 44-116 86-116s80 39 86 116c-27-27-56-41-86-41s-59 14-86 41Z" fill="#2b211d"/><path d="M208 112c34-20 75-19 107 4" fill="none" stroke="#46352d" stroke-width="13" stroke-linecap="round"/>',
};

function svg(p) {
  const glasses = p.glasses ? '<g fill="none" stroke="#151515" stroke-width="8"><rect x="194" y="223" width="54" height="37" rx="15"/><rect x="264" y="223" width="54" height="37" rx="15"/><path d="M248 239h16"/></g>' : '';
  const earrings = p.earrings ? `<g fill="none" stroke="${p.accent}" stroke-width="7"><circle cx="181" cy="266" r="12"/><circle cx="331" cy="266" r="12"/></g>` : '';
  const beard = p.beard ? '<path d="M207 293c12 43 86 43 98 0-11 68-87 73-98 0Z" fill="#1a1512" opacity=".92"/>' : '';
  const runner = p.runner ? `<path d="M221 377h70l-8 42h-54Z" fill="${p.accent}"/><text x="256" y="408" text-anchor="middle" font-family="Arial,sans-serif" font-size="24" font-weight="900" fill="${p.outfit}">KEN</text>` : '';
  const badge = p.badge ? `<path d="M218 377h76l-8 44h-60Z" fill="${p.accent}"/><text x="256" y="407" text-anchor="middle" font-family="Arial,sans-serif" font-size="22" font-weight="900" fill="${p.outfit}">${p.badge}</text>` : '';
  const tie = p.tie ? `<path d="M246 379h20l15 82-25 26-25-26Z" fill="${p.accent}"/>` : '';
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-labelledby="title desc">
  <title id="title">${p.name}</title>
  <desc id="desc">Stylized vector portrait of ${p.name} for the Game Mavelas Who Am I game.</desc>
  <rect width="512" height="512" rx="56" fill="#d7ff3f"/>
  <circle cx="72" cy="76" r="34" fill="#101314" opacity=".08"/><circle cx="447" cy="126" r="58" fill="#101314" opacity=".08"/>
  <path d="M89 512c10-112 68-173 167-173s157 61 167 173Z" fill="${p.outfit}"/>
  <path d="M215 328h82v73c-22 22-60 22-82 0Z" fill="${p.skin}"/>
  ${hair[p.hair]}
  <ellipse cx="256" cy="245" rx="82" ry="111" fill="${p.skin}"/>
  <ellipse cx="176" cy="254" rx="15" ry="25" fill="${p.skin}"/><ellipse cx="336" cy="254" rx="15" ry="25" fill="${p.skin}"/>
  <path d="M205 218c14-9 29-9 43-1M264 217c14-8 29-8 43 1" fill="none" stroke="#241713" stroke-width="8" stroke-linecap="round"/>
  <ellipse cx="226" cy="242" rx="7" ry="9" fill="#171211"/><ellipse cx="286" cy="242" rx="7" ry="9" fill="#171211"/>
  <path d="M254 244c-6 18-8 33-2 40 6 5 13 5 21 1" fill="none" stroke="#4d2b22" stroke-width="6" stroke-linecap="round"/>
  <path d="M221 303c20 19 50 20 71 0" fill="none" stroke="#58251f" stroke-width="8" stroke-linecap="round"/>
  ${beard}${glasses}${earrings}${runner}${badge}${tie}
  <path d="M18 420V92" stroke="#101314" stroke-width="8" stroke-linecap="round" opacity=".12"/>
</svg>\n`;
}

await mkdir(outputDir, { recursive: true });
await Promise.all(portraits.map((portrait) => writeFile(join(outputDir, `${portrait.slug}.svg`), svg(portrait))));
await writeFile(join(outputDir, "manifest.json"), `${JSON.stringify(portraits.map(({ slug, name }) => ({ slug, name, src: `/celebrities/${slug}.svg`, alt: `Stylized portrait of ${name}` })), null, 2)}\n`);
console.log(`Generated ${portraits.length} celebrity SVG portraits in ${outputDir}`);
