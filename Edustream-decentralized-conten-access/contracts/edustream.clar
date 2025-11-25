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