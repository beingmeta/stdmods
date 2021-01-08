(use-module '{logger optimize})
(config! 'optalltest #t)
(config! 'traceload #t)
;(config! 'optimize:rails #t)
;(config! 'optimize:checkusage #f)
(config! 'mysql:lazyprocs #f)
(define %loglevel %info%)

(config! 'loadpath 
	 (let ((dir (dirname (get-component "optall.scm"))))
	   (glom dir "%/module.scm:" dir "%.scm:"
	     dir "safe/%/module.scm:" dir "safe/%.scm:" )))

(optimize! 'optimize)

(define check-modules
  (macro expr
    `(begin
       (use-module ,(cadr expr))
       (do-choices (mod ,(cadr expr))
	 (loginfo |Load All| "Optimizing module " mod)
	 (optimize-module! mod)))))

(check-modules '{cachequeue calltrack checkurl codewalker
		 couchdb curlcache dopool apis/dropbox text/ellipsize
		 net/email sqloids ezrecords fakezip fifo fillin
		 findcycles getcontent gpath apis/gravatar gutdb
		 hashfs hashstats zipfs histogram hostinfo i18n
		 ice isbn json/export logctl logger
		 kno/meltcache net/mimeout net/mimetable
		 kno/mttools net/oauth openlibrary ;; optimize
		 opts kno/packetfns parsetime bugjar
		 pump readcsv kno/rulesets samplefns
		 savecontent saveopt crypto/signature speling ;; soap
		 stringfmts tinygis tracer trackrefs apis/twilio
		 updatefile varconfig whocalls imagick/ximage})

(check-modules '{apis/aws apis/aws/v4 apis/aws/roles
		 apis/aws/s3 apis/aws/ses apis/aws/simpledb apis/aws/sqs 
		 apis/aws/associates apis/aws/dynamodb})

(check-modules '{domutils domutils/index domutils/localize
		 domutils/styles domutils/css domutils/cleanup
		 domutils/adjust domutils/analyze
		 domutils/hyphenate})

(check-modules '{apis/facebook apis/facebook/fbcall apis/facebook/fbml})

(check-modules '{google google/drive})

(check-modules '{knodules knodules/drules
		 knodules/html knodules/plaintext})

(check-modules '{misc/oidshift})

(check-modules '{apis/paypal apis/paypal/checkout apis/paypal/express apis/paypal/adaptive})

(check-modules '{textindex textindex/domtext textindex/linkup})

(check-modules '{twitter})

(define (have-morph) (and (get-module 'morph) (get-module 'morph/en)))
(define (have-brico)
  (and (config 'bricosource)
       (onerror (begin (use-module 'brico) #t) #f)))						    
(define (have-lexdata)
  (and (config 'lexdata)
       (onerror (and (exists? (get (get-module 'ofsm) 'lextags))
		     ((get (get-module 'ofsm) 'lextags)))
	 (lambda () #f))))

(when (and (have-brico) (have-morph))
  (check-modules '{brico brico/dterms brico/indexing brico/lookup
		   brico/analytics brico/maprules brico/xdterms
		   brico/wikipedia
		   knodules/usebrico knodules/defterm
		   xtags rdf audit}))

(when (have-lexdata)
  (check-modules '{lexml}))
