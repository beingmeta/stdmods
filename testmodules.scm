;;; -*- Mode: Scheme; Character-encoding: utf-8; -*-
;;; Copyright (C) 2005-2020 beingmeta, inc. All rights reserved.

(in-module 'testmodules)

(use-module '{logger optimize})

(module-export! '{test-module
		  test-root-modules test-other-modules test-beingmeta-modules
		  test-all-modules})

(define root-modules
  '{audit cachequeue calltrack checkurl codewalker
    couchdb ctt curlcache dopool apis/dropbox text/ellipsize net/email
    sqloids ezrecords fakezip fifo fillin findcycles getcontent
    gpath apis/gravatar gutdb hashfs hashstats histogram hostinfo i18n
    ice json/export logctl logger kno/meltcache mergeutils net/mimeout ;;  lexml
    net/mimetable kno/mttools net/oauth openlibrary optimize opts
    kno/packetfns parsetime pump rdf readcsv recycle rss kno/rulesets
    samplefns savecontent saveopt crypto/signature speling ;; soap
    stringfmts tinygis tracer trackrefs twilio updatefile ;; tighten
    varconfig whocalls xtags})

(define other-modules
  '{(AWS AWS/S3 APIS/AWS/V4 AWS/SES AWS/SQS AWS/DYNAMODB
	 AWS/SIMPLEDB AWS/ASSOCIATES)
    (DOMUTILS DOMUTILS/CSS DOMUTILS/INDEX DOMUTILS/ADJUST DOMUTILS/STYLES
	      DOMUTILS/ANALYZE DOMUTILS/CLEANUP DOMUTILS/LOCALIZE
	      DOMUTILS/HYPHENATE)
    (BUGJAR)
    (KNODULES KNODULES/HTML KNODULES/DRULES KNODULES/DEFTERM
	      KNODULES/USEBRICO KNODULES/PLAINTEXT)
    (APIS/PAYPAL APIS/PAYPAL/EXPRESS APIS/PAYPAL/ADAPTIVE
	    APIS/PAYPAL/CHECKOUT)
    (FACEBOOK FACEBOOK/FBML APIS/FACEBOOK/FBCALL)
    (TWITTER)
    (GOOGLE GOOGLE/DRIVE)
    (TEXTINDEX TEXTINDEX/DOMTEXT)
    (BRICO BRICO/DTERMS BRICO/LOOKUP BRICO/XDTERMS
	   BRICO/INDEXING BRICO/MAPRULES BRICO/ANALYTICS BRICO/WIKIPEDIA
	   BRICO/DTERMCACHE)
    (MISC/OIDSHIFT)
    (TESTS/MTTOOLS)
    (WEBAPI/FACEBOOK)})

(define beingmeta-modules {})

(define (test-module name)
  (logwarn |Testing Module| "Module " name)
  (if (get-module name)
      (optimize-module! name)
      (logwarn |LoadFailed| "Couldn't load module " name)))

(define (test-root-modules)
  (do-choices (module root-modules) (test-module module)))

(define (test-other-modules)
  (do-choices (module-list other-modules)
    (test-module (car module-list))
    (test-module (elts (cdr module-list)))))

(define (test-beingmeta-modules)
  (do-choices (module-list beingmeta-modules)
    (test-module (car module-list))
    (test-module (elts (cdr module-list)))))

(define (test-all-modules)
  (test-root-modules)
  (test-other-modules)
  ;; (test-beingmeta-modules)
  )
