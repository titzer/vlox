;; ---- globals ----
  (global 0 (mut lox) $clock)
  (global 1 (mut lox) $a)
  (global 2 (mut lox) $b)
  (global 3 lox (1))
  (global 4 lox (2))
  (global 5 lox (nil))
  (global 6 lox ("x"))

(func 30 $<script> (param lox) (local lox)  ;; 1:1-1:1
2:9      |0      global.get 3  ;; 1
2:9      |2      local.tee 1
2:9      |4      call 0  ;; lox.truthy
2:9      |6      if (result lox)
2:15     |8        global.get 4  ;; 2
2:15     |10     else
2:15     |11       local.get 1
2:15     |13     end
2:1      |14     global.set 1  ;; $a
3:9      |16     global.get 5  ;; nil
3:9      |18     local.tee 1
3:9      |20     call 0  ;; lox.truthy
3:9      |22     if (result lox)
3:9      |24       local.get 1
3:9      |26     else
3:16     |27       global.get 6  ;; "x"
3:16     |29     end
3:1      |30     global.set 2  ;; $b
3:1      |32     global.get 5  ;; nil
3:1      |34   end
)
