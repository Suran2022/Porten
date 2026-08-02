const groupMemberCounts: Record<string, number> = {
  g1: 12,
  g2: 8,
  g3: 156,
  g4: 24,
};

export function getGroupMemberCount(chatId: string): number {
  return groupMemberCounts[chatId] || 1;
}
