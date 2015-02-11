(load "mk.scm")
(load "test-check.scm")

;; simple error-handling Scheme interpreter
;;
;; two types of error (referencing unbound variable, or taking car/cdr of a non-pair (really a closure))
;;
;; both errors are conflated, and represented as a single ERROR symbol

(define eval-expo
  (lambda (exp env val)
    (fresh ()
      (absento 'ERROR exp)
      (absento 'ERROR env)
      (absento 'closure exp)
      (conde
        ((== `(quote ,val) exp)
         (not-in-envo 'quote env))
        ((fresh (x body)
           (== `(lambda (,x) ,body) exp)
           (== `(closure ,x ,body ,env) val)
           (symbolo x)))
        ((symbolo exp) (lookupo exp env val))
        ((fresh (e1 e2 v1 v2)
           (== `(cons ,e1 ,e2) exp)
           (conde
             ((absento 'ERROR val)
              (== `(,v1 . ,v2) val)
              (eval-expo e1 env v1)
              (eval-expo e2 env v2))
             ((== 'ERROR val)
              (conde
                ((eval-expo e1 env 'ERROR))
                ((absento 'ERROR v1)
                 (eval-expo e1 env v1)
                 (eval-expo e2 env 'ERROR)))))))
        ((fresh (rator rand x body env^ a)
           (== `(,rator ,rand) exp)
           (conde
             ((absento 'ERROR val)
              (eval-expo rator env `(closure ,x ,body ,env^))
              (eval-expo rand env a)
              (eval-expo body `((,x . ,a) . ,env^) val))
             ((== 'ERROR val)
              (conde
                (
                 ;; must be careful here!
                 ;;
                 ;; we can't depend on the evaluation of rator to ensure
                 ;; application isn't overlapping with quote, for example
                 (=/= 'quote rator)
                 (=/= 'car rator)
                 (=/= 'cdr rator)
                 (eval-expo rator env 'ERROR))                
                ((eval-expo rator env `(closure ,x ,body ,env^))
                 (eval-expo rand env 'ERROR))
                ((eval-expo rator env `(closure ,x ,body ,env^))
                 (eval-expo rand env a)
                 (eval-expo body `((,x . ,a) . ,env^) 'ERROR)))))))
        ((fresh (e)
           (== `(car ,e) exp)
           (not-in-envo 'car env)
           (conde
             ((fresh (v2)
                (absento 'ERROR val)
                (eval-expo e env `(,val . ,v2))))
             ((== 'ERROR val)
              (conde
                ((eval-expo e env 'ERROR))
                ((fresh (v)
                   (absento 'ERROR v)
                   (not-pairo v)
                   (eval-expo e env v))))))))
        ((fresh (e)
           (== `(cdr ,e) exp)
           (not-in-envo 'cdr env)
           (conde
             ((fresh (v1)
                (absento 'ERROR val)
                (eval-expo e env `(,v1 . ,val))))
             ((== 'ERROR val)
              (conde
                ((eval-expo e env 'ERROR))
                ((fresh (v)
                   (absento 'ERROR v)
                   (not-pairo v)
                   (eval-expo e env v))))))))))))

#|
(define eval-expo
  (lambda (exp env val)
    (fresh ()
      (absento 'closure exp)
      (conde
        ((== `(quote ,val) exp)
         (not-in-envo 'quote env))
        ((fresh (x body)
           (== `(lambda (,x) ,body) exp)
           (== `(closure ,x ,body ,env) val)
           (symbolo x)))
        ((symbolo exp) (lookupo exp env val))
        ((fresh (e1 e2 v1 v2)
           (== `(cons ,e1 ,e2) exp)
           (== `(,v1 . ,v2) val)
           (eval-expo e1 env v1)
           (eval-expo e2 env v2)))
        ((fresh (rator rand x body env^ a)
           (== `(,rator ,rand) exp)
           (eval-expo rator env `(closure ,x ,body ,env^))
           (eval-expo rand env a)
           (eval-expo body `((,x . ,a) . ,env^) val)))
        ((fresh (e)
           (== `(car ,e) exp)
           (not-in-envo 'car env)
           (fresh (v2)
             (eval-expo e env `(,val . ,v2)))))
        ((fresh (e)
           (== `(cdr ,e) exp)
           (not-in-envo 'cdr env)
           (fresh (v1)
             (eval-expo e env `(,v1 . ,val)))))))))
|#

(define (not-in-envo x env)
  (conde
    ((== '() env))
    ((fresh (a d)
       (== `(,a . ,d) env)
       (=/= x a)
       (not-in-envo x d)))))

(define (not-pairo v)
  (fresh (x body env)
    (== `(closure ,x ,body ,env) v)))


(define lookupo
  (lambda (x env t)
    (conde
      ((== env '())
       (== t 'ERROR))
      ((fresh (rest y v)
          (== `((,y . ,v) . ,rest) env)
          (conde
            ((== y x) (== v t))
            ((=/= y x) (lookupo x rest t))))))))

#|
(define lookupo
  (lambda (x env t)
    (fresh (rest y v)
      (== `((,y . ,v) . ,rest) env)
      (conde
        ((== y x) (== v t))
        ((=/= y x) (lookupo x rest t))))))
|#

(test "1"
  (run* (q)
    (eval-expo `((((lambda (x) (lambda (y) (lambda (z) ((x z) (y z))))) (lambda (x) (lambda (y) (x y)))) (lambda (y) y)) (lambda (x) (quote foo))) '() 'foo))
  '(_.0))

(test "2"
  (run* (q)
    (eval-expo `(quote a) '() q))
  '(a))

(test "3"
  (run* (q)
    (eval-expo `((lambda (y) x) (lambda (z) z)) '() q))
  '(ERROR))

(test "4"
  (run* (q)
    (eval-expo `(cons 'a '()) '() q))
  '((a)))

(test "5"
  (run* (q)
    (eval-expo `(cdr (cons 'a (cons 'b '()))) '() q))
  '((b)))

(test "6"
  (map caar
       (run 20 (q d)
         (=/= d 'DUMMY)
         (eval-expo q '() 'ERROR)))
  '(_.0
    (cons _.0 _.1)
    (_.0 _.1)
    (cons '_.0 _.1)
    (cons (lambda (_.0) _.1) _.2)
    (car _.0)
    (cons (cons _.0 _.1) _.2)
    (cdr _.0)
    (car (lambda (_.0) _.1))
    (cdr (lambda (_.0) _.1))
    ((lambda (_.0) _.1) _.2)
    (cons (_.0 _.1) _.2)
    ((cons _.0 _.1) _.2)
    (cons '_.0 (cons _.1 _.2))
    (cons (cons '_.0 _.1) _.2)
    ((_.0 _.1) _.2)
    (cons '_.0 (_.1 _.2))
    (cons (cons (lambda (_.0) _.1) _.2) _.3)
    (cons (car _.0) _.1)
    (cons (lambda (_.0) _.1) (cons _.2 _.3))))

(test "7"
  (run 1 (q)
    (eval-expo q '() q))
  '((((lambda (_.0)
        (cons _.0 (cons (cons 'quote (cons _.0 '())) '())))
      '(lambda (_.0)
         (cons _.0 (cons (cons 'quote (cons _.0 '())) '()))))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0))))

(test "8"
  (run 20 (q)
    (eval-expo q '() '(I love you)))
  '('(I love you)
    (cons 'I '(love you))
    ((car '((I love you) . _.0))
     (absento (ERROR _.0) (closure _.0)))
    ((cdr '(_.0 I love you))
     (absento (ERROR _.0) (closure _.0)))
    (((lambda (_.0) '(I love you)) '_.1)
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (closure _.1)))
    (cons 'I (cons 'love '(you)))
    (((lambda (_.0) _.0) '(I love you))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0))
    ((cons (car '(I . _.0)) '(love you))
     (absento (ERROR _.0) (closure _.0)))
    (((lambda (_.0) '(I love you)) (lambda (_.1) _.2))
     (=/= ((_.0 ERROR)) ((_.0 closure)) ((_.1 ERROR))
          ((_.1 closure)))
     (sym _.0 _.1) (absento (ERROR _.2) (closure _.2)))
    ((cons (cdr '(_.0 . I)) '(love you))
     (absento (ERROR _.0) (closure _.0)))
    ((car (cons '(I love you) '_.0))
     (absento (ERROR _.0) (closure _.0)))
    ((cdr (cons '_.0 '(I love you)))
     (absento (ERROR _.0) (closure _.0)))
    ((cons 'I (car '((love you) . _.0)))
     (absento (ERROR _.0) (closure _.0)))
    ((cons 'I (cdr '(_.0 love you)))
     (absento (ERROR _.0) (closure _.0)))
    ((car (cons '(I love you) (lambda (_.0) _.1)))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (closure _.1)))
    ((cons (car '(I . _.0)) (cons 'love '(you)))
     (absento (ERROR _.0) (closure _.0)))
    ((cons 'I ((lambda (_.0) '(love you)) '_.1))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (closure _.1)))
    ((cdr (cons (lambda (_.0) _.1) '(I love you)))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (closure _.1)))
    (((lambda (_.0) (cons 'I '(love you))) '_.1)
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (closure _.1)))
    ((cons ((lambda (_.0) 'I) '_.1) '(love you))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (closure _.1)))))
