# Dosewell API

Rails API for a small clinic. A doctor prescribes from a seeded medication list. The API builds the patient's dose schedule, blocks unsafe prescriptions, and keeps an audit trail. Patients mark doses taken or missed and can read their adherence. Pharmacists can read and cannot write.

The Next.js clinic UI lives in the sibling repo `dosewell-web`.

## Setup

Clone this repo and `dosewell-web` side by side, then from this directory:

```bash
./bin/compose up --build
```

- API: http://localhost:3000
- Clinic UI: http://localhost:3001

Demo password for every seeded user: `Password1!`

| Name | Email | Role |
| --- | --- | --- |
| Maya Chen | maya.chen@dosewell.test | doctor |
| Ava Shah | ava.shah@dosewell.test | patient |
| Sam Okonkwo | sam.okonkwo@dosewell.test | patient |
| Priya Nair | priya.nair@dosewell.test | pharmacist |

Ava is allergic to ibuprofen and amoxicillin, and already has a lisinopril course. Run the suite with Docker:

```bash
./bin/compose --profile test run --rm test
```

Or locally against Postgres (`DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`):

```bash
bin/rails db:test:prepare && bin/rails test
```

## What the API does

- `POST /api/v1/auth/login` returns a signed token. Send it as `Authorization: Bearer`.
- Doctors `POST /api/v1/prescriptions` with dose, frequency, times, duration, start date, and an IANA timezone.
- The schedule is saved as one row per dose. Patients `PATCH /api/v1/doses/:id` with `taken` or `missed`.
- `GET /api/v1/adherence` is taken doses divided by doses already due. Unmarked past doses count against the percentage, except doses from before the day the course was written. Future doses are ignored. The payload also splits the same numbers by course.
- A doctor `POST /api/v1/prescriptions/:id/cancel` stops the course, removes future scheduled doses, and writes an audit row.
- Dose, prescription, and audit lists take `page` and `per` (max 100) and return `pagination`.
- Allergies block prescribing. Major drug interactions block it. Moderate interactions return `acknowledgement_required` until the doctor sends `acknowledge_warnings: true`. Minor interactions are stored and do not stop the prescription.
- Every saved change writes an audit row: actor, action, summary, and timestamp.

## Design decisions

Times are stored in UTC. The prescription keeps the IANA timezone used to build the schedule, so a later change to the patient's profile does not rewrite old doses.

Daily doses stay on the local clock. `08:00` is still `08:00` after a daylight-saving change, and the UTC instant moves. A wall time that does not exist (02:30 on a US spring-forward morning) is moved forward by the length of the gap and flagged `dst_adjusted`. A wall time that happens twice (the fall-back hour) is scheduled once, at the earlier occurrence. `every_n_hours` advances by elapsed time, so the local clock can shift by an hour after the change. That is what "every 8 hours" means.

Invalid input is rejected. A bad timezone, a daily frequency with the wrong number of times, or `8:00` instead of `08:00` returns 422. The API does not rewrite the request into a valid one.

Safety checks and schedule generation are separate from the controllers. The prescription is written, the doses are inserted, and the audit row is written in one transaction. A blocked prescription writes nothing.

Roles are enforced on the way in. Doctors prescribe. Patients record only their own due doses. Pharmacists are read-only. A patient can correct `taken` to `missed`; that correction is audited.

## Trade-offs

Doses are materialized when the prescription is created. Marking and auditing stay simple, and a long course is capped at 365 days. Changing a schedule means a new prescription, not an edit of the old rows.

Blocked attempts are not audited, because no record changed. Moderate interactions can be overridden; allergies and major interactions cannot.

Auth is a 24-hour signed token, not a session store with revocation. The demo seed password is for local use.

The interaction and allergy lists are seeded. They are not a drug database.

## What I would do next

- Audit denied prescriptions as well as saved changes.
- Mark a dose missed automatically after a grace period, with its own audit row.
- Match allergies by drug class, not only by ingredient.
- Add token revocation.
- Host the API on a container platform such as Fly or Render. Vercel and Netlify host the Next.js app; they are a poor fit for this Rails process.

## Deploy

Build the `Dockerfile` and set `DATABASE_URL` or `DB_HOST`, `SECRET_KEY_BASE`, and `FORCE_SSL=true` behind TLS. Do not commit the secret. Leave `SEED_DEMO` and `ALLOW_DEMO_SEED` unset outside a local demo. `./bin/compose` writes a gitignored `.env` for that demo, and seeding does not reset an existing password. The UI reads this API from `API_URL`.
