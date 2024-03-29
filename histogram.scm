;;; -*- Mode: Scheme; Character-encoding: utf-8; -*-
;;; Copyright (C) 2005-2020 beingmeta, inc.  All rights reserved.
;;; Copyright (C) 2020-2022 Kenneth Haase (ken.haase@alum.mit.edu).

(in-module 'histogram)

;;; Computes index/table histograms

(defambda (index-histogram index (slotids #f) (normalize #f))
  (let* ((values (if slotids
		     (get (getkeys index) slotids)
		     (getkeys index)))
	 (histogram (make-hashtable)))
    (do-choices (value values)
      (hashtable-increment! histogram value
	  (choice-size (get index (cons slotids value)))))
    histogram))

(module-export! '{index-histogram})

