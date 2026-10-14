-- Personal challenges no longer belong to a community.
ALTER TABLE "Challenge" ALTER COLUMN "communityId" DROP NOT NULL;
