(define-public (batch-log-temperatures (entries (list 50
    {
    shipment-id: (string-ascii 32),
    temperature: int,
    location: (string-ascii 50),
})))
    (ok (fold log-entry entries {
        logged: u0,
        violations: u0,
        failed: u0,
    }))
)

(define-private (log-entry
        (entry {
            shipment-id: (string-ascii 32),
            temperature: int,
            location: (string-ascii 50),
        })
        (summary {
            logged: uint,
            violations: uint,
            failed: uint,
        })
    )
    (let ((call-result (contract-call? .Cold-Chain-Temperature-Logger log-temperature
            (get shipment-id entry) (get temperature entry)
            (get location entry)
        )))
        (match call-result
            success
            {
                logged: (+ (get logged summary) u1),
                violations: (+ (get violations summary)
                    (if (get violation success)
                        u1
                        u0
                    )),
                failed: (get failed summary),
            }
            error-code
            {
                logged: (get logged summary),
                violations: (get violations summary),
                failed: (+ (get failed summary) u1),
            }
        )
    )
)
