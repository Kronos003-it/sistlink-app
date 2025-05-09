import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions"; // Import logger for v2

// Initialize Firebase Admin SDK
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Sends a push notification when a new chat message is created.
 * (Using v2 syntax)
 */
export const onChatMessageCreated = onDocumentCreated(
  "/chats/{chatId}/messages/{messageId}",
  async (event) => {
    const {chatId, messageId} = event.params; // Get params from event
    const snapshot = event.data; // Get DocumentSnapshot from event

    if (!snapshot) {
      logger.log("No data associated with the event.");
      return;
    }
    const newMessageData = snapshot.data();

    if (!newMessageData) {
      logger.log("No message data found in snapshot for id:", messageId);
      return;
    }

    const senderId = newMessageData.senderId as string | undefined;
    const messageText = newMessageData.text as string | undefined;
    const senderUsername =
      (newMessageData.senderUsername as string | undefined) || "Someone";

    if (!senderId || !messageText) {
      logger.log("Missing senderId or messageText.", {
        senderId,
        messageText,
      });
      return;
    }

    // Line 46 was potentially here or nearby, ensure logging is concise
    logger.log(
      `New message from ${senderUsername} (${senderId}) in chat ${chatId}, ` +
      `msgId ${messageId}: "${messageText}"`,
    );

    try {
      const chatDocRef = db.collection("chats").doc(chatId);
      const chatDocSnap = await chatDocRef.get();

      if (!chatDocSnap.exists) {
        logger.log(`Chat document ${chatId} not found.`);
        return;
      }

      const chatData = chatDocSnap.data();
      if (!chatData || !chatData.users || !Array.isArray(chatData.users)) {
        logger.log(`Invalid chat document data for ${chatId}.`, chatData);
        return;
      }

      const participants = chatData.users as string[];

      for (const recipientId of participants) {
        if (recipientId === senderId) {
          continue; // Don't send to self
        }

        logger.log(`Preparing notification for recipient: ${recipientId}`);

        const recipientDocRef = db.collection("users").doc(recipientId);
        const recipientDocSnap = await recipientDocRef.get();

        if (!recipientDocSnap.exists) {
          logger.log(`Recipient user document ${recipientId} not found.`);
          continue;
        }

        const recipientData = recipientDocSnap.data();
        if (
          !recipientData ||
          !recipientData.fcmTokens ||
          !Array.isArray(recipientData.fcmTokens) ||
          recipientData.fcmTokens.length === 0
        ) {
          // Line 115 was potentially here or nearby
          logger.log(
            `No valid FCM tokens for recipient ${recipientId}.`,
            recipientData,
          );
          continue;
        }

        const recipientTokens = recipientData.fcmTokens as string[];

        const payload: admin.messaging.MessagingPayload = {
          notification: {
            title: senderUsername,
            body: messageText,
          },
          data: {
            type: "new_message",
            chatId: chatId,
            senderId: senderId,
          },
        };

        const options: admin.messaging.MessagingOptions = {
          priority: "high",
          contentAvailable: true,
        };

        // Line 143 was potentially here or nearby
        logger.log(
          `Sending to ${recipientTokens.length} tokens for ${recipientId}.`,
        );
        const response = await messaging.sendToDevice(
          recipientTokens,
          payload,
          options,
        );

        // Token cleanup for this recipient
        const tokensToRemove: string[] = [];
        response.results.forEach((result, index) => {
          const error = result.error;
          if (error) {
            // Line 165 was potentially here or nearby
            logger.error(
              `Failure sending to token for ${recipientId}:`,
              error,
            );
            // Line 166 was potentially here or nearby
            if (
              error.code === "messaging/invalid-registration-token" ||
              error.code === "messaging/registration-token-not-registered"
            ) {
              tokensToRemove.push(recipientTokens[index]);
            }
          }
        });

        if (tokensToRemove.length > 0) {
          logger.log(
            `Removing ${tokensToRemove.length} invalid tokens for ${recipientId}.`,
          );
          await recipientDocRef.update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(
              ...tokensToRemove,
            ),
          });
        }
      } // End of participant loop

      logger.log("Notifications processing complete for message:", messageId);
    } catch (error) {
      logger.error(
        `Error processing new chat message for msgId ${messageId}:`,
        error,
      );
    }
  },
);

// You can add more functions here, for example:
// export const onNewFollower = onDocumentCreated(...);
// export const onNewLike = onDocumentCreated(...);
