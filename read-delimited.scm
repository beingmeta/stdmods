(in-module 'read-delimited)

(module-export! '{read-delimited
                  read-delimited-file})

(load "strings.scm")

(use-module 'texttools)

(define (convert-cell val)
  (if (string? val)
      (if (and (has-prefix val "\"")  (has-suffix val "\""))
          (convert-cell (subseq val 1 -1))
          (if (compound-string? val)
              val
              (if (empty-string? val)
                  val
                  (string->lisp val))))
      val))

;;; Return a list from FILE
(define (file->list file)
  (string-split (filestring file) #\newline))

;;; Remove comments from lines
(define (uncomment lines (char #\#))
  (let ((comment (->string char)))
    (remove-if (lambda (line)
                 (has-prefix (string-trim-left line) comment))
               lines)))

;;; Return cleaned up list from FILE
(define (file->list/clean file)
  (uncomment (file->list file)))

;;; Append newline to string
(define (string-append-newline string)
  (string-append string (->string #\newline)))

;;; Return a clean filestring from FILE
(define (filestring/clean file)
  (let ((input (filestring file)))
    (apply string-append
           (map string-append-newline
                (file->list/clean file)))))

;;; Return a list containing sublists of string items in CONTENT
(define (split-content content (delimiter #\,))
  (map (lambda (line) (string-split line delimiter))
       content))

;;; Make pairs
(define (*make-pairs x y acc)
  (cond ((or (null? x) (null? y)) acc)
        (else (*make-pairs (rest x)
                           (rest y)
                           (append acc (list (first x) (first y)))))))

(define (make-pairs x y)
  (*make-pairs x y '()))

;;; Make frames
(define (make-frame x y (f #[]))
  (cond ((or (null? x) (null? y)) f)
        (else (begin
                (store! f (first x) (first y))
                (make-frame (rest x) (rest y) f)))))

;;; Return true if the list is of even length
(define (even-list? xs)
  (even? (length xs)))

;;; Return true if the list is of odd length
(define (odd-list? xs)
  (not (even-list? xs)))

;;; Return a frame from list
(define (list->frame xs)
  (when (even-list? xs)
    #f))

;;; Compose content
(define (compose-content content)
  (let ((head (first content))
        (body (rest content)))
    (map->choice (lambda (entry) (make-frame head entry))
                 body)))

;;; Compose file
(define (compose-file file (delimiter #\,))
  (compose-content (split-content (file->list/clean file) delimiter)))

;;; Top-level
(define read-delimited compose-content)
(define read-delimited-file compose-file)
