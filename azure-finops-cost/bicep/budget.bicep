// =====================================================================
// FinOps — a monthly budget with an email alert.
// When spending reaches 80% of the budget, Azure emails you.
// Deployed at SUBSCRIPTION scope (budgets live at the subscription).
//
// Deploy:
//   az deployment sub create --location eastus --template-file budget.bicep \
//     --parameters alertEmail="you@example.com"
// =====================================================================
targetScope = 'subscription'

@description('Budget name.')
param budgetName string = 'monthly-cost-budget'

@description('Monthly limit in your billing currency (e.g. USD).')
param amount int = 50

@description('Where to send the alert. Replace with your real email at deploy time.')
param alertEmail string = 'you@example.com'

@description('First day of the current month, format YYYY-MM-01.')
param startDate string = '2026-07-01'

@description('An end date within 10 years.')
param endDate string = '2027-07-01'

resource budget 'Microsoft.Consumption/budgets@2023-11-01' = {
  name: budgetName
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
      endDate: endDate
    }
    notifications: {
      // Warn at 80% of the budget (actual spend).
      alertAt80Percent: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        contactEmails: [
          alertEmail
        ]
        thresholdType: 'Actual'
      }
      // Warn earlier, at 100% of the FORECAST (predicted to overspend).
      forecastOver100Percent: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        contactEmails: [
          alertEmail
        ]
        thresholdType: 'Forecasted'
      }
    }
  }
}

output budgetId string = budget.id
