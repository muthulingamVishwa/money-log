# Money Log: setup guide

Money Log is an income and expense tracker with accounts:

- **Sign up** with a username, email and password. The password must have 8–64 characters, an uppercase letter, a lowercase letter, a number and a symbol, and no spaces. A live checklist shows each rule as you type.
- **Email verification code (OTP)**: after signing up, the user gets a code by email and must enter it before the account works.
- **Log in** with email and password. **Forgot password** sends a code by email and lets the user set a new password.
- **Accounts**: add as many bank accounts as you like (or cash, wallet, credit card) with the bank name, account number and current balance. Only the last 4 digits of the account number are saved (shown as ••1234), which is enough to tell two accounts at the same bank apart. When adding an entry, tap the account the money came from or went into. Link an entry to an account and the balance updates. Filter the passbook by account to see a running account balance like a bank passbook.
- Each person sees only their own entries and accounts (enforced in the database, not just the app).

Everything runs on free plans: **Supabase** (database, login, emails) and **GitHub Pages** (hosting). It takes about 30 minutes to set up.

Files in this folder:

| File | What it is |
|---|---|
| `index.html` | The whole app |
| `supabase-setup.sql` | Creates the tables, security rules and signup trigger |
| `.github/workflows/keep-alive.yml` | Pings the database every 3 days so the free project never pauses |

---

## 1. Create the Supabase project

1. Sign up at **supabase.com** (free, no card needed).
2. **New project**. Pick the region **South Asia (Mumbai)**. Save the database password somewhere safe.
3. Wait about 2 minutes for it to finish setting up.

## 2. Create the database

1. Open **SQL Editor** → **New query**.
2. Paste everything from `supabase-setup.sql` → **Run**. It should say "Success. No rows returned".

Already ran an older copy of the script? Run the new one again. It's safe to re-run: it adds the accounts table and keeps your existing data.

## 3. Turn on email verification and password rules

Go to **Authentication → Sign In / Providers → Email**:

- **Confirm email**: ON (no one can log in until they enter the code).
- **Minimum password length**: `8`.
- **Password requirements**: *Lowercase, uppercase letters, digits and symbols*.
- **Email OTP length**: 6 is easiest to type (the app accepts 6 to 10 digits).
- Save.

The app checks the same password rules, but these settings make the server enforce them too.

## 4. Make the emails send a code instead of a link

Go to **Authentication → Emails → Templates**.

**Confirm signup**: subject `Your Money Log code`, body:

```html
<h2>Welcome to Money Log</h2>
<p>Your verification code is:</p>
<p style="font-size:28px;font-weight:700;letter-spacing:6px">{{ .Token }}</p>
<p>Enter it in the app to finish creating your account. It expires in 1 hour.</p>
<p>If you didn't sign up, ignore this email.</p>
```

**Reset password**: subject `Your Money Log password reset code`, body:

```html
<h2>Reset your Money Log password</h2>
<p>Your code is:</p>
<p style="font-size:28px;font-weight:700;letter-spacing:6px">{{ .Token }}</p>
<p>Enter it in the app and choose a new password. If you didn't ask for this, ignore this email.</p>
```

Save both.

## 5. Let the app email anyone (custom SMTP)

Supabase's built-in email only sends to members of your Supabase team, and only 2 per hour.

- **Only you will use the app?** You can skip this step. The built-in sender reaches your own email.
- **Friends or family will sign up too?** Connect a free email service:

**Brevo** (free: 300 emails/day, no domain needed)
1. Sign up at brevo.com → **Senders, Domains & Dedicated IPs** → add and verify your sender email.
2. **SMTP & API** → create an SMTP key.
3. In Supabase: **Authentication → Emails → SMTP Settings** → Enable custom SMTP:
   - Sender email: the address you verified · Sender name: `Money Log`
   - Host: `smtp-relay.brevo.com` · Port: `587`
   - Username: your Brevo SMTP login · Password: the SMTP key
4. Then **Authentication → Rate Limits**: set emails per hour to about 30.

(If you own a domain, **Resend** also works: 3,000 emails/month free, host `smtp.resend.com`, port `465`, username `resend`, password = your API key.)

## 6. Connect the app to your project

1. In Supabase, open **Project Settings → API Keys**. Copy the **publishable key** (or the legacy **anon** key).
2. Copy your **Project URL**. It looks like `https://abcdxyz.supabase.co` (find it under **Project Settings → Data API**, or the **Connect** button).
3. Open `index.html` and change these two lines near the top:

```js
window.MONEY_LOG_CONFIG = {
  url: "https://abcdxyz.supabase.co",
  key: "sb_publishable_..."
};
```

These keys are meant to be public. Row Level Security in the database stops anyone from reading someone else's entries. **Never** put the `service_role` or **secret** key in this file.

## 7. Put it online with GitHub Pages (free, always on)

1. On github.com → **New repository** → name it `money-log` → **Public** → Create.
2. **Add file → Upload files** → upload `index.html`. Commit.
3. Create the keep-alive file: **Add file → Create new file**, name it `.github/workflows/keep-alive.yml`, paste the contents of that file. Commit.
4. **Settings → Pages** → Source: *Deploy from a branch* → Branch: `main`, folder `/ (root)` → Save.
5. After a minute your app is live at `https://YOUR-GITHUB-NAME.github.io/money-log/`. On your phone, open it and use **Add to Home screen** so it opens like an app.

Then in Supabase → **Authentication → URL Configuration** → set **Site URL** to that address.

## 8. Stop the free project from pausing

Supabase pauses free projects after 7 days without activity. The workflow pings it every 3 days.

1. In the GitHub repo: **Settings → Secrets and variables → Actions → New repository secret**:
   - `SUPABASE_URL` = your Project URL
   - `SUPABASE_KEY` = your publishable (or anon) key
2. **Actions** tab → *Keep Supabase awake* → **Run workflow** once to check it shows a green tick.

GitHub turns off scheduled workflows in public repos after 60 days with no commits, and emails you first. If that happens, open the Actions tab and click **Enable workflow**. Any small commit also resets the timer.

If the project ever does pause, open the Supabase dashboard and click **Resume project**. Your data is kept.

## 9. Test it

1. Open your site → **Create account** → enter a username, your email and a password that passes every rule.
2. Check your email for the code → enter it → you land in the tracker.
3. Add an entry, log out, then log in again. The entry is still there.
4. Try **Forgot password?** once to make sure the reset email arrives.

## Free plan limits

| | Free |
|---|---|
| Database | 500 MB, enough for roughly a million entries |
| Users | 50,000 active per month |
| Emails | Built-in: 2/hour, your team only · Brevo: 300/day |
| Backups | None on free. Use **Download month as CSV** now and then to keep your own copy. |

## Troubleshooting

- **"Email address not authorized"**: custom SMTP isn't set up and that email isn't on your Supabase team (step 5).
- **"Too many attempts"**: wait a minute. Supabase allows one code email per 60 seconds per address.
- **The email has a link, not a code**: the template in step 4 is missing `{{ .Token }}`.
- **The page says "Almost there"**: the URL or key in step 6 hasn't been filled in.
- **"That username was just taken"**: someone signed up with it between your check and your submit. Pick another.
