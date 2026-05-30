-- Create a class (cohort). Learners self-enroll on first login while join_open=1.
-- Apply:  wrangler d1 execute chalk_db --remote --file cloudflare/seed.sql
INSERT OR IGNORE INTO classes (class_code, name, join_open)
VALUES ('UA-CAT531-SUMMER26', 'CAT 531 Summer 2026', 1);

-- To make yourself the instructor (full-cohort read) AFTER you log in once:
--   wrangler d1 execute chalk_db --remote --command \
--     "UPDATE learners SET role='instructor' WHERE login_name='jewoong' AND class_code='UA-CAT531-SUMMER26';"
