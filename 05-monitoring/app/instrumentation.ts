export async function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    const appInsights = await import("applicationinsights");
    appInsights
      .default
      .setup()
      .setAutoCollectRequests(true)
      .setAutoCollectExceptions(true)
      .setAutoCollectPerformance(true)
      .start();
  }
}
