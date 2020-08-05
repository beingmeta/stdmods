;; -*- coding: latin-1 -*-

;; English Morphology
;;  Copyright (C) 2001 Kenneth Haase, All Rights Reserved
;;  Copyright (C) 2001-2018 beingmeta, inc.

(in-module 'morph/en)

(use-module 'texttools)

(module-export!
 '{noun-root verb-root noun-roots verb-roots
	     gerund add-ing add-ed add-s
	     stop-words wordfreqs
	     prepositions aux-words glue-words pronouns
	     determiners conjunctions
	     adjectives adjectiveset
	     adverbs adverbset})

(define irregular-nouns
  (read-xtype (get-component "data/en-noun-roots.xtype"))
  ;; (use-index (get-component "data/en-noun-roots.index"))
  )
(define noun-roots
  (choice->hashset
   (qc (read-xtype (get-component "data/en-noun.xtype")))))

(define plural-rules
  '(#({"a" "e" "i" "o" "u"} (subst "ies" "y")) 
    ("xes" . "x") ("zes" . "z") ("ses" . "s")
    ("shes" . "sh") ("ches" . "ch") ("s" . "")))
(define (noun-root x (nountest #f))
  (try (get irregular-nouns x)
       (tryif (position #\Space x)
	      (list->phrase (compound-noun-root (segment x " ") nountest)))
       (morphrule x plural-rules (or nountest noun-roots))))

(define (compound-noun-root segmented nountest)
  (if (null? (cdr segmented))
      (list (noun-root (car segmented) nountest))
      (cons (car segmented) (compound-noun-root (cdr segmented) nountest))))

(define irregular-verbs
  (read-xtype (get-component "data/en-verb-roots.xtype"))
  ;; (use-index (get-component "data/en-verb-roots.index"))
  )
(define verb-roots
  (choice->hashset (read-xtype (get-component "data/en-verb.xtype"))))
(define ing-forms
  (let ((table (make-hashtable)))
    (do-choices (key (getkeys irregular-verbs))
      (when (has-suffix key "ing")
	(add! table (get irregular-verbs key) key)))
    table))
(define ed-forms
  (let ((table (make-hashtable)))
    (do-choices (key (getkeys irregular-verbs))
      (when (has-suffix key "ed")
	(add! table (get irregular-verbs key) key)))
    table))
(define s-forms
  (let ((table (make-hashtable)))
    (do-choices (key (getkeys irregular-verbs))
      (when (has-suffix key "s")
	(add! table (get irregular-verbs key) key)))
    table))

(define gerund-rules
  '(#((+ (isnotvowel)) (isvowel)
      {(SUBST "bbing" "b")
       (SUBST "dding" "d")
       (SUBST "gging" "g")
       (SUBST "nning" "n")
       (SUBST "pping" "p")
       (SUBST "rring" "r")
       (SUBST "tting" "t")})
      ("ing" . "e")
      ("ing" . "")))
(define past-rules
  '(#({"a" "e" "i" "o" "u"} (subst "ied" "y"))
    ("ed" . "ee")
    ("ed" . "e")
    ("ed" . "")))
(define s-rules
  '(#({"a" "e" "i" "o" "u"} (subst "ies" "y"))
    ("xes" . "x") ("zes" . "z") ("ses" . "s") 
    ("shes" . "sh") ("ches" . "ch") ("s" . "")))

(define (verb-root x (verbtest #f))
  (if (capitalized? x)
      (let ((d (downcase x)))
	(if (equal? d x) (fail) (verb-root d #f)))
      (try (get irregular-verbs x)
	   (tryif (position #\Space x)
		  (compound-verb-root x verbtest))
	   (morphrule x gerund-rules (or verbtest verb-roots))
	   (morphrule x past-rules (or verbtest verb-roots))
	   (morphrule x s-rules (or verbtest verb-roots)))))

(define (compound-verb-root x verbtest)
  (let ((pos (position #\Space x)))
    (append (verb-root (subseq x 0 pos) verbtest)
	    (subseq x pos))))

(define (base-add-ing x)
  (try (get ing-forms x)
       (morphrule x
		  '(("ee" . "eeing")
		    ("e" . "ing")
		    #((+ (isnotvowel)) (isvowel)
		      {(SUBST "b" "bbing")
		       (SUBST "d" "dding")
		       (SUBST "g" "gging")
		       (SUBST "n" "nning")
		       (SUBST "p" "pping")
		       (SUBST "r" "rring")
		       (SUBST "t" "tting")})
		    ("" . "ing"))
		  #t)))

(define (add-ing x)
  (if (position #\Space x)
      (let ((pos (position #\Space x)))
	(stringout (base-add-ing (subseq x 0 pos)) (subseq x pos)))
      (base-add-ing x)))
(define gerund (fcn/alias add-ing))

(define (base-add-ed x)
  (try (get ed-forms x)
       (morphrule x
		  '(("ee" . "eed")
		    ("e" . "ed")
		    #((+ (isnotvowel)) (isvowel)
		      {(SUBST "b" "bbed")
		       (SUBST "d" "dded")
		       (SUBST "g" "gged")
		       (SUBST "n" "nned")
		       (SUBST "p" "pped")
		       (SUBST "r" "rred")
		       (SUBST "t" "tted")})
		    ("" . "ed"))
		  #t)))

(define (add-ed x)
  (if (position #\Space x)
      (let ((pos (position #\Space x)))
	(stringout (base-add-ed (subseq x 0 pos)) (subseq x pos)))
      (base-add-ed x)))

(define (base-add-s x)
  (try (get s-forms x)
       (morphrule x
		  '(("sh" . "shes")
		    ("ch" . "ches")
		    ("x" . "xes")
		    ("z" . "zes")
		    ("s" . "ses")
		    #({"a" "e" "i" "o" "u"} (SUBST "y" "ys"))
		    ("y" . "ies")
		    ("" . "s"))
		  #t)))

(define (add-s x)
  (if (position #\Space x)
      (let ((pos (position #\Space x)))
	(stringout (base-add-s (subseq x 0 pos)) (subseq x pos)))
      (base-add-s x)))

;;;; Stop words

(define stop-words
  (let ((data (read-xtype (get-component "data/en-stop-words.xtype"))))
    (if (and (singleton? data) (hashset? data))
	data
	(choice->hashset data))))

;;;; Other categories

(define glue-words
  (read-xtype (get-component "data/en-glue-words.xtype")))

(define pronouns
  (read-xtype (get-component "data/en-pronouns.xtype")))

(define aux-words
  (read-xtype (get-component "data/en-aux-words.xtype")))

(define prepositions
  (read-xtype (get-component "data/en-prepositions.xtype")))

(define determiners
  (read-xtype (get-component "data/en-determiners.xtype")))

(define conjunctions
  (read-xtype (get-component "data/en-conjunctions.xtype")))

(define adverbs
  (read-xtype (get-component "data/en-adverbs.xtype")))
(define adverbset (choice->hashset adverbs))

(define adjectives
  (read-xtype (get-component "data/en-adjectives.xtype")))
(define adjectiveset (choice->hashset adjectives))

(hashset-add! stop-words
	      (choice glue-words pronouns aux-words prepositions determiners
		      conjunctions))

;;; Word frequencies

(define wordfreqs
  (read-xtype (get-component "data/en-freqs.xtype")))

;;; Interfacing with BRICO

;;; This interfaces with brico's lookup-word.to use English morphology
;;;  Note that through the magic of CONFIG, we don't have to have
;;;   BRICO loaded or working to specify this, though we do need to
;;;   use absolute OID references to specify the language.

(defambda (english-morphology word)
  (choice (list (noun-root word) 'type 'noun)
	  (list (verb-root word) 'type 'verb)))

(config! 'MORPHRULES
	 (vector 'ENGLISH-MORPHOLOGY @1/2c1c7"English" english-morphology))

