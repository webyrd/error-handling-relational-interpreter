(load "mk.scm")
(load "test-check.scm")

;; error-handling Scheme interpreter
;;
;; two types of error (referencing unbound variable, or taking car/cdr of a non-pair (really a closure))
;;
;; errors are now represented as tagged lists, with specific messages
;;
;; this version of the interpreter uses *every* legal Scheme
;; evaluation order for programs that generate errors (rather than
;; left-to-right order, for example)

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
             ((fresh (msg)
                (== `(ERROR . ,msg) val)
                (conde
                  ((eval-expo e1 env `(ERROR . ,msg)))
                  ((eval-expo e2 env `(ERROR . ,msg)))))))))
        ((fresh (rator rand x body env^ a)
           (== `(,rator ,rand) exp)
           (conde
             ((absento 'ERROR val)
              (eval-expo rator env `(closure ,x ,body ,env^))
              (eval-expo rand env a)
              (eval-expo body `((,x . ,a) . ,env^) val))
             ((fresh (msg)
                (== `(ERROR . ,msg) val)
                (conde
                  (
                   ;; must be careful here!
                   ;;
                   ;; we can't depend on the evaluation of rator to ensure
                   ;; application isn't overlapping with quote, for example
                   (=/= 'quote rator)
                   (=/= 'car rator)
                   (=/= 'cdr rator)
                   (eval-expo rator env `(ERROR . ,msg)))
                  ((=/= 'quote rator)
                   (=/= 'car rator)
                   (=/= 'cdr rator)
                   (eval-expo rand env `(ERROR . ,msg)))
                  ((eval-expo rator env `(closure ,x ,body ,env^))
                   (eval-expo rand env a)
                   (eval-expo body `((,x . ,a) . ,env^) `(ERROR . ,msg)))))))))
        ((fresh (e)
           (== `(car ,e) exp)
           (not-in-envo 'car env)
           (conde
             ((fresh (v2)
                (absento 'ERROR val)
                (eval-expo e env `(,val . ,v2))))
             ((fresh (msg)
                (== `(ERROR . ,msg) val)
                (conde
                  ((eval-expo e env `(ERROR . ,msg)))
                  ((fresh (v)
                     (== `(ERROR ATTEMPT-TO-TAKE-CAR-OF-NON-PAIR ,v) val)
                     (absento 'ERROR v)
                     (not-pairo v)
                     (eval-expo e env v)))))))))
        ((fresh (e)
           (== `(cdr ,e) exp)
           (not-in-envo 'cdr env)
           (conde
             ((fresh (v1)
                (absento 'ERROR val)
                (eval-expo e env `(,v1 . ,val))))
             ((fresh (msg)
                (== `(ERROR . ,msg) val)
                (conde
                  ((eval-expo e env `(ERROR . ,msg)))
                  ((fresh (v)
                     (== `(ERROR ATTEMPT-TO-TAKE-CDR-OF-NON-PAIR ,v) val)
                     (absento 'ERROR v)
                     (not-pairo v)
                     (eval-expo e env v)))))))))))))


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
       (== `(ERROR UNBOUND-VARIABLE ,x) t))
      ((fresh (rest y v)
          (== `((,y . ,v) . ,rest) env)
          (conde
            ((== y x) (== v t))
            ((=/= y x) (lookupo x rest t))))))))

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
  '((ERROR UNBOUND-VARIABLE x)))

(test "4"
  (run* (q)
    (eval-expo `(cons 'a '()) '() q))
  '((a)))

(test "5"
  (run* (q)
    (eval-expo `(cdr (cons 'a (cons 'b '()))) '() q))
  '((b)))

(test "6"
  (run 20 (q msg)
    (eval-expo q '() `(ERROR . ,msg)))
  '(((_.0 (UNBOUND-VARIABLE _.0))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0))
    (((cons _.0 _.1) (UNBOUND-VARIABLE _.0))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (closure _.1)))
    (((cons _.0 _.1) (UNBOUND-VARIABLE _.1))
     (=/= ((_.1 ERROR)) ((_.1 closure))) (sym _.1)
     (absento (ERROR _.0) (closure _.0)))
    (((_.0 _.1) (UNBOUND-VARIABLE _.0))
     (=/= ((_.0 ERROR)) ((_.0 car)) ((_.0 cdr))
          ((_.0 closure)) ((_.0 quote)))
     (sym _.0) (absento (ERROR _.1) (closure _.1)))
    (((_.0 _.1) (UNBOUND-VARIABLE _.1))
     (=/= ((_.0 car)) ((_.0 cdr)) ((_.0 quote)) ((_.1 ERROR))
          ((_.1 closure)))
     (sym _.1) (absento (ERROR _.0) (closure _.0)))
    (((car _.0) (UNBOUND-VARIABLE _.0))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0))
    (((cdr _.0) (UNBOUND-VARIABLE _.0))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0))
    (((cons (cons _.0 _.1) _.2) (UNBOUND-VARIABLE _.0))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (ERROR _.2) (closure _.1)
              (closure _.2)))
    (((cons _.0 (cons _.1 _.2)) (UNBOUND-VARIABLE _.1))
     (=/= ((_.1 ERROR)) ((_.1 closure))) (sym _.1)
     (absento (ERROR _.0) (ERROR _.2) (closure _.0)
              (closure _.2)))
    (((cons (cons _.0 _.1) _.2) (UNBOUND-VARIABLE _.1))
     (=/= ((_.1 ERROR)) ((_.1 closure))) (sym _.1)
     (absento (ERROR _.0) (ERROR _.2) (closure _.0)
              (closure _.2)))
    (((cons _.0 (cons _.1 _.2)) (UNBOUND-VARIABLE _.2))
     (=/= ((_.2 ERROR)) ((_.2 closure))) (sym _.2)
     (absento (ERROR _.0) (ERROR _.1) (closure _.0)
              (closure _.1)))
    (((car (lambda (_.0) _.1))
      (ATTEMPT-TO-TAKE-CAR-OF-NON-PAIR (closure _.0 _.1 ())))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (closure _.1)))
    (((cdr (lambda (_.0) _.1))
      (ATTEMPT-TO-TAKE-CDR-OF-NON-PAIR (closure _.0 _.1 ())))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (closure _.1)))
    (((cons (_.0 _.1) _.2) (UNBOUND-VARIABLE _.0))
     (=/= ((_.0 ERROR)) ((_.0 car)) ((_.0 cdr))
          ((_.0 closure)) ((_.0 quote)))
     (sym _.0)
     (absento (ERROR _.1) (ERROR _.2) (closure _.1)
              (closure _.2)))
    (((cons _.0 (_.1 _.2)) (UNBOUND-VARIABLE _.1))
     (=/= ((_.1 ERROR)) ((_.1 car)) ((_.1 cdr))
          ((_.1 closure)) ((_.1 quote)))
     (sym _.1)
     (absento (ERROR _.0) (ERROR _.2) (closure _.0)
              (closure _.2)))
    ((((cons _.0 _.1) _.2) (UNBOUND-VARIABLE _.0))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (ERROR _.2) (closure _.1)
              (closure _.2)))
    ((((cons _.0 _.1) _.2) (UNBOUND-VARIABLE _.1))
     (=/= ((_.1 ERROR)) ((_.1 closure))) (sym _.1)
     (absento (ERROR _.0) (ERROR _.2) (closure _.0)
              (closure _.2)))
    (((cons (_.0 _.1) _.2) (UNBOUND-VARIABLE _.1))
     (=/= ((_.0 car)) ((_.0 cdr)) ((_.0 quote)) ((_.1 ERROR))
          ((_.1 closure)))
     (sym _.1)
     (absento (ERROR _.0) (ERROR _.2) (closure _.0)
              (closure _.2)))
    (((cons _.0 (_.1 _.2)) (UNBOUND-VARIABLE _.2))
     (=/= ((_.1 car)) ((_.1 cdr)) ((_.1 quote)) ((_.2 ERROR))
          ((_.2 closure)))
     (sym _.2)
     (absento (ERROR _.0) (ERROR _.1) (closure _.0)
              (closure _.1)))
    ((((_.0 _.1) _.2) (UNBOUND-VARIABLE _.0))
     (=/= ((_.0 ERROR)) ((_.0 car)) ((_.0 cdr))
          ((_.0 closure)) ((_.0 quote)))
     (sym _.0)
     (absento (ERROR _.1) (ERROR _.2) (closure _.1)
              (closure _.2)))))

(test "7"
  (run 20 (q val)
    (eval-expo q '() `(ERROR ATTEMPT-TO-TAKE-CAR-OF-NON-PAIR . ,val)))
  '((((car (lambda (_.0) _.1)) ((closure _.0 _.1 ())))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (closure _.1)))
    (((cons (car (lambda (_.0) _.1)) _.2)
      ((closure _.0 _.1 ())))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (ERROR _.2) (closure _.1)
              (closure _.2)))
    (((cons _.0 (car (lambda (_.1) _.2)))
      ((closure _.1 _.2 ())))
     (=/= ((_.1 ERROR)) ((_.1 closure))) (sym _.1)
     (absento (ERROR _.0) (ERROR _.2) (closure _.0)
              (closure _.2)))
    ((((car (lambda (_.0) _.1)) _.2) ((closure _.0 _.1 ())))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (ERROR _.2) (closure _.1)
              (closure _.2)))
    (((cdr (car (lambda (_.0) _.1))) ((closure _.0 _.1 ())))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (closure _.1)))
    (((car ((lambda (_.0) (lambda (_.1) _.2)) '_.3))
      ((closure _.1 _.2 ((_.0 . _.3)))))
     (=/= ((_.0 ERROR)) ((_.0 closure)) ((_.1 ERROR))
          ((_.1 closure)))
     (sym _.0 _.1)
     (absento (ERROR _.2) (ERROR _.3) (closure _.2)
              (closure _.3)))
    (((car (cons (car (lambda (_.0) _.1)) '(_.2 _.3 _.4)))
      ((closure _.2 _.3 _.4)))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (ERROR _.2) (ERROR _.3) (ERROR _.4)
              (closure _.1) (closure _.2) (closure _.3)
              (closure _.4)))
    (((_.0 (car (lambda (_.1) _.2))) ((closure _.1 _.2 ())))
     (=/= ((_.0 car)) ((_.0 cdr)) ((_.0 quote)) ((_.1 ERROR))
          ((_.1 closure)))
     (sym _.1)
     (absento (ERROR _.0) (ERROR _.2) (closure _.0)
              (closure _.2)))
    (((car (car (lambda (_.0) _.1))) ((closure _.0 _.1 ())))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (closure _.1)))
    (((cons (cons (car (lambda (_.0) _.1)) _.2) _.3)
      ((closure _.0 _.1 ())))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (ERROR _.2) (ERROR _.3)
              (closure _.1) (closure _.2) (closure _.3)))
    (((cons _.0 (cons (car (lambda (_.1) _.2)) _.3))
      ((closure _.1 _.2 ())))
     (=/= ((_.1 ERROR)) ((_.1 closure))) (sym _.1)
     (absento (ERROR _.0) (ERROR _.2) (ERROR _.3)
              (closure _.0) (closure _.2) (closure _.3)))
    (((cons (cons _.0 (car (lambda (_.1) _.2))) _.3)
      ((closure _.1 _.2 ())))
     (=/= ((_.1 ERROR)) ((_.1 closure))) (sym _.1)
     (absento (ERROR _.0) (ERROR _.2) (ERROR _.3)
              (closure _.0) (closure _.2) (closure _.3)))
    (((cons _.0 (cons _.1 (car (lambda (_.2) _.3))))
      ((closure _.2 _.3 ())))
     (=/= ((_.2 ERROR)) ((_.2 closure))) (sym _.2)
     (absento (ERROR _.0) (ERROR _.1) (ERROR _.3)
              (closure _.0) (closure _.1) (closure _.3)))
    (((car
       ((lambda (_.0) (lambda (_.1) _.2)) (lambda (_.3) _.4)))
      ((closure _.1 _.2 ((_.0 closure _.3 _.4 ())))))
     (=/= ((_.0 ERROR)) ((_.0 closure)) ((_.1 ERROR))
          ((_.1 closure)) ((_.3 ERROR)) ((_.3 closure)))
     (sym _.0 _.1 _.3)
     (absento (ERROR _.2) (ERROR _.4) (closure _.2)
              (closure _.4)))
    (((car
       (cons (car (lambda (_.0) _.1)) (cons '_.2 '(_.3 _.4))))
      ((closure _.2 _.3 _.4)))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (ERROR _.2) (ERROR _.3) (ERROR _.4)
              (closure _.1) (closure _.2) (closure _.3)
              (closure _.4)))
    (((car ((lambda (_.0) _.0) (lambda (_.1) _.2)))
      ((closure _.1 _.2 ())))
     (=/= ((_.0 ERROR)) ((_.0 closure)) ((_.1 ERROR))
          ((_.1 closure)))
     (sym _.0 _.1) (absento (ERROR _.2) (closure _.2)))
    (((cons ((car (lambda (_.0) _.1)) _.2) _.3)
      ((closure _.0 _.1 ())))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (ERROR _.2) (ERROR _.3)
              (closure _.1) (closure _.2) (closure _.3)))
    (((cons _.0 ((car (lambda (_.1) _.2)) _.3))
      ((closure _.1 _.2 ())))
     (=/= ((_.1 ERROR)) ((_.1 closure))) (sym _.1)
     (absento (ERROR _.0) (ERROR _.2) (ERROR _.3)
              (closure _.0) (closure _.2) (closure _.3)))
    (((car (car (cons (lambda (_.0) _.1) '_.2)))
      ((closure _.0 _.1 ())))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (ERROR _.2) (closure _.1)
              (closure _.2)))
    ((((cons (car (lambda (_.0) _.1)) _.2) _.3)
      ((closure _.0 _.1 ())))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (ERROR _.2) (ERROR _.3)
              (closure _.1) (closure _.2) (closure _.3)))))

(test "8"
  (run 1 (q)
    (eval-expo q '() q))
  '((((lambda (_.0)
        (cons _.0 (cons (cons 'quote (cons _.0 '())) '())))
      '(lambda (_.0)
         (cons _.0 (cons (cons 'quote (cons _.0 '())) '()))))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0))))

(test "9"
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
    (((lambda (_.0) '(I love you)) (lambda (_.1) _.2))
     (=/= ((_.0 ERROR)) ((_.0 closure)) ((_.1 ERROR))
          ((_.1 closure)))
     (sym _.0 _.1) (absento (ERROR _.2) (closure _.2)))
    ((cons (car '(I . _.0)) '(love you))
     (absento (ERROR _.0) (closure _.0)))
    ((cons (cdr '(_.0 . I)) '(love you))
     (absento (ERROR _.0) (closure _.0)))
    ((car (cons '(I love you) '_.0))
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
    ((cdr (cons '_.0 '(I love you)))
     (absento (ERROR _.0) (closure _.0)))
    ((cons 'I ((lambda (_.0) '(love you)) '_.1))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (closure _.1)))
    (((lambda (_.0) (cons 'I '(love you))) '_.1)
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (closure _.1)))
    ((cons ((lambda (_.0) 'I) '_.1) '(love you))
     (=/= ((_.0 ERROR)) ((_.0 closure))) (sym _.0)
     (absento (ERROR _.1) (closure _.1)))
    (cons 'I (cons 'love (cons 'you '())))))

(test "10"
  (run 20 (q)
    (eval-expo q '() `(ERROR UNBOUND-VARIABLE foo)))
  '(foo
    ((cons foo _.0) (absento (ERROR _.0) (closure _.0)))
    ((cons _.0 foo) (absento (ERROR _.0) (closure _.0)))
    ((foo _.0) (absento (ERROR _.0) (closure _.0)))
    ((_.0 foo) (=/= ((_.0 car)) ((_.0 cdr)) ((_.0 quote)))
     (absento (ERROR _.0) (closure _.0)))
    (car foo)
    (cdr foo)
    ((cons (cons foo _.0) _.1)
     (absento (ERROR _.0) (ERROR _.1) (closure _.0)
              (closure _.1)))
    ((cons _.0 (cons foo _.1))
     (absento (ERROR _.0) (ERROR _.1) (closure _.0)
              (closure _.1)))
    ((cons (cons _.0 foo) _.1)
     (absento (ERROR _.0) (ERROR _.1) (closure _.0)
              (closure _.1)))
    ((cons _.0 (cons _.1 foo))
     (absento (ERROR _.0) (ERROR _.1) (closure _.0)
              (closure _.1)))
    ((cons (foo _.0) _.1)
     (absento (ERROR _.0) (ERROR _.1) (closure _.0)
              (closure _.1)))
    ((cons _.0 (foo _.1))
     (absento (ERROR _.0) (ERROR _.1) (closure _.0)
              (closure _.1)))
    (((cons foo _.0) _.1)
     (absento (ERROR _.0) (ERROR _.1) (closure _.0)
              (closure _.1)))
    (((cons _.0 foo) _.1)
     (absento (ERROR _.0) (ERROR _.1) (closure _.0)
              (closure _.1)))
    ((car (cons foo _.0)) (absento (ERROR _.0) (closure _.0)))
    ((cdr (cons foo _.0)) (absento (ERROR _.0) (closure _.0)))
    ((car (cons _.0 foo)) (absento (ERROR _.0) (closure _.0)))
    ((cdr (cons _.0 foo)) (absento (ERROR _.0) (closure _.0)))
    ((cons (_.0 foo) _.1)
     (=/= ((_.0 car)) ((_.0 cdr)) ((_.0 quote)))
     (absento (ERROR _.0) (ERROR _.1) (closure _.0)
              (closure _.1)))))

(test "11"
  (run* (q)
    (eval-expo '((w x) (y z)) '() q))
  '((ERROR UNBOUND-VARIABLE w)
    (ERROR UNBOUND-VARIABLE x)
    (ERROR UNBOUND-VARIABLE y)
    (ERROR UNBOUND-VARIABLE z)))

(test "12"
  (run* (q)
    (eval-expo '((w x) y) '() q))
  '((ERROR UNBOUND-VARIABLE y)
    (ERROR UNBOUND-VARIABLE w)
    (ERROR UNBOUND-VARIABLE x)))
