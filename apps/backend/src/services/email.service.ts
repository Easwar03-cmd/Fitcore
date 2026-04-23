import nodemailer from 'nodemailer';
import { config } from '../utils/config';

const smtpConfigured =
  config.SMTP_HOST && config.SMTP_USER && config.SMTP_PASS;

const transporter = smtpConfigured
  ? nodemailer.createTransport({
      host: config.SMTP_HOST,
      port: config.SMTP_PORT ?? 587,
      secure: config.SMTP_SECURE === 'true',
      auth: { user: config.SMTP_USER, pass: config.SMTP_PASS },
    })
  : null;

const from = config.SMTP_FROM ?? 'Zenfit <no-reply@zenfit.app>';

export async function sendPasswordResetEmail(
  to: string,
  code: string,
): Promise<void> {
  if (!transporter) {
    // Dev fallback: the code is returned in the API response instead.
    return;
  }

  await transporter.sendMail({
    from,
    to,
    subject: 'Your Zenfit password reset code',
    text: `Your Zenfit password reset code is: ${code}\n\nThis code expires in 15 minutes.\n\nIf you did not request a password reset, you can ignore this email.`,
    html: `
      <div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:32px 24px">
        <h2 style="color:#4CAF50;margin-bottom:4px">Zenfit</h2>
        <p style="color:#555;margin-bottom:32px">Your fitness journey, your way.</p>
        <h3 style="margin-bottom:8px">Password Reset Code</h3>
        <p style="color:#333">Use the code below to reset your password. It expires in <strong>15 minutes</strong>.</p>
        <div style="background:#f5f5f5;border-radius:12px;padding:24px;text-align:center;margin:24px 0">
          <span style="font-size:36px;font-weight:700;letter-spacing:8px;color:#222">${code}</span>
        </div>
        <p style="color:#888;font-size:13px">If you didn't request this, you can safely ignore this email. Your password won't change.</p>
      </div>`,
  });
}

export const isEmailConfigured = smtpConfigured;
