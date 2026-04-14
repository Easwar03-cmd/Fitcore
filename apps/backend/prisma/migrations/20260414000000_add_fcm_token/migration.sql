-- AlterTable: add FCM token column for push notifications
ALTER TABLE "User" ADD COLUMN "fcmToken" TEXT;
