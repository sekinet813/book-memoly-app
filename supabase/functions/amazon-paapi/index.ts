// Amazon Product Advertising API proxy via Supabase Edge Functions
// Handles AWS Signature v4 signing and returns simplified book data to the client.
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const encoder = new TextEncoder();

async function sha256(data: string | ArrayBuffer): Promise<string> {
  const encoded = typeof data === "string" ? encoder.encode(data) : data;
  const hashBuffer = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function getSignatureKey(
  key: string,
  dateStamp: string,
  region: string,
  service: string,
) {
  const kDate = await crypto.subtle.importKey(
    "raw",
    encoder.encode("AWS4" + key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const kRegion = await crypto.subtle.sign(
    "HMAC",
    kDate,
    encoder.encode(dateStamp),
  );
  const kRegionKey = await crypto.subtle.importKey(
    "raw",
    kRegion,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const kService = await crypto.subtle.sign(
    "HMAC",
    kRegionKey,
    encoder.encode(region),
  );
  const kServiceKey = await crypto.subtle.importKey(
    "raw",
    kService,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const kSigning = await crypto.subtle.sign(
    "HMAC",
    kServiceKey,
    encoder.encode(service),
  );
  const kServiceSigningKey = await crypto.subtle.importKey(
    "raw",
    kSigning,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const kSigningFinal = await crypto.subtle.sign(
    "HMAC",
    kServiceSigningKey,
    encoder.encode("aws4_request"),
  );
  const kSigningKey = await crypto.subtle.importKey(
    "raw",
    kSigningFinal,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  return kSigningKey;
}

async function hmacHex(key: CryptoKey, data: string): Promise<string> {
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(data),
  );
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function formatAmzDate(date: Date): { amzDate: string; dateStamp: string } {
  const year = date.getUTCFullYear();
  const month = `${date.getUTCMonth() + 1}`.padStart(2, "0");
  const day = `${date.getUTCDate()}`.padStart(2, "0");
  const hours = `${date.getUTCHours()}`.padStart(2, "0");
  const minutes = `${date.getUTCMinutes()}`.padStart(2, "0");
  const seconds = `${date.getUTCSeconds()}`.padStart(2, "0");

  const dateStamp = `${year}${month}${day}`;
  const amzDate = `${dateStamp}T${hours}${minutes}${seconds}Z`;
  return { amzDate, dateStamp };
}

function buildResources() {
  return [
    "Images.Primary.Small",
    "Images.Primary.Medium",
    "Images.Primary.Large",
    "ItemInfo.ByLineInfo",
    "ItemInfo.Classifications",
    "ItemInfo.ContentInfo",
    "ItemInfo.ProductInfo",
    "ItemInfo.Title",
    "Offers.Listings.Price",
    "CustomerReviews.Count",
    "CustomerReviews.StarRating",
    "BrowseNodeInfo.WebsiteSalesRank",
  ];
}

function mapItem(item: Record<string, unknown>) {
  const itemInfo = (item["ItemInfo"] ?? {}) as Record<string, unknown>;
  const byLine = (itemInfo["ByLineInfo"] ?? {}) as Record<string, unknown>;
  const content = (itemInfo["ContentInfo"] ?? {}) as Record<string, unknown>;
  const productInfo = (itemInfo["ProductInfo"] ?? {}) as Record<string, unknown>;
  const classifications = (itemInfo["Classifications"] ?? {}) as Record<string, unknown>;
  const images = (item["Images"] ?? {}) as Record<string, unknown>;
  const offers = (item["Offers"] ?? {}) as Record<string, unknown>;
  const customerReviews = (item["CustomerReviews"] ?? {}) as Record<string, unknown>;
  const browseInfo = (item["BrowseNodeInfo"] ?? {}) as Record<string, unknown>;

  const contributors = (byLine["Contributors"] as Array<Record<string, unknown>> | undefined)
    ?.map((contributor) => contributor?.["Name"] as string | undefined)
    .filter((name): name is string => Boolean(name)) ?? [];

  const imageSet = (images["Primary"] ?? {}) as Record<string, unknown>;
  const listings = (offers["Listings"] as Array<Record<string, unknown>> | undefined) ?? [];
  const price = listings[0]?.Price as Record<string, unknown> | undefined;

  return {
    asin: item["ASIN"] as string | undefined ?? "",
    title: (itemInfo["Title"] as Record<string, unknown> | undefined)?.["DisplayValue"] as
      | string
      | undefined ?? "タイトル不明",
    authors: contributors,
    publisher: (byLine["Manufacturer"] as Record<string, unknown> | undefined)?.["DisplayValue"] as
      | string
      | undefined,
    publicationDate: (content["PublicationDate"] as Record<string, unknown> | undefined)?.["DisplayValue"] as
      | string
      | undefined ?? (productInfo["ReleaseDate"] as Record<string, unknown> | undefined)?.["DisplayValue"] as
        | string
        | undefined,
    pageCount: (content["PagesCount"] as Record<string, unknown> | undefined)?.["DisplayValue"] as
      | number
      | undefined,
    imageUrls: {
      small: (imageSet["Small"] as Record<string, unknown> | undefined)?.["URL"] as string | undefined,
      medium: (imageSet["Medium"] as Record<string, unknown> | undefined)?.["URL"] as string | undefined,
      large: (imageSet["Large"] as Record<string, unknown> | undefined)?.["URL"] as string | undefined,
    },
    averageRating: (customerReviews["StarRating"] as Record<string, unknown> | undefined)?.["AverageRating"] as
      | number
      | undefined,
    isKindle: (classifications["Binding"] as Record<string, unknown> | undefined)?.["DisplayValue"] ===
      "Kindle",
    amazonUrl: item["DetailPageURL"] as string | undefined,
    salesRank: (browseInfo["WebsiteSalesRank"] as Record<string, unknown> | undefined)?.["SalesRank"] as
      | number
      | undefined,
    listPrice: price
      ? {
        amount: price["Amount"] as number | undefined ?? 0,
        currency: price["Currency"] as string | undefined ?? "",
      }
      : undefined,
  };
}

async function buildSignedRequest(
  body: string,
  host: string,
  region: string,
  operation: "SearchItems" | "GetItems",
  accessKey: string,
  secretKey: string,
) {
  const service = "ProductAdvertisingAPI";
  const { amzDate, dateStamp } = formatAmzDate(new Date());
  const canonicalUri = `/paapi5/${operation.toLowerCase()}`;

  const canonicalHeaders =
    `content-encoding:amz-1.0\ncontent-type:application/json; charset=utf-8\n` +
    `host:${host}\n` +
    `x-amz-date:${amzDate}\n` +
    `x-amz-target:com.amazon.paapi5.v1.ProductAdvertisingAPIv1.${operation}\n`;

  const signedHeaders = "content-encoding;content-type;host;x-amz-date;x-amz-target";
  const payloadHash = await sha256(body);
  const canonicalRequest =
    `POST\n${canonicalUri}\n\n${canonicalHeaders}\n${signedHeaders}\n${payloadHash}`;

  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const stringToSign =
    `AWS4-HMAC-SHA256\n${amzDate}\n${credentialScope}\n${await sha256(canonicalRequest)}`;

  const signingKey = await getSignatureKey(secretKey, dateStamp, region, service);
  const signature = await hmacHex(signingKey, stringToSign);

  const authorizationHeader =
    `AWS4-HMAC-SHA256 Credential=${accessKey}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

  const endpoint = `https://${host}${canonicalUri}`;

  const headers = {
    "content-encoding": "amz-1.0",
    "content-type": "application/json; charset=utf-8",
    host,
    "x-amz-date": amzDate,
    "x-amz-target": `com.amazon.paapi5.v1.ProductAdvertisingAPIv1.${operation}`,
    Authorization: authorizationHeader,
  };

  return new Request(endpoint, {
    method: "POST",
    headers,
    body,
  });
}

function errorResponse(message: string, status = 400) {
  return new Response(JSON.stringify({ message }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  const accessKey = Deno.env.get("PAAPI_ACCESS_KEY");
  const secretKey = Deno.env.get("PAAPI_SECRET_KEY");
  const partnerTag = Deno.env.get("PAAPI_PARTNER_TAG");
  const region = Deno.env.get("PAAPI_REGION") ?? "us-east-1";
  const host = Deno.env.get("PAAPI_HOST") ?? "webservices.amazon.co.jp";

  if (!accessKey || !secretKey || !partnerTag) {
    return errorResponse("Missing Amazon PA-API credentials", 500);
  }

  let payload: { query: string; searchType: string; maxResults?: number };
  try {
    payload = await req.json();
  } catch (error) {
    console.error("Failed to parse request body", error);
    return errorResponse("Invalid JSON body", 400);
  }

  const { query, searchType, maxResults = 10 } = payload;
  if (!query || typeof query !== "string") {
    return errorResponse("Query is required", 400);
  }

  const resources = buildResources();
  let operation: "SearchItems" | "GetItems" = "SearchItems";
  let requestBody: Record<string, unknown> = {
    Keywords: query,
    SearchIndex: "Books",
    Resources: resources,
    ItemCount: Math.min(maxResults, 20),
    PartnerTag: partnerTag,
    PartnerType: "Associates",
  };

  if (searchType === "isbn") {
    operation = "GetItems";
    requestBody = {
      ItemIds: [query.replaceAll("-", "")],
      IdType: "ISBN",
      SearchIndex: "Books",
      Resources: resources,
      PartnerTag: partnerTag,
      PartnerType: "Associates",
    };
  }

  const body = JSON.stringify(requestBody);

  try {
    const signedRequest = await buildSignedRequest(
      body,
      host,
      region,
      operation,
      accessKey,
      secretKey,
    );

    const response = await fetch(signedRequest);
    const data = await response.json();

    if (!response.ok) {
      const message = (data?.Errors?.[0]?.Message as string | undefined) ??
        `Amazon PA-API error: ${response.status}`;
      return errorResponse(message, response.status);
    }

    const items = (data.SearchResult?.Items ?? data.ItemsResult?.Items ?? []) as Array<Record<string, unknown>>;
    const mappedItems = items.map(mapItem);

    return new Response(
      JSON.stringify({
        items: mappedItems,
        requestId: data.RequestId ?? data?.SearchResult?.SearchCompletedRequestId,
        searchType,
      }),
      {
        headers: { "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("Amazon PA-API proxy error", error);
    return errorResponse("Failed to complete Amazon PA-API request", 500);
  }
});
