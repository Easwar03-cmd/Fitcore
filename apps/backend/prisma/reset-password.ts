/**
 * One-off password reset utility.
 *
 * Usage:
 *   cd apps/backend
 *   DATABASE_URL="<railway-postgres-url>" tsx prisma/reset-password.ts <email> <newPassword>
 *
 * Or if your .env already has DATABASE_URL:
 *   tsx --env-file=.env prisma/reset-password.ts <email> <newPassword>
 */

import { PrismaClient } from '@prisma/client';
import { scrypt, randomBytes } from 'crypto';
import { promisify } from 'util';

const scryptAsync = promisify(scrypt);

async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16).toString('hex');
  const buf = (await scryptAsync(password, salt, 64)) as Buffer;
  return `${salt}:${buf.toString('hex')}`;
}

async function main() {
  const [email, newPassword] = process.argv.slice(2);

  if (!email || !newPassword) {
    console.error('Usage: tsx prisma/reset-password.ts <email> <newPassword>');
    console.error('  newPassword must be at least 8 characters');
    process.exit(1);
  }

  if (newPassword.length < 8) {
    console.error('Error: newPassword must be at least 8 characters');
    process.exit(1);
  }

  const prisma = new PrismaClient();

  try {
    const user = await prisma.user.findFirst({
      where: { email: { equals: email.toLowerCase().trim(), mode: 'insensitive' } },
      select: { id: true, email: true, name: true },
    });

    if (!user) {
      console.error(`No account found for email: ${email}`);
      process.exit(1);
    }

    console.log(`Found account: ${user.name} <${user.email}>`);

    const passwordHash = await hashPassword(newPassword);
    await prisma.user.update({
      where: { id: user.id },
      data: { passwordHash },
    });

    console.log('Password updated successfully.');
    console.log(`You can now log in with: ${user.email} / ${newPassword}`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
