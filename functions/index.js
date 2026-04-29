const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

/**
 * STEP 2: FIRESTORE TRIGGER
 * Listen to tasks collection on create/update.
 * Since no Flutter code changes are allowed, this automatically 
 * sets `notificationSent = false` when a task is created or its dueDate changes.
 */
exports.onTaskWrite = functions.firestore
  .document("users/{userId}/tasks/{taskId}")
  .onWrite((change, context) => {
    // If deleted, do nothing
    if (!change.after.exists) return null;

    const beforeData = change.before.data() || {};
    const afterData = change.after.data();

    // If dueDate changed or it's a new task, reset notificationSent to false
    const dueDateChanged = beforeData.dueDate?.toMillis() !== afterData.dueDate?.toMillis();
    const isNewTask = !change.before.exists;

    if ((isNewTask || dueDateChanged) && afterData.dueDate) {
      console.log(`Task ${context.params.taskId} updated/created. Resetting notification flag.`);
      return change.after.ref.update({ notificationSent: false }, { merge: true });
    }

    return null;
  });

/**
 * Scheduled function that runs every minute to check for due tasks.
 */
exports.sendTaskReminders = functions.pubsub.schedule("* * * * *").onRun(async (context) => {
  console.log("Starting task reminder check...");
  
  const now = admin.firestore.Timestamp.now();

  try {
    // Note: Since you requested "No Flutter code changes", existing tasks might not have 
    // the 'notificationSent' boolean field. Firestore cannot query on a field that does not exist.
    // To solve this cleanly without touching Flutter, we query tasks due in the past 24 hours
    // that haven't been marked sent, and filter in memory. 
    
    // 24 hours ago
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const yesterdayTimestamp = admin.firestore.Timestamp.fromDate(yesterday);

    const tasksSnapshot = await db.collectionGroup("tasks")
      .where("dueDate", "<=", now)
      .where("dueDate", ">", yesterdayTimestamp)
      .get();

    if (tasksSnapshot.empty) {
      console.log("No pending tasks found.");
      return null;
    }

    const batch = db.batch();
    const promises = [];
    let processedCount = 0;

    for (const doc of tasksSnapshot.docs) {
      const taskData = doc.data();
      const taskRef = doc.ref;

      // Skip tasks that have already had a notification sent
      if (taskData.notificationSent === true) {
        continue;
      }

      processedCount++;

      // Extract userId from the path: users/{userId}/tasks/{taskId}
      const userId = taskRef.parent.parent.id;

      // Fetch user's FCM token
      const userDoc = await db.collection("users").doc(userId).get();
      
      if (!userDoc.exists || !userDoc.data().fcmToken) {
        console.log(`User ${userId} has no FCM token. Skipping task ${doc.id}.`);
        // Mark as sent so we don't keep checking it every minute
        batch.update(taskRef, { notificationSent: true });
        continue;
      }

      const fcmToken = userDoc.data().fcmToken;

      // Prepare notification payload
      const payload = {
        token: fcmToken,
        notification: {
          title: "Task Reminder",
          body: `Your task "${taskData.title || 'Task'}" is due now!`,
        },
        data: {
          taskId: doc.id,
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        }
      };

      // Send the FCM message
      const p = messaging.send(payload)
        .then(() => {
          console.log(`Successfully sent notification for task ${doc.id}`);
          batch.update(taskRef, { notificationSent: true });
        })
        .catch((error) => {
          console.error(`Error sending notification for task ${doc.id}:`, error);
          
          // Clean up invalid tokens
          if (error.code === 'messaging/invalid-registration-token' ||
              error.code === 'messaging/registration-token-not-registered') {
            console.log(`Token invalid for user ${userId}.`);
          }
          // Mark as sent anyway to prevent infinite retry loops on failure
          batch.update(taskRef, { notificationSent: true });
        });

      promises.push(p);
    }

    if (processedCount === 0) {
      console.log("No new tasks required notifications.");
      return null;
    }

    // Wait for all messages to send
    await Promise.all(promises);

    // Commit the batch update to Firestore (marking all processed as true)
    await batch.commit();
    console.log(`Finished processing ${processedCount} task reminders.`);

  } catch (error) {
    console.error("Error running task reminder check:", error);
  }

  return null;
});
