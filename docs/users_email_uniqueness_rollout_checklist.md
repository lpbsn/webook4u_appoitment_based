# Users Email Uniqueness Rollout Checklist

This checklist is required before applying the `users.email` global unique index introduced by `db/migrate/20260418120000_add_role_and_active_to_users.rb`.

## 1) Pre-deploy SQL check (blocking)

Run on the target database:

```sql
SELECT LOWER(email) AS normalized_email, COUNT(*) AS duplicates_count
FROM users
GROUP BY LOWER(email)
HAVING COUNT(*) > 1;
```

Expected result: zero rows.

## 2) If duplicates are found (blocking remediation)

- Pick one canonical account per duplicated email.
- Re-link dependent records to the canonical account where needed.
- Deactivate or archive non-canonical duplicates according to product decision.
- Re-run the SQL check until it returns zero rows.

## 3) Deploy-time validation

- Apply migration.
- Confirm unique index exists:

```sql
SELECT indexname
FROM pg_indexes
WHERE tablename = 'users' AND indexname = 'index_users_on_email';
```

- Verify constraints are active:
  - `users_role_allowed_values`
  - `users_admin_without_client`
  - `users_client_user_requires_client`
