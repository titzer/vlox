;; ---- globals ----
  (global 0 (mut lox) $clock)
  (global 1 (mut lox) $f)
  (global 2 lox (1))
  (global 3 lox (2))
  (global 4 lox (nil))

(func 30 $<script> (param lox)  ;; 1:1-1:1
1:1      |0      i32.const 31
1:1      |2      i32.const 0
1:1      |4      call 21  ;; lox.closure
1:1      |6      global.set 1  ;; $f
2:1      |8      global.get 1  ;; $f
2:1      |10     i32.const 1
2:1      |12     call 15  ;; lox.check_global
2:3      |14     global.get 2  ;; 1
2:6      |16     global.get 3  ;; 2
2:1      |18     i32.const 2
2:1      |20     call 14  ;; lox.call
2:1      |22     drop
3:1      |23     global.get 0  ;; $clock
3:1      |25     i32.const 0
3:1      |27     call 15  ;; lox.check_global
3:1      |29     i32.const 0
3:1      |31     call 14  ;; lox.call
3:1      |33     drop
3:1      |34     global.get 4  ;; nil
3:1      |36   end
)

(func 31 $f (param lox lox lox)  ;; 1:5-1:30
1:22     |0      local.get 1
1:26     |2      local.get 2
1:22     |4      call 3  ;; lox.add
1:15     |6      return
1:15     |7      global.get 4  ;; nil
1:15     |9    end
)
