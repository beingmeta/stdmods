;;; -*- Mode: Scheme; Character-encoding: utf-8; -*-
;;; Copyright (C) 2005-2020 beingmeta, inc.  All rights reserved.
;;; Copyright (C) 2020-2022 Kenneth Haase (ken.haase@alum.mit.edu).

(in-module 'tracer)

;;; Simple tracing facility, not really used anymore.

(define tracelevel #f)

(define (tracep level)
  (and tracelevel (< level tracelevel)))

(define tracer
  (macro expr
    `(when (if (bound? tracelevel)
	       (< ,(second expr) tracelevel)
	       (tracep ,(second expr)))
       (message (elapsed-time) " " ,@(cdr (cdr expr))))))

(define tracelevel-config
  (slambda (var (val 'unbound))
    (if (eq? val 'unbound) tracelevel
	(set! tracelevel val))))
(config-def! 'tracelevel tracelevel-config)

(module-export! '{tracep tracer})
