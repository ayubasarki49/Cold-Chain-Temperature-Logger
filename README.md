# 🧊 Cold-Chain-Temperature-Logger

A Stacks blockchain smart contract for tracking temperature data in cold supply chains, ensuring product integrity from origin to destination.

## 🌟 Features

- **🚚 Shipment Management**: Create and track cold-chain shipments with custom temperature thresholds
- **🌡️ Temperature Logging**: Record temperature readings with location and timestamp data
- **⚠️ Violation Tracking**: Automatic detection and counting of temperature threshold violations
- **👥 Authorization System**: Manage authorized temperature loggers and shipment owners
- **📊 Compliance Monitoring**: Check shipment compliance and generate health reports
- **🚨 Emergency Controls**: Emergency stop functionality for critical situations

## 📋 Contract Overview

The contract manages shipments through three main entities:
- **Shipments**: Core shipment data with temperature thresholds and status
- **Temperature Logs**: Individual temperature readings with metadata
- **Authorized Loggers**: Principals authorized to record temperature data

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js for testing

### Installation
```bash
git clone <repository-url>
cd Cold-Chain-Temperature-Logger
clarinet check
```

## 📖 Usage

### 🆕 Creating a Shipment
```clarity
(contract-call? .Cold-Chain-Temperature-Logger create-shipment "SHIP001" -5 5)
```

### 🌡️ Logging Temperature
```clarity
(contract-call? .Cold-Chain-Temperature-Logger log-temperature "SHIP001" 2 "Warehouse A")
```

### 👤 Authorizing Loggers
```clarity
(contract-call? .Cold-Chain-Temperature-Logger authorize-logger 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### ✅ Completing Shipment
```clarity
(contract-call? .Cold-Chain-Temperature-Logger complete-shipment "SHIP001")
```

## 🔍 Query Functions

### 📦 Get Shipment Information
```clarity
(contract-call? .Cold-Chain-Temperature-Logger get-shipment "SHIP001")
```

### 📈 Get Temperature Statistics
```clarity
(contract-call? .Cold-Chain-Temperature-Logger get-temperature-stats "SHIP001")
```

### 🏥 Check Compliance
```clarity
(contract-call? .Cold-Chain-Temperature-Logger check-compliance "SHIP001")
```

### 📊 Get Shipment Summary
```clarity
(contract-call? .Cold-Chain-Temperature-Logger get-shipment-summary "SHIP001")
```

## ⚙️ Configuration

### Temperature Limits
- **Minimum**: -30°C
- **Maximum**: +10°C
- **Violation Threshold**: 2 violations maximum

### Status Types
- `active`: Shipment is being monitored
- `completed`: Shipment successfully delivered
- `emergency`: Emergency stop triggered
- `damaged`: Shipment marked as damaged

## 🧪 Testing

Run the test suite:
```bash
npm install
npm test
```

## 🛡️ Security Features

- **Owner-only functions**: Contract management restricted to owner
- **Authorization system**: Only authorized loggers can record temperatures
- **Validation checks**: Input validation for temperature ranges and shipment data
- **Emergency controls**: Emergency stop functionality for critical situations

## 📚 API Reference

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `create-shipment` | Create new shipment | `shipment-id`, `min-temp`, `max-temp` |
| `log-temperature` | Record temperature reading | `shipment-id`, `temperature`, `location` |
| `complete-shipment` | Mark shipment as completed | `shipment-id` |
| `authorize-logger` | Grant logging permissions | `logger` |
| `revoke-logger` | Remove logging permissions | `logger` |
| `emergency-stop-shipment` | Emergency stop monitoring | `shipment-id` |
| `update-temperature-thresholds` | Modify temperature limits | `shipment-id`, `new-min-temp`, `new-max-temp` |
| `transfer-shipment-ownership` | Transfer shipment ownership | `shipment-id`, `new-owner` |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-shipment` | Get shipment details | Shipment data |
| `get-temperature-log` | Get specific temperature log | Temperature log data |
| `get-shipment-summary` | Get comprehensive shipment overview | Summary with stats |
| `check-compliance` | Check shipment compliance status | Compliance report |
| `get-temperature-stats` | Get temperature statistics | Statistical summary |
| `validate-temperature-chain` | Validate complete temperature chain | Validation result |


## 📄 License

This project is licensed under the MIT License.
