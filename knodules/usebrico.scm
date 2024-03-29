;;; -*- Mode: Scheme; Character-encoding: utf-8; -*-
;;; Copyright (C) 2005-2020 beingmeta, inc.  All rights reserved.
;;; Copyright (C) 2020-2022 Kenneth Haase (ken.haase@alum.mit.edu).

(in-module 'knodules/usebrico)

;;; Using brico from knodules, especially for importing information

(use-module '{texttools knodules brico})
(use-module '{brico/lookup brico/dterms brico/analytics})

(module-export! '{brico->kno kno/usebrico})
(module-export! '{kno/copy-brico-terms! kno/copy-brico-links!})

;;;; Resolving references

(define serial 0)

(define (get-unique-id base knodule)
  (let ((dterms (knodule-dterms knodule)))
    (do ((i 1 (1+ i)))
	((fail? (get dterms (stringout base "(" i ")")))
	 (stringout base "(" i ")")))))

(define (brico->kno bf knodule (create #f))
  (try (find-frames knodule:indexes 'oid bf)
       (find-frames knodule:indexes
	 'oid bf 'knodule (knodule-oid knodule))
       (tryif create
	 (let* ((language (knodule-language knodule))
		(langframe (get language-map language))
		(dterm (pick-one (get-dterm bf langframe)))
		(index (knodule-index knodule))
		(kf (kno/dterm
		     (try (or dterm {})
			  (get-unique-id (get-norm bf language)
					 knodule))
		     knodule)))
	   (when (ambiguous? bf)
	     (iadd! kf 'dterms (get-dterm bf langframe) index))
	   (unless (eq? language 'en)
	     (iadd! kf 'dterms (cons 'en (get-dterm bf en)) index))
	   (when (fail? dterm)
	     (warning "Can't get DTERM for " bf))
	   (iadd! kf 'oid bf)
	   (store! kf 'gloss
		   (try
		    (tryif (eq? language 'en) (get bf 'gloss))
		    (get-gloss bf langframe)))
	   (iadd! kf 'en (get-norm bf en))
	   (iadd! kf language
		  (get bf (get language-map language)))
	   kf))))

(define (brico->kno* bf knodule (visits (make-hashset)))
  (try (find-frames (knodule-index knodule) 'oid bf)
       (?? 'oid bf 'knodule (knodule-oid knodule))
       (let* ((always (get bf always)))
	 (hashset-add! visits bf)
	 (brico->kno* (reject always visits) knodule visits))))

;;; Copying information from brico

(define usebrico-defaults
  '#{en fr es nl pt ja zh sw})

(define (kno/usebrico (kf #f) (bf #f) (slotids usebrico-defaults))
  (when (or kf bf)
    (when (not kf)
      (set! kf (find-frames (knodule-index default-knodule)
		 'oid bf)))
    (when (not bf) (set! bf (get kf 'oid)))
    (when (overlaps? slotids 'languages)
      (set+! slotids langids))
    (let* ((knodule (get knodules (get kf 'knodule)))
	   (knolang (knodule-language knodule))
	   (languages (intersection slotids langids)))
      (if (and (test bf 'gloss) (eq? knolang 'en) (not (test kf 'gloss)))
	  (store! kf 'gloss (get bf 'gloss)))
      (do-choices (lang languages)
	(let ((bricolang (get language-map lang)))
	  (add! kf lang (get bf bricolang))
	  (if (eq? lang knolang)
	      (add! kf 'norms (get-norm bf bricolang))
	      (add! kf 'norms (cons lang (get-norm bf bricolang))))
	  (when (and (eq? lang knolang) (not (test kf 'gloss)))
	    (store! kf 'gloss (get-single-gloss bf bricolang)))
	  (if (eq? lang knolang)
	      (add! kf 'glosses (get bf (get gloss-map lang)))
	      (add! kf 'glosses
		    (cons lang (get bf (get gloss-map lang)))))
	  (if (eq? lang knolang)
	      (add! kf 'hooks (get bf (get index-map lang)))
	      (add! kf 'hooks
		    (cons lang
			  (get bf (get index-map lang)))))))
      (unless (test bf 'sensecat '{noun.tops verb.tops})
	(let* ((genls (get bf {always commonly}))
	       (commonly (difference (get bf commonly) genls))
	       (sometimes (difference (get bf sometimes) genls)))
	  (kno/add! kf 'genls (brico->kno genls knodule))
	  (kno/add! kf 'commonly (brico->kno commonly knodule))
	  (kno/add! kf 'sometimes (brico->kno sometimes knodule))))
      (let* ((never (get bf never))
	     (rarely (difference (get bf rarely) never))
	     (somenot (difference (get bf somenot) never)))
	(kno/add! kf 'never (brico->kno never knodule))
	(kno/add! kf 'rarely (brico->kno rarely knodule))
	(kno/add! kf 'somenot (brico->kno somenot knodule)))
      (when (test bf refterms)
	(kno/add! kf 'refs (brico->kno (get bf refterms) knodule)))
      (when (test bf sumterms)
	(kno/add! kf 'assocs
		  (brico->kno (get bf sumterms) knodule #t)))
      (when (test bf sumterms)
	(kno/add! kf 'defs
		  (brico->kno (get bf diffterms) knodule #t)))
      (when (test bf 'country)
	(kno/add! kf (kno/dterm "country" knodule)
		  (brico->kno (get bf 'country) knodule #t)))
      (when (test bf 'region)
	(kno/add! kf (kno/dterm "region" knodule)
		  (brico->kno (get bf 'region) knodule #t)))
      (when (test bf ingredients)
	(kno/add! kf (kno/dterm "ingredient" knodule)
		  (brico->kno (get bf ingredients) knodule #t)))
      (when (test bf memberof)
	(kno/add! kf (kno/dterm "group" knodule)
		  (brico->kno (get bf memberof) knodule #t)))
      (when (test bf partof)
	(kno/add! kf (kno/dterm "assemblage" knodule)
		  (brico->kno (get bf memberof) knodule #t)))
      (do-choices (role (pick (pickoids (getkeys bf)) 'sensecat))
	(do-choices (v (pickoids (%get bf role)))
	  (kno/add! kf (brico->kno role knodule #t)
		    (brico->kno v knodule #t))))
      kf)))

;;;; Copy BRICO links

(define (kno/copy-brico-terms! bf kf (languages {}) (opts 'glosses))
  (let* ((knodule (->knodule kf))
	 (knolang (knodule-language knodule))
	 (index (knodule-index knodule)))
    (do-choices (language (choice knolang 'en languages))
      (let* ((langframe (get language-map language)))
	(when (overlaps? opts 'dterms)
	  (let ((dterm (pick-one (get-dterm bf langframe))))
	    (if (eq? language knolang)
		(iadd! kf 'dterms dterm index)
		(iadd! kf 'dterms (cons 'en dterm) index))
	    (when (fail? dterm)
	      (warning "Can't get DTERM for " bf " in " language))))
	(iadd! kf 'oid bf)
	(when (and (eq? language knolang) (not (test kf 'gloss)))
	  (store! kf 'gloss
		  (stdspace
		   (try
		    (tryif (eq? language 'en) (get bf 'gloss))
		    (get-gloss bf langframe)))))
	(iadd! kf language (get bf langframe))
	(when (overlaps? opts 'glosses)
	  (add! kf 'glosses
		(cons language (stdspace (get-gloss bf langframe)))))
	kf))))

(define (kno/copy-brico-links! (bf #f) (kf #f) (slotids usebrico-defaults))
  (cond ((knodule? kf)
	 (do-choices (kf (find-frames (knodule-index kf) 'has 'oid))
	   (kno/copy-brico-links! kf (get kf 'oid) (qc slotids))))
	((and (not (or kf bf)) default-knodule)
	 (kno/copy-brico-links! default-knodule #f (qc slotids)))
	((or kf bf)
	 (when (not kf)
	   (set! kf (find-frames (knodule-index default-knodule)
		      'oid bf)))
	 (when (not bf) (set! bf (get kf 'oid)))
	 (kno/copy-brico-terms! bf kf (qc (intersection slotids langids)))
	 (let* ((knodule (get knodules (get kf 'knodule)))
		(index (knodule-index knodule)))
	   (unless (test bf 'sensecat '{noun.tops verb.tops})
	     (let* ((genls (get bf {always commonly}))
		    (commonly (difference (get bf commonly) genls))
		    (sometimes (difference (get bf sometimes) genls)))
	       (kno/add! kf 'genls (brico->kno genls knodule))
	       (let ((g* (get* kf 'genls))
		     (ng* (find-frames index 'oid (?? specls* bf))))
		 (kno/add! kf 'genls (get-basis (difference ng* g*) 'genls)))
	       (kno/add! kf 'commonly (brico->kno commonly knodule))
	       (kno/add! kf 'sometimes (brico->kno sometimes knodule))))
	   (let* ((never (get bf never))
		  (rarely (difference (get bf rarely) never))
		  (somenot (difference (get bf somenot) never)))
	     (kno/add! kf 'never (brico->kno never knodule))
	     (kno/add! kf 'rarely (brico->kno rarely knodule))
	     (kno/add! kf 'somenot (brico->kno somenot knodule)))
	   (let* ((never (get+ bf never))
		  (rarely (difference (get+ bf rarely) never))
		  (somenot (difference (get+ bf somenot) never)))
	     (kno/add! kf 'never (find-frames index 'oid never))
	     (kno/add! kf 'rarely (find-frames index 'oid rarely))
	     (kno/add! kf 'somenot (find-frames index 'oid somenot)))
	   (when (overlaps? slotids 'refs)
	     (when (test bf refterms)
	       (kno/add! kf 'refs
			 (find-frames index 'oid (get bf refterms)))))
	   (when (test bf sumterms)
	     (kno/add! kf 'assocs
		       (find-frames index 'oid (get bf sumterms))))
	   (when (test bf sumterms)
	     (kno/add! kf 'defs
		       (find-frames index 'oid (get bf diffterms))))
	   (when (test bf 'country)
	     (kno/add! kf (kno/dterm "country" knodule)
		       (brico->kno (get bf 'country) knodule #t)))
	   (when (test bf 'region)
	     (kno/add! kf (kno/dterm "region" knodule)
		       (brico->kno (get bf 'region) knodule #t)))
	   (when (test bf ingredients)
	     (kno/add! kf (kno/dterm "ingredient" knodule)
		       (find-frames index 'oid (get bf ingredients))))
	   (when (test bf memberof)
	     (kno/add! kf (kno/dterm "group" knodule)
		       (find-frames index 'oid (get bf memberof))))
	   (when (test bf partof)
	     (kno/add! kf (kno/dterm "assemblage" knodule)
		       (find-frames index 'oid (get bf partof))))
	   (do-choices (role (pick (pickoids (getkeys bf)) 'sensecat))
	     (do-choices (v (find-frames index
			      'oid (pickoids (%get bf role))))
	       (kno/add! kf (brico->kno role knodule)
			 (find-frames index 'oid v))))
	   kf))
	(else (fail))))





