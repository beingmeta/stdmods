;;; -*- Mode: Scheme; Character-encoding: utf-8; -*-
;;; Copyright (C) 2005-2020 beingmeta, inc.  All rights reserved.
;;; Copyright (C) 2020-2021 beingmeta, llc.

(in-module 'tests/mttools)

(use-module 'kno/mttools)

(module-export! 'test-mttools)

(config! 'bricosource "/data/bg/brico")
(config! 'cachelevel 2)
(use-module '{kno/mttools})
(define all-slots (make-hashset))

(define (test-mttools pool)
  (do-choices-mt (f (pool-elts pool) 4 8192 mt/fetchoids)
     (hashset-add! all-slots (getslots f))))

