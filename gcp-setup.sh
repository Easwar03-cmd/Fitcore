#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Zenfit — One-time GCP infrastructure setup
# Run this ONCE after creating your GCP project.
# Usage: bash gcp-setup.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── EDIT THESE ────────────────────────────────────────────────────────────────
PROJECT_ID="your-gcp-project-id"       # e.g. zenfit-prod-123456
REGION="us-central1"
DB_INSTANCE="zenfit-db"
DB_NAME="zenfit"
DB_USER="zenfit_user"
REPO="zenfit"
SERVICE="zenfit-api"
# ─────────────────────────────────────────────────────────────────────────────

echo ">>> Setting project to $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

echo ">>> Enabling required APIs..."
gcloud services enable \
  run.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  --quiet

echo ">>> Creating Artifact Registry repository..."
gcloud artifacts repositories create "$REPO" \
  --repository-format=docker \
  --location="$REGION" \
  --description="Zenfit API images" \
  --quiet || echo "Repository already exists, skipping."

echo ">>> Creating Cloud SQL PostgreSQL instance (this takes ~5 minutes)..."
gcloud sql instances create "$DB_INSTANCE" \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region="$REGION" \
  --storage-type=SSD \
  --storage-size=10GB \
  --backup-start-time=03:00 \
  --no-assign-ip \
  --quiet || echo "Instance already exists, skipping."

echo ">>> Creating database and user..."
gcloud sql databases create "$DB_NAME" --instance="$DB_INSTANCE" --quiet || echo "DB already exists."
DB_PASSWORD=$(openssl rand -base64 24)
gcloud sql users create "$DB_USER" \
  --instance="$DB_INSTANCE" \
  --password="$DB_PASSWORD" \
  --quiet || echo "User already exists."

echo ""
echo ">>> IMPORTANT: Save this database password now (it won't be shown again):"
echo "    DB_PASSWORD=$DB_PASSWORD"
echo ""

# Cloud SQL connection string via Unix socket (used inside Cloud Run)
CONNECTION_NAME=$(gcloud sql instances describe "$DB_INSTANCE" --format='value(connectionName)')
DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@localhost/${DB_NAME}?host=/cloudsql/${CONNECTION_NAME}"

echo ">>> Storing secrets in Secret Manager..."

store_secret() {
  local name=$1
  local value=$2
  echo -n "$value" | gcloud secrets create "$name" \
    --data-file=- \
    --replication-policy=automatic \
    --quiet 2>/dev/null || \
  echo -n "$value" | gcloud secrets versions add "$name" --data-file=- --quiet
  echo "    Stored: $name"
}

# Auto-generated secrets
store_secret "ZENFIT_DATABASE_URL" "$DATABASE_URL"
JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n')
JWT_REFRESH_SECRET=$(openssl rand -base64 48 | tr -d '\n')
store_secret "ZENFIT_JWT_SECRET" "$JWT_SECRET"
store_secret "ZENFIT_JWT_REFRESH_SECRET" "$JWT_REFRESH_SECRET"

echo ""
echo ">>> Secrets that need YOUR values — paste them when prompted:"
echo "    (Get these from your existing .env file)"
echo ""

prompt_and_store() {
  local secret_name=$1
  local prompt_text=$2
  echo -n "  $prompt_text: "
  read -r value
  store_secret "$secret_name" "$value"
}

prompt_and_store "ZENFIT_REDIS_URL"                "Upstash Redis URL (from upstash.com)"
prompt_and_store "ZENFIT_GEMINI_API_KEY"           "Gemini API key"
prompt_and_store "ZENFIT_STRIPE_SECRET_KEY"        "Stripe secret key (sk_live_... or sk_test_...)"
prompt_and_store "ZENFIT_STRIPE_WEBHOOK_SECRET"    "Stripe webhook secret (whsec_...)"
prompt_and_store "ZENFIT_STRIPE_PRO_PRICE_ID"      "Stripe Pro price ID (price_...)"
prompt_and_store "ZENFIT_STRIPE_COACH_PRICE_ID"    "Stripe Coach price ID (price_...)"
prompt_and_store "ZENFIT_CLOUDINARY_URL"           "Cloudinary URL (cloudinary://...)"
prompt_and_store "ZENFIT_USDA_API_KEY"             "USDA API key"
prompt_and_store "ZENFIT_FIREBASE_SERVICE_ACCOUNT" "Firebase service account JSON (single line)"

echo ">>> Granting Cloud Run SA access to secrets and Cloud SQL..."
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
SA="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SA" \
  --role="roles/secretmanager.secretAccessor" --quiet

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SA" \
  --role="roles/cloudsql.client" --quiet

echo ">>> Granting Cloud Build SA permission to deploy Cloud Run..."
CB_SA="$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"
for role in roles/run.admin roles/iam.serviceAccountUser roles/artifactregistry.writer; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$CB_SA" \
    --role="$role" --quiet
done

echo ""
echo "✅  GCP infrastructure setup complete!"
echo ""
echo "Next steps:"
echo "  1. Go to https://console.cloud.google.com/cloud-build/triggers"
echo "  2. Create a trigger → connect your GitHub repo → branch: main"
echo "  3. Build config: cloudbuild.yaml (auto-detected at repo root)"
echo "  4. Set substitution variable: _DB_INSTANCE=$DB_INSTANCE"
echo "  5. Push to main — first deploy will run Prisma migrations then start the server"
echo ""
echo "  Cloud Run URL will appear in the GCP console after first deploy."
echo "  Use that URL as FLUTTER_API_URL in your mobile .env"
