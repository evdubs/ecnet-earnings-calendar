#lang racket/base

(require db
         gregor
         json
         racket/cmdline
         racket/port
         racket/sequence
         racket/string
         threading)

(define base-folder (make-parameter "/var/tmp/ecnet/earnings-calendar"))

(define folder-date (make-parameter (today)))

(define db-user (make-parameter "user"))

(define db-name (make-parameter "local"))

(define db-pass (make-parameter ""))

(command-line
 #:program "racket transform-load.rkt"
 #:once-each
 [("-b" "--base-folder") folder
                         "Earnings Calendar base folder. Defaults to /var/tmp/ecnet/earnings-calendar"
                         (base-folder folder)]
 [("-d" "--folder-date") date
                         "Earnings Calendar folder date. Defaults to today"
                         (folder-date (iso8601->date date))]
 [("-n" "--db-name") name
                     "Database name. Defaults to 'local'"
                     (db-name name)]
 [("-p" "--db-pass") password
                     "Database password"
                     (db-pass password)]
 [("-u" "--db-user") user
                     "Database user name. Defaults to 'user'"
                     (db-user user)])

(define dbc (postgresql-connect #:user (db-user) #:database (db-name) #:password (db-pass)))

; we clean up the future part of the table in case earnings dates have been shifted
(query-exec dbc "
delete from
  ecnet.earnings_calendar
where
  date >= $1::text::date;
"
            (~t (folder-date) "yyyy-MM-dd"))

(parameterize ([current-directory (string-append (base-folder) "/" (~t (folder-date) "yyyy-MM-dd") "/")])
  (for ([p (sequence-filter (λ (p) (string-contains? (path->string p) ".json")) (in-directory))])
    (let ([file-name (string-append (base-folder) "/" (~t (folder-date) "yyyy-MM-dd") "/" (path->string p))]
          [date-of-earnings (string-replace (path->string p) ".json" "")])
      (call-with-input-file file-name
        (λ (in)
          (with-handlers ([exn:fail? (λ (e) (displayln (string-append "Failed to parse "
                                                                      file-name
                                                                      " for date "
                                                                      date-of-earnings))
                                       (displayln ((error-value->string-handler) e 1000)))])
            (~> (port->string in)
                (string->jsexpr _)
                (for-each (λ (ticker-when-hash)
                            (with-handlers ([exn:fail? (λ (e) (displayln (string-append "Failed to insert "
                                                                                        (hash-ref ticker-when-hash 'ticker)
                                                                                        " for date "
                                                                                        date-of-earnings))
                                                         (displayln ((error-value->string-handler) e 1000))
                                                         (rollback-transaction dbc))])
                              (start-transaction dbc)
                              (query-exec dbc "
insert into ecnet.earnings_calendar (
  act_symbol,
  date,
  \"when\"
) values (
  $1,
  $2::text::date,
  case $3
    when 'amc' then 'After market close'::ecnet.when
    when 'bmo' then 'Before market open'::ecnet.when
    when '--' then NULL
  end
) on conflict do nothing;
"
                                          (hash-ref ticker-when-hash 'ticker)
                                          date-of-earnings
                                          (hash-ref ticker-when-hash 'when))
                              (commit-transaction dbc))) _))))))))

; vacuum (garbage collect) and reindex table as we deleted from it earlier
(query-exec dbc "
vacuum full freeze analyze ecnet.earnings_calendar;
")

(query-exec dbc "
reindex table ecnet.earnings_calendar;
")

(disconnect dbc)
