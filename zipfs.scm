;;; -*- Mode: Scheme; Character-encoding: utf-8; -*-
;;; Copyright (C) 2005-2020 beingmeta, inc.  All rights reserved.
;;; Copyright (C) 2020-2022 Kenneth Haase (ken.haase@alum.mit.edu).

(in-module 'zipfs)

;;; Virtual file system implemented on top of zipfiles and hashtables

(use-module '{net/mimetable ezrecords texttools 
	      logger gpath ziptools})
(define %used_modules '{ezrecords net/mimetable})

(module-export! '{zipfs? zipfs/open zipfs/make zipfs/save!
		  zipfs/filename zipfs/string
		  zipfs/get zipfs/get+ zipfs/info 
		  zipfs/list zipfs/list+
		  zipfs-source 
		  zipfs/commit!})

(defrecord (zipfs OPAQUE)
  files (zip #f) (opts #f) (source #f)
  (sync #f) (bemeta #f))

(define (zipfs/open (source #f) (opts #f) (create))
  (when (and (not opts) (table? source) (not (gpath? source)))
    (set! opts source)
    (set! source (getopt opts 'source #f)))
  (default! create (getopt opts 'create #f))
  (when source (set! source (->gpath source)))
  (when (and (not create) (or (not source) (not (gp/exists? source))))
    (if source 
	(irritant source |NoSuchFile|)
	(error |NoSourceSpecified|
	    "Use zipfs/make to create an anonymous ZIPFS")))
  (let* ((zipfile (get-zipfile source opts))
	 (has-metadata (zip/exists? zipfile ".zipfs/bemeta"))
	 (zipfs (cons-zipfs (make-hashtable) zipfile opts source 
			    (getopt opts 'sync #f)
			    (getopt opts 'bemeta has-metadata))))
    (when (and (not has-metadata) (getopt opts 'bemeta))
      (zip/add! zipfile ".zipfs/bemeta" (get (gmtimestamp) 'iso)))
    zipfs))
(define (zipfs/make (source #f) (opts #f) (create #t))
  (when (and (not opts) (table? source) (not (gpath? source)))
    (set! opts source)
    (set! source (getopt opts 'source #f)))
  (when source (set! source (->gpath source)))
  (let* ((zipfile (get-zipfile source opts))
	 (has-metadata (zip/exists? zipfile ".zipfs/bemeta"))
	 (zipfs (cons-zipfs (make-hashtable) zipfile opts source 
			    (getopt opts 'sync #f)
			    (getopt opts 'bemeta has-metadata))))
    (when (and (not has-metadata) (getopt opts 'bemeta))
      (zip/add! zipfile ".zipfs/bemeta" (get (gmtimestamp) 'iso)))
    zipfs))

(define (zipfs/string zipfs path)
  (if path
      (stringout "zipfs:" path "(" (gpath->string (zipfs-source zipfs)) ")")
      (stringout "zipfs:" "(" (gpath->string (zipfs-source zipfs)) ")")))

(define (zipfs->string zipfs)
  (stringout "#<ZIPFS "
    (when (zipfs-source zipfs) (write (gpath->string (zipfs-source zipfs))))
    " "
    (write (zip/filename (zipfs-zip zipfs)))
    ">"))
(compound-set-stringfn! 'ZIPFS zipfs->string)

(define (zipfs/filename zipfs)
  (zip/filename (zipfs-zip zipfs)))

(define (get-zipfile source opts (copy))
  (default! copy (getopt opts 'copy #f))
  (cond ((zipfile? source) source)
	((and source (gp/exists? source) copy 
	      (not (getopt opts 'overwrite)))
	 (irritant source |ZipFSConflict|
		   " already exists, can't copy from " copy))
	((and source (gp/localpath? source) (gp/exists? source))
	 (if (getopt opts 'overwrite)
	     (begin (move-file! source (zip-backup-file source))
	       (zip/make source))
	     (zip/open source)))
	((gp/localpath? source) (zip/make source))
	(else (let* ((tmpdir (getopt opts 'tmpdir 
				     (tempdir (getopt opts 'tmplate)
					      (getopt opts 'keeptemp))))
		     (name (getopt opts 'name
				   (if source (gp/basename source)
				       (if copy (gp/basename copy)
					   "zipfs.zip"))))
		     (path (mkpath tmpdir name))
		     (zip #f))
		(cond ((and source (gp/exists? source) 
			    (not (getopt opts 'overwrite)))
		       (gp/copy! source path)
		       (set! zip (zip/open path opts)))
		      ((and copy (gp/exists? copy))
		       (gp/copy! copy path)
		       (set! zip (zip/open path opts))))
		(or zip (zip/make path))))))

(define (zip-backup-file source)
  (string-subst source ".zip" (glom (millitime) ".zip")))

(define (zipfs/save! zipfs path data (type) (metadata #f))
  (default! type 
    (getopt metadata 'content-type 
	    (path->mimetype path (if (packet? data) "application" "text"))))
  (when (and (not metadata) (table? type))
    (set! metadata type)
    (set! type (path->mimetype path (if (packet? data) "application" "text"))))
  (if metadata
      (set! metadata (deep-copy metadata))
      (set! metadata (frame-create #f)))
  (store! metadata 'content-type type)
  (store! metadata 'last-modified (gmtimestamp))
  (when (zipfs-bemeta zipfs)
    (zip/add! (zipfs-zip zipfs)
	      (glom ".zipfs/" path)
	      (dtype->packet metadata)))
  (store! metadata 'content data)
  (store! (zipfs-files zipfs) path metadata)
  (zip/add! (zipfs-zip zipfs) path data)
  (when (zipfs-sync zipfs) (zip/close (zipfs-zip zipfs))))

(define (zip-info zipfs zip path opts)
  (tryif (zip/exists? zip path)
    (let* ((ctype (path->mimetype path #f))
	   (encoding (path->encoding path))
	   (istext (and ctype (mimetype/text? ctype) (not encoding)))
	   (charset (and istext (ctype->charset ctype)))
	   (entry (frame-create #f
		    'gpath (cons zipfs path)
		    'gpathstring (gpath->string (cons zipfs path))
		    'rootpath path
		    'content-type (tryif ctype ctype)
		    'charset 
		    (if (string? charset) charset (if charset "utf-8" {}))
		    'content-length (tryif (bound? zip/getsize)
				      (zip/getsize zip path))
		    'last-modified (tryif (bound? zip/modtime)
				     (zip/modtime zip path)))))
      entry)))

(define (cached-content files zip path content opts)
  (let* ((ctype (getopt opts 'content-type
			(path->mimetype path #f (getopt opts 'typemap))))
	 (encoding (getopt opts 'encoding (path->encoding path)))
	 (istext (and ctype (mimetype/text? ctype) (not encoding)))
	 (charset (and istext (ctype->charset ctype)))
	 (content (zip/get zip path))
	 (entry (frame-create #f
		  'content
		  (cond ((and (string? content) istext) content)
			((and (packet? content) istext)
			 (packet->string content charset))
			((packet? content) content)
			((string? content) (string->packet content charset))
			(else (irritant content "Not a string or packet")))
		  'content-type (tryif ctype ctype)
		  'content-length (length content)
		  'charset (if (string? charset) charset (if charset "utf-8" {}))
		  'last-modified (tryif (bound? zip/modtime)
				   (zip/modtime zip realpath))
		  'etag (packet->base16 (md5 content)))))
    (store! files path entry)
    entry))

(define (zipfs/get zipfs path (opts #f) (files) (zip))
  (set! files (zipfs-files zipfs))
  (set! zip (zipfs-zip zipfs))
  (try (get (get files path) 'content)
       (let ((content (zip/get (zipfs-zip zipfs) path)))
	 (if content
	     (get (cached-content files zip path content opts) 'content)
	     (fail)))))
(define (zipfs/get+ zipfs path (opts #f) (files) (zip))
  (set! files (zipfs-files zipfs))
  (set! zip (zipfs-zip zipfs))
  (try (get files path)
       (let ((content (zip/get (zipfs-zip zipfs) path)))
	 (if content
	     (cached-content files zip path content opts)
	     (fail)))))

(define (zipfs/info zipfs path)
  (zip-info zipfs (zipfs-zip zipfs) path #f))

(define (zipfs/list zipfs (prefix #f) (match #f))
  (let* ((paths (if prefix
		    (pick (pickstrings (zip/getfiles (zipfs-zip zipfs)))
			  has-prefix prefix)
		    (pickstrings (zip/getfiles (zipfs-zip zipfs)))))
	 (matching (if match
		       (filter-choices (path paths)
			 (textsearch (qc match) path))
		       paths)))
    (for-choices (path matching)
      (cons zipfs (if (has-prefix path "/") (slice  path 1) path)))))
(define (zipfs/list+ zipfs (prefix #f) (match #f))
  (let* ((paths (if prefix
		    (pick (pickstrings (zip/getfiles (zipfs-zip zipfs)))
			  has-prefix prefix)
		    (pickstrings (zip/getfiles (zipfs-zip zipfs)))))
	 (matching (if match
		       (filter-choices (path paths)
			 (textsearch (qc match) path))
		       paths))
	 (files (zipfs-files zipfs))
	 (zip (zipfs-zip zipfs)))
    (if prefix
	(for-choices (path matching)
	  (add-relpath (zip-info zipfs zip path #f)
		       prefix))
	(zip-info zipfs zip matching #f))))

(define (add-relpath info prefix)
  (modify-frame info 'relpath 
		(strip-prefix (get info 'rootpath) prefix)))

(define (zipfs/commit! zipfs)
  (if (zipfs-source zipfs)
      (begin (zip/close! (zipfs-zip zipfs))
	(unless (equal? (zipfs-source zipfs)
			(zip/filename (zipfs-zip zipfs)))
	  (loginfo |CopyingZIPFS|
	    "To " (zipfs-source zipfs)
	    " from "(zip/filename (zipfs-zip zipfs)))
	  (gp/save! (zipfs-source zipfs)
	      (filedata (zip/filename (zipfs-zip zipfs)))
	    "application/zip")))
      (error "This ZIPFS doesn't have a source" zipfs)))

;;;; GPATH handlers

(define (gpath/info zipfs path (opts #f))
  (zipfs-info zipfs path opts))
(define (gpath/fetch zipfs path (opts #f))
  (zipfs-get+ zipfs path opts))
(define (gpath/content zipfs path (opts #f))
  (zipfs-get zipfs path opts))
(define (gpath/write! zipfs path content ctype (opts #f))
  (default! ctype 
    (getopt opts 'mimetype
	    (path->mimetype
	     path (if (packet? data) "application" "text"))))
  (zipfs/save! zipfs path content ctype (getopt opts 'metadata #f)))
(define (gpath/open path opts) (zipfs/open path opts))

(kno/handler! 'zipfs gpath/info)
(kno/handler! 'zipfs gpath/fetch)
(kno/handler! 'zipfs gpath/content)
(kno/handler! 'zipfs gpath/open)
