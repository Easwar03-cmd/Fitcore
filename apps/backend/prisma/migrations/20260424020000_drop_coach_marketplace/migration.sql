-- Drop CoachSessionRequest first (has FK to CoachProfile and User)
ALTER TABLE "CoachSessionRequest" DROP CONSTRAINT IF EXISTS "CoachSessionRequest_userId_fkey";
ALTER TABLE "CoachSessionRequest" DROP CONSTRAINT IF EXISTS "CoachSessionRequest_coachId_fkey";
DROP TABLE IF EXISTS "CoachSessionRequest";

-- Drop CoachProfile
DROP TABLE IF EXISTS "CoachProfile";
