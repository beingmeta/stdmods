;;; -*- Mode: Scheme; Character-encoding: utf-8; -*-
;;; Copyright (C) 2005-2020 beingmeta, inc.  All rights reserved.
;;; Copyright (C) 2020-2022 Kenneth Haase (ken.haase@alum.mit.edu).

(in-module 'ezstats)

(module-export! '{mean avg stddev median gmean hmean
		  arithmetic-variance variance
		  arithmetic-mean harmonic-mean
		  standard-deviation}) 

;;; Most common functions

(defambda (mean x (fn #f) (vec)) 
  (set! vec
    (if (and (singleton? x) (or (vector? x) (list? x)))
	(->vector x)
	(choice->vector x)))
  (arithmetic-mean
   (cond ((not fn) vec)
	 ((applicable? fn) (forseq (v vec) (fn v)))
	 ((table? fn) (forseq (v vec) (get fn v)))
	 ((slotid? fn) (forseq (v vec) (get v fn)))
	 (else (irritant fn |InvalidFunction|)))))
(defambda (stddev x (fn #f) (vec))
  (set! vec
    (if (and (singleton? x) (or (vector? x) (list? x)))
	(->vector x)
	(choice->vector x)))
  (sqrt (arithmetic-variance
	 (cond ((not fn) vec)
	       ((applicable? fn) (forseq (v vec) (fn v)))
	       ((table? fn) (forseq (v vec) (get fn v)))
	       ((slotid? fn) (forseq (v vec) (get v fn)))
	       (else (irritant fn |InvalidFunction|))))))
;;; Arithmetic functions

(define (arithmetic-mean vec (weights #f) (inexact #t))
  (if weights
      (if (= (length vec) (length weights))
	  (arithmetic-mean (map * vec weights) #f inexact)
	  (irritant weights |LengthMismatch|
	    "Data length (" (length vec) ") != "
	    "weight length (" (length weights) ")"))
      (if inexact
	  (/~ (reduce + vec) (length vec))
	  (/ (reduce + vec) (length vec)))))
(define avg arithmetic-mean)

(define (arithmetic-variance vec (weights #f))
  (let ((avg (arithmetic-mean vec weights)))
    (/~ (reduce + (map (lambda (x) (* (- x avg) (- x avg))) vec))
	(length vec))))
(define variance arithmetic-variance)

(define (standard-deviation vec (weights #f))
  (sqrt (arithmetic-variance vec weights)))

;;; Utilities

(define-init >=0? (lambda (x) (>= x 0)))
(define-init <=0? (lambda (x) (<= x 0)))

;;; Other means

(define (geometric-mean vec (weights #f) (inexact #f))
  (if weights
      (if (= (length weights) (length vec))
	  (geometric-mean (map * weights vec) #f inexact)
	  (irritant weights |Vector/WeightsMismatch|
		    "The number of weights " (length weights) " "
		    "is not the same as the the length "
		    "of the input vector " (length vec)))
      (if (or (every? >=0? vec) (every? <=0? vec))
	  (let* ((len (length vec))
		 (product (reduce * vec))
		 (root (pow product (/~ len))))
	    (if (or inexact (inexact? product))
		(* 1.0 root)
		(let ((exact-root (->exact root))
		      (prod 1))
		  (dotimes (i len) (set! prod (* prod exact-root)))
		  (if (= prod product)
		      exact-root
		      root))))
	  (irritant vec |MixedNegativePositiveElements|))))
(defambda (gmean x (fn #f) (vec)) 
  (set! vec
    (if (and (singleton? x) (or (vector? x) (list? x)))
	(->vector x)
	(choice->vector x)))
  (geometric-mean
   (cond ((not fn) vec)
	 ((applicable? fn) (forseq (v vec) (fn v)))
	 ((table? fn) (forseq (v vec) (get fn v)))
	 (else (irritant fn |InvalidFunction|)))))

(define (harmonic-mean vec (weights #f) (drop-zeros #f) (inexact #f))
  (if (some? zero? vec)
      (if drop-zeros 
	  (harmonic-mean (remove-if zero? vec) weights)
	  (irritant vec |ZeroValuedElements|))
      (if weights
	  (if (= (length weights) (length vec))
	      (if inexact
		  (/~ (reduce + weights) (reduce + (map /~ weights vec)))
		  (/ (reduce + weights) (reduce + (map / weights vec))))
	      (irritant weights |Vector/WeightsMismatch|
			"The number of weights " (length weights) " "
			"is not the same as the the length "
			"of the input vector " (length vec)))
	  (if inexact
	      (/~ (length vec) (reduce + (map /~ vec)))
	      (/ (length vec) (reduce + (map / vec)))))))
(defambda (hmean x (fn #f) (vec)) 
  (set! vec
    (if (and (singleton? x) (or (vector? x) (list? x)))
	(->vector x)
	(choice->vector x)))
  (harmonic-mean
   (cond ((not fn) vec)
	 ((applicable? fn) (forseq (v vec) (fn v)))
	 ((table? fn) (forseq (v vec) (get fn v)))
	 (else (irritant fn |InvalidFunction|)))))

(define (median vec)
  (let* ((vec (sortvec vec)) 
	 (len (length vec))
	 (middle (quotient len 2)))
    (if (zero? (remainder len 2))
	(/~ (+ (elt vec middle) (elt vec (1+ middle))) 2)
	(elt vec middle))))

