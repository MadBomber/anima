---
name: minitest
description: "Minitest testing — activate when writing tests, fixing failing tests, editing *_test.rb files, planning test strategy, or discussing Ruby unit/integration tests."
---

# Minitest Testing

## Philosophy

Tests verify behavior, not implementation. A test suite that survives a refactor is more valuable than one that breaks because you renamed a private method.

**Avoid mocks.** Mocks test wiring, not behavior. Asserting "method X was called with argument Y" is testing how the code works internally — not whether it produces the right outcome. The programmer looks clever; the codebase goes untested.

Use real objects whenever possible. If a method is hard to test without mocking its internals, that is a design signal: the method has too many responsibilities or its dependencies are too tightly coupled. **Refactor first.** Extract a smaller unit, accept dependencies as arguments, or move logic somewhere it can be exercised directly. Fix the design; don't paper over it with mocks.

**Stubs are acceptable** for irreversible side effects you cannot allow in tests: email delivery, payment charges, file writes to production paths. Use `Object#stub` for this — it prevents the side effect without asserting anything about call counts.

**The test is your first user of the code.** If the test is awkward to write, the API is awkward to use. Let that friction guide you toward a better design.

## Test Data: FixtureBot

This project uses **fixturebot-rails** (`gem "fixturebot-rails"`). Define the test data world once in `test/fixtures.rb` using a Ruby DSL; FixtureBot compiles it to YAML fixtures checked into git. At runtime Rails loads the YAML as standard fixtures — FixtureBot is entirely absent.

```ruby
# test/fixtures.rb
FixtureBot.define do
  user.email { |f| "#{f.key}@example.com" }   # generator: fills all records

  user :alice do
    name "Alice"
    role :admin
  end

  user :bob do
    name "Bob"
    # email filled in by generator: "bob@example.com"
  end

  post :hello_world do
    title "Hello World"
    author :alice          # sets author_id to alice's stable ID
    tags :ruby, :rails     # creates rows in posts_tags
  end

  tag.name { |f| f.key.to_s.capitalize }
  tag :ruby
  tag :rails
end
```

Access in tests exactly like standard fixtures:

```ruby
users(:alice)         # => Alice (admin)
posts(:hello_world)   # => the post
```

The generated YAML is deterministic and diffs cleanly. Treat it like a lockfile — commit it, don't hand-edit it.

## Build Strategy

FixtureBot's `build`/`create`/`build_stubbed` mirror FactoryBot's API but reference named fixture records instead of anonymous factory definitions:

```ruby
# FactoryBot style (anonymous)     # FixtureBot style (named)
build(:user)                        build(:user, :alice)
create(:user)                       create(:user, :alice)
build(:user, name: "X")            build(:user, :alice, name: "X")
build_stubbed(:user)               build_stubbed(:user, :alice)
```

Default to the cheapest strategy that makes the test pass:

| Strategy | Use When |
|---|---|
| `users(:alice)` | The fixture record as-is — zero cost |
| `build_stubbed(:user, :alice)` | Unit tests, policies, decorators — fake-persisted, no DB |
| `build(:user, :alice, ...)` | In-memory variant with overrides |
| `create(:user, :alice, ...)` | Must persist and query the DB |
| `attributes_for(:user, :alice)` | Integration test params (form submissions) |

The fixture record (`users(:alice)`) is already in the database and costs nothing. Reach for it first. Upgrade to `build_stubbed` when you need overrides but not a DB write. Reach for `create` only when the test is actually about querying.

## Test Structure

```ruby
class OrderTest < ActiveSupport::TestCase
  class WithSufficientFunds < ActiveSupport::TestCase
    def setup
      @order = orders(:funded)
    end

    test "charge reduces balance" do
      @order.charge(20)
      assert_equal 80, @order.balance
    end
  end

  class WithInsufficientFunds < ActiveSupport::TestCase
    def setup
      @order = build(:order, :empty, balance: 0)
    end

    test "charge raises InsufficientFunds" do
      assert_raises(InsufficientFunds) { @order.charge(20) }
    end
  end
end
```

- Use `test "description" do` — not `def test_method_name`
- Name the behavior, not the method: `"raises InsufficientFunds when balance is zero"` not `"test_charge"`
- One concept per test. Multiple `assert` calls on unrelated things should be split.
- Group related tests by state using inner classes rather than a flat long class.
- Test the public interface only. Private methods are implementation detail.

## Rails Test Classes

| Test Type | Class |
|---|---|
| Models, POROs, services | `ActiveSupport::TestCase` |
| HTTP endpoints | `ActionDispatch::IntegrationTest` |
| ActionCable channels | `ActionCable::Channel::TestCase` |
| Background jobs | `ActiveJob::TestCase` |
| Mailers | `ActionMailer::TestCase` |
| Browser / UI (Capybara) | `ActionDispatch::SystemTestCase` |

Prefer integration tests over unit tests for behavior that crosses layers. An integration test that exercises the whole stack catches more bugs than ten unit tests that mock everything.

## Key Assertions

```ruby
assert_equal expected, actual        # expected first — always
assert_predicate obj, :valid?        # better failure message than assert obj.valid?
assert_difference "User.count" do    # preferred over checking count before/after
  User.create!(...)
end
assert_raises(ArgumentError) { risky_call }
err = assert_raises(PaymentError) { charge(nil) }
assert_match(/insufficient/, err.message)
assert_enqueued_with(job: WelcomeJob) do
  post users_url, params: { user: valid_params }
end
```

## Shoulda Matchers (`shoulda-matchers`)

This project uses `shoulda-matchers` configured for Minitest. Use `should` one-liners in model tests to declare that Rails macros are in place — validations, associations, DB structure. This is the right level of abstraction: Rails already tests that `validates_presence_of` works; you just need to assert you declared it.

```ruby
class UserTest < ActiveSupport::TestCase
  # Validations
  should validate_presence_of(:name)
  should validate_uniqueness_of(:email).case_insensitive
  should validate_length_of(:password).is_at_least(8)
  should validate_inclusion_of(:role).in_array(%w[admin member guest])

  # Associations
  should belong_to(:organization)
  should have_many(:posts).dependent(:destroy)
  should have_one(:profile)
  should have_many_attached(:documents)

  # Database
  should have_db_column(:email).of_type(:string).with_options(null: false)
  should have_db_index(:email).unique(true)
  should have_db_index([:organization_id, :role])
end
```

Use `should` matchers for structural Rails declarations. Write full `test "..." do` blocks for business logic and behavior — shoulda-matchers don't replace those.

Setup in `test/test_helper.rb`:

```ruby
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :minitest
    with.library :rails
  end
end
```

## Difftastic Diffs (`minitest-difftastic`)

This project uses `minitest-difftastic`. When an assertion fails, Minitest shows a structural side-by-side diff (Expected | Actual) using `difftastic` instead of a plain unified diff. No change to how you write tests — it just makes failures easier to read, especially for long strings, nested hashes, and objects. The plugin loads automatically in Minitest 5; in Minitest 6 add `Minitest.load :difftastic` to `test_helper.rb`.

## Power Assert (`minitest-power_assert`)

This project uses `minitest-power_assert`. When `assert` is called with a block, it displays the intermediate value at every node of the expression on failure — far more diagnostic than "Expected false to be truthy":

```ruby
assert { user.account.balance >= order.total }
#              |       |               |
#              |       42.50           89.99
#              #<Account id=7>
# => Failure — you see exactly where it broke down
```

Use `assert { }` for complex boolean expressions that don't map cleanly to a named assertion. For everything else, prefer the specific assertion — `assert_equal`, `assert_predicate`, `assert_raises` produce better output for the cases they cover.

```ruby
# Prefer specific assertions when you have a clear expected/actual:
assert_equal 42.50, user.account.balance    # not: assert { user.account.balance == 42.50 }
assert_predicate user, :active?             # not: assert { user.active? }

# Power assert shines for multi-step expressions with no obvious expected value:
assert { invoice.line_items.map(&:total).sum == invoice.grand_total }
assert { user.roles.any? { |r| r.permits?(:publish) } }
```

## When Mocks Are Acceptable

Mocks are justified in two narrow cases:

1. **A fire-and-forget side effect with no observable return value** — e.g., confirming an audit log entry was written when the audit store is a collaborator injected via the constructor.
2. **A genuinely external, slow collaborator** — a third-party API with no test mode. Stub it to prevent the call; mock it only if call count matters.

When you reach for a mock outside these two cases, stop and ask whether the method needs refactoring instead.

## Rules

1. Each test must pass in isolation and in any random order. Shared state between tests is a bug.
2. `mock.verify` must always be called. An unverified mock silently passes even if the call never happened.
3. `skip "reason"` rather than commenting out a failing test.
4. Failing to test something because it's hard to test means the design needs attention, not the test suite.
5. Test names are documentation. A reader should understand the system's behavior from test names alone.

## Running Tests

```bash
bundle exec rails test                              # all tests
bundle exec rails test test/models                 # directory
bundle exec rails test test/models/user_test.rb    # file
bundle exec rails test test/models/user_test.rb:42 # line

bundle exec rails test -v                          # verbose (show names)
bundle exec rails test --fail-fast                 # stop on first failure
bundle exec rails test -n /pattern/               # filter by regexp
bundle exec rails test --seed 12345               # reproducible order
```
