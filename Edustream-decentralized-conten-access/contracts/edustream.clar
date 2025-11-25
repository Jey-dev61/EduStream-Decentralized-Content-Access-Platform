;; EduStream - Decentralized Educational Content Access Platform
;; Allows students to access educational content with blockchain verification

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-input (err u104))
(define-constant err-already-revoked (err u105))
(define-constant err-inactive-content (err u106))
(define-constant err-insufficient-payment (err u107))

;; Data Variables
(define-data-var content-nonce uint u0)
(define-data-var platform-fee uint u1000000) ;; 1 STX in microSTX
(define-data-var total-revenue uint u0)

;; Data Maps
(define-map contents
    uint
    {
        title: (string-ascii 100),
        creator: principal,
        ipfs-hash: (string-ascii 64),
        category: (string-ascii 50),
        active: bool,
        price: uint,
        total-views: uint
    }
)

(define-map user-access
    { user: principal, content-id: uint }
    { 
        access-granted: bool, 
        timestamp: uint,
        expiry: uint
    }
)

(define-map content-ratings
    { user: principal, content-id: uint }
    {
        rating: uint,
        review: (string-ascii 200)
    }
)

(define-map creator-stats
    principal
    {
        total-contents: uint,
        total-earnings: uint,
        verified: bool
    }
)

(define-map user-subscriptions
    principal
    {
        active: bool,
        expiry-block: uint,
        tier: (string-ascii 20)
    }
)

;; #[allow(unchecked_data)]
;; Add new educational content
(define-public (add-content (title (string-ascii 100)) (ipfs-hash (string-ascii 64)) (category (string-ascii 50)) (price uint))
    ;; #[allow(unchecked_data)]
    (let
        (
            (content-id (var-get content-nonce))
            (creator-info (default-to 
                { total-contents: u0, total-earnings: u0, verified: false }
                (map-get? creator-stats tx-sender)))
        )
        (asserts! (> (len title) u0) err-invalid-input)
        (asserts! (> (len ipfs-hash) u0) err-invalid-input)
        (map-set contents content-id {
            title: title,
            creator: tx-sender,
            ipfs-hash: ipfs-hash,
            category: category,
            active: true,
            price: price,
            total-views: u0
        })
        (map-set creator-stats tx-sender 
            (merge creator-info { total-contents: (+ (get total-contents creator-info) u1) }))
        (var-set content-nonce (+ content-id u1))
        (ok content-id)
    )
)

;; #[allow(unchecked_data)]
;; Update content activity status
(define-public (toggle-content-status (content-id uint))
    ;; #[allow(unchecked_data)]
    (let
        (
            (content (unwrap! (map-get? contents content-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get creator content)) err-unauthorized)
        (ok (map-set contents content-id 
            (merge content { active: (not (get active content)) })
        ))
    )
)

;; #[allow(unchecked_data)]
;; Update content price
(define-public (update-content-price (content-id uint) (new-price uint))
    ;; #[allow(unchecked_data)]
    (let
        (
            (content (unwrap! (map-get? contents content-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get creator content)) err-unauthorized)
        (ok (map-set contents content-id 
            (merge content { price: new-price })
        ))
    )
)

;; #[allow(unchecked_data)]
;; Grant access to a student
(define-public (grant-access (user principal) (content-id uint) (duration uint))
    ;; #[allow(unchecked_data)]
    (let
        (
            (content (unwrap! (map-get? contents content-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get creator content)) err-unauthorized)
        (asserts! (get active content) err-inactive-content)
        (ok (map-set user-access { user: user, content-id: content-id }
            { 
                access-granted: true, 
                timestamp: stacks-block-height,
                expiry: (+ stacks-block-height duration)
            }
        ))
    )
)

;; #[allow(unchecked_data)]
;; Revoke access from a user
(define-public (revoke-access (user principal) (content-id uint))
    ;; #[allow(unchecked_data)]
    (let
        (
            (content (unwrap! (map-get? contents content-id) err-not-found))
            (access-info (unwrap! (map-get? user-access { user: user, content-id: content-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get creator content)) err-unauthorized)
        (asserts! (get access-granted access-info) err-already-revoked)
        (ok (map-set user-access { user: user, content-id: content-id }
            (merge access-info { access-granted: false })
        ))
    )
)

;; #[allow(unchecked_data)]
;; Purchase content access
(define-public (purchase-access (content-id uint) (payment uint))
    ;; #[allow(unchecked_data)]
    (let
        (
            (content (unwrap! (map-get? contents content-id) err-not-found))
            (creator (get creator content))
            (creator-info (default-to 
                { total-contents: u0, total-earnings: u0, verified: false }
                (map-get? creator-stats creator)))
        )
        (asserts! (get active content) err-inactive-content)
        (asserts! (>= payment (get price content)) err-insufficient-payment)
        
        ;; Update creator earnings
        (map-set creator-stats creator 
            (merge creator-info { total-earnings: (+ (get total-earnings creator-info) payment) }))
        
        ;; Grant access for 1000 blocks (~1 week)
        (map-set user-access { user: tx-sender, content-id: content-id }
            { 
                access-granted: true, 
                timestamp: stacks-block-height,
                expiry: (+ stacks-block-height u1000)
            })
        
        ;; Increment view count
        (map-set contents content-id 
            (merge content { total-views: (+ (get total-views content) u1) }))
        
        (var-set total-revenue (+ (var-get total-revenue) payment))
        (ok true)
    )
)

;; #[allow(unchecked_data)]
;; Rate and review content
(define-public (rate-content (content-id uint) (rating uint) (review (string-ascii 200)))
    ;; #[allow(unchecked_data)]
    (let
        (
            (content (unwrap! (map-get? contents content-id) err-not-found))
            (access-info (unwrap! (map-get? user-access { user: tx-sender, content-id: content-id }) err-unauthorized))
        )
        (asserts! (get access-granted access-info) err-unauthorized)
        (asserts! (<= rating u5) err-invalid-input)
        (ok (map-set content-ratings { user: tx-sender, content-id: content-id }
            { rating: rating, review: review }
        ))
    )
)

;; #[allow(unchecked_data)]
;; Subscribe to platform
(define-public (subscribe (tier (string-ascii 20)) (duration uint))
    ;; #[allow(unchecked_data)]
    (begin
        (asserts! (> duration u0) err-invalid-input)
        (ok (map-set user-subscriptions tx-sender
            {
                active: true,
                expiry-block: (+ stacks-block-height duration),
                tier: tier
            }
        ))
    )
)

;; #[allow(unchecked_data)]
;; Verify creator (owner only)
(define-public (verify-creator (creator principal))
    ;; #[allow(unchecked_data)]
    (let
        (
            (creator-info (default-to 
                { total-contents: u0, total-earnings: u0, verified: false }
                (map-get? creator-stats creator)))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set creator-stats creator 
            (merge creator-info { verified: true })
        ))
    )
)

;; #[allow(unchecked_data)]
;; Update platform fee (owner only)
(define-public (update-platform-fee (new-fee uint))
    ;; #[allow(unchecked_data)]
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set platform-fee new-fee))
    )
)

;; Get content details
(define-read-only (get-content (content-id uint))
    (map-get? contents content-id)
)

;; #[allow(unchecked_data)]
;; Check user access with expiry validation
(define-read-only (check-access (user principal) (content-id uint))
    ;; #[allow(unchecked_data)]
    (let
        (
            (access-info (default-to 
                { access-granted: false, timestamp: u0, expiry: u0 }
                (map-get? user-access { user: user, content-id: content-id })))
        )
        (if (and (get access-granted access-info) 
                 (< stacks-block-height (get expiry access-info)))
            access-info
            { access-granted: false, timestamp: u0, expiry: u0 }
        )
    )
)

;; Get total content count
(define-read-only (get-content-count)
    (ok (var-get content-nonce))
)

;; Get creator statistics
(define-read-only (get-creator-stats (creator principal))
    (map-get? creator-stats creator)
)

;; Get content rating
(define-read-only (get-rating (user principal) (content-id uint))
    (map-get? content-ratings { user: user, content-id: content-id })
)

;; Get user subscription
(define-read-only (get-subscription (user principal))
    (map-get? user-subscriptions user)
)

;; #[allow(unchecked_data)]
;; Check if subscription is active
(define-read-only (is-subscription-active (user principal))
    ;; #[allow(unchecked_data)]
    (let
        (
            (sub-info (map-get? user-subscriptions user))
        )
        (match sub-info
            subscription (and (get active subscription) 
                             (< stacks-block-height (get expiry-block subscription)))
            false
        )
    )
)

;; Get platform fee
(define-read-only (get-platform-fee)
    (ok (var-get platform-fee))
)

;; Get total platform revenue
(define-read-only (get-total-revenue)
    (ok (var-get total-revenue))
)

;; #[allow(unchecked_data)]
;; Check if content is accessible by user
(define-read-only (can-access-content (user principal) (content-id uint))
    ;; #[allow(unchecked_data)]
    (let
        (
            (content (map-get? contents content-id))
            (access-info (map-get? user-access { user: user, content-id: content-id }))
        )
        (match content
            content-data
                (match access-info
                    access-data
                        (and (get active content-data)
                             (get access-granted access-data)
                             (< stacks-block-height (get expiry access-data)))
                    false)
            false)
    )
)