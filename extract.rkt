#lang racket/base

(require net/url
         racket/cmdline
         racket/file
         racket/list
         racket/port
         srfi/19
         tasks
         threading)

(define (add-days d n)
  (time-utc->date (add-duration (date->time-utc d)
                                (make-time 'time-duration 0 (* 60 60 24 n)))))

(define (days-between d e)
  (/ (time-second (time-difference (date->time-utc e) (date->time-utc d))) (* 60 60 24)))

(define (download-day date)
  (make-directory* (string-append "/var/tmp/ecnet/earnings-calendar/" (date->string (current-date) "~1")))
  (call-with-output-file (string-append "/var/tmp/ecnet/earnings-calendar/" (date->string (current-date) "~1") "/"
                                        (date->string date "~1") ".json")
    (λ (out)
      (~> (string-append "https://api.earningscalendar.net/?date=" (date->string date "~Y~m~d"))
          (string->url _)
          (get-pure-port _)
          (copy-port _ out)))
    #:exists 'append))

(define end-date (make-parameter (add-days (current-date) (* 7 6))))

(define start-date (make-parameter (current-date)))

(command-line
 #:program "racket extract.rkt"
 #:once-each
 [("-e" "--end-date") ed
                      "End date. Defaults to today + 6 weeks"
                      (end-date (string->date ed "~Y-~m-~d"))]
 [("-s" "--start-date") sd
                        "Start date. Defaults to today"
                        (start-date (string->date sd "~Y-~m-~d"))])

(define delay-interval 10)

(with-task-server (for-each (λ (i) (schedule-delayed-task (λ () (download-day (add-days (start-date) i)))
                                                          (* i 10)))
                            (range 0 (days-between (start-date) (end-date))))
  ; add a final task that will halt the task server
  (schedule-delayed-task (λ () (schedule-stop-task)) (* delay-interval (days-between (start-date) (end-date))))
  (run-tasks))
