const DB_NAME = "porten_messages";
const DB_VERSION = 1;
const STORE_NAME = "messages";

let dbPromise: Promise<IDBDatabase> | null = null;

function openDB(): Promise<IDBDatabase> {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
    request.onupgradeneeded = (event) => {
      const db = (event.target as IDBOpenDBRequest).result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        const store = db.createObjectStore(STORE_NAME, { keyPath: "localId" });
        store.createIndex("conversationId", "conversationId", { unique: false });
        store.createIndex("id", "id", { unique: false });
      }
    };
  });
  return dbPromise;
}

export interface StoredMessage {
  localId: string;
  id?: number;
  conversationId: number;
  type: string;
  content: string;
  extra?: Record<string, unknown>;
  senderId: string;
  senderName: string;
  senderAvatar: string;
  timestamp: string;
  isMe: boolean;
  status?: string;
  progress?: number;
  duration?: number;
}

export async function saveMessage(message: StoredMessage): Promise<void> {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readwrite");
    const store = tx.objectStore(STORE_NAME);
    const request = store.put(message);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve();
  });
}

export async function saveMessages(messages: StoredMessage[]): Promise<void> {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readwrite");
    const store = tx.objectStore(STORE_NAME);
    messages.forEach((m) => store.put(m));
    tx.onerror = () => reject(tx.error);
    tx.oncomplete = () => resolve();
  });
}

export async function getMessagesByConversation(
  conversationId: number
): Promise<StoredMessage[]> {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readonly");
    const store = tx.objectStore(STORE_NAME);
    const index = store.index("conversationId");
    const request = index.getAll(conversationId);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const list = (request.result as StoredMessage[]) || [];
      list.sort(
        (a, b) =>
          new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()
      );
      resolve(list);
    };
  });
}

export async function deleteMessage(localId: string): Promise<void> {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readwrite");
    const store = tx.objectStore(STORE_NAME);
    const request = store.delete(localId);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve();
  });
}

export async function clearConversation(conversationId: number): Promise<void> {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readwrite");
    const store = tx.objectStore(STORE_NAME);
    const index = store.index("conversationId");
    const request = index.openCursor(conversationId);
    request.onerror = () => reject(request.error);
    request.onsuccess = (event) => {
      const cursor = (event.target as IDBRequest).result as IDBCursorWithValue;
      if (cursor) {
        cursor.delete();
        cursor.continue();
      }
    };
    tx.oncomplete = () => resolve();
  });
}

export async function getLatestServerId(
  conversationId: number
): Promise<number | undefined> {
  const list = await getMessagesByConversation(conversationId);
  const serverIds = list
    .map((m) => m.id)
    .filter((id): id is number => typeof id === "number");
  return serverIds.length ? Math.max(...serverIds) : undefined;
}

export async function deleteMessagesByIdExceptLocalId(
  id: number,
  keepLocalId: string
): Promise<void> {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readwrite");
    const store = tx.objectStore(STORE_NAME);
    const index = store.index("id");
    const request = index.openCursor(id);
    request.onerror = () => reject(request.error);
    request.onsuccess = (event) => {
      const cursor = (event.target as IDBRequest).result as IDBCursorWithValue;
      if (cursor) {
        const msg = cursor.value as StoredMessage;
        if (msg.localId !== keepLocalId) {
          cursor.delete();
        }
        cursor.continue();
      }
    };
    tx.oncomplete = () => resolve();
  });
}
