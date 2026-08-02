const DB_NAME = "porten_media_cache";
const DB_VERSION = 1;
const STORE_NAME = "media";

interface CachedMedia {
  key: string;
  blob: Blob;
  contentType: string;
  size: number;
  createdAt: number;
}

let dbPromise: Promise<IDBDatabase> | null = null;

function normalizeKey(url: string): string {
  if (/^(blob:|data:)/i.test(url)) return url;
  if (/^https?:/i.test(url)) return url;
  const base = (import.meta.env.VITE_API_BASE_URL as string) || "";
  const origin = base.startsWith("http")
    ? new URL(base).origin
    : typeof window !== "undefined"
      ? window.location.origin
      : "";
  return `${origin}${url.startsWith("/") ? url : `/${url}`}`;
}

function openDB(): Promise<IDBDatabase> {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
    request.onupgradeneeded = (event) => {
      const db = (event.target as IDBOpenDBRequest).result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: "key" });
      }
    };
  });
  return dbPromise;
}

export async function saveMediaBlob(
  url: string,
  blob: Blob
): Promise<void> {
  const db = await openDB();
  const key = normalizeKey(url);
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readwrite");
    const store = tx.objectStore(STORE_NAME);
    const request = store.put({
      key,
      blob,
      contentType: blob.type || "application/octet-stream",
      size: blob.size,
      createdAt: Date.now(),
    } satisfies CachedMedia);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve();
  });
}

export async function getMediaBlob(url: string): Promise<Blob | undefined> {
  const db = await openDB();
  const key = normalizeKey(url);
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readonly");
    const store = tx.objectStore(STORE_NAME);
    const request = store.get(key);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const result = request.result as CachedMedia | undefined;
      resolve(result?.blob);
    };
  });
}

export async function deleteMediaBlob(url: string): Promise<void> {
  const db = await openDB();
  const key = normalizeKey(url);
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readwrite");
    const store = tx.objectStore(STORE_NAME);
    const request = store.delete(key);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve();
  });
}

const objectUrlCache = new Map<string, string>();

export async function getCachedMediaUrl(
  url: string | undefined
): Promise<string | undefined> {
  if (!url) return url;
  if (/^(blob:|data:)/i.test(url)) return url;
  const key = normalizeKey(url);
  if (objectUrlCache.has(key)) return objectUrlCache.get(key);
  const blob = await getMediaBlob(url);
  if (!blob) return url;
  const objectUrl = URL.createObjectURL(blob);
  objectUrlCache.set(key, objectUrl);
  return objectUrl;
}
