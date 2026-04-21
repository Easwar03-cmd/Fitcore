-- AlterTable: add Stripe customer and price ID columns to Subscription
ALTER TABLE "Subscription" ADD COLUMN "stripeCustomerId" TEXT;
ALTER TABLE "Subscription" ADD COLUMN "stripePriceId" TEXT;

-- CreateIndex: unique constraint on stripeCustomerId
CREATE UNIQUE INDEX "Subscription_stripeCustomerId_key" ON "Subscription"("stripeCustomerId");
