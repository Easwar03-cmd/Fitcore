-- AlterTable
ALTER TABLE "Subscription" ADD COLUMN "googlePlayToken" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "Subscription_googlePlayToken_key" ON "Subscription"("googlePlayToken");
