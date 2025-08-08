;; =============================================================================
;; NEURAL FORGE - AI MODEL MARKETPLACE
;; For training data, pre-trained models, and inference APIs
;; =============================================================================

;; Constants
(define-constant platform-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-payment (err u103))
(define-constant err-model-exists (err u104))

;; Data Variables
(define-data-var marketplace-fee-percent uint u250) ;; 2.5% fee (250 basis points)

;; Data Maps
(define-map ai-models 
  { model-id: (string-ascii 64) }
  {
    trainer: principal,
    model-name: (string-utf8 100),
    description: (string-utf8 500),
    model-type: (string-ascii 32), ;; "llm", "vision", "audio", "multimodal"
    inference-cost: uint,
    training-cost: uint,
    total-inferences: uint,
    total-revenue: uint,
    active: bool,
    checkpoint-hash: (string-ascii 64) ;; Points to model weights/metadata
  }
)

(define-map model-subscriptions
  { researcher: principal, model-id: (string-ascii 64) }
  {
    subscription-type: (string-ascii 16), ;; "monthly" or "pay-per-use"
    expires-at: uint,
    inferences-remaining: uint,
    total-paid: uint
  }
)

(define-map model-reviews
  { model-id: (string-ascii 64), reviewer: principal }
  {
    rating: uint, ;; 1-5 stars
    review: (string-utf8 500),
    block-height: uint
  }
)

(define-map trainer-earnings principal uint)

;; Read-only functions
(define-read-only (get-model (model-id (string-ascii 64)))
  (map-get? ai-models { model-id: model-id })
)

(define-read-only (get-subscription (researcher principal) (model-id (string-ascii 64)))
  (map-get? model-subscriptions { researcher: researcher, model-id: model-id })
)

(define-read-only (get-model-review (model-id (string-ascii 64)) (reviewer principal))
  (map-get? model-reviews { model-id: model-id, reviewer: reviewer })
)

(define-read-only (get-trainer-earnings (trainer principal))
  (default-to u0 (map-get? trainer-earnings trainer))
)

(define-read-only (can-use-model (researcher principal) (model-id (string-ascii 64)))
  (let (
    (subscription (get-subscription researcher model-id))
  )
    (match subscription
      sub-data 
        (or 
          (> (get inferences-remaining sub-data) u0)
          (> (get expires-at sub-data) block-height)
        )
      false
    )
  )
)

;; Public functions

;; Register a new AI model
(define-public (register-model 
    (model-id (string-ascii 64))
    (model-name (string-utf8 100))
    (description (string-utf8 500))
    (model-type (string-ascii 32))
    (inference-cost uint)
    (training-cost uint)
    (checkpoint-hash (string-ascii 64))
  )
  (let (
    (existing-model (get-model model-id))
  )
    (asserts! (is-none existing-model) err-model-exists)
    (ok (map-set ai-models 
      { model-id: model-id }
      {
        trainer: tx-sender,
        model-name: model-name,
        description: description,
        model-type: model-type,
        inference-cost: inference-cost,
        training-cost: training-cost,
        total-inferences: u0,
        total-revenue: u0,
        active: true,
        checkpoint-hash: checkpoint-hash
      }
    ))
  )
)

;; Subscribe to a model (monthly)
(define-public (subscribe-monthly (model-id (string-ascii 64)))
  (let (
    (model (unwrap! (get-model model-id) err-not-found))
    (monthly-price (get training-cost model))
    (marketplace-fee (/ (* monthly-price (var-get marketplace-fee-percent)) u10000))
    (trainer-payment (- monthly-price marketplace-fee))
  )
    (asserts! (get active model) err-not-found)
    (try! (stx-transfer? monthly-price tx-sender (as-contract tx-sender)))
    
    ;; Update model stats
    (map-set ai-models 
      { model-id: model-id }
      (merge model {
        total-inferences: (+ (get total-inferences model) u1),
        total-revenue: (+ (get total-revenue model) monthly-price)
      })
    )
    
    ;; Create subscription
    (map-set model-subscriptions
      { researcher: tx-sender, model-id: model-id }
      {
        subscription-type: "monthly",
        expires-at: (+ block-height u4320), ;; ~30 days (144 blocks/day)
        inferences-remaining: u0,
        total-paid: monthly-price
      }
    )
    
    ;; Pay trainer
    (map-set trainer-earnings 
      (get trainer model)
      (+ (get-trainer-earnings (get trainer model)) trainer-payment)
    )
    
    (ok true)
  )
)

;; Buy pay-per-inference credits
(define-public (buy-inference-credits (model-id (string-ascii 64)) (num-inferences uint))
  (let (
    (model (unwrap! (get-model model-id) err-not-found))
    (total-cost (* (get inference-cost model) num-inferences))
    (marketplace-fee (/ (* total-cost (var-get marketplace-fee-percent)) u10000))
    (trainer-payment (- total-cost marketplace-fee))
  )
    (asserts! (get active model) err-not-found)
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    
    ;; Update model stats
    (map-set ai-models 
      { model-id: model-id }
      (merge model {
        total-inferences: (+ (get total-inferences model) u1),
        total-revenue: (+ (get total-revenue model) total-cost)
      })
    )
    
    ;; Update or create subscription
    (let (
      (existing-sub (get-subscription tx-sender model-id))
    )
      (match existing-sub
        sub-data
          (map-set model-subscriptions
            { researcher: tx-sender, model-id: model-id }
            (merge sub-data {
              inferences-remaining: (+ (get inferences-remaining sub-data) num-inferences),
              total-paid: (+ (get total-paid sub-data) total-cost)
            })
          )
        (map-set model-subscriptions
          { researcher: tx-sender, model-id: model-id }
          {
            subscription-type: "pay-per-use",
            expires-at: u0,
            inferences-remaining: num-inferences,
            total-paid: total-cost
          }
        )
      )
    )
    
    ;; Pay trainer
    (map-set trainer-earnings 
      (get trainer model)
      (+ (get-trainer-earnings (get trainer model)) trainer-payment)
    )
    
    (ok true)
  )
)

;; Run inference (decrements usage or checks subscription)
(define-public (run-inference (model-id (string-ascii 64)))
  (let (
    (model (unwrap! (get-model model-id) err-not-found))
    (subscription (unwrap! (get-subscription tx-sender model-id) err-unauthorized))
  )
    (asserts! (get active model) err-not-found)
    
    ;; Check if user can use the model
    (if (is-eq (get subscription-type subscription) "pay-per-use")
      (begin
        (asserts! (> (get inferences-remaining subscription) u0) err-unauthorized)
        (map-set model-subscriptions
          { researcher: tx-sender, model-id: model-id }
          (merge subscription {
            inferences-remaining: (- (get inferences-remaining subscription) u1)
          })
        )
      )
      (asserts! (> (get expires-at subscription) block-height) err-unauthorized)
    )
    
    (ok true)
  )
)

;; Leave a review for a model
(define-public (review-model 
    (model-id (string-ascii 64))
    (rating uint)
    (review (string-utf8 500))
  )
  (let (
    (model (unwrap! (get-model model-id) err-not-found))
  )
    (asserts! (and (>= rating u1) (<= rating u5)) (err u105))
    (asserts! (can-use-model tx-sender model-id) err-unauthorized)
    
    (ok (map-set model-reviews
      { model-id: model-id, reviewer: tx-sender }
      {
        rating: rating,
        review: review,
        block-height: block-height
      }
    ))
  )
)

;; Trainer withdraws earnings
(define-public (withdraw-earnings)
  (let (
    (earnings (get-trainer-earnings tx-sender))
  )
    (asserts! (> earnings u0) err-not-found)
    (try! (as-contract (stx-transfer? earnings tx-sender tx-sender)))
    (map-set trainer-earnings tx-sender u0)
    (ok earnings)
  )
)

;; Update model (only by trainer)
(define-public (update-model 
    (model-id (string-ascii 64))
    (model-name (string-utf8 100))
    (description (string-utf8 500))
    (inference-cost uint)
    (training-cost uint)
    (checkpoint-hash (string-ascii 64))
    (active bool)
  )
  (let (
    (model (unwrap! (get-model model-id) err-not-found))
  )
    (asserts! (is-eq (get trainer model) tx-sender) err-unauthorized)
    
    (ok (map-set ai-models 
      { model-id: model-id }
      (merge model {
        model-name: model-name,
        description: description,
        inference-cost: inference-cost,
        training-cost: training-cost,
        checkpoint-hash: checkpoint-hash,
        active: active
      })
    ))
  )
)

;; Admin functions (contract owner only)
(define-public (set-marketplace-fee (new-fee-percent uint))
  (begin
    (asserts! (is-eq tx-sender platform-owner) err-owner-only)
    (asserts! (<= new-fee-percent u1000) (err u106)) ;; Max 10%
    (ok (var-set marketplace-fee-percent new-fee-percent))
  )
)