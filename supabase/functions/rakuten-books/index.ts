function toNumber(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  return undefined;
}

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import { isLikelyAuthorQuery, normalizeQuery } from "./utils.ts";

const APPLICATION_ID = Deno.env.get("RAKUTEN_APPLICATION_ID");
const MAX_HITS = 30;
const DEFAULT_HITS = 20;
const MAX_PAGE = 100;
const DEFAULT_PAGE = 1;
const DEFAULT_SORT = "standard";

type SearchMode = "isbn" | "author" | "keyword" | "title-fallback";

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

function errorResponse(message: string, status = 400, detail?: unknown) {
  console.error({ message, detail });
  return jsonResponse({ error: message }, status);
}

function mapItem(rawItem: Record<string, unknown>) {
  return {
    title: (rawItem["title"] as string | undefined) ?? "タイトル不明",
    author: rawItem["author"] as string | undefined,
    publisherName: rawItem["publisherName"] as string | undefined,
    salesDate: rawItem["salesDate"] as string | undefined,
    isbn: rawItem["isbn"] as string | undefined,
    itemCaption: rawItem["itemCaption"] as string | undefined,
    smallImageUrl: rawItem["smallImageUrl"] as string | undefined,
    mediumImageUrl: rawItem["mediumImageUrl"] as string | undefined,
    largeImageUrl: rawItem["largeImageUrl"] as string | undefined,
    itemUrl: rawItem["itemUrl"] as string | undefined,
  };
}

async function callRakutenApi(params: URLSearchParams) {
  const url = `https://app.rakuten.co.jp/services/api/BooksBook/Search/20170404?${params.toString()}`;

  const response = await fetch(url);
  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(
      `Rakuten Books API returned status ${response.status}: ${errorBody}`,
    );
  }

  const data = (await response.json()) as Record<string, unknown>;
  const rawItems = Array.isArray(data["Items"]) ? data["Items"] : [];

  const mappedItems = rawItems
    .map((item) => (item && typeof item === "object" && "Item" in item
      ? (item as Record<string, unknown>)["Item"]
      : item) as Record<string, unknown> | undefined)
    .filter((item): item is Record<string, unknown> => Boolean(item))
    .map(mapItem);

  return {
    data,
    mappedItems,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  if (!APPLICATION_ID) {
    return errorResponse("Missing Rakuten API credentials", 500);
  }

  let payload: Record<string, unknown>;

  try {
    payload = await req.json();
  } catch (error) {
    return errorResponse("Invalid JSON payload", 400, error);
  }

  const query = typeof payload.query === "string" ? payload.query.trim() : "";
  const searchType = payload.searchType === "isbn" ? "isbn" : "keywords";
  const hitsRaw = Number(payload.hits ?? DEFAULT_HITS);
  const hits = Number.isFinite(hitsRaw)
    ? Math.min(Math.max(Math.trunc(hitsRaw), 1), MAX_HITS)
    : DEFAULT_HITS;
  const pageRaw = Number(payload.page ?? DEFAULT_PAGE);
  const page = Number.isFinite(pageRaw)
    ? Math.min(Math.max(Math.trunc(pageRaw), 1), MAX_PAGE)
    : DEFAULT_PAGE;

  if (!query) {
    return errorResponse("Query is required", 400);
  }

  const baseParams = new URLSearchParams({
    applicationId: APPLICATION_ID,
    format: "json",
    formatVersion: "2",
    hits: hits.toString(),
    page: page.toString(),
  });

  const isIsbnSearch = searchType === "isbn";
  const normalizedQuery = normalizeQuery(query, { isbn: isIsbnSearch });
  const authorIntent = !isIsbnSearch && isLikelyAuthorQuery(normalizedQuery);

  if (searchType === "isbn") {
    baseParams.set("isbn", normalizedQuery);
    try {
      const { data, mappedItems } = await callRakutenApi(baseParams);
      const count = toNumber(data["count"]) ?? mappedItems.length;
      const hitsFromApi = toNumber(data["hits"]);
      const pageFromApi = toNumber(data["page"]);
      const pageCount = toNumber(data["pageCount"]);
      return jsonResponse({
        Items: mappedItems,
        count,
        hits: hitsFromApi ?? hits,
        page: pageFromApi ?? page,
        pageCount,
        searchMode: "isbn" as SearchMode,
      });
    } catch (error) {
      return errorResponse("Failed to fetch from Rakuten Books API", 500, error);
    }
  }

  if (authorIntent) {
    const authorParams = new URLSearchParams(baseParams);
    authorParams.set("author", normalizedQuery);
    authorParams.set("sort", DEFAULT_SORT);
    try {
      const { data, mappedItems } = await callRakutenApi(authorParams);
      if (mappedItems.length > 0) {
        const count = toNumber(data["count"]) ?? mappedItems.length;
        const hitsFromApi = toNumber(data["hits"]);
        const pageFromApi = toNumber(data["page"]);
        const pageCount = toNumber(data["pageCount"]);
        return jsonResponse({
          Items: mappedItems,
          count,
          hits: hitsFromApi ?? hits,
          page: pageFromApi ?? page,
          pageCount,
          searchMode: "author" as SearchMode,
        });
      }
    } catch (error) {
      console.warn("Author search failed, falling back to keyword search", error);
    }
  }

  const keywordParams = new URLSearchParams(baseParams);
  keywordParams.set("keyword", normalizedQuery);
  keywordParams.set("orFlag", "1");
  keywordParams.set("sort", DEFAULT_SORT);

  try {
    let searchMode: SearchMode = "keyword";
    let { data, mappedItems } = await callRakutenApi(keywordParams);

    if (mappedItems.length === 0) {
      const titleParams = new URLSearchParams(baseParams);
      titleParams.set("title", normalizedQuery);
      ({ data, mappedItems } = await callRakutenApi(titleParams));
      searchMode = "title-fallback";
    }

    const count = toNumber(data["count"]) ?? mappedItems.length;
    const hitsFromApi = toNumber(data["hits"]);
    const pageFromApi = toNumber(data["page"]);
    const pageCount = toNumber(data["pageCount"]);
    return jsonResponse({
      Items: mappedItems,
      count,
      hits: hitsFromApi ?? hits,
      page: pageFromApi ?? page,
      pageCount,
      searchMode,
    });
  } catch (error) {
    return errorResponse("Failed to fetch from Rakuten Books API", 500, error);
  }
});
