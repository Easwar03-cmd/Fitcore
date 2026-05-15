-- CreateTable: MoodLog
-- Stores daily mood scores (1-5) logged by the user in the Wellness screen.
CREATE TABLE "MoodLog" (
    "id"       TEXT NOT NULL,
    "userId"   TEXT NOT NULL,
    "score"    INTEGER NOT NULL,
    "loggedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MoodLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable: WearableConnection
-- Stores OAuth tokens for third-party wearable integrations
-- (Fitbit, Garmin, WHOOP, Oura). Tokens are encrypted at rest by Cloud SQL.
CREATE TABLE "WearableConnection" (
    "id"           TEXT NOT NULL,
    "userId"       TEXT NOT NULL,
    "provider"     TEXT NOT NULL,
    "accessToken"  TEXT NOT NULL,
    "refreshToken" TEXT,
    "expiresAt"    TIMESTAMP(3),
    "connectedAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"    TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WearableConnection_pkey" PRIMARY KEY ("id")
);

-- CreateIndex: WearableConnection unique constraint (one connection per provider per user)
CREATE UNIQUE INDEX "WearableConnection_userId_provider_key"
    ON "WearableConnection"("userId", "provider");

-- AddForeignKey: MoodLog → User
ALTER TABLE "MoodLog" ADD CONSTRAINT "MoodLog_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey: WearableConnection → User
ALTER TABLE "WearableConnection" ADD CONSTRAINT "WearableConnection_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
