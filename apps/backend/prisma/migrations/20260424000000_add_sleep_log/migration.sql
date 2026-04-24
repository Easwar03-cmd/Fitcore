-- CreateTable
CREATE TABLE "SleepLog" (
    "id"           TEXT NOT NULL,
    "userId"       TEXT NOT NULL,
    "sleepDate"    TIMESTAMP(3) NOT NULL,
    "sleepMinutes" INTEGER NOT NULL,
    "deepMinutes"  INTEGER,
    "lightMinutes" INTEGER,
    "remMinutes"   INTEGER,
    "sleepScore"   INTEGER NOT NULL,
    "syncedAt"     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SleepLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "SleepLog_userId_sleepDate_key" ON "SleepLog"("userId", "sleepDate");

-- AddForeignKey
ALTER TABLE "SleepLog" ADD CONSTRAINT "SleepLog_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
