;; -*- Coding: utf-8 -*-

;; English Morphology
;;  Copyright (C) 2001 Kenneth Haase, All Rights Reserved
;;  Copyright (C) 2001-2018 beingmeta, inc.

(in-module 'morph/freqs)

(use-module 'texttools)

(module-export!
 '{english-word-freqs english-root-freqs
   english-word-relfreqs english-root-relfreqs
   dataroot})

(define dataroot (get-component "data/"))

(define english-word-freqs
  (read-xtype (get-component "data/en-word-freq.xtable")))
(define english-root-freqs
  (read-xtype (get-component "data/en-root-freq.xtable")))
(define english-word-relfreqs
  (read-xtype (get-component "data/en-word-relfreq.xtable")))
(define english-root-relfreqs
  (read-xtype (get-component "data/en-root-relfreq.xtable")))




