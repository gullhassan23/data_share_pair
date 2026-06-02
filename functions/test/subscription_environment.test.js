const { test } = require("node:test");
const assert = require("node:assert/strict");

function resolveSubscriptionEnvironment(data, usedSandbox, { isFallback = false } = {}) {
  if (isFallback) return "sandbox";
  const appleEnv =
    data && typeof data.environment === "string"
      ? data.environment.toLowerCase()
      : "";
  const isSandbox = usedSandbox || appleEnv === "sandbox";
  return isSandbox ? "sandbox" : "production";
}

test("fallback verification is always sandbox", () => {
  assert.equal(
    resolveSubscriptionEnvironment({}, false, { isFallback: true }),
    "sandbox"
  );
});

test("Apple Sandbox environment maps to sandbox", () => {
  assert.equal(
    resolveSubscriptionEnvironment({ environment: "Sandbox" }, false),
    "sandbox"
  );
});

test("status 21007 retry sets usedSandbox to production path", () => {
  assert.equal(resolveSubscriptionEnvironment({ environment: "Production" }, true), "sandbox");
});

test("production receipt maps to production", () => {
  assert.equal(
    resolveSubscriptionEnvironment({ environment: "Production" }, false),
    "production"
  );
});
