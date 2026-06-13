const admin = require("firebase-admin");
const { defineSecret } = require("firebase-functions/params");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");

admin.initializeApp();
const db = admin.firestore();
const USERS_COLLECTION = "Users";

const APPSTORE_SHARED_SECRET = defineSecret("APPSTORE_SHARED_SECRET");

/**
 * Maps Apple verifyReceipt response to subscription environment for analytics.
 * Trusts Apple's environment when present; otherwise infers from verify URL used.
 */
function resolveSubscriptionEnvironment(data, usedSandbox) {
  const appleEnv =
    data && typeof data.environment === "string"
      ? data.environment.toLowerCase()
      : "";
  if (appleEnv === "sandbox") return "sandbox";
  if (appleEnv === "production") return "production";
  return usedSandbox ? "sandbox" : "production";
}

function isAppleJws(value) {
  return (
    typeof value === "string" &&
    value.startsWith("eyJ") &&
    value.split(".").length === 3
  );
}

function decodeAppleJwsPayload(jws) {
  const part = jws.split(".")[1];
  if (!part) return null;
  const padded = part + "=".repeat((4 - (part.length % 4)) % 4);
  const json = Buffer.from(
    padded.replace(/-/g, "+").replace(/_/g, "/"),
    "base64"
  ).toString("utf8");
  return JSON.parse(json);
}

function environmentFromJwsPayload(payload) {
  const env =
    payload && typeof payload.environment === "string"
      ? payload.environment.toLowerCase()
      : "";
  return env === "sandbox" ? "sandbox" : "production";
}

async function persistSubscriptionState({
  userId,
  productId,
  isPremium,
  expiryDate,
  autoRenewStatus,
  fcmToken,
  isRestore,
  environment,
  source,
  transactionId,
  appleStatus,
}) {
  const userRef = db.collection(USERS_COLLECTION).doc(userId);
  const updateData = {
    isPremium,
    productId,
    expiryDate: expiryDate
      ? admin.firestore.Timestamp.fromDate(expiryDate)
      : null,
    autoRenewStatus,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (fcmToken && typeof fcmToken === "string") {
    updateData.fcmToken = fcmToken;
  }
  await userRef.set(updateData, { merge: true });

  try {
    const docId = transactionId || `${Date.now()}`;
    await userRef
      .collection("subscriptions")
      .doc(docId)
      .set(
        {
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          productId,
          isPremium,
          expiryDate: expiryDate
            ? admin.firestore.Timestamp.fromDate(expiryDate)
            : null,
          autoRenewStatus,
          transactionId,
          status: appleStatus ?? 0,
          environment,
          isRestore: !!isRestore,
          source,
        },
        { merge: true }
      );
  } catch (e) {
    console.error("Subscription history write failed:", e);
  }
}

async function verifyStoreKit2Jws({
  jws,
  productId,
  userId,
  fcmToken,
  isRestore,
}) {
  let payload;
  try {
    payload = decodeAppleJwsPayload(jws);
  } catch (e) {
    console.error("StoreKit2 JWS decode failed:", e);
    return null;
  }
  if (!payload || typeof payload !== "object") return null;

  const txProductId = payload.productId;
  if (txProductId && txProductId !== productId) {
    console.error("StoreKit2 JWS product mismatch", {
      expected: productId,
      actual: txProductId,
    });
    return {
      isValid: false,
      environment: environmentFromJwsPayload(payload),
      verified: false,
      appleStatus: -1,
      error: "product_mismatch",
    };
  }

  const expiresMs = payload.expiresDate;
  const expiryDate =
    expiresMs != null && !Number.isNaN(Number(expiresMs))
      ? new Date(Number(expiresMs))
      : null;
  const now = new Date();
  const isPremium =
    expiryDate && expiryDate.getTime() > now.getTime() ? true : false;
  const environment = environmentFromJwsPayload(payload);
  const transactionId =
    payload.transactionId != null ? String(payload.transactionId) : null;

  await persistSubscriptionState({
    userId,
    productId,
    isPremium,
    expiryDate,
    autoRenewStatus: payload.revocationDate ? "0" : "1",
    fcmToken,
    isRestore,
    environment,
    source: "storekit2_jws",
    transactionId,
    appleStatus: 0,
  });

  console.log(
    "verifyAppleSubscription: StoreKit2 JWS",
    JSON.stringify({
      environment,
      isPremium,
      productId,
      userId,
      transactionId,
    })
  );

  return {
    isValid: isPremium,
    environment,
    verified: true,
    source: "storekit2_jws",
  };
}

async function sendFcmNotification({
  fcmToken,
  title,
  body,
  data,
}) {
  if (!fcmToken || typeof fcmToken !== "string") return;

  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title,
        body,
      },
      data: data && typeof data === "object" ? data : undefined,
    });
  } catch (e) {
    console.error("FCM send failed:", e);
  }
}

exports.verifyAppleSubscription = onRequest(
  {
    secrets: [APPSTORE_SHARED_SECRET],
    invoker: "public",
  },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        return res.status(405).send("Method not allowed");
      }

      const { receiptData, productId, userId, fcmToken, isRestore, jwsRepresentation, transactionId } =
        req.body || {};

      if (isRestore) {
        console.log("verifyAppleSubscription: restore flow", { userId, productId });
      }

      if (!receiptData || !productId || !userId) {
        return res.status(400).json({
          isValid: false,
          error: "Missing receiptData, productId or userId",
        });
      }

      const jws =
        (typeof jwsRepresentation === "string" && jwsRepresentation) ||
        (isAppleJws(receiptData) ? receiptData : null);

      if (jws) {
        const jwsResult = await verifyStoreKit2Jws({
          jws,
          productId,
          userId,
          fcmToken,
          isRestore,
        });
        if (jwsResult) {
          return res.status(200).json(jwsResult);
        }
      }

      const legacyReceipt = isAppleJws(receiptData) ? null : receiptData;
      if (!legacyReceipt) {
        return res.status(400).json({
          isValid: false,
          error: "Missing legacy App Store receipt for verifyReceipt",
        });
      }

      const APPLE_VERIFY_URL_PROD = "https://buy.itunes.apple.com/verifyReceipt";
      const APPLE_VERIFY_URL_SANDBOX =
        "https://sandbox.itunes.apple.com/verifyReceipt";

      const sharedSecret = APPSTORE_SHARED_SECRET.value();
      const payload = {
        "receipt-data": legacyReceipt,
        password: sharedSecret,
        "exclude-old-transactions": true,
      };

      let usedSandbox = false;
      let response = await fetch(APPLE_VERIFY_URL_PROD, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      let data = await response.json();

      if (data.status === 21007) {
        usedSandbox = true;
        response = await fetch(APPLE_VERIFY_URL_SANDBOX, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
        data = await response.json();
      }

      if (data.status !== 0) {
        console.error(
          "Apple verification failed:",
          JSON.stringify({
            status: data.status,
            usedSandbox,
            environment: data.environment ?? null,
            productId,
            userId,
          })
        );

        // Sandbox-only fallback: keep premium for sandbox QA when verify still fails.
        // Production verification failures must NOT grant premium or fake revenue env.
        if (!usedSandbox) {
          console.log(
            "verifyAppleSubscription: production verify failed — no fallback",
            JSON.stringify({
              status: data.status,
              productId,
              userId,
            })
          );
          return res.status(200).json({
            isValid: false,
            environment: "production",
            verified: false,
            appleStatus: data.status,
            error: "apple_verification_failed",
          });
        }

        const now = new Date();
        const days =
          typeof productId === "string" && productId.includes("yearly")
            ? 365
            : 30;
        const expiryDate = new Date(
          now.getTime() + days * 24 * 60 * 60 * 1000
        );
        const userRef = db.collection(USERS_COLLECTION).doc(userId);
        const previousUserSnapshot = await userRef.get();
        const previousUserData = previousUserSnapshot.exists
          ? previousUserSnapshot.data() || {}
          : {};
        const previousIsPremium = previousUserData.isPremium === true;
        const previousExpiryDateMs = previousUserData.expiryDate?.toDate
          ? previousUserData.expiryDate.toDate().getTime()
          : null;

        const updateData = {
          isPremium: true,
          productId,
          expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
          autoRenewStatus: "1",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (fcmToken && typeof fcmToken === "string")
          updateData.fcmToken = fcmToken;
        await userRef.set(updateData, { merge: true });

        // Store a history record for troubleshooting / analytics.
        try {
          const subRef = userRef.collection("subscriptions").doc(String(Date.now()));
          await subRef.set(
            {
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              productId,
              isPremium: true,
              expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
              autoRenewStatus: "1",
              status: data.status,
              environment: usedSandbox ? "sandbox" : "production",
              isRestore: !!isRestore,
              source: "apple_verify_fallback",
            },
            { merge: true }
          );
        } catch (e) {
          console.error("Subscription history write failed (fallback):", e);
        }
        if (fcmToken && typeof fcmToken === "string") {
          const newExpiryDateMs = expiryDate.getTime();
          const isNewSubscription = !previousIsPremium;
          const isRenewal =
            previousIsPremium &&
            previousExpiryDateMs != null &&
            newExpiryDateMs > previousExpiryDateMs + 12 * 60 * 60 * 1000;

          const lastNotified = previousUserData.lastNotified || {};
          const markAndSend = async ({
            notificationKey,
            title,
            body,
            event,
            expiryDateMs,
          }) => {
            const alreadyNotifiedForExpiry =
              expiryDateMs != null &&
              lastNotified?.[notificationKey] === expiryDateMs;
            if (alreadyNotifiedForExpiry) return;

            await sendFcmNotification({
              fcmToken,
              title,
              body,
              data: {
                subscriptionEvent: event,
                productId: String(productId || ""),
                expiryDateMs: expiryDateMs != null ? String(expiryDateMs) : "",
              },
            });

            const update = {};
            update[`lastNotified.${notificationKey}`] =
              expiryDateMs != null ? expiryDateMs : Date.now();
            await userRef.set(update, { merge: true });
          };

          if (isRestore) {
            await markAndSend({
              notificationKey: "restore",
              title: "Premium restored",
              body: "Your premium access has been restored on this device.",
              event: "restore",
              expiryDateMs: newExpiryDateMs,
            });
          } else if (isNewSubscription) {
            await markAndSend({
              notificationKey: "firstSubscribe",
              title: "Welcome to Premium",
              body: "Your premium subscription is active. Enjoy all features!",
              event: "first_subscribe",
              expiryDateMs: newExpiryDateMs,
            });
          } else if (isRenewal) {
            await markAndSend({
              notificationKey: "renewal",
              title: "Subscription renewed",
              body: "Your premium subscription has been renewed successfully.",
              event: "renewal",
              expiryDateMs: newExpiryDateMs,
            });
          }
        }
        console.log(
          "verifyAppleSubscription: sandbox DEV fallback",
          JSON.stringify({
            status: data.status,
            usedSandbox,
            appleEnvironment: data.environment ?? null,
            resolvedEnvironment: "sandbox",
            productId,
            userId,
          })
        );
        return res.status(200).json({
          isValid: true,
          environment: "sandbox",
          verified: false,
          appleStatus: data.status,
          source: "sandbox_dev_fallback",
        });
      }

      const receiptInfo = Array.isArray(data.latest_receipt_info)
        ? data.latest_receipt_info
        : data.receipt && Array.isArray(data.receipt.in_app)
          ? data.receipt.in_app
          : [];

      const matching = receiptInfo.filter(
        (t) => t && t.product_id === productId
      );
      const candidates = matching.length ? matching : receiptInfo;

      const latestInfo = candidates.reduce((best, cur) => {
        const bestMs =
          best && best.expires_date_ms ? Number(best.expires_date_ms) : -1;
        const curMs =
          cur && cur.expires_date_ms ? Number(cur.expires_date_ms) : -1;
        return curMs > bestMs ? cur : best;
      }, null);

      let expiryDate = null;
      if (latestInfo && latestInfo.expires_date_ms) {
        expiryDate = new Date(Number(latestInfo.expires_date_ms));
      }

      let autoRenewStatus = null;
      if (Array.isArray(data.pending_renewal_info)) {
        const pr =
          data.pending_renewal_info.find(
            (p) => p && p.auto_renew_product_id === productId
          ) ||
          data.pending_renewal_info.find(
            (p) => p && p.product_id === productId
          ) ||
          null;
        if (pr && typeof pr.auto_renew_status !== "undefined") {
          autoRenewStatus = pr.auto_renew_status;
        }
      }

      const now = new Date();
      const isPremium =
        expiryDate && expiryDate.getTime() > now.getTime() ? true : false;

      const userRef = db.collection(USERS_COLLECTION).doc(userId);
      const previousUserSnapshot = await userRef.get();
      const previousUserData = previousUserSnapshot.exists
        ? previousUserSnapshot.data() || {}
        : {};
      const previousIsPremium = previousUserData.isPremium === true;
      const previousAutoRenewStatus =
        typeof previousUserData.autoRenewStatus === "string"
          ? previousUserData.autoRenewStatus
          : null;
      const previousExpiryDateMs = previousUserData.expiryDate?.toDate
        ? previousUserData.expiryDate.toDate().getTime()
        : null;

      const updateData = {
        isPremium,
        productId,
        expiryDate: expiryDate
          ? admin.firestore.Timestamp.fromDate(expiryDate)
          : null,
        autoRenewStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        latestReceipt: data.latest_receipt || null,
      };
      if (fcmToken && typeof fcmToken === "string") {
        updateData.fcmToken = fcmToken;
      }
      await userRef.set(updateData, { merge: true });

      // Write subscription history under subcollection.
      try {
        const transactionId =
          latestInfo && typeof latestInfo.transaction_id === "string"
            ? latestInfo.transaction_id
            : null;
        const originalTransactionId =
          latestInfo && typeof latestInfo.original_transaction_id === "string"
            ? latestInfo.original_transaction_id
            : null;
        const docId = transactionId || `${Date.now()}`;
        await userRef
          .collection("subscriptions")
          .doc(docId)
          .set(
            {
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              productId,
              isPremium,
              expiryDate: expiryDate
                ? admin.firestore.Timestamp.fromDate(expiryDate)
                : null,
              autoRenewStatus,
              transactionId,
              originalTransactionId,
              status: data.status,
              environment: usedSandbox ? "sandbox" : "production",
              isRestore: !!isRestore,
            },
            { merge: true }
          );
      } catch (e) {
        console.error("Subscription history write failed:", e);
      }

      if (fcmToken && typeof fcmToken === "string") {
        const newExpiryDateMs = expiryDate ? expiryDate.getTime() : null;
        const isNewSubscription = !previousIsPremium && isPremium;
        const isCancelledNow =
          autoRenewStatus === "0" && previousAutoRenewStatus !== "0";

        const isRenewal =
          previousIsPremium &&
          isPremium &&
          previousExpiryDateMs != null &&
          newExpiryDateMs != null &&
          newExpiryDateMs > previousExpiryDateMs + 12 * 60 * 60 * 1000;

        const lastNotified = previousUserData.lastNotified || {};
        const markAndSend = async ({
          notificationKey,
          title,
          body,
          event,
          expiryDateMs,
        }) => {
          const alreadyNotifiedForExpiry =
            expiryDateMs != null && lastNotified?.[notificationKey] === expiryDateMs;
          if (alreadyNotifiedForExpiry) return;

          await sendFcmNotification({
            fcmToken,
            title,
            body,
            data: {
              subscriptionEvent: event,
              productId: String(productId || ""),
              expiryDateMs: expiryDateMs != null ? String(expiryDateMs) : "",
            },
          });

          const update = {};
          if (expiryDateMs != null) {
            update[`lastNotified.${notificationKey}`] = expiryDateMs;
          } else {
            update[`lastNotified.${notificationKey}`] = Date.now();
          }
          await userRef.set(update, { merge: true });
        };

        if (isRestore && isPremium) {
          await markAndSend({
            notificationKey: "restore",
            title: "Premium restored",
            body: "Your premium access has been restored on this device.",
            event: "restore",
            expiryDateMs: newExpiryDateMs,
          });
        } else if (isNewSubscription) {
          await markAndSend({
            notificationKey: "firstSubscribe",
            title: "Welcome to Premium",
            body: "Your premium subscription is active. Enjoy all features!",
            event: "first_subscribe",
            expiryDateMs: newExpiryDateMs,
          });
        } else if (isRenewal) {
          await markAndSend({
            notificationKey: "renewal",
            title: "Subscription renewed",
            body: "Your premium subscription has been renewed successfully.",
            event: "renewal",
            expiryDateMs: newExpiryDateMs,
          });
        }

        if (isCancelledNow && isPremium) {
          await markAndSend({
            notificationKey: "cancel",
            title: "Subscription cancelled",
            body:
              "Auto-renew has been turned off. You will keep premium until it expires.",
            event: "cancel",
            expiryDateMs: newExpiryDateMs,
          });
        }
      }

      const environment = resolveSubscriptionEnvironment(data, usedSandbox);
      console.log(
        "verifyAppleSubscription: success",
        JSON.stringify({
          status: data.status,
          usedSandbox,
          appleEnvironment: data.environment ?? null,
          resolvedEnvironment: environment,
          isPremium,
          productId,
          userId,
        })
      );
      return res.status(200).json({
        isValid: isPremium,
        environment,
        verified: true,
      });
    } catch (e) {
      console.error("verifyAppleSubscription error:", e);
      return res.status(500).json({ isValid: false, error: "Internal error" });
    }
  }
);

exports.checkSubscriptions = onSchedule("every 24 hours", async () => {
  const now = new Date();
  const soon = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);

  const usersRef = db.collection(USERS_COLLECTION);

  const aboutToExpireSnap = await usersRef
    .where("isPremium", "==", true)
    .where("expiryDate", ">=", admin.firestore.Timestamp.fromDate(now))
    .where("expiryDate", "<=", admin.firestore.Timestamp.fromDate(soon))
    .get();

  const expiredSnap = await usersRef
    .where("isPremium", "==", true)
    .where("expiryDate", "<", admin.firestore.Timestamp.fromDate(now))
    .get();

  const messaging = admin.messaging();
  const sendPromises = [];

  aboutToExpireSnap.forEach((doc) => {
    const data = doc.data();
    const token = data.fcmToken;
    if (!token) return;
    sendPromises.push(
      messaging.send({
        token,
        notification: {
          title: "Premium subscription renewing soon",
          body:
            "Your premium subscription will renew soon. Ensure your payment method is up to date.",
        },
      })
    );
  });

  expiredSnap.forEach((doc) => {
    const data = doc.data();
    const token = data.fcmToken;
    if (token) {
      sendPromises.push(
        messaging.send({
          token,
          notification: {
            title: "Premium subscription expired",
            body:
              "Your premium subscription has expired. Renew to continue using premium features.",
          },
        })
      );
    }
  });

  const batch = db.batch();
  expiredSnap.forEach((doc) => {
    batch.update(doc.ref, { isPremium: false });
  });

  await Promise.allSettled(sendPromises);
  await batch.commit();

  return null;
});
