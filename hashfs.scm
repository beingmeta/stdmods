;;; -*- Mode: Scheme; Character-encoding: utf-8; -*-
;;; Copyright (C) 2005-2020 beingmeta, inc.  All rights reserved.
;;; Copyright (C) 2020-2021 Kenneth Haase (ken.haase@alum.mit.edu)

(in-module 'hashfs)

;;; Virtual file system implemented on top of hashtables

(use-module '{net/mimetable ezrecords texttools gpath})
(define %used_modules '{ezrecords net/mimetable})

(module-export! '{hashfs? hashfs/open hashfs/save!
		  hashfs/get hashfs/get+ hashfs/info
		  hashfs/list hashfs/list+
		  hashfs/commit!
		  hashfs/string})

(defrecord (hashfs OPAQUE)
  files (label (getuuid)) (source #f))

(define (hashfs/open (label #f) (init (make-hashtable)))
  (when (or (hashtable? label) (gpath? label))
    (set! init label) (set! label #f))
  (when (not label) (set! label (getuuid)))
  (cons-hashfs (if (not init) (make-hashtable) (hashfs-init init))
	       label (and (gpath? init) init)))
(define (hashfs/string hashfs path)
  (stringout "hashfs:" path
    "(" (or (hashfs-source hashfs) (hashfs-label hashfs)) ")"))

(define (hashfs-init init)
  (if (hashtable? init) init
      (if (gpath? init)
	  (if (gp/exists? init)
	      (let ((value (gp/fetch init)))
		(if (and value (exists? value) (packet? value))
		    (let ((hs (packet->dtype (gp/fetch init))))
		      (if (hashtable? hs) hs
			  (error "Invalid HASHFS init" init)))
		    (packet->dtype (gp/fetch init))))
	      (make-hashtable))
	  (error "Invalid HASHFS init" init))))

(define (hashfs/save! hashfs path data (type))
  (default! type (path->mimetype
		  path (if (packet? data) "application" "text")))
  (unless (has-prefix path "/") (set! path (glom "/" path)))
  (store! (hashfs-files hashfs) path
	  `#[data ,data ctype ,type modified ,(gmtimestamp)]))

(define (hashfs/get hashfs path)
  (unless (has-prefix path "/") (set! path (glom "/" path)))
  (get (get (hashfs-files hashfs) path) 'data))
(define (hashfs/get+ hashfs path)
  (unless (has-prefix path "/") (set! path (glom "/" path)))
  (let ((info (get (hashfs-files hashfs) path)))
    (tryif (exists? info)
      `#[content ,(get info 'data) ctype ,(get info 'ctype)
	 modified ,(get info 'modified)])))

(define (hashfs/info hashfs path)
  (unless (has-prefix path "/") (set! path (glom "/" path)))
  (tryif (test (hashfs-files hashfs) path)
    `#[path ,path gpath (gp/mkpath hashfs path)
       gpathstring (hashfs/string hashfs path)
       ctype ,(get (get (hashfs-files hashfs) path) 'ctype)
       modified ,(get (get (hashfs-files hashfs) path) 'ctype)]))

(define (hashfs/list hashfs (match #f))
  (let* ((paths (pickstrings (getkeys (hashfs-files hashfs))))
	 (matching (if match
		       (filter-choices (path paths)
			 (textsearch (qc match) path))
		       paths)))
    (for-choices (path matching)
      (if (has-prefix path "/") (slice  path 1) path))))
(define (hashfs/list+ hashfs (match #f))
  (let* ((paths (pickstrings (getkeys (hashfs-files hashfs))))
	 (matching (if match
		       (filter-choices (path paths)
			 (textsearch (qc match) path))
		       paths)))
    (for-choices (path matching)
      `#[path ,(if (has-prefix path "/") (slice  path 1) path)
	 gpath (gp/mkpath hashfs path)
	 gpathstring (hashfs/string hashfs path)
	 ctype ,(get (get (hashfs-files hashfs) path) 'ctype)
	 modified ,(get (get (hashfs-files hashfs) path) 'ctype)])))

(define (hashfs/commit! hashfs)
  (if (hashfs-source hashfs)
      (gp/save! (hashfs-source hashfs)
	(dtype->packet (hashfs-files hashfs)))
      (error "This HASHFS doesn't have a source" hashfs)))

;;;; GPATH handlers

(define (gpath/info hashfs path (opts #f))
  (hashfs/info hashfs path))
(define (gpath/fetch hashfs path (opts #f))
  (hashfs/get+ hashfs path))
(define (gpath/content hashfs path (opts #f))
  (hashfs/get hashfs path))
(define (gpath/write! hashfs path content ctype (opts #f))
  (default! ctype 
    (getopt opts 'mimetype
	    (path->mimetype
	     path (if (packet? content) "application" "text"))))
  (hashfs/save! hashfs path content ctype))

(kno/handler! 'hashfs gpath/info)
(kno/handler! 'hashfs gpath/fetch)
(kno/handler! 'hashfs gpath/content)
(kno/handler! 'hashfs gpath/write!)
