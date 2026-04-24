-- CreateTable: CoachProfile
CREATE TABLE "CoachProfile" (
    "id"              TEXT NOT NULL,
    "displayName"     TEXT NOT NULL,
    "bio"             TEXT NOT NULL,
    "specializations" TEXT NOT NULL,
    "hourlyRateUsd"   INTEGER NOT NULL,
    "yearsExp"        INTEGER NOT NULL,
    "certifications"  TEXT,
    "avatarUrl"       TEXT,
    "rating"          DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    "reviewCount"     INTEGER NOT NULL DEFAULT 0,
    "isActive"        BOOLEAN NOT NULL DEFAULT true,
    "createdAt"       TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CoachProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable: CoachSessionRequest
CREATE TABLE "CoachSessionRequest" (
    "id"          TEXT NOT NULL,
    "userId"      TEXT NOT NULL,
    "coachId"     TEXT NOT NULL,
    "message"     TEXT NOT NULL,
    "status"      TEXT NOT NULL DEFAULT 'pending',
    "requestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CoachSessionRequest_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "CoachSessionRequest" ADD CONSTRAINT "CoachSessionRequest_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "CoachSessionRequest" ADD CONSTRAINT "CoachSessionRequest_coachId_fkey"
    FOREIGN KEY ("coachId") REFERENCES "CoachProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
