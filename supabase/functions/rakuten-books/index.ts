import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const APPLICATION_ID = Deno.env.get("RAKUTEN_APPLICATION_ID");

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
  const hitsRaw = Number(payload.hits ?? 20);
  const hits = Number.isFinite(hitsRaw)
    ? Math.min(Math.max(Math.trunc(hitsRaw), 1), 30)
    : 20;

  if (!query) {
    return errorResponse("Query is required", 400);
  }

  const params = new URLSearchParams({
    applicationId: APPLICATION_ID,
    format: "json",
    formatVersion: "2",
    hits: hits.toString(),
  });

  if (searchType === "isbn") {
    params.set("isbn", query.replaceAll("-", ""));
  } else {
    params.set("title", query);
  }

  const url = `https://app.rakuten.co.jp/services/api/BooksBook/Search/20170404?${params.toString()}`;

  try {
    const response = await fetch(url);

    if (!response.ok) {
      const errorBody = await response.text();
      return errorResponse(
        `Rakuten Books API returned status ${response.status}`,
        response.status,
        errorBody,
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

    return jsonResponse({
      Items: mappedItems,
      count: (typeof data["count"] === "number" ? data["count"] : mappedItems.length),
      hits: data["hits"],
      page: data["page"],
    });
  } catch (error) {
    return errorResponse("Failed to fetch from Rakuten Books API", 500, error);
  }
});
