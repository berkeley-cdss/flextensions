// Polls /sync_status until the sync identified by `prefix` ("roster" or
// "assignments") completes. Resolves when `${prefix}_synced_at` advances past
// its value in `statusBefore` (the /sync_status payload fetched before the
// sync was kicked off). Rejects with the recorded error message as soon as a
// new `${prefix}_sync_failed_at` appears, so a failed background job surfaces
// immediately instead of as a timeout.
export async function pollUntilDone(courseId, prefix, statusBefore, intervalMs = 1000, timeoutMs = 60000) {
  const syncedKey = `${prefix}_synced_at`;
  const failedKey = `${prefix}_sync_failed_at`;
  const beforeTs = statusBefore[syncedKey];
  const beforeFailedAt = statusBefore[failedKey];
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    await new Promise(resolve => setTimeout(resolve, intervalMs));
    const r = await fetch(`/courses/${courseId}/sync_status`);
    if (!r.ok) throw new Error(`Sync status check failed. ${r.status}`);
    const status = await r.json();
    if (status[syncedKey] && status[syncedKey] !== beforeTs) return;
    if (status[failedKey] && status[failedKey] !== beforeFailedAt) {
      throw new Error(status[`${prefix}_sync_error`] || "Sync failed.");
    }
  }
  throw new Error("Sync timed out. Please refresh the page.");
}
