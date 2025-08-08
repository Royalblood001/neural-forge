# Neural Forge - AI Model Marketplace

A decentralized marketplace built on the Stacks blockchain for AI model training data, pre-trained models, and inference APIs. Neural Forge enables AI researchers and developers to monetize their models while providing easy access to AI capabilities through smart contracts.

## 🚀 Features

- **Model Registration**: Register and list AI models (LLM, Vision, Audio, Multimodal)
- **Flexible Pricing**: Support for both monthly subscriptions and pay-per-inference models
- **Revenue Sharing**: Automatic distribution of payments between trainers and platform
- **Model Reviews**: Community-driven rating system for model quality
- **Secure Payments**: All transactions handled through Stacks (STX) blockchain
- **Trainer Earnings**: Built-in earnings tracking and withdrawal system

## 📋 Contract Overview

The Neural Forge smart contract is written in Clarity and provides the following core functionality:

### Model Types Supported
- `llm` - Large Language Models
- `vision` - Computer Vision Models  
- `audio` - Audio Processing Models
- `multimodal` - Multi-modal AI Models

### Subscription Types
- **Monthly**: Fixed monthly fee with unlimited inferences during subscription period
- **Pay-per-use**: Purchase specific number of inference credits

## 🔧 Core Functions

### For Model Trainers

#### `register-model`
Register a new AI model on the marketplace.

```clarity
(register-model 
  "model-123"              ;; model-id
  u"GPT-Style Language Model"  ;; model-name
  u"High-performance language model for text generation"  ;; description
  "llm"                    ;; model-type
  u1000                    ;; inference-cost (in STX micro-units)
  u50000                   ;; training-cost/monthly-price
  "hash123..."             ;; checkpoint-hash
)
```

#### `update-model`
Update model details, pricing, or status (trainer only).

#### `withdraw-earnings`
Withdraw accumulated earnings from model usage.

### For Researchers/Users

#### `subscribe-monthly`
Subscribe to a model with unlimited monthly access.

```clarity
(subscribe-monthly "model-123")
```

#### `buy-inference-credits`
Purchase specific number of inference credits.

```clarity
(buy-inference-credits "model-123" u100)  ;; Buy 100 inferences
```

#### `run-inference`
Execute an inference (decrements credits or checks subscription validity).

```clarity
(run-inference "model-123")
```

#### `review-model`
Leave a rating and review for a model you've used.

```clarity
(review-model "model-123" u5 u"Excellent model quality and speed!")
```

### Read-Only Functions

- `get-model`: Retrieve model information
- `get-subscription`: Check user's subscription status
- `get-model-review`: Get review for a model
- `get-trainer-earnings`: Check trainer's earnings
- `can-use-model`: Verify if user can access a model

## 💰 Economics

### Platform Fee
- Default marketplace fee: **2.5%** (250 basis points)
- Adjustable by contract owner (max 10%)
- Automatically deducted from payments to trainers

### Revenue Distribution
```
User Payment = Base Price
├── Platform Fee (2.5%)
└── Trainer Payment (97.5%)
```

## 🔒 Security Features

- **Owner Controls**: Platform owner can adjust marketplace fees
- **Trainer Authorization**: Only model trainers can update their models
- **Subscription Validation**: Automatic checking of subscription validity
- **Payment Security**: All payments handled through STX transfers
- **Review Authorization**: Only users with active subscriptions can review

## 📊 Data Structure

### AI Models
```clarity
{
  trainer: principal,
  model-name: string,
  description: string,  
  model-type: string,
  inference-cost: uint,
  training-cost: uint,
  total-inferences: uint,
  total-revenue: uint,
  active: bool,
  checkpoint-hash: string
}
```

### Subscriptions
```clarity
{
  subscription-type: string,  // "monthly" or "pay-per-use"
  expires-at: uint,
  inferences-remaining: uint,
  total-paid: uint
}
```

## 🚀 Getting Started

### Prerequisites
- Stacks wallet with STX tokens
- Access to Stacks blockchain (testnet or mainnet)

### Deployment
1. Deploy the contract to Stacks blockchain
2. The deployer becomes the platform owner
3. Set marketplace fee if different from default 2.5%

### For Model Trainers
1. Prepare your model and host checkpoint data
2. Register your model with `register-model`
3. Set competitive pricing for inferences and subscriptions
4. Monitor usage and withdraw earnings regularly

### For Researchers
1. Browse available models using read-only functions
2. Choose between monthly subscription or pay-per-use
3. Purchase access using `subscribe-monthly` or `buy-inference-credits`
4. Use models with `run-inference`
5. Leave reviews to help the community

## 🔍 Error Codes

- `u100`: Owner-only function called by non-owner
- `u101`: Resource not found
- `u102`: Unauthorized access
- `u103`: Insufficient payment
- `u104`: Model already exists
- `u105`: Invalid rating (must be 1-5)
- `u106`: Fee percentage too high (max 10%)

## 🏗️ Technical Details

- **Blockchain**: Stacks (STX)
- **Language**: Clarity Smart Contracts  
- **Block Time**: ~10 minutes (Bitcoin anchored)
- **Monthly Subscription**: 4,320 blocks (~30 days)

## 🤝 Contributing

Neural Forge is a decentralized platform. Model trainers and researchers contribute by:
- Registering high-quality models
- Providing honest reviews and ratings
- Reporting issues or suggesting improvements
- Building applications on top of the marketplace
