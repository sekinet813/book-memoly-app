type NormalizeOptions = {
  isbn?: boolean;
};

const AUTHOR_CHAR_REGEX =
  /^[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{L}・\s]+$/u;

export function normalizeQuery(raw: string, options: NormalizeOptions = {}) {
  const { isbn = false } = options;

  let result = raw.trim();
  result = result.replace(/\u3000/g, " "); // 全角スペースを半角へ
  result = result.replace(/\s+/g, " "); // 連続スペースを1つに圧縮

  if (isbn) {
    result = result.replace(/-/g, "");
  }

  return result;
}

export function isLikelyAuthorQuery(query: string) {
  const trimmed = query.trim();
  if (trimmed.length < 2) {
    return false;
  }

  if (/\d/.test(trimmed)) {
    return false;
  }

  const containsAsciiLetters = /[A-Za-z]/.test(trimmed);
  const containsCjkLetters =
    /[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]/u.test(trimmed);
  if (containsAsciiLetters && containsCjkLetters) {
    return false;
  }

  return AUTHOR_CHAR_REGEX.test(trimmed);
}

