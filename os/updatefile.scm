;;; -*- Mode: Scheme; Character-encoding: utf-8; -*-
;;; Copyright (C) 2005-2020 beingmeta, inc.  All rights reserved.
;;; Copyright (C) 2020-2022 Kenneth Haase (ken.haase@alum.mit.edu).

(in-module 'os/updatefile)

;;; This handles automatic updating of files into environments. 

(use-module 'fileio)

(module-export! '{updatefile updatefiles})

(define (needs-reload? file table)
  (or (fail? (get table file))
      (time-earlier? (get table file) (file-modtime file))))

(define updatefile
  (macro expr
    (let ((filename-expr (get-arg expr 1)))
      `(begin (default! %loadtimes (make-hashtable))
	      (let ((filename ,filename-expr))
		(when (,needs-reload? filename %loadtimes)
		  (load filename)
		  (store! %loadtimes filename (,file-modtime filename))))))))
(define updatefiles
  (macro expr
    (let ((filename-expr (get-arg expr 1)))
      `(begin (default! %loadtimes (make-hashtable))
	      (do-choices (filename (getkeys %loadtimes))
		(when (,needs-reload? filename %loadtimes)
		  (load filename)
		  (store! %loadtimes filename (,file-modtime filename))))))))






