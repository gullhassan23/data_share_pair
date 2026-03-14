const admin = require("firebase-admin");
const { defineSecret } = require("firebase-functions/params");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");

admin.initializeApp();
const db = admin.firestore();

const APPSTORE_SHARED_SECRET = defineSecret("APPSTORE_SHARED_SECRET");

exports.verifyAppleSubscription = onRequest(
  { secrets: [APPSTORE_SHARED_SECRET] },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        return res.status(405).send("Method not allowed");
      }

      const { receiptData, productId, userId, fcmToken } = req.body || {};

      if (!receiptData || !productId || !userId) {
        return res.status(400).json({
          isValid: false,
          error: "Missing receiptData, productId or userId",
        });
      }

      const APPLE_VERIFY_URL_PROD = "https://buy.itunes.apple.com/verifyReceipt";
      const APPLE_VERIFY_URL_SANDBOX =
        "https://sandbox.itunes.apple.com/verifyReceipt";

      const sharedSecret = APPSTORE_SHARED_SECRET.value();
      const payload = {
        "receipt-data": receiptData,
        password: sharedSecret,
        "exclude-old-transactions": true,
      };

      let response = await fetch(APPLE_VERIFY_URL_PROD, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      let data = await response.json();

      if (data.status === 21007) {
        response = await fetch(APPLE_VERIFY_URL_SANDBOX, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
        data = await response.json();
      }

      if (data.status !== 0) {
        console.error("Apple verification failed:", data);
        // DEV fallback: still grant premium with 30/365 days for testing
        const now = new Date();
        const days =
          typeof productId === "string" && productId.includes("yearly")
            ? 365
            : 30;
        const expiryDate = new Date(
          now.getTime() + days * 24 * 60 * 60 * 1000
        );
        const userRef = db.collection("UsersFileTransfer").doc(userId);
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
        if (fcmToken && typeof fcmToken === "string") {
          try {
            await admin.messaging().send({
              token: fcmToken,
              notification: {
                title: "Welcome to Premium",
                body:
                  "Your premium subscription is active. Enjoy all features!",
              },
            });
          } catch (e) {
            console.error("Welcome FCM send failed:", e);
          }
        }
        return res.status(200).json({ isValid: true });
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

      const userRef = db.collection("UsersFileTransfer").doc(userId);
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

      if (fcmToken && typeof fcmToken === "string" && isPremium) {
        try {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: "Welcome to Premium",
              body:
                "Your premium subscription is active. Enjoy all features!",
            },
          });
        } catch (e) {
          console.error("Welcome FCM send failed:", e);
        }
      }

      return res.status(200).json({ isValid: isPremium });
    } catch (e) {
      console.error("verifyAppleSubscription error:", e);
      return res.status(500).json({ isValid: false, error: "Internal error" });
    }
  }
);

exports.checkSubscriptions = onSchedule("every 24 hours", async () => {
  const now = new Date();
  const soon = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);

  const usersRef = db.collection("UsersFileTransfer");

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
