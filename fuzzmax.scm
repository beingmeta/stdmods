;;; -*- Mode: Scheme; Character-encoding: utf-8; -*-
;;; Copyright (C) 2005-2018 beingmeta, inc.  All rights reserved.

(in-module 'fuzzmax)

(use-module 'ezstats)

(module-export! '{fuzzmax+ fuzzmax fuzzmax/thresh})

(define (fuzzmax+ scores (thresh 0.9))
  (let* ((maxval (table-maxval scores))
	 (meanthresh (* maxval thresh))
	 (allvals (rsorted (getvalues scores)))
	 (results (table-skim scores maxval))
	 (mean-score maxval)
	 (thresh maxval)
	 (n (length allvals))
	 (i 1))
    (while (< i n)
      (let* ((next (elt allvals i))
	     (new-results (table-skim scores next))
	     (new-mean (mean new-results scores)))
	(when (< new-mean meanthresh) (break))
	(set! thresh next)
	(set! results new-results)
	(set! i (1+ i))))
    (cons thresh (qc results))))

(define (fuzzmax scores (thresh 0.9))
  (cdr (fuzzmax+ scores thresh)))

(define (fuzzmax/thresh scores (thresh 0.9))
  (car (fuzzmax+ scores thresh)))

