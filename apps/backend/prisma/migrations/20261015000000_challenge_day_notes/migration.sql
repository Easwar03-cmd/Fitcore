-- Per-day notepad sheets for challenges.
CREATE TABLE "ChallengeDayNote" (
    "id" TEXT NOT NULL,
    "participantId" TEXT NOT NULL,
    "dayNumber" INTEGER NOT NULL,
    "notes" TEXT NOT NULL DEFAULT '',
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ChallengeDayNote_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ChallengeDayNote_participantId_dayNumber_key"
    ON "ChallengeDayNote"("participantId", "dayNumber");

ALTER TABLE "ChallengeDayNote"
    ADD CONSTRAINT "ChallengeDayNote_participantId_fkey"
    FOREIGN KEY ("participantId") REFERENCES "ChallengeParticipant"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- Existing single notepads become the day 1 sheet.
INSERT INTO "ChallengeDayNote" ("id", "participantId", "dayNumber", "notes", "updatedAt")
SELECT 'dn_' || "id", "id", 1, "notes", CURRENT_TIMESTAMP
FROM "ChallengeParticipant"
WHERE "notes" <> '';
