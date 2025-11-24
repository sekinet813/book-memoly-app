import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { isLikelyAuthorQuery, normalizeQuery } from "./utils.ts";

Deno.test("normalizeQuery trims whitespace and normalizes spaces", () => {
  const input = "  太宰\u3000治   走れ  メロス  ";
  const result = normalizeQuery(input);
  assertEquals(result, "太宰 治 走れ メロス");
});

Deno.test("normalizeQuery removes hyphen when ISBN option is set", () => {
  const input = "978-4-10-101013-7";
  const result = normalizeQuery(input, { isbn: true });
  assertEquals(result, "9784101010137");
});

Deno.test("isLikelyAuthorQuery detects Japanese author names", () => {
  assertEquals(isLikelyAuthorQuery("村上春樹"), true);
  assertEquals(isLikelyAuthorQuery(" 太宰 治 "), true);
});

Deno.test("isLikelyAuthorQuery rejects numeric or mixed queries", () => {
  assertEquals(isLikelyAuthorQuery("1Q84"), false);
  assertEquals(isLikelyAuthorQuery("JavaScript 入門"), false);
});

