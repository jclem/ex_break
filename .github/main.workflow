workflow "Tests & Formatting" {
  on = "push"
  resolves = ["Run Tests", "Check Formatting"]
}

action "Get Deps" {
  uses = "jclem/action-mix/deps.get@v1.3.3"
}

action "Run Tests" {
  uses = "jclem/action-mix/test@v1.3.3"
  needs = "Get Deps"
}

action "Check Formatting" {
  uses = "jclem/action-mix@v1.3.3"
  needs = "Get Deps"
  args = "format --check-formatted"
}