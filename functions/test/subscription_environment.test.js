const { test } = require("node:test");
const assert = require("node:assert/strict");

function resolveSubscriptionEnvironment(data, usedSandbox) {
  const appleEnv =
    data && typeof data.environment === "string"
      ? data.environment.toLowerCase()
      : "";
  if (appleEnv === "sandbox") return "sandbox";
  if (appleEnv === "production") return "production";
  return usedSandbox ? "sandbox" : "production";
}

test("Apple Sandbox environment maps to sandbox", () => {
  assert.equal(
    resolveSubscriptionEnvironment({ environment: "Sandbox" }, false),
    "sandbox"
  );
});

test("Apple Production environment maps to production", () => {
  assert.equal(
    resolveSubscriptionEnvironment({ environment: "Production" }, false),
    "production"
  );
});

test("missing Apple environment with usedSandbox infers sandbox", () => {
  assert.equal(resolveSubscriptionEnvironment({}, true), "sandbox");
});

test("missing Apple environment without usedSandbox infers production", () => {
  assert.equal(resolveSubscriptionEnvironment({}, false), "production");
});

test("21007 sandbox retry still maps sandbox when Apple says Sandbox", () => {
  assert.equal(
    resolveSubscriptionEnvironment({ environment: "Sandbox" }, true),
    "sandbox"
  );
});
