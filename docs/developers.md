---
title: Developing Flextensions
permalink: /developers/
---

# Developing Flextensions

## Standing Up the Application

This guide walks you through setting up the Flextensions app on your local machine and on your Heroku server and preparing it for development and deployment.

## Set Up in Your Local Environment

### Clone the Repository

```bash
git clone git@github.com:berkeley-cdss/flextensions.git
cd flextensions
```

---

### Set Up Ruby Environment

#### (If you are on Windows, please use WSL instead).

Install `mise`, such as `brew install mise` or any other ruby language manager.

Any Ruby from 3.3 through 4.0 will work. Local dev and CI run 4.0, but the
deployed Elastic Beanstalk platform currently runs Ruby 3.3, so the app must
remain compatible with both (the Gemfile allows `>= 3.3, < 5`):

```
mise use ruby@4.0
```

### Install dependencies:

```
bundle install --without production
```

### Install PostgreSQL
#### On macOS:

```bash
brew install postgresql
# Optionally, if it does not start by default
brew services start postgresql@16
/opt/homebrew/opt/postgresql@16/bin/postgres -D /opt/homebrew/var/postgresql@16
```
#### On Linux / WSL:

```bash
sudo apt install postgresql
# Create a postgres user.
sudo su-postgres #(to get into postgres shell)
createuser --interactive --pwprompt #(in postgres shell)0
Save DB_USER and DB_PASSWORD fields in the .env file.
#Start postgres if necessary.
pg ctlcluster 12 main start
#Note: if you are using WSL2 on windows, the command to start postares is
sudo seryice posteresal start
```
### Install Overmind

In order to stand up the server you must first install [Overmind](https://github.com/DarthSim/overmind).
  Development has been tested with overmind 2.4.0

With Overmind, you can run `$make dev` or `$make`

### Environment Variables
- Copy `.env.sample` to `.env`.
- Get client secrets from your Canvas sandbox instance. Flextensions uses bcourses (Canvas) third-party authentication. For developers, you need a sandbox admin account to generate client ID and secrets for your app when using Canvas authentication APIs.
1. Log into your sandbox admin account. Contact your instructor if you do not have one.
2. Click `admin` on the sidebar on the left, then Click `UC Berkeley Sandbox`
3. Go to the `Developer Keys` section on the left sidebar, add an API key.
4. Fill in each field with your own information. `Redirect_URI` should be the same as your `APP_HOST` in `.env` (See the code block below)
5. For your environment variables, the `CANVAS_CLIENT_ID` should be something like `2653xxxxxxxxx`; the `APP_KEY` should be the secret corresponding to it.
- Setup the following ENV variables in your .env file:
```
DB_PORT (default: 5432)
DB_USER (default: postgres)
DB_PASSWORD (default: password)
DB_NAME (default: postgres)
CANVAS_URL (No default, but if you are using instructure sandbox then it should be set as "https://www.instructure.com/canvas?domain=canvas")
CANVAS_CLIENT_ID (Ask the instructor for this. Used for authentication token request)
APP_HOST (The full domain of the app itself, e.g. "flextensions.eecs.cloud". If you are standing up the app locally then it should be "http://localhost:3000". Links in notification emails and Slack messages are built from this, so it must be the domain users reach the app at.)
```

In the root directory of Flextensions app, run

```
make env
```

### Rails Database

run `rails db:setup`

To start the server locally, run `rails server` . You should be able to land to the login page.

### Hypershield

Hypershield is a tool which allows admins to query data, without relevaing sensitive tokens.

You may need to run:

```sh
rake hypershield:refresh:dry_run
```

### Background and Scheduled Jobs

Background jobs run on [GoodJob](https://github.com/bensheldon/good_job), backed by
the app's Postgres database. In production and staging GoodJob runs *inside* the
Puma process (`config.good_job.execution_mode = :async`), so Elastic Beanstalk does
not need a worker tier, a Procfile `worker` entry, or an EC2 crontab.

Recurring jobs are defined once, in `config/application.rb` under
`config.good_job.cron`, and executed by GoodJob's own cron thread wherever
`config.good_job.enable_cron` is true (production and staging). Times use an
explicit `America/Los_Angeles` timezone field, so they do not depend on the
server clock, and GoodJob's unique index on `(cron_key, cron_at)` means an
occurrence is enqueued once even if several processes are running.

| Cron key | Schedule | Job |
|----------|----------|-----|
| `daily_enrollment_sync` | 3:00 AM PT daily | `DailyEnrollmentSyncJob` |
| `pending_digests_hourly` | Top of every hour | `PendingRequestsNotificationJob('hourly')` |
| `pending_digests_daily` | 4:00 PM PT daily | `PendingRequestsNotificationJob('daily')` |
| `pending_digests_weekly` | 4:00 PM PT Thursdays | `PendingRequestsNotificationJob('weekly')` |

Each notification run emails the courses whose **Pending Request Notifications**
setting matches that frequency and that currently have pending requests.

The daily enrollment sweep considers Canvas-linked courses imported within the
past five weeks and skips any roster synced less than six hours ago. Eligible
per-course jobs are spaced evenly across the hour after the 3:00 AM sweep to
avoid a burst of Canvas API calls. Canvas applies a separate quota to each OAuth
access token, so syncs performed with different instructors' tokens do not
consume one shared quota; courses that share an instructor can still share that
token's quota. See the [Canvas API throttling documentation](https://developerdocs.instructure.com/services/canvas/basics/file.throttling).

Admins can inspect queues, schedules and past runs at `/admin/good_job`. To send a
digest by hand (locally, or to backfill after downtime):

```sh
bundle exec rake 'notifications:send_pending_digests[hourly]'
```

Set `GOOD_JOB_ENABLE_CRON=false` on an instance to stop it from enqueueing
recurring jobs — for example when moving them to a dedicated worker started with
`bundle exec good_job start --enable-cron`.

---

## Deployment (Elastic Beanstalk)

Staging and production run on the *Ruby 3.3 on Amazon Linux 2023* platform, built
by CodeBuild (`buildspec.yml`) and deployed by CodePipeline.

### The `Procfile` and `config/puma.rb`

The root `Procfile` starts the web process with the app's own Puma config:

```
web: bundle exec puma -C config/puma.rb
```

Without a `Procfile`, Elastic Beanstalk [generates the default](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/ruby-platform-procfile.html)
for the Ruby platform (`bundle exec puma -C /opt/elasticbeanstalk/config/private/pumaconf.rb`)
and `config/puma.rb` is never read. The app ships its own config so it can raise
`worker_timeout` (the nightly AIDE scan was killing workers at the 60s default)
and wire GoodJob into Puma's fork lifecycle.

`config/puma.rb` decides *where to listen* from where it is running, and
*how many processes to run* from `WEB_CONCURRENCY`. The two are independent:

- **On an EB host** (detected by the presence of `/opt/elasticbeanstalk`) Puma
  binds the Unix socket `/var/run/puma/my_app.sock`, which is what the
  platform's nginx config proxies to
  (`upstream my_app { server unix:///var/run/puma/my_app.sock; }`), runs from
  `/var/app/current` and logs to `/var/log/puma/puma.log`. The Ruby platform does
  **not** set a `PORT` variable and nginx does not proxy to a TCP port, so binding
  anything else makes nginx return 502, the health check fails and EB rolls the
  deployment back.
- **Everywhere else** (development, CI, the Docker image) Puma listens on TCP
  `PORT` (default 3000).
- `WEB_CONCURRENCY` sets the worker count. Until it is set as an EB environment
  property, `RAILS_ENV=production` and `RAILS_ENV=staging` default to 2 workers
  and every other environment to 0 (a single process). Either mode works on EB,
  because the socket bind does not depend on it.

Two platform behaviours to keep in mind when editing the `Procfile`:

- **Comments are not supported.** Every line must match
  `^[A-Za-z0-9_-]+:\s*[^\s].*$`. A `#` comment makes the whole file invalid, and
  Elastic Beanstalk silently falls back to its generated default — so a
  `Procfile` with comments *appears* to work while none of its lines are
  actually running. Document the process model here instead.
- The `web` process must bind `unix:///var/run/puma/my_app.sock`, not a TCP port,
  or nginx will return 502.

Because GoodJob runs in-process (see [Background and Scheduled Jobs](#background-and-scheduled-jobs)),
the single `web` process is all this app needs. In cluster mode `config/puma.rb`
stops GoodJob before the fork and restarts it in each worker, as GoodJob's Puma
guidance requires when `preload_app!` is on; `spec/config/puma_spec.rb` checks
the bind, worker and hook settings for both environments.

---

## Standing Up the Application on Heroku

1. Setup the following ENV variables in heroku, with the same values in your local .env file.

   ```bash
   APP_HOST
   CANVAS_CLIENT_ID
   CANVAS_URL
   # Active Record Encryption Values
   # SMTP Email Settings
   ```

2. Push branch [Iter4](https://github.com/cs169/flextensions/tree/iter4-end-2025-04-21) to the flextensions heroku app.

   ```bash
   heroku login
   git remote add golden https://git.heroku.com/flextensions.git
   git push golden main
   ```

3. The app is then available at <https://sp25-02-flextensions-4f5b4fbccd7f.herokuapp.com>.







## Testing
### Test Commands

| Test Type | Command |
|-----------|---------|
| RSpec Tests (no a11y) | `bundle exec rspec --tag '~a11y'` |
| Cucumber Tests (no a11y) | `bundle exec cucumber --tags 'not @a11y and not @skip'` |
| All Regular Tests | `bundle exec rspec --tag '~a11y' && bundle exec cucumber --tags 'not @a11y and not @skip'` |
| Accessibility Tests (RSpec) | `bundle exec rspec --tag a11y` |
| Accessibility Tests (Cucumber) | `bundle exec cucumber --tags @a11y` |
| All Tests (including a11y) | `bundle exec rspec && bundle exec cucumber --tags 'not @skip'` |
| Lint Code (RuboCop) | `bundle exec rubocop` |
| Auto-fix Lint Issues | `bundle exec rubocop -A` |
| Validate Swagger API | `npx @redocly/cli lint app/assets/swagger/swagger.json --extends=minimal` |

### Test Tags

| Tag | Description |
|-----|-------------|
| `@javascript` | Tests requiring JS execution in browser (uses Selenium/headless browser), without the tag, it will run in rack, which is exponentially faster to test |
| `@a11y` | Accessibility tests using axe-core to verify WCAG compliance |
| `@skip` | Temporarily skipped tests (known failures) |
| `@wip` | Work In Progress tests still under development |


### Accessibility (a11y) after-hooks

Accessibility auditing is wired up as an **after-hook** in both test frameworks,
so any test opted in with the `a11y`/`@a11y` tag has its final rendered page
audited with axe-core automatically -- individual tests do not need to call the
axe matcher themselves.

- **RSpec** (`spec/support/accessibility_helper.rb`): every feature spec tagged
  `:a11y` runs `expect(page).to be_axe_clean` against the current page after the
  example. See `spec/features/accessibility_spec.rb` for usage.
- **Cucumber** (`features/support/axe_helper.rb`): every scenario tagged `@a11y`
  is audited after it runs. Because axe-core needs a real browser, `@a11y`
  scenarios run under the JavaScript driver.

### Tips

- Use `~` (RSpec) or `not` (Cucumber) to exclude tags
- Combine tags in Cucumber with `and`/`or`: `--tags '@javascript and not @skip'`
- Run accessibility tests separately (slower)


### Conventions

1. Testing convention css selector:

   ```html
   <a class="nav-link testid-username" href="#"> Tashrique </a>
   ```

Notice the `testid-username` class. We will be using this style in **class** to grab elements from DOM to test.

Please don't remove any class that starts with `testid-`.

## Notes

For how Flextensions reads Canvas assignment due dates and reads/writes
assignment overrides (and the gotchas around `override_assignment_dates`, the
25-date `all_dates` limit, and `/date_details`), see
[Canvas Dates API notes](/canvas-dates-api/) (`docs/Canvas_Dates_API.md`).

There are now two separate instances of Canvas, each with it's own triad of prod/test/beta environments:
1. [bcourses.berkeley.edu](https://bcourses.berkeley.edu)
2. [ucberkeleysandbox.instructure.com](https://ucberkeleysandbox.instructure.com)

We recommend developing in this order:
1. [ucberkeleysandbox.instructure.com](https://ucberkeleysandbox.instructure.com) (no risk) - this is the one for which this repo currently has oauth2 keys (secrets)
2. [bcourses.test.instructure.com](https://bcourses.test.instructure.com) (no risk of impacting courses, but contains real data)
3. [bcourses.berkeley.edu](https://bcourses.berkeley.edu)
