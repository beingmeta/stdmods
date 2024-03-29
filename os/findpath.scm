;;; -*- Mode: Scheme; Character-encoding: utf-8; -*-
;;; Copyright (C) 2005-2020 beingmeta, inc.  All rights reserved.
;;; Copyright (C) 2020-2022 Kenneth Haase (ken.haase@alum.mit.edu)

(in-module 'os/findpath)

(module-export! '{find-path find-paths
		  ;; Have aliases which agree with the module name
		  findpath findpaths })

(defambda (find-path obj . path)
  (if (null? path) obj
      (try-choices (obj obj)
	(tryif (table? obj)
	  (if (test obj (car path))
	      (try-choices (o (get obj (car path)))
		(apply find-path o (cdr path)))
	      (try-choices (key (getkeys obj))
		(try-choices (value (get obj key))
		  (if (table? value)
		      (apply find-path value path)
		      (tryif (or (vector? value) (list? value))
			(try-choices (elt value)
			  (tryif (table? elt)
			    (apply find-path elt path))))))))))))

(defambda (find-paths obj . path)
  (if (null? path) obj
      (try-choices (obj obj)
	(tryif (table? obj)
	  (choice
	   (tryif (test obj (car path))
	     (for-choices (o (get obj (car path)))
	       (apply find-paths o (cdr path))))
	   (for-choices (key (getkeys obj))
	     (for-choices (value (get obj key))
	       (choice
		(tryif (table? value)
		  (apply find-paths value path))
		(tryif (or (vector? value) (list? value))
		  (for-choices (elt (elts value))
		    (tryif (table? elt)
		      (apply find-paths elt path))))))))))))


(defambda (findpath . args) (apply find-path args))
(defambda (findpaths . args) (apply find-paths args))
