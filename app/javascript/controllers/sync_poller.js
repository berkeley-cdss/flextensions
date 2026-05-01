export async function pollUntilDone(courseId, key, beforeTs, intervalMs = 1000, timeoutMs = 60000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    await new Promise(resolve => setTimeout(resolve, intervalMs));
    const r = await fetch(`/courses/${courseId}/sync_status`);
    if (!r.ok) throw new Error(`Sync status check failed. ${r.status}`);
    const status = await r.json();
    if (status[key] && status[key] !== beforeTs) return;
  }
  throw new Error("Sync timed out. Please refresh the page.");
}
