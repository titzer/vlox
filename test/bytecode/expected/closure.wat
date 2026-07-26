;; ---- globals ----
  (global 0 (mut lox) $clock)
  (global 1 (mut lox) $outer)
  (global 2 lox (nil))
  (global 3 lox (1))

(func 30 $<script> (param lox)  ;; 1:1-1:1
2:1      |0      i32.const 31
2:1      |2      i32.const 0
2:1      |4      call 21  ;; lox.closure
2:1      |6      global.set 1  ;; $outer
2:1      |8      global.get 2  ;; nil
2:1      |10   end
)

(func 31 $outer (param lox) (local lox lox)  ;; 2:5-6:2
3:3      |0      global.get 2  ;; nil
3:3      |2      call 17  ;; lox.cell_new
3:3      |4      local.set 1
3:3      |6      local.get 1
3:11     |8      global.get 3  ;; 1
3:3      |10     call 19  ;; lox.cell_set
3:3      |12     drop
4:3      |13     local.get 1
4:3      |15     i32.const 32
4:3      |17     i32.const 1
4:3      |19     call 21  ;; lox.closure
4:3      |21     local.set 2
5:10     |23     local.get 2
5:3      |25     return
5:3      |26     global.get 2  ;; nil
5:3      |28   end
)

(func 32 $inner (param lox)  ;; 4:7-4:39 captures local1
4:17     |0      i32.const 0
4:17     |2      call 20  ;; lox.upvalue
4:21     |4      i32.const 0
4:21     |6      call 20  ;; lox.upvalue
4:21     |8      call 18  ;; lox.cell_get
4:25     |10     global.get 3  ;; 1
4:21     |12     call 3  ;; lox.add
4:17     |14     call 19  ;; lox.cell_set
4:17     |16     drop
4:35     |17     i32.const 0
4:35     |19     call 20  ;; lox.upvalue
4:35     |21     call 18  ;; lox.cell_get
4:28     |23     return
4:28     |24     global.get 2  ;; nil
4:28     |26   end
)
