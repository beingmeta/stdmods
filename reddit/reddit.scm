;;; -*- Mode: Scheme; Character-encoding: utf-8; -*-
;;; Copyright (C) 2005-2017 beingmeta, inc.  All rights reserved.

(in-module 'reddit)

(use-module '{fdweb texttools reflection varconfig logger})
(use-module '{oauth})

(module-export! '{reddit/creds reddit.creds reddit.opts
		  reddit/get reddit/post reddit/thing})

(define reddit.oauth #f)
(define reddit.creds #f)

(define-init reddit.opts #[])

(define reddit:keep {})
(varconfig! reddit:keep reddit:keep)
(define reddit:drop {})
(varconfig! reddit:drop reddit:drop)

(define (reddit/creds)
  (or (and reddit.creds
	   (future? (getopt reddit.creds 'expires))
	   reddit.creds)
      (let* ((spec (if reddit.oauth
		       (if (pair? reddit.oauth)
			   reddit.oauth
			   (cons reddit.oauth (oauth/provider 'reddit)))
		       (oauth/provider 'reddit)))
	     (creds (oauth/getclient spec)))
	(set! reddit.creds creds)
	creds)))

(module-export! '{subreddits/search subreddits/new subreddits/popular
		  subreddits/default subreddits/gold
		  subreddits/subscribed})

(define (reddit/get endpoint (opts #f) (args #f) (conn))
  (default! conn 
    (if (testopt opts 'realm) opts
	(getopt opts 'creds (reddit/creds))))
  (if opts
      (set! opts (cons opts reddit.opts))
      (set! opts reddit.opts))
  (let* ((r (oauth/call conn 'GET endpoint args opts))
	 (response (car r)))
    (if (getopt opts 'raw #f)
	response
	(reddit/thing response opts))))

(define (reddit/post conn endpoint content (args #f))
  (let ((r (oauth/call conn 'GET endpoint args))
	(response (car r)))
    (reddit/thing response)))

(define (subreddits/search cl string)
  (oauth/call cl 'GET "/subreddits/search" `#["q" ,string]))
(define (subreddits/new cl)
  (oauth/call cl 'GET "/subreddits/new"))
(define (subreddits/popular cl)
  (oauth/call cl 'GET "/subreddits/popular"))
(define (subreddits/gold cl)
  (oauth/call cl 'GET "/subreddits/gold"))
(define (subreddits/default cl)
  (oauth/call cl 'GET "/subreddits/default"))

(define (reddit/thing json (opts #f))
  (cond ((vector? json) 
	 (forseq (elt json) (reddit/thing elt opts)))
	((not (table? json)) json)
	((test json 'data)
	 (if (has-prefix (get json 'kind) "t")
	     (reddit/thing (get json 'data) opts)
	     (if (test (get json 'data) 'children)
		 (let ((data (reddit/thing (get json 'data) opts)))
		   (store! data (intern (upcase (get json 'kind)))
			   (get data 'children))
		   (drop! data 'children)
		   data)
		 (frame-create #f 
		   (intern (upcase (get json 'kind)))
		   (reddit/thing (get json 'data) opts)))))
	((test json 'children)
	 (frame-create #f
	   'children 
	   (for-choices (child (elts (get json 'children)))
	     (reddit/thing child opts))
	   'before (get json 'before) 'after (get json 'after)))
	(else (let* ((name (get json 'name))
		     (created (->exact (get json 'created)))
		     (created_utc (->exact (get json 'created_utc)))
		     (output (frame-create #f
			       'reddid name '%id (get json 'name)))
		     (keys (getkeys json))
		     (drop (choice (getopt opts 'drop {})
				   (cdr (pick (getopt opts 'pref {}) keys)))))
		(store! output 'created
			(mktime created_utc 'gmtoff (- created created_utc)))
		(do-choices (slot (difference keys drop))
		  (let ((value (get json slot)))
		    (cond ((and (not (overlaps? slot reddit:keep))
				(or (fail? value)
				    (zero? value)
				    (overlaps? slot reddit:drop)
				    (overlaps? value {#f "" #()})
				    (and (table? value) (fail? (getkeys value))))))
			  ((string? value)
			   (store! output slot (decode-entities (get json slot))))
			  ((overlaps? slot '{created created_utc}))
			  (else 
			   (store! output slot (reddit/thing value opts))))))
		output))))
