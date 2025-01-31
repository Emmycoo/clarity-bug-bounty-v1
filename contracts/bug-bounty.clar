;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-invalid-status (err u104))
(define-constant err-not-hunter (err u105))

;; Define data vars
(define-map bounties
    { bounty-id: uint }
    {
        title: (string-ascii 100),
        description: (string-ascii 500),
        reward: uint,
        status: (string-ascii 20),
        hunter: (optional principal),
        dispute: (optional {
          reason: (string-ascii 200),
          resolved: bool
        })
    }
)

(define-data-var next-bounty-id uint u1)

;; Create a new bounty
(define-public (create-bounty (title (string-ascii 100)) (description (string-ascii 500)) (reward uint))
    (let
        (
            (bounty-id (var-get next-bounty-id))
        )
        (if (is-eq tx-sender contract-owner)
            (begin
                (map-insert bounties
                    { bounty-id: bounty-id }
                    {
                        title: title,
                        description: description,
                        reward: reward,
                        status: "open",
                        hunter: none,
                        dispute: none
                    }
                )
                (var-set next-bounty-id (+ bounty-id u1))
                (ok bounty-id)
            )
            err-owner-only
        )
    )
)

;; Submit bug report and claim bounty
(define-public (submit-bug (bounty-id uint))
    (let
        (
            (bounty (unwrap! (map-get? bounties { bounty-id: bounty-id }) err-not-found))
        )
        (if (is-eq (get status bounty) "open")
            (begin
                (map-set bounties
                    { bounty-id: bounty-id }
                    {
                        title: (get title bounty),
                        description: (get description bounty),
                        reward: (get reward bounty),
                        status: "submitted",
                        hunter: (some tx-sender),
                        dispute: none
                    }
                )
                (ok true)
            )
            err-already-exists
        )
    )
)

;; File a dispute
(define-public (file-dispute (bounty-id uint) (reason (string-ascii 200)))
    (let
        (
            (bounty (unwrap! (map-get? bounties { bounty-id: bounty-id }) err-not-found))
            (hunter (unwrap! (get hunter bounty) err-not-found))
        )
        (if (and (is-eq tx-sender hunter) (is-eq (get status bounty) "submitted"))
            (begin
                (map-set bounties
                    { bounty-id: bounty-id }
                    {
                        title: (get title bounty),
                        description: (get description bounty),
                        reward: (get reward bounty),
                        status: "disputed",
                        hunter: (some hunter),
                        dispute: (some {
                            reason: reason,
                            resolved: false
                        })
                    }
                )
                (ok true)
            )
            err-not-hunter
        )
    )
)

;; Resolve dispute
(define-public (resolve-dispute (bounty-id uint) (approve bool))
    (let
        (
            (bounty (unwrap! (map-get? bounties { bounty-id: bounty-id }) err-not-found))
            (hunter (unwrap! (get hunter bounty) err-not-found))
        )
        (if (and (is-eq tx-sender contract-owner) (is-eq (get status bounty) "disputed"))
            (begin
                (if approve
                    (begin
                        (try! (stx-transfer? (get reward bounty) tx-sender hunter))
                        (map-set bounties
                            { bounty-id: bounty-id }
                            {
                                title: (get title bounty),
                                description: (get description bounty),
                                reward: (get reward bounty),
                                status: "paid",
                                hunter: (some hunter),
                                dispute: (some {
                                    reason: (get reason (unwrap! (get dispute bounty) err-not-found)),
                                    resolved: true
                                })
                            }
                        ))
                    (begin
                        (map-set bounties
                            { bounty-id: bounty-id }
                            {
                                title: (get title bounty),
                                description: (get description bounty),
                                reward: (get reward bounty),
                                status: "rejected",
                                hunter: none,
                                dispute: (some {
                                    reason: (get reason (unwrap! (get dispute bounty) err-not-found)),
                                    resolved: true
                                })
                            }
                        ))
                )
                (ok true)
            )
            err-owner-only
        )
    )
)

;; Approve and pay bounty 
(define-public (approve-bounty (bounty-id uint))
    (let
        (
            (bounty (unwrap! (map-get? bounties { bounty-id: bounty-id }) err-not-found))
            (hunter (unwrap! (get hunter bounty) err-not-found))
        )
        (if (and (is-eq tx-sender contract-owner) (is-eq (get status bounty) "submitted"))
            (begin
                (try! (stx-transfer? (get reward bounty) tx-sender hunter))
                (map-set bounties
                    { bounty-id: bounty-id }
                    {
                        title: (get title bounty),
                        description: (get description bounty),
                        reward: (get reward bounty),
                        status: "paid",
                        hunter: (some hunter),
                        dispute: none
                    }
                )
                (ok true)
            )
            err-owner-only
        )
    )
)

;; Read only functions
(define-read-only (get-bounty (bounty-id uint))
    (map-get? bounties { bounty-id: bounty-id })
)

(define-read-only (get-next-id)
    (ok (var-get next-bounty-id))
)
