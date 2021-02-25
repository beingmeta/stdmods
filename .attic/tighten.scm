;;; -*- Mode: Scheme; Character-encoding: utf-8; -*-
;;; Copyright (C) 2005-2020 beingmeta, inc.  All rights reserved.
;;; Copyright (C) 2020-2021 beingmeta, llc.

(in-module 'tighten)

(use-module 'optimize)

(define tighten! (within-module 'optimize optimize!))
(define tighten-procedure! (within-module 'optimize optimize-procedure!))
(define tighten-module! (within-module 'optimize optimize-module!))

(warning "The TIGHTEN module is deprecated, please use OPTIMIZE instead")

(module-export! '{tighten! tighten-procedure! tighten-module!})
