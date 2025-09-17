(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-SHIPMENT-NOT-FOUND (err u404))
(define-constant ERR-INVALID-TEMPERATURE (err u400))
(define-constant ERR-SHIPMENT-ALREADY-EXISTS (err u409))
(define-constant ERR-SHIPMENT-COMPLETED (err u410))
(define-constant ERR-INVALID-STATUS (err u411))
(define-constant ERR-TEMPERATURE-VIOLATION (err u412))
(define-constant ERR-ALERT-NOT-FOUND (err u413))
(define-constant ERR-ALERT-ALREADY-EXISTS (err u414))
(define-constant ERR-INVALID-ALERT-TYPE (err u415))

(define-constant MIN-TEMP -30)
(define-constant MAX-TEMP 10)
(define-constant VIOLATION-THRESHOLD u2)

(define-data-var contract-owner principal tx-sender)

(define-map shipments
    { shipment-id: (string-ascii 32) }
    {
        owner: principal,
        status: (string-ascii 10),
        start-block: uint,
        end-block: (optional uint),
        min-temp-threshold: int,
        max-temp-threshold: int,
        violation-count: uint,
        created-at: uint,
    }
)

(define-map temperature-logs
    {
        shipment-id: (string-ascii 32),
        log-id: uint,
    }
    {
        temperature: int,
        timestamp: uint,
        recorder: principal,
        location: (string-ascii 50),
    }
)

(define-map shipment-log-counter
    { shipment-id: (string-ascii 32) }
    { counter: uint }
)

(define-map authorized-loggers
    { logger: principal }
    { authorized: bool }
)

(define-map alert-rules
    {
        shipment-id: (string-ascii 32),
        alert-id: (string-ascii 20),
    }
    {
        alert-type: (string-ascii 20),
        threshold-value: uint,
        is-active: bool,
        created-by: principal,
        created-at: uint,
        triggered-count: uint,
        last-triggered: (optional uint),
    }
)

(define-map active-alerts
    {
        shipment-id: (string-ascii 32),
        alert-id: (string-ascii 20),
    }
    {
        severity: (string-ascii 10),
        message: (string-ascii 100),
        triggered-at: uint,
        acknowledged: bool,
        acknowledged-by: (optional principal),
    }
)

(define-map shipment-alert-counter
    { shipment-id: (string-ascii 32) }
    { counter: uint }
)

(define-read-only (get-contract-owner)
    (var-get contract-owner)
)

(define-read-only (is-authorized-logger (logger principal))
    (default-to false
        (get authorized (map-get? authorized-loggers { logger: logger }))
    )
)

(define-read-only (get-alert-rule
        (shipment-id (string-ascii 32))
        (alert-id (string-ascii 20))
    )
    (map-get? alert-rules {
        shipment-id: shipment-id,
        alert-id: alert-id,
    })
)

(define-read-only (get-active-alert
        (shipment-id (string-ascii 32))
        (alert-id (string-ascii 20))
    )
    (map-get? active-alerts {
        shipment-id: shipment-id,
        alert-id: alert-id,
    })
)

(define-read-only (get-shipment-alert-count (shipment-id (string-ascii 32)))
    (default-to u0
        (get counter
            (map-get? shipment-alert-counter { shipment-id: shipment-id })
        ))
)

(define-read-only (is-alert-active
        (shipment-id (string-ascii 32))
        (alert-id (string-ascii 20))
    )
    (match (get-alert-rule shipment-id alert-id)
        rule-data (get is-active rule-data)
        false
    )
)

(define-read-only (get-shipment (shipment-id (string-ascii 32)))
    (map-get? shipments { shipment-id: shipment-id })
)

(define-read-only (get-temperature-log
        (shipment-id (string-ascii 32))
        (log-id uint)
    )
    (map-get? temperature-logs {
        shipment-id: shipment-id,
        log-id: log-id,
    })
)

(define-read-only (get-shipment-log-count (shipment-id (string-ascii 32)))
    (default-to u0
        (get counter (map-get? shipment-log-counter { shipment-id: shipment-id }))
    )
)

(define-read-only (get-latest-temperature (shipment-id (string-ascii 32)))
    (let ((log-count (get-shipment-log-count shipment-id)))
        (if (> log-count u0)
            (map-get? temperature-logs {
                shipment-id: shipment-id,
                log-id: (- log-count u1),
            })
            none
        )
    )
)

(define-read-only (is-temperature-in-range
        (temperature int)
        (min-temp int)
        (max-temp int)
    )
    (and (>= temperature min-temp) (<= temperature max-temp))
)

(define-read-only (get-shipment-violations (shipment-id (string-ascii 32)))
    (match (get-shipment shipment-id)
        shipment-data (get violation-count shipment-data)
        u0
    )
)

(define-read-only (get-temperature-stats (shipment-id (string-ascii 32)))
    (let (
            (log-count (get-shipment-log-count shipment-id))
            (shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND))
        )
        (ok {
            count: log-count,
            avg-temp: 0,
            min-temp: (get min-temp-threshold shipment-data),
            max-temp: (get max-temp-threshold shipment-data),
        })
    )
)

(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

(define-public (authorize-logger (logger principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set authorized-loggers { logger: logger } { authorized: true })
        (ok true)
    )
)

(define-public (revoke-logger (logger principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set authorized-loggers { logger: logger } { authorized: false })
        (ok true)
    )
)

(define-public (create-alert-rule
        (shipment-id (string-ascii 32))
        (alert-id (string-ascii 20))
        (alert-type (string-ascii 20))
        (threshold-value uint)
    )
    (let ((shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND)))
        (asserts!
            (or
                (is-eq tx-sender (get owner shipment-data))
                (is-eq tx-sender (var-get contract-owner))
            )
            ERR-NOT-AUTHORIZED
        )
        (asserts! (is-none (get-alert-rule shipment-id alert-id))
            ERR-ALERT-ALREADY-EXISTS
        )
        (asserts!
            (or
                (is-eq alert-type "temp-violation")
                (is-eq alert-type "duration-limit")
                (is-eq alert-type "compliance-risk")
                (is-eq alert-type "trend-warning")
            )
            ERR-INVALID-ALERT-TYPE
        )
        (map-set alert-rules {
            shipment-id: shipment-id,
            alert-id: alert-id,
        } {
            alert-type: alert-type,
            threshold-value: threshold-value,
            is-active: true,
            created-by: tx-sender,
            created-at: stacks-block-height,
            triggered-count: u0,
            last-triggered: none,
        })
        (let ((current-count (get-shipment-alert-count shipment-id)))
            (if (is-eq current-count u0)
                (map-set shipment-alert-counter { shipment-id: shipment-id } { counter: u1 })
                (map-set shipment-alert-counter { shipment-id: shipment-id } { counter: (+ current-count u1) })
            )
        )
        (ok true)
    )
)

(define-public (toggle-alert-rule
        (shipment-id (string-ascii 32))
        (alert-id (string-ascii 20))
        (active bool)
    )
    (let (
            (shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND))
            (rule-data (unwrap! (get-alert-rule shipment-id alert-id) ERR-ALERT-NOT-FOUND))
        )
        (asserts!
            (or
                (is-eq tx-sender (get owner shipment-data))
                (is-eq tx-sender (var-get contract-owner))
            )
            ERR-NOT-AUTHORIZED
        )
        (map-set alert-rules {
            shipment-id: shipment-id,
            alert-id: alert-id,
        }
            (merge rule-data { is-active: active })
        )
        (ok true)
    )
)

(define-public (trigger-alert
        (shipment-id (string-ascii 32))
        (alert-id (string-ascii 20))
        (severity (string-ascii 10))
        (message (string-ascii 100))
    )
    (let (
            (rule-data (unwrap! (get-alert-rule shipment-id alert-id) ERR-ALERT-NOT-FOUND))
            (shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND))
        )
        (asserts!
            (or
                (is-authorized-logger tx-sender)
                (is-eq tx-sender (get owner shipment-data))
                (is-eq tx-sender (var-get contract-owner))
            )
            ERR-NOT-AUTHORIZED
        )
        (asserts! (get is-active rule-data) ERR-INVALID-STATUS)
        (map-set active-alerts {
            shipment-id: shipment-id,
            alert-id: alert-id,
        } {
            severity: severity,
            message: message,
            triggered-at: stacks-block-height,
            acknowledged: false,
            acknowledged-by: none,
        })
        (map-set alert-rules {
            shipment-id: shipment-id,
            alert-id: alert-id,
        }
            (merge rule-data {
                triggered-count: (+ (get triggered-count rule-data) u1),
                last-triggered: (some stacks-block-height),
            })
        )
        (ok true)
    )
)

(define-public (acknowledge-alert
        (shipment-id (string-ascii 32))
        (alert-id (string-ascii 20))
    )
    (let (
            (alert-data (unwrap! (get-active-alert shipment-id alert-id) ERR-ALERT-NOT-FOUND))
            (shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND))
        )
        (asserts!
            (or
                (is-eq tx-sender (get owner shipment-data))
                (is-authorized-logger tx-sender)
            )
            ERR-NOT-AUTHORIZED
        )
        (map-set active-alerts {
            shipment-id: shipment-id,
            alert-id: alert-id,
        }
            (merge alert-data {
                acknowledged: true,
                acknowledged-by: (some tx-sender),
            })
        )
        (ok true)
    )
)

(define-public (create-shipment
        (shipment-id (string-ascii 32))
        (min-temp int)
        (max-temp int)
    )
    (begin
        (asserts! (is-none (get-shipment shipment-id))
            ERR-SHIPMENT-ALREADY-EXISTS
        )
        (asserts!
            (and
                (>= min-temp MIN-TEMP)
                (<= max-temp MAX-TEMP)
                (< min-temp max-temp)
            )
            ERR-INVALID-TEMPERATURE
        )
        (map-set shipments { shipment-id: shipment-id } {
            owner: tx-sender,
            status: "active",
            start-block: stacks-block-height,
            end-block: none,
            min-temp-threshold: min-temp,
            max-temp-threshold: max-temp,
            violation-count: u0,
            created-at: stacks-block-height,
        })
        (map-set shipment-log-counter { shipment-id: shipment-id } { counter: u0 })
        (ok true)
    )
)

(define-public (log-temperature
        (shipment-id (string-ascii 32))
        (temperature int)
        (location (string-ascii 50))
    )
    (let (
            (shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND))
            (log-count (get-shipment-log-count shipment-id))
            (is-violation (not (is-temperature-in-range temperature
                (get min-temp-threshold shipment-data)
                (get max-temp-threshold shipment-data)
            )))
        )
        (asserts!
            (or (is-authorized-logger tx-sender) (is-eq tx-sender (get owner shipment-data)))
            ERR-NOT-AUTHORIZED
        )
        (asserts! (is-eq (get status shipment-data) "active")
            ERR-SHIPMENT-COMPLETED
        )
        (map-set temperature-logs {
            shipment-id: shipment-id,
            log-id: log-count,
        } {
            temperature: temperature,
            timestamp: stacks-block-height,
            recorder: tx-sender,
            location: location,
        })
        (map-set shipment-log-counter { shipment-id: shipment-id } { counter: (+ log-count u1) })
        (if is-violation
            (begin
                (map-set shipments { shipment-id: shipment-id }
                    (merge (unwrap-panic (get-shipment shipment-id)) { violation-count: (+ (get violation-count shipment-data) u1) })
                )
                (ok {
                    logged: true,
                    violation: true,
                })
            )
            (ok {
                logged: true,
                violation: false,
            })
        )
    )
)

(define-public (complete-shipment (shipment-id (string-ascii 32)))
    (let ((shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get owner shipment-data)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status shipment-data) "active")
            ERR-SHIPMENT-COMPLETED
        )
        (map-set shipments { shipment-id: shipment-id }
            (merge shipment-data {
                status: "completed",
                end-block: (some stacks-block-height),
            })
        )
        (ok true)
    )
)

(define-public (update-temperature-thresholds
        (shipment-id (string-ascii 32))
        (new-min-temp int)
        (new-max-temp int)
    )
    (let ((shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get owner shipment-data)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status shipment-data) "active")
            ERR-SHIPMENT-COMPLETED
        )
        (asserts!
            (and
                (>= new-min-temp MIN-TEMP)
                (<= new-max-temp MAX-TEMP)
                (< new-min-temp new-max-temp)
            )
            ERR-INVALID-TEMPERATURE
        )
        (map-set shipments { shipment-id: shipment-id }
            (merge shipment-data {
                min-temp-threshold: new-min-temp,
                max-temp-threshold: new-max-temp,
            })
        )
        (ok true)
    )
)

(define-public (transfer-shipment-ownership
        (shipment-id (string-ascii 32))
        (new-owner principal)
    )
    (let ((shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get owner shipment-data)) ERR-NOT-AUTHORIZED)
        (map-set shipments { shipment-id: shipment-id }
            (merge shipment-data { owner: new-owner })
        )
        (ok true)
    )
)

(define-public (emergency-stop-shipment (shipment-id (string-ascii 32)))
    (let ((shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND)))
        (asserts!
            (or
                (is-eq tx-sender (var-get contract-owner))
                (is-eq tx-sender (get owner shipment-data))
            )
            ERR-NOT-AUTHORIZED
        )
        (asserts! (is-eq (get status shipment-data) "active")
            ERR-SHIPMENT-COMPLETED
        )
        (map-set shipments { shipment-id: shipment-id }
            (merge shipment-data {
                status: "emergency",
                end-block: (some stacks-block-height),
            })
        )
        (ok true)
    )
)

(define-read-only (get-shipment-summary (shipment-id (string-ascii 32)))
    (match (get-shipment shipment-id)
        shipment-data (ok {
            shipment-id: shipment-id,
            owner: (get owner shipment-data),
            status: (get status shipment-data),
            total-logs: (get-shipment-log-count shipment-id),
            violations: (get violation-count shipment-data),
            duration-blocks: (match (get end-block shipment-data)
                end-block (- end-block (get start-block shipment-data))
                (- stacks-block-height (get start-block shipment-data))
            ),
            temp-range: {
                min: (get min-temp-threshold shipment-data),
                max: (get max-temp-threshold shipment-data),
            },
        })
        ERR-SHIPMENT-NOT-FOUND
    )
)

(define-read-only (check-compliance (shipment-id (string-ascii 32)))
    (match (get-shipment shipment-id)
        shipment-data (let ((violations (get violation-count shipment-data)))
            (ok {
                compliant: (<= violations VIOLATION-THRESHOLD),
                violation-count: violations,
                max-allowed: VIOLATION-THRESHOLD,
            })
        )
        ERR-SHIPMENT-NOT-FOUND
    )
)

(define-read-only (get-shipment-duration (shipment-id (string-ascii 32)))
    (match (get-shipment shipment-id)
        shipment-data (ok (match (get end-block shipment-data)
            end-block (- end-block (get start-block shipment-data))
            (- stacks-block-height (get start-block shipment-data))
        ))
        ERR-SHIPMENT-NOT-FOUND
    )
)

(define-read-only (is-shipment-compliant (shipment-id (string-ascii 32)))
    (match (get-shipment shipment-id)
        shipment-data (ok (<= (get violation-count shipment-data) VIOLATION-THRESHOLD))
        ERR-SHIPMENT-NOT-FOUND
    )
)

(define-read-only (get-active-shipments-count)
    (ok u0)
)

(define-read-only (get-completed-shipments-count)
    (ok u0)
)

(define-public (batch-create-shipments (shipment-data (list 5 {
    id: (string-ascii 32),
    min-temp: int,
    max-temp: int,
})))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (fold process-shipment-creation shipment-data (ok u0))
    )
)

(define-private (process-shipment-creation
        (data {
            id: (string-ascii 32),
            min-temp: int,
            max-temp: int,
        })
        (result (response uint uint))
    )
    (match result
        success-count (let ((creation-result (create-shipment (get id data) (get min-temp data)
                (get max-temp data)
            )))
            (match creation-result
                success (ok (+ success-count u1))
                error (err error)
            )
        )
        error-val
        result
    )
)

(define-read-only (validate-temperature-chain (shipment-id (string-ascii 32)))
    (let (
            (shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND))
            (log-count (get-shipment-log-count shipment-id))
            (violations (get violation-count shipment-data))
        )
        (ok {
            valid-chain: (and
                (> log-count u0)
                (<= violations VIOLATION-THRESHOLD)
                (not (is-eq (get status shipment-data) "emergency"))
            ),
            total-readings: log-count,
            violations: violations,
            status: (get status shipment-data),
        })
    )
)

(define-public (mark-shipment-damaged (shipment-id (string-ascii 32)))
    (let ((shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND)))
        (asserts!
            (or
                (is-eq tx-sender (var-get contract-owner))
                (is-eq tx-sender (get owner shipment-data))
            )
            ERR-NOT-AUTHORIZED
        )
        (map-set shipments { shipment-id: shipment-id }
            (merge shipment-data {
                status: "damaged",
                end-block: (some stacks-block-height),
            })
        )
        (ok true)
    )
)

(define-read-only (get-shipment-alerts (shipment-id (string-ascii 32)))
    (let ((shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND)))
        (ok {
            high-violations: (> (get violation-count shipment-data) VIOLATION-THRESHOLD),
            emergency-status: (is-eq (get status shipment-data) "emergency"),
            damaged-status: (is-eq (get status shipment-data) "damaged"),
            active-monitoring: (is-eq (get status shipment-data) "active"),
        })
    )
)

(define-public (update-shipment-status
        (shipment-id (string-ascii 32))
        (new-status (string-ascii 10))
    )
    (let ((shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get owner shipment-data)) ERR-NOT-AUTHORIZED)
        (asserts!
            (or
                (is-eq new-status "active")
                (is-eq new-status "completed")
                (is-eq new-status "emergency")
                (is-eq new-status "damaged")
            )
            ERR-INVALID-STATUS
        )
        (let ((should-end (or
                (is-eq new-status "completed")
                (is-eq new-status "emergency")
                (is-eq new-status "damaged")
            )))
            (map-set shipments { shipment-id: shipment-id }
                (merge shipment-data {
                    status: new-status,
                    end-block: (if should-end
                        (some stacks-block-height)
                        none
                    ),
                })
            )
            (ok true)
        )
    )
)

(define-read-only (get-logger-activity (logger principal))
    (ok {
        is-authorized: (is-authorized-logger logger),
        total-logs: u0,
    })
)

(define-public (reset-violation-count (shipment-id (string-ascii 32)))
    (let ((shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND)))
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set shipments { shipment-id: shipment-id }
            (merge shipment-data { violation-count: u0 })
        )
        (ok true)
    )
)

(define-read-only (calculate-shipment-compliance-score (shipment-id (string-ascii 32)))
    (let (
            (shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND))
            (log-count (get-shipment-log-count shipment-id))
            (violations (get violation-count shipment-data))
        )
        (if (is-eq log-count u0)
            (ok u100)
            (let ((compliance-percentage (- u100 (* (/ (* violations u100) log-count) u1))))
                (ok (if (< compliance-percentage u0)
                    u0
                    compliance-percentage
                ))
            )
        )
    )
)

(define-read-only (get-shipment-health-status (shipment-id (string-ascii 32)))
    (let (
            (shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND))
            (latest-temp (get-latest-temperature shipment-id))
            (violations (get violation-count shipment-data))
        )
        (ok {
            status: (get status shipment-data),
            has-recent-data: (is-some latest-temp),
            violation-level: (if (<= violations VIOLATION-THRESHOLD)
                "low"
                "high"
            ),
            monitoring-active: (is-eq (get status shipment-data) "active"),
        })
    )
)

(define-public (bulk-authorize-loggers (loggers (list 10 principal)))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (fold authorize-single-logger loggers (ok u0))
    )
)

(define-private (authorize-single-logger
        (logger principal)
        (result (response uint uint))
    )
    (match result
        success-count (let ((auth-result (authorize-logger logger)))
            (match auth-result
                success (ok (+ success-count u1))
                error (err error)
            )
        )
        error-val
        result
    )
)

(define-read-only (get-global-statistics)
    (ok {
        total-shipments: u0,
        active-shipments: u0,
        completed-shipments: u0,
        emergency-shipments: u0,
        total-temperature-logs: u0,
        contract-owner: (var-get contract-owner),
    })
)

(define-public (archive-old-shipments (cutoff-block uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (< cutoff-block stacks-block-height) ERR-INVALID-STATUS)
        (ok true)
    )
)

(define-read-only (get-shipment-alert-summary (shipment-id (string-ascii 32)))
    (let ((shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND)))
        (ok {
            total-alert-rules: (get-shipment-alert-count shipment-id),
            violation-count: (get violation-count shipment-data),
            shipment-status: (get status shipment-data),
            monitoring-duration: (match (get end-block shipment-data)
                end-block (- end-block (get start-block shipment-data))
                (- stacks-block-height (get start-block shipment-data))
            ),
        })
    )
)

(define-read-only (check-alert-conditions (shipment-id (string-ascii 32)))
    (let (
            (shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND))
            (violations (get violation-count shipment-data))
            (log-count (get-shipment-log-count shipment-id))
            (duration (- stacks-block-height (get start-block shipment-data)))
        )
        (ok {
            should-alert-violations: (> violations VIOLATION-THRESHOLD),
            should-alert-duration: (> duration u1000),
            should-alert-compliance: (and (> log-count u0) (> (/ (* violations u100) log-count) u20)),
            current-violations: violations,
            current-duration: duration,
            compliance-score: (if (> log-count u0)
                (- u100 (/ (* violations u100) log-count))
                u100
            ),
        })
    )
)

(define-read-only (get-unacknowledged-alerts-count (shipment-id (string-ascii 32)))
    (ok u0)
)

(define-read-only (evaluate-temperature-trends (shipment-id (string-ascii 32)))
    (let (
            (shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND))
            (latest-temp (get-latest-temperature shipment-id))
            (violations (get violation-count shipment-data))
        )
        (ok {
            has-recent-data: (is-some latest-temp),
            trend-concerning: (> violations u3),
            requires-attention: (and
                (is-eq (get status shipment-data) "active")
                (> violations u1)
            ),
            temperature-stability: (if (<= violations u1)
                "stable"
                "unstable"
            ),
        })
    )
)

(define-public (auto-check-and-trigger-alerts (shipment-id (string-ascii 32)))
    (let (
            (shipment-data (unwrap! (get-shipment shipment-id) ERR-SHIPMENT-NOT-FOUND))
            (conditions (unwrap-panic (check-alert-conditions shipment-id)))
        )
        (asserts!
            (or
                (is-authorized-logger tx-sender)
                (is-eq tx-sender (var-get contract-owner))
            )
            ERR-NOT-AUTHORIZED
        )
        (asserts! (is-eq (get status shipment-data) "active")
            ERR-SHIPMENT-COMPLETED
        )
        (if (get should-alert-violations conditions)
            (begin
                (unwrap-panic (trigger-alert shipment-id "violation-alert" "high"
                    "Temperature violations exceeded threshold"
                ))
                (ok {
                    violations-triggered: true,
                    duration-triggered: false,
                    compliance-triggered: false,
                })
            )
            (if (get should-alert-duration conditions)
                (begin
                    (unwrap-panic (trigger-alert shipment-id "duration-alert" "medium"
                        "Shipment duration exceeds normal limits"
                    ))
                    (ok {
                        violations-triggered: false,
                        duration-triggered: true,
                        compliance-triggered: false,
                    })
                )
                (if (get should-alert-compliance conditions)
                    (begin
                        (unwrap-panic (trigger-alert shipment-id "compliance-alert" "high"
                            "Compliance score below acceptable threshold"
                        ))
                        (ok {
                            violations-triggered: false,
                            duration-triggered: false,
                            compliance-triggered: true,
                        })
                    )
                    (ok {
                        violations-triggered: false,
                        duration-triggered: false,
                        compliance-triggered: false,
                    })
                )
            )
        )
    )
)
